from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import mock_data
from app.models import ChapterModel, DraftModel, NovelModel

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


def latest_draft(session: Session, chapter_id: str) -> DraftModel | None:
    return session.scalar(
        select(DraftModel)
        .where(DraftModel.chapter_id == chapter_id)
        .order_by(DraftModel.version_no.desc())
        .limit(1)
    )


def ensure_structured_prompt(chapter: ChapterModel) -> dict:
    if chapter.structured_prompt:
        return dict(chapter.structured_prompt)

    prompt = dict(mock_data.STRUCTURED_PROMPT)
    prompt["chapter_id"] = chapter.id
    chapter.structured_prompt = prompt
    return prompt


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
    return revision
