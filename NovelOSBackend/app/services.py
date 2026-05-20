from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import config, mock_data
from app.agents.base import AgentResult
from app.agents.safety import highest_severity, summary_passed
from app.errors import llm_error_detail
from app.llm.gateway import LLMGatewayError
from app.models import (
    AgentRunModel,
    AuditReportModel,
    BootstrapImportModel,
    CanonEditHistoryModel,
    CanonUpdatePatchModel,
    CharacterCardModel,
    ChapterModel,
    ContextPackModel,
    DraftModel,
    KnowledgeMatrixEntryModel,
    MemoryFactModel,
    NovelModel,
    StructuredPromptModel,
    WorldBibleSectionModel,
)
from app.orchestrator import ChapterWorkflowOrchestrator

APPLE_REFERENCE_DATE = datetime(2001, 1, 1, tzinfo=timezone.utc)


def apple_timestamp_now() -> float:
    return (datetime.now(timezone.utc) - APPLE_REFERENCE_DATE).total_seconds()


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


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
        status=payload.get("status") or "active",
        language=payload.get("language") or "zh-Hans",
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


def create_chapter(session: Session, novel: NovelModel, payload: dict) -> ChapterModel:
    chapter_no = int(payload["chapter_no"])
    existing = session.scalar(
        select(ChapterModel).where(
            ChapterModel.novel_id == novel.id,
            ChapterModel.chapter_no == chapter_no,
        )
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail=f"Chapter already exists: {chapter_no}")
    chapter = ChapterModel(
        id=payload.get("id") or f"{novel.id}_chapter_{chapter_no:03}",
        novel_id=novel.id,
        chapter_no=chapter_no,
        title=payload.get("title"),
        status="draftInput",
        target_word_count=int(payload.get("target_word_count") or 3000),
        approved_version_id=None,
        current_version_id=None,
        canon_version_used=novel.current_canon_version,
    )
    session.add(chapter)
    novel.current_chapter_no = max(novel.current_chapter_no or 0, chapter_no)
    return chapter


def require_chapter(session: Session, chapter_id: str) -> ChapterModel:
    chapter = session.get(ChapterModel, chapter_id)
    if chapter is None:
        raise HTTPException(status_code=404, detail=f"Chapter not found: {chapter_id}")
    return chapter


def require_context_pack(session: Session, chapter_id: str) -> ContextPackModel:
    context_pack = latest_context_pack(session, chapter_id)
    if context_pack is None:
        raise HTTPException(status_code=404, detail=f"Context Pack not found for chapter: {chapter_id}")
    return context_pack


def import_storage_dir() -> Path:
    return Path(os.getenv("NOVEL_OS_IMPORT_STORAGE_DIR", "data/imports"))


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


def latest_context_pack(session: Session, chapter_id: str) -> ContextPackModel | None:
    return session.scalar(
        select(ContextPackModel)
        .where(ContextPackModel.chapter_id == chapter_id)
        .order_by(ContextPackModel.created_at.desc(), ContextPackModel.id.desc())
        .limit(1)
    )


def latest_structured_prompt(session: Session, chapter_id: str) -> StructuredPromptModel | None:
    return session.scalar(
        select(StructuredPromptModel)
        .where(StructuredPromptModel.chapter_id == chapter_id)
        .order_by(StructuredPromptModel.version.desc(), StructuredPromptModel.created_at.desc())
        .limit(1)
    )


def latest_canon_patch(session: Session, chapter_id: str) -> CanonUpdatePatchModel | None:
    return session.scalar(
        select(CanonUpdatePatchModel)
        .where(CanonUpdatePatchModel.chapter_id == chapter_id)
        .order_by(CanonUpdatePatchModel.created_at.desc(), CanonUpdatePatchModel.id.desc())
        .limit(1)
    )


def latest_agent_run(session: Session, chapter_id: str, agent_name: str) -> AgentRunModel | None:
    return session.scalar(
        select(AgentRunModel)
        .where(
            AgentRunModel.chapter_id == chapter_id,
            AgentRunModel.agent_name == agent_name,
        )
        .order_by(AgentRunModel.created_at.desc(), AgentRunModel.id.desc())
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
    storage_dir = import_storage_dir()
    storage_dir.mkdir(parents=True, exist_ok=True)
    import_id = f"bootstrap_{novel.id}_{uuid4().hex[:8]}"
    storage_path = storage_dir / f"{import_id}.json"
    storage_path.write_text(
        json.dumps({"novel_id": novel.id, "chapters": chapters_payload}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    import_row = BootstrapImportModel(
        id=import_id,
        novel_id=novel.id,
        status="imported",
        source_type="first_three_chapters",
        storage_path=str(storage_path),
        chapters_payload=chapters_payload,
        analysis_payload={},
        created_at=now,
        updated_at=now,
    )
    session.add(import_row)

    canon_version = novel.current_canon_version or 1
    novel.current_canon_version = canon_version
    for chapter_payload in chapters_payload:
        chapter_no = int(chapter_payload["chapter_no"])
        text = chapter_payload["text"].strip()
        word_count = len(text)
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
                status="completed",
                target_word_count=max(3000, word_count),
                approved_version_id=None,
                current_version_id=None,
                canon_version_used=canon_version,
            )
            session.add(chapter)
        else:
            chapter.title = chapter_payload.get("title") or chapter.title
            chapter.status = "completed"
            chapter.target_word_count = max(chapter.target_word_count, word_count)
            chapter.canon_version_used = chapter.canon_version_used or canon_version

        draft = session.scalar(
            select(DraftModel).where(
                DraftModel.chapter_id == chapter.id,
                DraftModel.version_no == 1,
            )
        )
        if draft is None:
            draft = DraftModel(
                id=f"{chapter.id}_import_v1",
                chapter_id=chapter.id,
                version_no=1,
                text=text,
                word_count=word_count,
                audit_summary=None,
                source="imported_source",
                created_at=now,
            )
            session.add(draft)
        else:
            draft.text = text
            draft.word_count = word_count
            draft.source = "imported_source"
            draft.created_at = now

        chapter.current_version_id = draft.id
        chapter.approved_version_id = draft.id

    novel.bootstrap_status = "imported"
    novel.current_chapter_no = max(novel.current_chapter_no or 0, 3)
    session.flush()
    return bootstrap_status_payload(session, novel)


def analyze_bootstrap_import(session: Session, novel: NovelModel) -> dict:
    import_row = latest_bootstrap_import(session, novel.id)
    if import_row is None:
        raise HTTPException(status_code=409, detail="Import the first three chapters before analysis.")

    try:
        result = ChapterWorkflowOrchestrator().run_bootstrap_analysis(
            novel_id=novel.id,
            chapters=import_row.chapters_payload,
        )
    except LLMGatewayError as exc:
        fail_agent_run(
            session,
            run_id=f"{import_row.id}_import_agent_failed",
            novel_id=novel.id,
            chapter_id=None,
            agent_name="Import Agent",
            run_type="bootstrap",
            input_payload={"import_id": import_row.id, "chapter_count": len(import_row.chapters_payload)},
            error=exc,
        )
    import_row.analysis_payload = result.payload
    apply_bootstrap_canon_analysis(session, novel, result.payload)
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
        input_payload={"import_id": import_row.id},
    )
    return {
        "novel_id": novel.id,
        "status": novel.bootstrap_status,
        "import_id": import_row.id,
        "analysis": import_row.analysis_payload,
    }


def apply_bootstrap_canon_analysis(session: Session, novel: NovelModel, analysis: dict) -> None:
    now = apple_timestamp_now()
    canon_version = novel.current_canon_version or 1
    novel.current_canon_version = canon_version

    character_id_by_name: dict[str, str] = {}
    for index, item in enumerate(_dict_items(analysis.get("character_cards"))):
        name = _text(item.get("name")) or f"角色 {index + 1}"
        character_id = _stable_doc_id(novel.id, "char", name)
        character_id_by_name[name] = character_id
        relationships = [
            {
                "id": _text(rel.get("id")) or _stable_doc_id(character_id, "rel", rel.get("target_character_name") or rel.get("target_name") or index),
                "target_character_name": _text(rel.get("target_character_name") or rel.get("target_name")),
                "relationship_summary": _text(rel.get("relationship_summary") or rel.get("summary")),
                "current_tension": _optional_text(rel.get("current_tension")),
                "last_changed_chapter_no": _optional_int(rel.get("last_changed_chapter_no")),
            }
            for index, rel in enumerate(_dict_items(item.get("relationships")))
            if _text(rel.get("target_character_name") or rel.get("target_name"))
        ]
        payload = {
            "id": character_id,
            "novel_id": novel.id,
            "name": name,
            "aliases": _string_list(item.get("aliases")),
            "role": _text(item.get("role"), "未分类人物"),
            "stable_traits": _string_list(item.get("stable_traits")),
            "current_state": _summary_dict(item.get("current_state")),
            "dialogue_style": _summary_dict(item.get("dialogue_style")),
            "knowledge_summary": _plain_dict(item.get("knowledge_summary")),
            "do_not_auto_mention": bool(item.get("do_not_auto_mention") or False),
            "default_visibility": _text(item.get("default_visibility"), "manual_only"),
            "relationships": relationships,
            "forbidden_behavior": _string_list(item.get("forbidden_behavior")),
            "last_active_chapter_no": _optional_int(item.get("last_active_chapter_no")),
            "canon_version": canon_version,
        }
        _upsert_character_card(session, payload)

    for item in _dict_items(analysis.get("world_bible_sections")):
        title = _text(item.get("title")) or "未命名基础设定"
        section_key = _optional_text(item.get("section_key"))
        payload = {
            "id": _stable_doc_id(novel.id, "wb", section_key or title),
            "novel_id": novel.id,
            "section_key": section_key,
            "title": title,
            "content": _text(item.get("content") or item.get("summary")),
            "tags": _string_list(item.get("tags")),
            "importance": _choice(item.get("importance"), {"low", "medium", "high", "critical"}, "medium"),
            "activation_policy": _choice(
                item.get("activation_policy"),
                {"always_in_context_brief", "always_considered", "tag_matched", "manual_only"},
                "tag_matched",
            ),
            "canon_version": canon_version,
            "updated_at": now,
        }
        _upsert_model(session, WorldBibleSectionModel, payload)

    for index, item in enumerate(_dict_items(analysis.get("memory_facts"))):
        chapter_no = _optional_int(item.get("chapter_no")) or 1
        summary = _text(item.get("summary")) or f"第 {chapter_no} 章导入事实"
        payload = {
            "id": _text(item.get("id")) or _stable_doc_id(novel.id, "mem", chapter_no, summary),
            "novel_id": novel.id,
            "chapter_no": chapter_no,
            "fact_type": _text(item.get("fact_type"), "event"),
            "time_in_story": _optional_text(item.get("time_in_story")),
            "summary": summary,
            "participants": _string_list(item.get("participants")),
            "location": _optional_text(item.get("location")),
            "evidence": _text(item.get("evidence"), f"前三章导入分析 #{index + 1}"),
            "canon_status": _text(item.get("canon_status"), "confirmed"),
            "canon_version": canon_version,
            "metadata_json": _plain_dict(item.get("metadata")),
            "created_by": _text(item.get("created_by"), "import_agent"),
        }
        _upsert_model(session, MemoryFactModel, payload)

    for item in _dict_items(analysis.get("knowledge_matrix")):
        fact_title = _text(item.get("fact_title") or item.get("title")) or "未命名知识条目"
        character_knowledge = []
        visibility = {
            "author": _knowledge_state(item.get("author_knowledge"), "known"),
            "reader": _knowledge_state(item.get("reader_knowledge"), "reader_unknown"),
        }
        for rel in _dict_items(item.get("character_knowledge")):
            character_name = _text(rel.get("character_name") or rel.get("name"))
            character_id = _text(rel.get("character_id")) or character_id_by_name.get(character_name)
            if not character_name and character_id:
                character_name = character_id
            if character_name and not character_id:
                character_id = _stable_doc_id(novel.id, "char", character_name)
            if character_id and character_name:
                state = _knowledge_state(rel.get("state"), "unknown")
                visibility[character_id] = state
                character_knowledge.append(
                    {
                        "character_id": character_id,
                        "character_name": character_name,
                        "state": state,
                    }
                )
        payload = {
            "id": _text(item.get("id")) or _stable_doc_id(novel.id, "km", fact_title),
            "novel_id": novel.id,
            "fact": _optional_text(item.get("fact")) or fact_title,
            "fact_title": fact_title,
            "truth_status": _text(item.get("truth_status"), "confirmed"),
            "author_knowledge": visibility["author"],
            "reader_knowledge": visibility["reader"],
            "character_knowledge": character_knowledge,
            "visibility": visibility,
            "allowed_narration": _summary_dict(item.get("allowed_narration")),
            "canon_version": canon_version,
        }
        _upsert_model(session, KnowledgeMatrixEntryModel, payload)


def _upsert_model(session: Session, model_class, payload: dict) -> None:
    row = session.get(model_class, payload["id"])
    if row is None:
        session.add(model_class(**payload))
        return
    for key, value in payload.items():
        if key != "id":
            setattr(row, key, value)


def _upsert_character_card(session: Session, payload: dict) -> None:
    row = session.get(CharacterCardModel, payload["id"]) or session.scalar(
        select(CharacterCardModel).where(
            CharacterCardModel.novel_id == payload["novel_id"],
            CharacterCardModel.name == payload["name"],
        )
    )
    if row is None:
        session.add(CharacterCardModel(**payload))
        return
    for key, value in payload.items():
        if key != "id":
            setattr(row, key, value)


def _dict_items(value: object) -> list[dict]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _text(value: object, default: str = "") -> str:
    if value is None:
        return default
    if isinstance(value, str):
        stripped = value.strip()
        return stripped if stripped else default
    if isinstance(value, (int, float, bool)):
        return str(value)
    if isinstance(value, dict):
        for key in ("summary", "text", "content", "value"):
            if key in value:
                return _text(value.get(key), default)
    return default


def _optional_text(value: object) -> str | None:
    text = _text(value)
    return text or None


def _optional_int(value: object) -> int | None:
    try:
        if value is None or value == "":
            return None
        return int(value)
    except (TypeError, ValueError):
        return None


def _string_list(value: object) -> list[str]:
    if isinstance(value, list):
        return [_text(item) for item in value if _text(item)]
    text = _text(value)
    return [text] if text else []


def _plain_dict(value: object) -> dict:
    return dict(value) if isinstance(value, dict) else {}


def _summary_dict(value: object) -> dict:
    if isinstance(value, dict):
        return dict(value)
    return {"summary": _text(value)}


def _choice(value: object, allowed: set[str], default: str) -> str:
    text = _text(value).lower()
    return text if text in allowed else default


def _knowledge_state(value: object, default: str) -> str:
    aliases = {
        "reader known": "reader_known",
        "reader unknown": "reader_unknown",
        "author only": "author_only",
        "may know": "may_know",
        "strongly suspects": "strongly_suspects",
    }
    allowed = {
        "known",
        "unknown",
        "suspects",
        "hinted",
        "partial",
        "may_know",
        "reader_known",
        "reader_unknown",
        "author_only",
        "strongly_suspects",
    }
    text = _text(value).strip().lower().replace("-", "_")
    text = aliases.get(text, text)
    return text if text in allowed else default


def _stable_doc_id(*parts: object) -> str:
    prefix = "_".join(_safe_id_part(part) for part in parts[:2] if _safe_id_part(part)) or "doc"
    digest = hashlib.sha1("|".join(str(part) for part in parts).encode("utf-8")).hexdigest()[:10]
    return f"{prefix}_{digest}"


def _safe_id_part(value: object) -> str:
    text = "".join(char.lower() if char.isalnum() else "_" for char in str(value or ""))
    return "_".join(part for part in text.split("_") if part)[:32]


def ensure_structured_prompt(session: Session, chapter: ChapterModel) -> dict:
    row = latest_structured_prompt(session, chapter.id)
    if row is not None:
        chapter.structured_prompt = row.payload
        return dict(row.payload)

    if chapter.structured_prompt:
        prompt = dict(chapter.structured_prompt)
        _upsert_structured_prompt(session, chapter, prompt, status="draft")
        return prompt

    prompt = dict(mock_data.STRUCTURED_PROMPT)
    prompt["chapter_id"] = chapter.id
    chapter.structured_prompt = prompt
    _upsert_structured_prompt(session, chapter, prompt, status="draft")
    return prompt


def _upsert_structured_prompt(
    session: Session,
    chapter: ChapterModel,
    prompt: dict,
    *,
    status: str,
) -> StructuredPromptModel:
    version = int(prompt.get("version", 1))
    row = session.scalar(
        select(StructuredPromptModel).where(
            StructuredPromptModel.chapter_id == chapter.id,
            StructuredPromptModel.version == version,
        )
    )
    values = {
        "chapter_id": chapter.id,
        "version": version,
        "payload": prompt,
        "status": status,
        "created_by": "prompt_expander",
        "created_at": apple_timestamp_now(),
    }
    if row is None:
        row = StructuredPromptModel(id=prompt.get("id") or f"sp_{chapter.id}_v{version}", **values)
        session.add(row)
    else:
        for key, value in values.items():
            setattr(row, key, value)
    return row


def save_structured_prompt(
    session: Session,
    chapter: ChapterModel,
    prompt: dict,
    *,
    status: str = "ready_for_review",
) -> StructuredPromptModel:
    chapter.structured_prompt = prompt
    return _upsert_structured_prompt(session, chapter, prompt, status=status)


def build_context_pack(session: Session, chapter: ChapterModel) -> dict:
    characters = session.scalars(
        select(CharacterCardModel)
        .where(CharacterCardModel.novel_id == chapter.novel_id)
        .order_by(CharacterCardModel.id)
    ).all()
    world_sections = session.scalars(
        select(WorldBibleSectionModel)
        .where(WorldBibleSectionModel.novel_id == chapter.novel_id)
        .order_by(WorldBibleSectionModel.id)
    ).all()
    memory_facts = session.scalars(
        select(MemoryFactModel)
        .where(MemoryFactModel.novel_id == chapter.novel_id)
        .order_by(MemoryFactModel.chapter_no, MemoryFactModel.id)
    ).all()
    knowledge_entries = session.scalars(
        select(KnowledgeMatrixEntryModel)
        .where(KnowledgeMatrixEntryModel.novel_id == chapter.novel_id)
        .order_by(KnowledgeMatrixEntryModel.id)
    ).all()

    active_entities = [character.name for character in characters if not character.do_not_auto_mention]
    location_names = sorted({fact.location for fact in memory_facts if fact.location})
    allowed_names = [*active_entities, *location_names, "旧案", "A 的母亲"]
    knowledge_limits = []
    for entry in knowledge_entries:
        narration = entry.allowed_narration
        if isinstance(narration, dict):
            text = narration.get("text")
        else:
            text = str(narration)
        if text:
            knowledge_limits.append(text)

    forbidden_named_entities = ["陌生角色", "新角色"]
    if chapter.novel_id == mock_data.NOVEL["id"]:
        forbidden_named_entities.insert(0, "D")

    return {
        "chapter_no": chapter.chapter_no,
        "canon_version": chapter.canon_version_used or 1,
        "allowed_named_entities": allowed_names,
        "active_entities": active_entities,
        "mention_allowed_entities": [
            {"name": "A 的母亲", "budget": 1, "form": "brief_memory"}
        ],
        "new_entity_policy": "allow_minor_unnamed_only",
        "knowledge_limits": knowledge_limits,
        "forbidden_named_entities": forbidden_named_entities,
        "world_bible": [
            {"title": section.title, "content": section.content, "tags": section.tags}
            for section in world_sections
        ],
        "memory": [
            {"chapter_no": fact.chapter_no, "summary": fact.summary, "participants": fact.participants}
            for fact in memory_facts
        ],
        "knowledge_matrix": [
            {
                "fact": entry.fact or entry.fact_title,
                "truth_status": entry.truth_status,
                "visibility": entry.visibility or {},
                "allowed_narration": entry.allowed_narration,
            }
            for entry in knowledge_entries
        ],
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
    run_type: str = "workflow",
    model: str | None = "mock",
    payload: dict | None = None,
    input_payload: dict | None = None,
    output_payload: dict | None = None,
    token_usage: dict | None = None,
    error_message: str | None = None,
    started_at: float | None = None,
    completed_at: datetime | None = None,
) -> AgentRunModel:
    now = apple_timestamp_now()
    resolved_input = input_payload or {}
    resolved_output = output_payload if output_payload is not None else (payload or {})
    run = session.get(AgentRunModel, run_id)
    values = {
        "novel_id": novel_id,
        "chapter_id": chapter_id,
        "agent_name": agent_name,
        "run_type": run_type,
        "model": model,
        "summary": summary,
        "status": status,
        "payload": payload or {},
        "input_payload": resolved_input,
        "output_payload": resolved_output,
        "input_json": resolved_input,
        "output_json": resolved_output,
        "token_usage": token_usage or {},
        "error_message": error_message,
        "started_at": started_at or now,
        "completed_at": completed_at or utc_now(),
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
    input_payload: dict | None = None,
) -> AgentRunModel:
    return upsert_agent_run(
        session,
        run_id=run_id,
        novel_id=novel_id,
        chapter_id=chapter_id,
        agent_name=result.agent_name,
        run_type=result.run_type,
        model=result.model or "mock",
        summary=result.summary,
        status=result.status,
        payload=result.payload,
        input_payload=input_payload,
        output_payload=result.payload,
        token_usage=result.token_usage or {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
        error_message=result.error_message,
    )


def fail_agent_run(
    session: Session,
    *,
    run_id: str,
    novel_id: str | None,
    chapter_id: str | None,
    agent_name: str,
    run_type: str,
    input_payload: dict | None,
    error: Exception,
) -> None:
    detail = llm_error_detail(error)
    upsert_agent_run(
        session,
        run_id=run_id,
        novel_id=novel_id,
        chapter_id=chapter_id,
        agent_name=agent_name,
        run_type=run_type,
        model=config.active_llm_provider().model if config.active_llm_provider() else config.openai_compatible_model(),
        summary=detail,
        status="failed",
        payload={"retryable": True},
        input_payload=input_payload or {},
        output_payload={},
        token_usage={},
        error_message=detail,
    )
    session.commit()
    raise HTTPException(status_code=502, detail=detail)


def run_prompt_pipeline(session: Session, chapter: ChapterModel, prompt: str) -> dict:
    chapter.user_prompt = prompt
    context_payload = build_context_pack(session, chapter)
    orchestrator = ChapterWorkflowOrchestrator()
    try:
        results = orchestrator.run_prompt(
            novel_id=chapter.novel_id,
            chapter_id=chapter.id,
            prompt=prompt,
            context_payload=context_payload,
        )
    except LLMGatewayError as exc:
        fail_agent_run(
            session,
            run_id=f"{chapter.id}_prompt_pipeline_failed",
            novel_id=chapter.novel_id,
            chapter_id=chapter.id,
            agent_name="Prompt Pipeline",
            run_type="prompt",
            input_payload={"prompt": prompt, "context_payload": context_payload},
            error=exc,
        )
    structured_prompt = dict(results[-1].payload)
    chapter.structured_prompt = structured_prompt
    chapter.status = "structuredPromptReady"

    structured_row = _upsert_structured_prompt(session, chapter, structured_prompt, status="ready_for_review")
    now = apple_timestamp_now()
    context_pack = ContextPackModel(
        id=f"context_{chapter.id}_{uuid4().hex[:8]}",
        chapter_id=chapter.id,
        canon_version=chapter.canon_version_used or 1,
        payload=context_payload,
        created_at=now,
    )
    session.add(context_pack)

    record_agent_result(
        session,
        run_id=f"{chapter.id}_intent_parser",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=results[0],
        input_payload={"prompt": prompt},
    )
    record_agent_result(
        session,
        run_id=f"{chapter.id}_context_compiler",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=results[1],
        input_payload={"prompt": prompt},
    )
    record_agent_result(
        session,
        run_id=f"{chapter.id}_prompt_expander",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=results[2],
        input_payload={"prompt": prompt, "context_pack_id": context_pack.id, "structured_prompt_id": structured_row.id},
    )
    return structured_prompt


def ensure_canon_patch(session: Session, chapter: ChapterModel) -> dict:
    row = latest_canon_patch(session, chapter.id)
    if row is not None:
        if _should_replace_seed_canon_patch(chapter, row.payload, row.status):
            patch = _build_canon_patch_from_extraction(session, chapter)
            row.id = patch["id"]
            row.target_canon_version = int(patch["target_canon_version"])
            row.status = "pending_user_confirmation"
            row.payload = patch
            row.created_at = apple_timestamp_now()
            row.confirmed_at = None
            chapter.canon_patch = patch
            return patch
        chapter.canon_patch = row.payload
        return dict(row.payload)

    if chapter.canon_patch:
        patch = dict(chapter.canon_patch)
        if _should_replace_seed_canon_patch(chapter, patch):
            patch = _build_canon_patch_from_extraction(session, chapter)
        _upsert_canon_patch(session, chapter, patch)
        return patch

    if _uses_seed_canon_patch(chapter):
        patch = dict(mock_data.CANON_PATCH)
        patch["chapter_id"] = chapter.id
    else:
        patch = _build_canon_patch_from_extraction(session, chapter)
    chapter.canon_patch = patch
    _upsert_canon_patch(session, chapter, patch)
    return patch


def _uses_seed_canon_patch(chapter: ChapterModel) -> bool:
    return config.llm_mode() != "live" and chapter.novel_id == mock_data.NOVEL["id"]


def _patch_looks_like_seed_canon_patch(patch: dict) -> bool:
    if not isinstance(patch, dict):
        return False
    if patch.get("id") == mock_data.CANON_PATCH["id"]:
        return True
    summaries = " ".join(_text(item.get("summary")) for item in _dict_items(patch.get("items")))
    return "旧码头" in summaries and "A" in summaries and "B" in summaries and "C" in summaries


def _should_replace_seed_canon_patch(
    chapter: ChapterModel,
    patch: dict,
    status: str | None = None,
) -> bool:
    return (
        chapter.novel_id != mock_data.NOVEL["id"]
        and status != "confirmed"
        and _patch_looks_like_seed_canon_patch(patch)
    )


def _build_canon_patch_from_extraction(session: Session, chapter: ChapterModel) -> dict:
    novel = require_novel(session, chapter.novel_id)
    extraction_run = latest_agent_run(session, chapter.id, "Extraction Agent")
    extraction_payload = extraction_run.payload if extraction_run else {}
    base_version = max(
        int(novel.current_canon_version or 1),
        int(chapter.canon_version_used or 1),
    )
    patch_id = f"patch_{chapter.id}"
    items: list[dict] = []
    items.extend(
        _canon_patch_items(
            patch_id=patch_id,
            target="Memory",
            title="新增章节事实",
            values=extraction_payload.get("candidate_facts"),
        )
    )
    items.extend(
        _canon_patch_items(
            patch_id=patch_id,
            target="Knowledge",
            title="更新 Knowledge Matrix",
            values=extraction_payload.get("knowledge_entries"),
        )
    )
    items.extend(
        _canon_patch_items(
            patch_id=patch_id,
            target="WorldBible",
            title="补充世界设定",
            values=extraction_payload.get("world_bible_updates"),
        )
    )
    items.extend(
        _canon_patch_items(
            patch_id=patch_id,
            target="Character",
            title="更新人物状态",
            values=extraction_payload.get("character_updates"),
        )
    )
    if not items:
        draft = latest_draft(session, chapter.id)
        fallback = _text(draft.text[:220] if draft else "")
        if fallback:
            items.append(
                _canon_patch_item(
                    patch_id=patch_id,
                    target="Memory",
                    title="新增章节事实",
                    summary=fallback,
                    index=1,
                )
            )
    return {
        "id": patch_id,
        "chapter_id": chapter.id,
        "target_canon_version": base_version + 1,
        "items": items,
    }


def _canon_patch_items(*, patch_id: str, target: str, title: str, values: object) -> list[dict]:
    return [
        _canon_patch_item(
            patch_id=patch_id,
            target=target,
            title=title if len(_string_list(values)) == 1 else f"{title} {index}",
            summary=summary,
            index=index,
        )
        for index, summary in enumerate(_string_list(values), start=1)
    ]


def _canon_patch_item(
    *,
    patch_id: str,
    target: str,
    title: str,
    summary: str,
    index: int,
) -> dict:
    item_id = _stable_doc_id(patch_id, target.lower(), index, summary)
    return {
        "id": item_id,
        "target": target,
        "title": title,
        "summary": summary,
        "proposed_action": "accept",
        "editable_payload": summary,
    }


def _upsert_canon_patch(session: Session, chapter: ChapterModel, patch: dict) -> CanonUpdatePatchModel:
    row = session.get(CanonUpdatePatchModel, patch["id"])
    values = {
        "chapter_id": chapter.id,
        "target_canon_version": int(patch["target_canon_version"]),
        "status": "pending_user_confirmation",
        "payload": patch,
        "created_at": apple_timestamp_now(),
    }
    if row is None:
        row = CanonUpdatePatchModel(id=patch["id"], **values)
        session.add(row)
    else:
        for key, value in values.items():
            setattr(row, key, value)
    return row


def save_canon_patch(session: Session, chapter: ChapterModel, patch: dict) -> CanonUpdatePatchModel:
    chapter.canon_patch = patch
    return _upsert_canon_patch(session, chapter, patch)


def ensure_initial_draft(session: Session, chapter: ChapterModel) -> DraftModel:
    draft = latest_draft(session, chapter.id)
    if draft is not None:
        return draft

    chapter_number = f"{chapter.chapter_no:03}"
    draft_id = (
        f"draft_{chapter_number}_v3"
        if chapter.novel_id == mock_data.NOVEL["id"]
        else f"{chapter.id}_draft_v3"
    )
    draft = DraftModel(
        id=draft_id,
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
    context_pack = latest_context_pack(session, chapter.id)
    context_payload = context_pack.payload if context_pack else build_context_pack(session, chapter)
    if config.llm_mode() == "live" and latest_draft(session, chapter.id) is None:
        structured_prompt = ensure_structured_prompt(session, chapter)
        try:
            result = ChapterWorkflowOrchestrator().run_writing(
                novel_id=chapter.novel_id,
                chapter_id=chapter.id,
                draft=None,
                chapter=chapter,
                structured_prompt=structured_prompt,
                context_payload=context_payload,
            )
        except LLMGatewayError as exc:
            fail_agent_run(
                session,
                run_id=f"{chapter.id}_writing_agent_failed",
                novel_id=chapter.novel_id,
                chapter_id=chapter.id,
                agent_name="Writing Agent",
                run_type="draft",
                input_payload={
                    "structured_prompt": structured_prompt,
                    "context_payload": context_payload,
                },
                error=exc,
            )
        draft = DraftModel(
            id=f"{chapter.id}_draft_v1",
            chapter_id=chapter.id,
            version_no=1,
            text=result.payload["text"],
            word_count=int(result.payload.get("word_count") or len(result.payload["text"])),
            audit_summary=None,
            source="initial_generation",
            created_at=apple_timestamp_now(),
        )
        session.add(draft)
        session.flush()
    else:
        draft = ensure_initial_draft(session, chapter)
        result = ChapterWorkflowOrchestrator().run_writing(
            novel_id=chapter.novel_id,
            chapter_id=chapter.id,
            draft=draft,
        )
    chapter.status = "draftGenerated"
    chapter.current_version_id = draft.id
    record_agent_result(
        session,
        run_id=f"{chapter.id}_writing_agent_v{draft.version_no}",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=result,
        input_payload={"structured_prompt_id": (chapter.structured_prompt or {}).get("id")},
    )
    run_audit_pipeline(session, chapter, draft, timestamp_prefix="12:09")
    return draft


def run_extraction_agent(session: Session, chapter: ChapterModel, draft: DraftModel) -> AgentRunModel:
    try:
        result = ChapterWorkflowOrchestrator().run_extraction(
            novel_id=chapter.novel_id,
            chapter_id=chapter.id,
            draft=draft,
        )
    except LLMGatewayError as exc:
        fail_agent_run(
            session,
            run_id=f"{draft.id}_extraction_agent_failed",
            novel_id=chapter.novel_id,
            chapter_id=chapter.id,
            agent_name="Extraction Agent",
            run_type="canon",
            input_payload={"draft_id": draft.id},
            error=exc,
        )
    run = record_agent_result(
        session,
        run_id=f"{draft.id}_extraction_agent",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=result,
        input_payload={"draft_id": draft.id},
    )
    session.flush()
    return run


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
    context_pack = latest_context_pack(session, chapter.id)
    context_payload = context_pack.payload if context_pack else build_context_pack(session, chapter)
    base_summary = (
        mock_data.AUDIT_SUMMARY
        if config.llm_mode() != "live" and chapter.novel_id == mock_data.NOVEL["id"]
        else None
    )
    draft.audit_summary, results = ChapterWorkflowOrchestrator().run_audit(
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        draft_id=draft.id,
        draft_text=draft.text,
        context_payload=context_payload,
        base_summary=base_summary,
    )
    named_entity_result = dict(results[0].payload)
    knowledge_result = dict(results[1].payload)
    continuity_result = dict(results[2].payload)

    record_agent_result(
        session,
        run_id=f"{draft.id}_named_entity_auditor",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=results[0],
        input_payload={"draft_id": draft.id},
    )
    record_agent_result(
        session,
        run_id=f"{draft.id}_knowledge_auditor",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
        result=results[1],
        input_payload={"draft_id": draft.id},
    )
    record_agent_result(
        session,
        run_id=f"{draft.id}_continuity_auditor",
        novel_id=chapter.novel_id,
        chapter_id=chapter.id,
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
    if config.llm_mode() == "live":
        try:
            result = ChapterWorkflowOrchestrator().run_revision(
                novel_id=chapter.novel_id,
                chapter_id=chapter.id,
                current=current,
                revision=None,
                feedback=feedback,
            )
        except LLMGatewayError as exc:
            fail_agent_run(
                session,
                run_id=f"{chapter.id}_revision_agent_v{next_version}_failed",
                novel_id=chapter.novel_id,
                chapter_id=chapter.id,
                agent_name="Revision Agent",
                run_type="draft",
                input_payload={"from_draft_id": current.id, "feedback": feedback or ""},
                error=exc,
            )
        revision = DraftModel(
            id=f"{chapter.id}_draft_v{next_version}",
            chapter_id=chapter.id,
            version_no=next_version,
            text=result.payload["text"],
            word_count=int(result.payload.get("word_count") or len(result.payload["text"])),
            audit_summary=None,
            source="revision_by_user_feedback",
            user_feedback=feedback,
            created_at=apple_timestamp_now(),
        )
        session.add(revision)
        chapter.current_version_id = revision.id
        chapter.status = "revisionRequired"
        record_agent_result(
            session,
            run_id=f"{chapter.id}_revision_agent_v{next_version}",
            novel_id=chapter.novel_id,
            chapter_id=chapter.id,
            result=result,
            input_payload={"from_draft_id": current.id, "feedback": feedback or ""},
        )
        run_audit_pipeline(session, chapter, revision, timestamp_prefix="12:13")
        return revision

    revision = DraftModel(
        id=f"draft_{chapter_number}_v{next_version}",
        chapter_id=chapter.id,
        version_no=next_version,
        text=mock_data.REVISED_DRAFT_TEXT,
        word_count=2980,
        audit_summary=mock_data.AUDIT_SUMMARY,
        source="revision_by_user_feedback",
        user_feedback=feedback,
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
        result=result,
        input_payload={"from_draft_id": current.id, "feedback": feedback or ""},
    )
    run_audit_pipeline(session, chapter, revision, timestamp_prefix="12:13")
    return revision


def confirm_canon_update_patch(session: Session, chapter: ChapterModel, novel: NovelModel) -> dict:
    patch = ensure_canon_patch(session, chapter)
    patch_row = latest_canon_patch(session, chapter.id)
    result = ChapterWorkflowOrchestrator().run_canon_merge(
        novel_id=novel.id,
        chapter_id=chapter.id,
        patch=patch,
    )
    record_agent_result(
        session,
        run_id=f"{patch['id']}_canon_merge_agent",
        novel_id=novel.id,
        chapter_id=chapter.id,
        result=result,
        input_payload={"patch_id": patch["id"]},
    )
    now = apple_timestamp_now()
    if patch_row is not None:
        patch_row.status = "confirmed"
        patch_row.confirmed_at = now
        patch_row.payload = patch
    for item in patch.get("items", []):
        action = _text(item.get("proposed_action"), "accept")
        if action != "reject":
            _apply_canon_patch_item(session, novel, chapter, patch, item)
        history_id = _stable_doc_id(novel.id, "history", chapter.id, item.get("id"))
        history = session.get(CanonEditHistoryModel, history_id)
        history_values = {
            "novel_id": novel.id,
            "chapter_id": chapter.id,
            "target": _text(item.get("target"), "Unknown"),
            "action": action,
            "payload": item,
            "created_by": "canon_merge_agent",
            "created_at": now,
        }
        if history is None:
            session.add(CanonEditHistoryModel(id=history_id, **history_values))
        else:
            for key, value in history_values.items():
                setattr(history, key, value)
    chapter.status = "completed"
    novel.current_canon_version = patch["target_canon_version"]
    return patch


def _apply_canon_patch_item(
    session: Session,
    novel: NovelModel,
    chapter: ChapterModel,
    patch: dict,
    item: dict,
) -> None:
    summary = _text(item.get("editable_payload")) or _text(item.get("summary"))
    if not summary:
        return
    target = _safe_id_part(item.get("target")).lower()
    title = _text(item.get("title"), "Canon 更新")
    canon_version = int(patch["target_canon_version"])
    if "memory" in target:
        _upsert_model(
            session,
            MemoryFactModel,
            {
                "id": _stable_doc_id(novel.id, "mem", chapter.chapter_no, item.get("id"), summary),
                "novel_id": novel.id,
                "chapter_no": chapter.chapter_no,
                "fact_type": "event",
                "time_in_story": None,
                "summary": summary,
                "participants": [],
                "location": None,
                "evidence": f"第 {chapter.chapter_no} 章 Canon Patch：{title}",
                "canon_status": "confirmed",
                "canon_version": canon_version,
                "metadata_json": {
                    "source": "canon_patch",
                    "patch_id": patch["id"],
                    "item_id": item.get("id"),
                },
                "created_by": "canon_merge_agent",
            },
        )
        return
    if "knowledge" in target:
        _upsert_model(
            session,
            KnowledgeMatrixEntryModel,
            {
                "id": _stable_doc_id(novel.id, "km", chapter.chapter_no, item.get("id"), summary),
                "novel_id": novel.id,
                "fact": summary,
                "fact_title": title,
                "truth_status": "confirmed",
                "author_knowledge": "known",
                "reader_knowledge": "reader_known",
                "character_knowledge": [],
                "visibility": {"author": "known", "reader": "reader_known"},
                "allowed_narration": {"summary": summary},
                "canon_version": canon_version,
            },
        )
        return
    if "world" in target or "bible" in target:
        _upsert_model(
            session,
            WorldBibleSectionModel,
            {
                "id": _stable_doc_id(novel.id, "wb", chapter.chapter_no, item.get("id"), title),
                "novel_id": novel.id,
                "section_key": None,
                "title": title,
                "content": summary,
                "tags": ["canon_patch", f"chapter_{chapter.chapter_no:03}"],
                "importance": "medium",
                "activation_policy": "tag_matched",
                "canon_version": canon_version,
                "updated_at": apple_timestamp_now(),
            },
        )
        return
    if "character" in target:
        character = _match_character_for_patch(session, novel.id, title, summary)
        if character is not None:
            state = _plain_dict(character.current_state)
            state["summary"] = summary
            state["source_patch_id"] = patch["id"]
            character.current_state = state
            character.last_active_chapter_no = chapter.chapter_no
            character.canon_version = canon_version


def _match_character_for_patch(
    session: Session,
    novel_id: str,
    title: str,
    summary: str,
) -> CharacterCardModel | None:
    haystack = f"{title}\n{summary}"
    characters = session.scalars(
        select(CharacterCardModel).where(CharacterCardModel.novel_id == novel_id)
    ).all()
    for character in characters:
        names = [character.name, *_string_list(character.aliases)]
        if any(name and name in haystack for name in names):
            return character
    return None
