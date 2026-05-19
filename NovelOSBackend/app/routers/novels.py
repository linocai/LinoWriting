from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import NovelModel
from app.schemas import (
    BootstrapAnalyzeResponse,
    BootstrapImportRequest,
    BootstrapStatus,
    Chapter,
    ChapterCreate,
    Novel,
    NovelCreate,
    NovelUpdate,
)
from app.services import (
    analyze_bootstrap_import,
    bootstrap_status_payload,
    create_novel,
    create_chapter,
    import_first_three_chapters,
    require_novel,
    update_novel,
)

router = APIRouter(prefix="/api/novels", tags=["novels"])


@router.get("", response_model=list[Novel])
def list_novels(session: Session = Depends(get_session)):
    return session.scalars(select(NovelModel).order_by(NovelModel.title, NovelModel.id)).all()


@router.post("", response_model=Novel)
def post_novel(request: NovelCreate, session: Session = Depends(get_session)):
    novel = create_novel(session, request.model_dump())
    session.commit()
    session.refresh(novel)
    return novel


@router.get("/{novel_id}", response_model=Novel)
def get_novel(novel_id: str, session: Session = Depends(get_session)):
    return require_novel(session, novel_id)


@router.patch("/{novel_id}", response_model=Novel)
def patch_novel(novel_id: str, request: NovelUpdate, session: Session = Depends(get_session)):
    novel = update_novel(session, novel_id, request.model_dump(exclude_unset=True))
    session.commit()
    session.refresh(novel)
    return novel


@router.get("/{novel_id}/chapters", response_model=list[Chapter])
def list_chapters(novel_id: str, session: Session = Depends(get_session)):
    from app.models import ChapterModel

    require_novel(session, novel_id)
    return session.scalars(
        select(ChapterModel).where(ChapterModel.novel_id == novel_id).order_by(ChapterModel.chapter_no)
    ).all()


@router.post("/{novel_id}/chapters", response_model=Chapter)
def post_chapter(novel_id: str, request: ChapterCreate, session: Session = Depends(get_session)):
    novel = require_novel(session, novel_id)
    chapter = create_chapter(session, novel, request.model_dump())
    session.commit()
    session.refresh(chapter)
    return chapter


@router.post("/{novel_id}/bootstrap/import-first-three-chapters", response_model=BootstrapStatus)
def import_bootstrap_chapters(
    novel_id: str,
    request: BootstrapImportRequest,
    session: Session = Depends(get_session),
):
    novel = require_novel(session, novel_id)
    payload = [chapter.model_dump(mode="json") for chapter in request.chapters]
    status = import_first_three_chapters(session, novel, payload)
    session.commit()
    return status


@router.get("/{novel_id}/bootstrap/status", response_model=BootstrapStatus)
def get_bootstrap_status(novel_id: str, session: Session = Depends(get_session)):
    novel = require_novel(session, novel_id)
    return bootstrap_status_payload(session, novel)


@router.post("/{novel_id}/bootstrap/analyze", response_model=BootstrapAnalyzeResponse)
def analyze_bootstrap(novel_id: str, session: Session = Depends(get_session)):
    novel = require_novel(session, novel_id)
    result = analyze_bootstrap_import(session, novel)
    session.commit()
    return result
