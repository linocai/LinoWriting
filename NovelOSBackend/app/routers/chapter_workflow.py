from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_session
from app.models import AgentRunModel
from app.schemas import (
    AgentRun,
    CanonUpdatePatch,
    ContextPackSnapshot,
    Draft,
    DraftReviewRequest,
    StructuredPrompt,
    UserPromptRequest,
)
from app.services import (
    create_revision,
    ensure_canon_patch,
    ensure_initial_draft,
    ensure_structured_prompt,
    latest_draft,
    require_context_pack,
    require_chapter,
    require_novel,
    run_prompt_pipeline,
    run_writing_agent,
)

router = APIRouter(prefix="/api/chapters/{chapter_id}", tags=["chapter-workflow"])


@router.post("/user-prompt", status_code=204)
def submit_user_prompt(
    chapter_id: str,
    request: UserPromptRequest,
    session: Session = Depends(get_session),
):
    chapter = require_chapter(session, chapter_id)
    run_prompt_pipeline(session, chapter, request.prompt)
    session.commit()
    return Response(status_code=204)


@router.get("/structured-prompt", response_model=StructuredPrompt)
def get_structured_prompt(chapter_id: str, session: Session = Depends(get_session)):
    chapter = require_chapter(session, chapter_id)
    prompt = ensure_structured_prompt(chapter)
    session.commit()
    return prompt


@router.patch("/structured-prompt", response_model=StructuredPrompt)
def update_structured_prompt(
    chapter_id: str,
    prompt: StructuredPrompt,
    session: Session = Depends(get_session),
):
    chapter = require_chapter(session, chapter_id)
    payload = prompt.model_dump(mode="json")
    payload["chapter_id"] = chapter.id
    chapter.structured_prompt = payload
    chapter.status = "structuredPromptReady"
    session.commit()
    return payload


@router.post("/structured-prompt", status_code=204)
@router.post("/structured-prompt/approve", status_code=204)
def approve_structured_prompt(chapter_id: str, session: Session = Depends(get_session)):
    chapter = require_chapter(session, chapter_id)
    ensure_structured_prompt(chapter)
    chapter.status = "structuredPromptApproved"
    session.commit()
    return Response(status_code=204)


@router.post("/draft/generate", status_code=204)
def generate_draft(chapter_id: str, session: Session = Depends(get_session)):
    chapter = require_chapter(session, chapter_id)
    run_writing_agent(session, chapter)
    session.commit()
    return Response(status_code=204)


@router.get("/draft/latest", response_model=Draft)
def get_latest_draft(chapter_id: str, session: Session = Depends(get_session)):
    require_chapter(session, chapter_id)
    draft = latest_draft(session, chapter_id)
    if draft is None:
        raise HTTPException(status_code=404, detail=f"Draft not found for chapter: {chapter_id}")
    return draft


@router.post("/draft/review", status_code=204)
def review_draft(
    chapter_id: str,
    request: DraftReviewRequest,
    session: Session = Depends(get_session),
):
    chapter = require_chapter(session, chapter_id)
    if request.decision == "revise":
        create_revision(session, chapter, request.feedback)
    else:
        draft = ensure_initial_draft(session, chapter)
        chapter.status = "draftApproved"
        chapter.current_version_id = draft.id
        chapter.approved_version_id = draft.id
    session.commit()
    return Response(status_code=204)


@router.post("/approve-final-text", status_code=204)
def approve_final_text(chapter_id: str, session: Session = Depends(get_session)):
    chapter = require_chapter(session, chapter_id)
    draft = ensure_initial_draft(session, chapter)
    ensure_canon_patch(chapter)
    chapter.status = "canonPatchPending"
    chapter.current_version_id = draft.id
    chapter.approved_version_id = draft.id
    session.commit()
    return Response(status_code=204)


@router.get("/canon-update-patch", response_model=CanonUpdatePatch)
def get_canon_update_patch(chapter_id: str, session: Session = Depends(get_session)):
    chapter = require_chapter(session, chapter_id)
    patch = ensure_canon_patch(chapter)
    session.commit()
    return patch


@router.patch("/canon-update-patch", response_model=CanonUpdatePatch)
def update_canon_update_patch(
    chapter_id: str,
    patch: CanonUpdatePatch,
    session: Session = Depends(get_session),
):
    chapter = require_chapter(session, chapter_id)
    payload = patch.model_dump(mode="json")
    payload["chapter_id"] = chapter.id
    chapter.canon_patch = payload
    session.commit()
    return payload


@router.post("/canon-update-patch", status_code=204)
@router.post("/canon-update-patch/confirm", status_code=204)
def confirm_canon_update_patch(chapter_id: str, session: Session = Depends(get_session)):
    chapter = require_chapter(session, chapter_id)
    novel = require_novel(session, chapter.novel_id)
    patch = ensure_canon_patch(chapter)
    chapter.status = "completed"
    novel.current_canon_version = patch["target_canon_version"]
    session.commit()
    return Response(status_code=204)


@router.get("/context-pack", response_model=ContextPackSnapshot)
def get_context_pack(chapter_id: str, session: Session = Depends(get_session)):
    require_chapter(session, chapter_id)
    return require_context_pack(session, chapter_id)


@router.get("/agent-runs", response_model=list[AgentRun])
def get_agent_runs(chapter_id: str, session: Session = Depends(get_session)):
    require_chapter(session, chapter_id)
    return session.scalars(
        select(AgentRunModel)
        .where(AgentRunModel.chapter_id == chapter_id)
        .order_by(AgentRunModel.timestamp_label, AgentRunModel.id)
    ).all()
