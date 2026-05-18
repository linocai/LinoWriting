from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import mock_data
from app.models import AgentRunModel, AuditReportModel, ChapterModel, ContextPackModel, DraftModel, NovelModel

APPLE_REFERENCE_DATE = datetime(2001, 1, 1, tzinfo=timezone.utc)


def apple_timestamp_now() -> float:
    return (datetime.now(timezone.utc) - APPLE_REFERENCE_DATE).total_seconds()


def require_novel(session: Session, novel_id: str) -> NovelModel:
    novel = session.get(NovelModel, novel_id)
    if novel is None:
        raise HTTPException(status_code=404, detail=f"Novel not found: {novel_id}")
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
    }


def upsert_agent_run(
    session: Session,
    *,
    run_id: str,
    chapter_id: str,
    agent_name: str,
    summary: str,
    status: str,
    timestamp_label: str,
    payload: dict | None = None,
) -> AgentRunModel:
    run = session.get(AgentRunModel, run_id)
    values = {
        "chapter_id": chapter_id,
        "agent_name": agent_name,
        "summary": summary,
        "status": status,
        "timestamp_label": timestamp_label,
        "payload": payload or {},
        "created_at": apple_timestamp_now(),
    }
    if run is None:
        run = AgentRunModel(id=run_id, **values)
        session.add(run)
    else:
        for key, value in values.items():
            setattr(run, key, value)
    return run


def run_prompt_pipeline(session: Session, chapter: ChapterModel, prompt: str) -> dict:
    chapter.user_prompt = prompt
    structured_prompt = dict(mock_data.STRUCTURED_PROMPT)
    structured_prompt["chapter_id"] = chapter.id
    chapter.structured_prompt = structured_prompt
    chapter.status = "structuredPromptReady"

    context_payload = build_context_pack(chapter)
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

    upsert_agent_run(
        session,
        run_id=f"{chapter.id}_intent_parser",
        chapter_id=chapter.id,
        agent_name="Intent Parser",
        summary="识别 A/B/C、旧码头、旧案、冷感基调。",
        status="pass",
        timestamp_label="12:01",
        payload={"prompt": prompt, "entities": ["A", "B", "C", "旧码头", "旧案"]},
    )
    upsert_agent_run(
        session,
        run_id=f"{chapter.id}_context_compiler",
        chapter_id=chapter.id,
        agent_name="Context Compiler",
        summary="生成 allowed names，隐藏非本章人物。",
        status="pass",
        timestamp_label="12:02",
        payload=context_payload,
    )
    upsert_agent_run(
        session,
        run_id=f"{chapter.id}_prompt_expander",
        chapter_id=chapter.id,
        agent_name="Prompt Expander",
        summary="生成结构化 Prompt。",
        status="ready_for_review",
        timestamp_label="12:04",
        payload=structured_prompt,
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
    upsert_agent_run(
        session,
        run_id=f"{chapter.id}_writing_agent_v{draft.version_no}",
        chapter_id=chapter.id,
        agent_name="Writing Agent",
        summary=f"生成正文 v{draft.version_no}，字数 {draft.word_count}，S0=0。",
        status="draft_generated",
        timestamp_label="12:08",
        payload={"draft_id": draft.id, "version_no": draft.version_no},
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
    draft.audit_summary = draft.audit_summary or mock_data.AUDIT_SUMMARY
    named_entity_result = audit_result_payload(draft, "named_entity")
    knowledge_result = audit_result_payload(draft, "knowledge")
    continuity_result = audit_result_payload(draft, "continuity")

    upsert_agent_run(
        session,
        run_id=f"{draft.id}_named_entity_auditor",
        chapter_id=chapter.id,
        agent_name="Named Entity Auditor",
        summary="检查非法命名实体、未激活人物和新增命名角色。",
        status="pass" if named_entity_result["passed"] else "block",
        timestamp_label=timestamp_prefix,
        payload={"draft_id": draft.id, **named_entity_result},
    )
    upsert_agent_run(
        session,
        run_id=f"{draft.id}_knowledge_auditor",
        chapter_id=chapter.id,
        agent_name="Knowledge Auditor",
        summary="检查 Knowledge Matrix 限制和旁白泄露风险。",
        status="pass" if knowledge_result["passed"] else "block",
        timestamp_label=increment_timestamp(timestamp_prefix, 1),
        payload={"draft_id": draft.id, **knowledge_result},
    )
    upsert_agent_run(
        session,
        run_id=f"{draft.id}_continuity_auditor",
        chapter_id=chapter.id,
        agent_name="Continuity Auditor",
        summary=f"S0={draft.audit_summary['s0_count']}，S1={draft.audit_summary['s1_count']}，S2={draft.audit_summary['s2_count']}。",
        status="suggest" if draft.audit_summary["s1_count"] or draft.audit_summary["s2_count"] else "pass",
        timestamp_label=increment_timestamp(timestamp_prefix, 2),
        payload={"draft_id": draft.id, **continuity_result},
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
    upsert_agent_run(
        session,
        run_id=f"{chapter.id}_revision_agent_v{next_version}",
        chapter_id=chapter.id,
        agent_name="Revision Agent",
        summary=f"按用户意见生成 v{next_version}，保留正文审核步骤。",
        status="revision_generated",
        timestamp_label="12:12",
        payload={
            "from_draft_id": current.id,
            "draft_id": revision.id,
            "feedback": feedback or "",
            "version_no": next_version,
        },
    )
    run_audit_pipeline(session, chapter, revision, timestamp_prefix="12:13")
    return revision
