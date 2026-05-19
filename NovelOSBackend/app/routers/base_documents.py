from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import CharacterCardModel, MemoryFactModel, WorldBibleSectionModel
from app.schemas import CharacterCard, MemoryFact, WorldBibleSection
from app.services import require_novel

router = APIRouter(prefix="/api/novels/{novel_id}", tags=["base-documents"])


def _character_payload(card: CharacterCard) -> dict:
    payload = card.model_dump(mode="json")
    if isinstance(payload.get("current_state"), str):
        payload["current_state"] = {"summary": payload["current_state"]}
    if isinstance(payload.get("dialogue_style"), str):
        payload["dialogue_style"] = {"summary": payload["dialogue_style"]}
    return payload


def _memory_payload(fact: MemoryFact) -> dict:
    payload = fact.model_dump(mode="json")
    payload["metadata_json"] = payload.pop("metadata", {})
    return payload


def _memory_response(row: MemoryFactModel) -> dict:
    return {
        "id": row.id,
        "chapter_no": row.chapter_no,
        "fact_type": row.fact_type,
        "time_in_story": row.time_in_story,
        "summary": row.summary,
        "participants": row.participants,
        "location": row.location,
        "evidence": row.evidence,
        "canon_status": row.canon_status,
        "canon_version": row.canon_version,
        "metadata": row.metadata_json,
        "created_by": row.created_by,
    }


def _require_world_section(session: Session, novel_id: str, section_id: str) -> WorldBibleSectionModel:
    row = session.scalar(
        select(WorldBibleSectionModel).where(
            WorldBibleSectionModel.novel_id == novel_id,
            WorldBibleSectionModel.id == section_id,
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail=f"World Bible section not found: {section_id}")
    return row


def _require_character(session: Session, novel_id: str, character_id: str) -> CharacterCardModel:
    row = session.scalar(
        select(CharacterCardModel).where(
            CharacterCardModel.novel_id == novel_id,
            CharacterCardModel.id == character_id,
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail=f"Character not found: {character_id}")
    return row


def _require_memory_fact(session: Session, novel_id: str, fact_id: str) -> MemoryFactModel:
    row = session.scalar(
        select(MemoryFactModel).where(
            MemoryFactModel.novel_id == novel_id,
            MemoryFactModel.id == fact_id,
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail=f"Memory fact not found: {fact_id}")
    return row


@router.get("/world-bible", response_model=list[WorldBibleSection])
def get_world_bible_sections(novel_id: str, session: Session = Depends(get_session)):
    require_novel(session, novel_id)
    return session.scalars(
        select(WorldBibleSectionModel)
        .where(WorldBibleSectionModel.novel_id == novel_id)
        .order_by(WorldBibleSectionModel.id)
    ).all()


@router.post("/world-bible/sections", response_model=WorldBibleSection)
def create_world_bible_section(
    novel_id: str,
    section: WorldBibleSection,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = WorldBibleSectionModel(novel_id=novel_id, **section.model_dump())
    session.add(row)
    session.commit()
    session.refresh(row)
    return row


@router.patch("/world-bible/sections/{section_id}", response_model=WorldBibleSection)
def update_world_bible_section(
    novel_id: str,
    section_id: str,
    section: WorldBibleSection,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_world_section(session, novel_id, section_id)
    for key, value in section.model_dump().items():
        if key != "id":
            setattr(row, key, value)
    session.commit()
    session.refresh(row)
    return row


@router.delete("/world-bible/sections/{section_id}", status_code=204)
def delete_world_bible_section(
    novel_id: str,
    section_id: str,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_world_section(session, novel_id, section_id)
    session.delete(row)
    session.commit()
    return Response(status_code=204)


@router.get("/characters", response_model=list[CharacterCard])
def get_character_cards(novel_id: str, session: Session = Depends(get_session)):
    require_novel(session, novel_id)
    return session.scalars(
        select(CharacterCardModel)
        .where(CharacterCardModel.novel_id == novel_id)
        .order_by(CharacterCardModel.id)
    ).all()


@router.post("/characters", response_model=CharacterCard)
def create_character_card(
    novel_id: str,
    card: CharacterCard,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = CharacterCardModel(novel_id=novel_id, **_character_payload(card))
    session.add(row)
    session.commit()
    session.refresh(row)
    return row


@router.patch("/characters/{character_id}", response_model=CharacterCard)
def update_character_card(
    novel_id: str,
    character_id: str,
    card: CharacterCard,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_character(session, novel_id, character_id)
    for key, value in _character_payload(card).items():
        if key != "id":
            setattr(row, key, value)
    session.commit()
    session.refresh(row)
    return row


@router.get("/memory", response_model=list[MemoryFact])
def get_memory_facts(novel_id: str, session: Session = Depends(get_session)):
    require_novel(session, novel_id)
    rows = session.scalars(
        select(MemoryFactModel)
        .where(MemoryFactModel.novel_id == novel_id)
        .order_by(MemoryFactModel.id)
    ).all()
    return [_memory_response(row) for row in rows]


@router.post("/memory", response_model=MemoryFact)
def create_memory_fact(
    novel_id: str,
    fact: MemoryFact,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = MemoryFactModel(novel_id=novel_id, **_memory_payload(fact))
    session.add(row)
    session.commit()
    session.refresh(row)
    return _memory_response(row)


@router.patch("/memory/{fact_id}", response_model=MemoryFact)
def update_memory_fact(
    novel_id: str,
    fact_id: str,
    fact: MemoryFact,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_memory_fact(session, novel_id, fact_id)
    for key, value in _memory_payload(fact).items():
        if key != "id":
            setattr(row, key, value)
    session.commit()
    session.refresh(row)
    return _memory_response(row)


@router.delete("/memory/{fact_id}", status_code=204)
def delete_memory_fact(
    novel_id: str,
    fact_id: str,
    session: Session = Depends(get_session),
):
    require_novel(session, novel_id)
    row = _require_memory_fact(session, novel_id, fact_id)
    session.delete(row)
    session.commit()
    return Response(status_code=204)
