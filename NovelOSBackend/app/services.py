from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import mock_data
from app.agents.base import AgentResult
from app.agents.safety import highest_severity, summary_passed
from app.models import (
    AgentRunModel,
    AuditReportModel,
    BootstrapImportModel,
    ChapterModel,
    ContextPackModel,
    DraftModel,
    NovelModel,
)
from app.orchestrator import ChapterWorkflowOrchestrator

APPLE_REFERENCE_DATE = datetime(2001, 1, 1, tzinfo=timezone.utc)


def apple_timestamp_now() -> float:
    return (datetime.now(timezone.utc) - APPLE_REFERENCE_DATE).total_seconds()


def require_novel(session: Session, novel_id: str) -> NovelModel:
    novel = session.get(NovelModel, novel_id)
    if novel is None:
        raise HTTPException(status_code=404, detail=f"Novel not found: {novel_id}")
    return novel


def create_novel(session: Session, payload: dict) -> NovelModel:
    novel_id = payload.get("id") or f"novel_{uuid4().hex[:8]}"
    if session.get(NovelModel, novel_id) is not None:
        raise HTTPException(status_code=409, detail=f"Novel already exists: {novel_id}")
    novel = NovelModel(
        id=novel_id,
        title=payload["title"],
        genre=payload.get("genre"),
        current_chapter_no=payload.get("current_chapter_no"),
        current_canon_version=payload.get("current_canon_version"),
        bootstrap_status=payload.get("bootstrap_status") or "not_started",
    )
    session.add(novel)
    return novel


def update_novel(session: Session, novel_id: str, payload: dict) -> NovelModel:
    novel = require_novel(session, novel_id)
    for key, value in payload.items():
        if value is not None:
            setattr(novel, key, value)
    return novel


def require_chapter(session: Session, chapter_id: str) -> ChapterModel:
    chapter = session.get(ChapterModel, chapter_id)
    if chapter is None:
        raise HTTPException(status_code=404, detail=f"Chapter not found: {chapter_id}")
    return chapter


def require_context_pack(session: Session, chapter_id: str) -> ContextPackModel:
    context_pack = session.get(ContextPackModel, f"context_{chapter_id}")
    if context_pack is None:
        raise HTTPException(status_code=404, detail=f"Context Pack not found for chapter: {chapter_id}")
    return context_pack


def latest_draft(session: Session, chapter_id: str) -> DraftModel | None:
    return session.scalar(
        select(DraftModel)
        .where(DraftModel.chapter_id == chapter_id)
        .order_by(DraftModel.version_no.desc())
        .limit(1)
    )


def latest_audit_report(session: Session, chapter_id: str) -> AuditReportModel | None:
    return session.scalar(
        select(AuditReportModel)
        .where(AuditReportModel.chapter_id == chapter_id)
        .order_by(AuditReportModel.created_at.desc(), AuditReportModel.id.desc())
        .limit(1)
    )


def latest_bootstrap_import(session: Session, novel_id: str) -> BootstrapImportModel | None:
    return session.scalar(
        select(BootstrapImportModel)
        .where(BootstrapImportModel.novel_id == novel_id)
        .order_by(BootstrapImportModel.updated_at.desc(), BootstrapImportModel.id.desc())
        .limit(1)
    )


def bootstrap_status_payload(session: Session, novel: NovelModel) -> dict:
    import_row = latest_bootstrap_import(session, novel.id)
    chapters = import_row.chapters_payload if import_row else []
    return {
        "novel_id": novel.id,
        "status": novel.bootstrap_status,
        "import_id": import_row.id if import_row else None,
        "imported_chapter_count": len(chapters),
        "analysis_ready": bool(import_row and import_row.analysis_payload),
        "updated_at": import_row.updated_at if import_row else None,
    }


def import_first_three_chapters(
    session: Session,
    novel: NovelModel,
    chapters_payload: list[dict],
) -> dict:
    chapter_numbers = [int(chapter["chapter_no"]) for chapter in chapters_payload]
    if sorted(chapter_numbers) != [1, 2, 3]:
        raise HTTPException(status_code=400, detail="Bootstrap import requires exactly chapters 1, 2, and 3.")

    now = apple_timestamp_now()
    import_row = BootstrapImportModel(
        id=f"bootstrap_{novel.id}_{uuid4().hex[:8]}",
        novel_id=novel.id,
        status="imported",
        source_type="first_three_chapters",
        chapters_payload=chapters_payload,
        analysis_payload={},
        created_at=now,
        updated_at=now,
    )
    session.add(import_row)

    for chapter_payload in chapters_payload:
        chapter_no = int(chapter_payload["chapter_no"])
        chapter = session.scalar(
            select(ChapterModel).where(
                ChapterModel.novel_id == novel.id,
                ChapterModel.chapter_no == chapter_no,
            )
        )
        if chapter is None:
            chapter = ChapterModel(
                id=f"{novel.id}_chapter_{chapter_no:03}",
                novel_id=novel.id,
                chapter_no=chapter_no,
                title=chapter_payload.get("title"),
                status="imported",
                target_word_count=3000,
                approved_version_id=None,
                current_version_id=None,
                canon_version_used=novel.current_canon_version,
            )
            session.add(chapter)
        else:
            chapter.title = chapter_payload.get("title") or chapter.title
            chapter.status = "imported"

    novel.bootstrap_status = "imported"
    novel.current_chapter_no = max(novel.current_chapter_no or 0, 3)
    novel.current_canon_version = novel.current_canon_version or 1
    session.flush()
    return bootstrap_status_payload(session, novel)


def analyze_bootstrap_import(session: Session, novel: NovelModel) -> dict:
    import_row = latest_bootstrap_import(session, novel.id)
    if import_row is None:
        raise HTTPException(status_code=409, detail="Import the first three chapters before analysis.")

    result = ChapterWorkflowOrchestrator().run_bootstrap_analysis(
        novel_id=novel.id,
        chapters=import_row.chapters_payload,
    )
    import_row.analysis_payload = result.payload
    import_row.status = "analyzed"
    import_row.updated_at = apple_timestamp_now()
    novel.bootstrap_status = "analyzed"
    novel.current_chapter_no = max(novel.current_chapter_no or 0, 3)
    novel.current_canon_version = novel.current_canon_version or 1
    record_agent_result(
        session,
        run_id=f"{import_row.id}_import_agent",
        novel_id=novel.id,
        chapter_id=None,
        result=result,
        timestamp_label="bootstrap",
        input_payload={"import_id": import_row.id},
    )
    return {
        "novel_id": novel.id,
        "status": novel.bootstrap_status,
        "import_id": import_row.id,
        "analysis": import_row.analysis_payload,
    }


def ensure_structured_prompt(chapter: ChapterModel) -> dict:
    if chapter.structured_prompt:
        return dict(chapter.structured_prompt)

    prompt = dict(mock_data.STRUCTURED_PROMPT)
    prompt["chapter_id"] = chapter.id
    chapter.structured_prompt = prompt
    return prompt


def build_context_pack(chapter: ChapterModel) -> dict:
    return {
        "chapter_no": chapter.chapter_no,
        "allowed_named_entities": ["A", "B", "C", "旧码头", "旧案", "A 的母亲"],
        "active_entities": ["A", "B", "C"],
        "mention_allowed_entities": [
            {"name": "A 的母亲", "budget": 1, "form": "brief_memory"}
        ],
        "new_entity_policy": "allow_minor_unnamed_only",
        "knowledge_limits": [
            "A cannot know the full truth of the old case",
            "Narration cannot confirm B's full involvement",
        ],
        "forbidden_named_entities": ["D", "陌生角色", "新角色"],
    }


def upsert_agent_run(
    session: Session,
    *,
    run_id: str,
    chapter_id: str | None,
    novel_id: str | None = None,
    agent_name: str,
    summary: str,
    status: str,
    timestamp_label: str,
    run_type: str = "workflow",
    payload: dict | None = None,
    input_payload: dict | None = None,
    output_payload: dict | None = None,
    error_message: str | None = None,
    started_at: float | None = None,
    finished_at: float | None = None,
) -> AgentRunModel:
    now = apple_timestamp_now()
    run = session.get(AgentRunModel, run_id)
    values = {
        "novel_id": novel_id,
        "chapter_id": chapter_id,
        "agent_name": agent_name,
        "run_type": run_type,
        "summary": summary,
        "status": status,
        "timestamp_label": timestamp_label,
        "payload": payload or {},
        "input_payload": input_payload or {},
        "output_payload": output_payload if output_payload is not None else (payload or {}),
        "error_message": error_message,
        "started_at": started_at or now,
        "finished_at": finished_at or now,
        "created_at": now,
    }
    if run is None:
        run = AgentRunModel(id=run_id, **values)
        session.add(run)
    else:
        for key, value in values.items():
            setattr(run, key, value)
    return run


def record_agent_result(
    session: Session,
    *,
    run_id: str,
    novel_id: str | None,
    chapter_id: str | None,
    result: AgentResult,
    timestamp_label: str,
    input_payload: dict | None = None,
) -> AgentRunModel:
    return upsert_agent_run(
        session,
        run_id=run_id,
        novel_id=novel_id,
        chapter_id=chapter_id,
        agent_name=result.agent_name,
        run_type=result.run_type,
        summary=result.summary,
        status=result.status,
        timestamp_label=timestamp_label,
        payload=result.payload,
        input_payload=input_payload,
        output_payload=result.payload,
        error_message=result.error_message,
    )


def run_prompt_pipeline(session: Session, chapter: ChapterModel, prompt: str) -> dict:
    chapter.user_prompt = prompt
    context_payload = build_context_pack(chapter)
    orchestrator = ChapterWorkflowOrchestrator()
    results = orchestrator.run_prompt(
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        prompt=prompt,
        context_payload=context_payload,
    )
    structured_prompt = dict(results[-1].payload)
    chapter.structured_prompt = structured_prompt
    chapter.status = "structuredPromptReady"

    context_pack = session.get(ContextPackModel, f"context_{chapter.id}")
    if context_pack is None:
        context_pack = ContextPackModel(
            id=f"context_{chapter.id}",
            chapter_id=chapter.id,
            payload=context_payload,
            created_at=apple_timestamp_now(),
        )
        session.add(context_pack)
    else:
        context_pack.payload = context_payload
        context_pack.created_at = apple_timestamp_now()

    record_agent_result(
        session,
        run_id=f"{chapter.id}_intent_parser",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label="12:01",
        result=results[0],
        input_payload={"prompt": prompt},
    )
    record_agent_result(
        session,
        run_id=f"{chapter.id}_context_compiler",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label="12:02",
        result=results[1],
        input_payload={"prompt": prompt},
    )
    record_agent_result(
        session,
        run_id=f"{chapter.id}_prompt_expander",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label="12:04",
        result=results[2],
        input_payload={"prompt": prompt, "context_pack_id": context_pack.id},
    )
    return structured_prompt


def ensure_canon_patch(chapter: ChapterModel) -> dict:
    if chapter.canon_patch:
        return dict(chapter.canon_patch)

    patch = dict(mock_data.CANON_PATCH)
    patch["chapter_id"] = chapter.id
    chapter.canon_patch = patch
    return patch


def ensure_initial_draft(session: Session, chapter: ChapterModel) -> DraftModel:
    draft = latest_draft(session, chapter.id)
    if draft is not None:
        return draft

    chapter_number = f"{chapter.chapter_no:03}"
    draft = DraftModel(
        id=f"draft_{chapter_number}_v3",
        chapter_id=chapter.id,
        version_no=3,
        text=mock_data.DRAFT_TEXT,
        word_count=3120,
        audit_summary=mock_data.AUDIT_SUMMARY,
        source="initial_generation",
        created_at=apple_timestamp_now(),
    )
    session.add(draft)
    session.flush()
    return draft


def run_writing_agent(session: Session, chapter: ChapterModel) -> DraftModel:
    draft = ensure_initial_draft(session, chapter)
    chapter.status = "draftGenerated"
    chapter.current_version_id = draft.id
    result = ChapterWorkflowOrchestrator().run_writing(
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        draft=draft,
    )
    record_agent_result(
        session,
        run_id=f"{chapter.id}_writing_agent_v{draft.version_no}",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label="12:08",
        result=result,
        input_payload={"structured_prompt_id": (chapter.structured_prompt or {}).get("id")},
    )
    run_audit_pipeline(session, chapter, draft, timestamp_prefix="12:09")
    return draft


def audit_summary_has_s0(draft: DraftModel) -> bool:
    summary = draft.audit_summary or {}
    return int(summary.get("s0_count", 0)) > 0


def require_s0_free(draft: DraftModel) -> None:
    if audit_summary_has_s0(draft):
        raise HTTPException(status_code=409, detail="Draft has S0 audit issues and cannot be approved.")


def audit_result_payload(draft: DraftModel, auditor: str) -> dict:
    summary = draft.audit_summary or mock_data.AUDIT_SUMMARY
    if auditor == "named_entity":
        return {
            "illegal_named_entity_count": summary["illegal_named_entity_count"],
            "inactive_character_appearance_count": summary["inactive_character_appearance_count"],
            "new_named_entity_count": summary["new_named_entity_count"],
            "passed": summary["s0_count"] == 0,
        }
    if auditor == "knowledge":
        return {
            "knowledge_violation_count": summary["knowledge_violation_count"],
            "checked_limits": [
                "A cannot know the full truth of the old case",
                "Narration cannot confirm B's full involvement",
            ],
            "passed": summary["knowledge_violation_count"] == 0,
        }
    return {
        "s1_count": summary["s1_count"],
        "s2_count": summary["s2_count"],
        "issues": summary["issues"],
        "passed": summary["s0_count"] == 0,
    }


def run_audit_pipeline(
    session: Session,
    chapter: ChapterModel,
    draft: DraftModel,
    *,
    timestamp_prefix: str,
) -> AuditReportModel:
    session.flush()
    context_pack = session.get(ContextPackModel, f"context_{chapter.id}")
    context_payload = context_pack.payload if context_pack else build_context_pack(chapter)
    draft.audit_summary, results = ChapterWorkflowOrchestrator().run_audit(
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        draft_id=draft.id,
        draft_text=draft.text,
        context_payload=context_payload,
        base_summary=draft.audit_summary or mock_data.AUDIT_SUMMARY,
    )
    named_entity_result = dict(results[0].payload)
    knowledge_result = dict(results[1].payload)
    continuity_result = dict(results[2].payload)

    record_agent_result(
        session,
        run_id=f"{draft.id}_named_entity_auditor",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label=timestamp_prefix,
        result=results[0],
        input_payload={"draft_id": draft.id},
    )
    record_agent_result(
        session,
        run_id=f"{draft.id}_knowledge_auditor",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label=increment_timestamp(timestamp_prefix, 1),
        result=results[1],
        input_payload={"draft_id": draft.id},
    )
    record_agent_result(
        session,
        run_id=f"{draft.id}_continuity_auditor",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label=increment_timestamp(timestamp_prefix, 2),
        result=results[2],
        input_payload={"draft_id": draft.id},
    )

    report_id = f"audit_{draft.id}"
    report = session.get(AuditReportModel, report_id)
    values = {
        "chapter_id": chapter.id,
        "draft_id": draft.id,
        "named_entity_result": named_entity_result,
        "knowledge_result": knowledge_result,
        "continuity_result": continuity_result,
        "summary": draft.audit_summary,
        "passed": summary_passed(draft.audit_summary),
        "highest_severity": highest_severity(draft.audit_summary),
        "created_at": apple_timestamp_now(),
    }
    if report is None:
        report = AuditReportModel(id=report_id, **values)
        session.add(report)
    else:
        for key, value in values.items():
            setattr(report, key, value)
    return report


def increment_timestamp(label: str, minutes: int) -> str:
    hour, minute = label.split(":")
    total_minutes = int(hour) * 60 + int(minute) + minutes
    return f"{total_minutes // 60:02}:{total_minutes % 60:02}"


def create_revision(session: Session, chapter: ChapterModel, feedback: str | None) -> DraftModel:
    current = ensure_initial_draft(session, chapter)
    next_version = current.version_no + 1
    chapter_number = f"{chapter.chapter_no:03}"
    revision = DraftModel(
        id=f"draft_{chapter_number}_v{next_version}",
        chapter_id=chapter.id,
        version_no=next_version,
        text=mock_data.REVISED_DRAFT_TEXT,
        word_count=2980,
        audit_summary=mock_data.AUDIT_SUMMARY,
        source="revision_by_user_feedback",
        created_at=apple_timestamp_now(),
    )
    session.add(revision)
    chapter.current_version_id = revision.id
    chapter.status = "revisionRequired"
    result = ChapterWorkflowOrchestrator().run_revision(
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        current=current,
        revision=revision,
        feedback=feedback,
    )
    record_agent_result(
        session,
        run_id=f"{chapter.id}_revision_agent_v{next_version}",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        timestamp_label="12:12",
        result=result,
        input_payload={"from_draft_id": current.id, "feedback": feedback or ""},
    )
    run_audit_pipeline(session, chapter, revision, timestamp_prefix="12:13")
    return revision
