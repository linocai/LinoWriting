from sqlalchemy import select
from sqlalchemy.orm import Session

from app import mock_data
from app.models import (
    CanonUpdatePatchModel,
    CharacterCardModel,
    ChapterModel,
    DraftModel,
    KnowledgeMatrixEntryModel,
    MemoryFactModel,
    NovelModel,
    StructuredPromptModel,
    WorldBibleSectionModel,
)


def seed_database(session: Session, mode: str = "completed_mock") -> None:
    if session.get(NovelModel, mock_data.NOVEL["id"]) is not None:
        if mode not in {"empty", "empty_bootstrap"}:
            _seed_imported_chapters(session)
            session.commit()
        return

    novel_payload = dict(mock_data.NOVEL)
    if mode in {"empty", "empty_bootstrap"}:
        novel_payload.update(
            current_chapter_no=None,
            current_canon_version=None,
            bootstrap_status="not_started",
        )
    novel = NovelModel(**novel_payload)
    session.add(novel)
    session.flush()

    if mode in {"empty", "empty_bootstrap"}:
        session.commit()
        return

    _seed_imported_chapters(session)

    chapter = ChapterModel(
        **mock_data.CHAPTER,
        user_prompt=mock_data.PROMPT_DRAFT,
        structured_prompt=mock_data.STRUCTURED_PROMPT,
        canon_patch=mock_data.CANON_PATCH,
    )
    session.add(chapter)
    session.flush()
    session.add(
        StructuredPromptModel(
            id=mock_data.STRUCTURED_PROMPT["id"],
            chapter_id=mock_data.CHAPTER["id"],
            version=mock_data.STRUCTURED_PROMPT["version"],
            payload=mock_data.STRUCTURED_PROMPT,
            status="approved",
            created_by="seed",
            created_at=mock_data.APPLE_REFERENCE_NOW,
        )
    )
    session.add(
        CanonUpdatePatchModel(
            id=mock_data.CANON_PATCH["id"],
            chapter_id=mock_data.CHAPTER["id"],
            target_canon_version=mock_data.CANON_PATCH["target_canon_version"],
            status="pending_user_confirmation",
            payload=mock_data.CANON_PATCH,
            created_at=mock_data.APPLE_REFERENCE_NOW,
        )
    )

    session.add_all(
        WorldBibleSectionModel(novel_id=mock_data.NOVEL["id"], **section)
        for section in mock_data.WORLD_BIBLE_SECTIONS
    )
    session.add_all(
        CharacterCardModel(novel_id=mock_data.NOVEL["id"], **card)
        for card in mock_data.CHARACTER_CARDS
    )
    session.add_all(
        MemoryFactModel(novel_id=mock_data.NOVEL["id"], **_memory_fact_model_payload(fact))
        for fact in mock_data.MEMORY_FACTS
    )
    session.add_all(
        KnowledgeMatrixEntryModel(novel_id=mock_data.NOVEL["id"], **entry)
        for entry in mock_data.KNOWLEDGE_MATRIX
    )

    existing_draft = session.scalar(
        select(DraftModel).where(DraftModel.id == "draft_004_v3")
    )
    if existing_draft is None:
        session.add(
            DraftModel(
                id="draft_004_v3",
                chapter_id=mock_data.CHAPTER["id"],
                version_no=3,
                text=mock_data.DRAFT_TEXT,
                word_count=3120,
                audit_summary=mock_data.AUDIT_SUMMARY,
                source="initial_generation",
                created_at=mock_data.APPLE_REFERENCE_NOW,
            )
        )

    session.commit()


def _seed_imported_chapters(session: Session) -> None:
    for imported in mock_data.IMPORTED_CHAPTERS:
        chapter_payload = imported["chapter"]
        draft_payload = imported["draft"]
        chapter = session.get(ChapterModel, chapter_payload["id"]) or session.scalar(
            select(ChapterModel).where(
                ChapterModel.novel_id == chapter_payload["novel_id"],
                ChapterModel.chapter_no == chapter_payload["chapter_no"],
            )
        )
        if chapter is None:
            chapter = ChapterModel(**chapter_payload)
            session.add(chapter)
        else:
            chapter.title = chapter.title or chapter_payload["title"]
            chapter.status = chapter.status if chapter.status != "imported" else "completed"
            chapter.current_version_id = chapter.current_version_id or chapter_payload["current_version_id"]
            chapter.approved_version_id = chapter.approved_version_id or chapter_payload["approved_version_id"]
            chapter.canon_version_used = chapter.canon_version_used or chapter_payload["canon_version_used"]

        effective_draft_payload = dict(draft_payload)
        if chapter.id != draft_payload["chapter_id"]:
            effective_draft_payload["id"] = f"{chapter.id}_import_v1"
            effective_draft_payload["chapter_id"] = chapter.id
            chapter.current_version_id = chapter.current_version_id or effective_draft_payload["id"]
            chapter.approved_version_id = chapter.approved_version_id or effective_draft_payload["id"]

        existing_draft = session.get(DraftModel, effective_draft_payload["id"]) or session.scalar(
            select(DraftModel).where(
                DraftModel.chapter_id == chapter.id,
                DraftModel.version_no == effective_draft_payload["version_no"],
            )
        )
        if existing_draft is None:
            session.add(DraftModel(**effective_draft_payload))


def _memory_fact_model_payload(fact: dict) -> dict:
    payload = dict(fact)
    payload["metadata_json"] = payload.pop("metadata", {})
    return payload
