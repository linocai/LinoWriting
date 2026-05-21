from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import KnowledgeMatrixEntryModel
from app.schemas import KnowledgeMatrixEntry, KnowledgeMatrixEntryUpsert
from app.services import require_novel

router = APIRouter(prefix="/api/novels/{novel_id}/knowledge-matrix", tags=["knowledge-matrix"])


def _visibility_from_entry_payload(payload: dict) -> dict:
    visibility = dict(payload.get("visibility") or {})
    visibility.setdefault("author", payload.get("author_knowledge") or "known")
    visibility.setdefault("reader", payload.get("reader_knowledge") or "reader_unknown")
    for item in payload.get("character_knowledge", []):
        key = item.get("character_name") or item.get("character_id")
        if key:
            visibility.setdefault(key, item.get("state") or "unknown")
    return visibility


def _storage_payload(entry: KnowledgeMatrixEntryUpsert) -> dict:
    payload = entry.model_dump(mode="json")
    payload["visibility"] = _visibility_from_entry_payload(payload)
    payload["fact"] = payload.get("fact") or payload.get("fact_title")
    payload["author_knowledge"] = payload["visibility"].get("author", payload.get("author_knowledge", "known"))
    payload["reader_knowledge"] = payload["visibility"].get("reader", payload.get("reader_knowledge", "reader_unknown"))
    payload["character_knowledge"] = []
    if isinstance(payload.get("allowed_narration"), str):
        payload["allowed_narration"] = {"text": payload["allowed_narration"]}
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
    entry: KnowledgeMatrixEntryUpsert,
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
    entry: KnowledgeMatrixEntryUpsert,
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
