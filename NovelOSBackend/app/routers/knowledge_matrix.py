from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import KnowledgeMatrixEntryModel
from app.schemas import KnowledgeMatrixEntry
from app.services import require_novel

router = APIRouter(prefix="/api/novels/{novel_id}/knowledge-matrix", tags=["knowledge-matrix"])


def _visibility_from_entry_payload(payload: dict) -> dict:
    visibility = dict(payload.get("visibility") or {})
    visibility.setdefault("author", payload.get("author_knowledge"))
    visibility.setdefault("reader", payload.get("reader_knowledge"))
    for item in payload.get("character_knowledge", []):
        character_id = item.get("character_id")
        if character_id:
            visibility.setdefault(character_id, item.get("state"))
    return visibility


def _storage_payload(entry: KnowledgeMatrixEntry) -> dict:
    payload = entry.model_dump(mode="json")
    payload["visibility"] = _visibility_from_entry_payload(payload)
    return payload


def _require_entry(session: Session, novel_id: str, entry_id: str) -> KnowledgeMatrixEntryModel:
    row = session.scalar(
        select(KnowledgeMatrixEntryModel).where(
            KnowledgeMatrixEntryModel.novel_id == novel_id,
            KnowledgeMatrixEntryModel.id == entry_id,
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail=f"Knowledge Matrix entry not found: {entry_id}")
    return row


@router.get("", response_model=list[KnowledgeMatrixEntry])
def get_entries(novel_id: str, session: Session = Depends(get_session)):
    require_novel(session, novel_id)
    return session.scalars(
        select(KnowledgeMatrixEntryModel)
        .where(KnowledgeMatrixEntryModel.novel_id == novel_id)
        .order_by(KnowledgeMatrixEntryModel.id)
    ).all()


@router.post("", response_model=KnowledgeMatrixEntry)
def create_entry(
    novel_id: str,
    entry: KnowledgeMatrixEntry,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = KnowledgeMatrixEntryModel(novel_id=novel_id, **_storage_payload(entry))
    session.add(row)
    session.commit()
    session.refresh(row)
    return row


@router.patch("/{entry_id}", response_model=KnowledgeMatrixEntry)
def update_entry(
    novel_id: str,
    entry_id: str,
    entry: KnowledgeMatrixEntry,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_entry(session, novel_id, entry_id)
    for key, value in _storage_payload(entry).items():
        if key != "id":
            setattr(row, key, value)
    session.commit()
    session.refresh(row)
    return row


@router.delete("/{entry_id}", status_code=204)
def delete_entry(
    novel_id: str,
    entry_id: str,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_entry(session, novel_id, entry_id)
    session.delete(row)
    session.commit()
    return Response(status_code=204)
