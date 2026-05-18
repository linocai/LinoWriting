from sqlalchemy import select
from sqlalchemy.orm import Session

from app import mock_data
from app.models import (
    CharacterCardModel,
    ChapterModel,
    DraftModel,
    KnowledgeMatrixEntryModel,
    MemoryFactModel,
    NovelModel,
    WorldBibleSectionModel,
)


def seed_database(session: Session) -> None:
    if session.get(NovelModel, mock_data.NOVEL["id"]) is not None:
        return

    session.add(NovelModel(**mock_data.NOVEL))
    session.add(
        ChapterModel(
            **mock_data.CHAPTER,
            user_prompt=mock_data.PROMPT_DRAFT,
            structured_prompt=mock_data.STRUCTURED_PROMPT,
            canon_patch=mock_data.CANON_PATCH,
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
        MemoryFactModel(novel_id=mock_data.NOVEL["id"], **fact)
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
