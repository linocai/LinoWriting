from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict


class APIModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Novel(APIModel):
    id: str
    title: str
    genre: Optional[str] = None
    current_chapter_no: Optional[int] = None
    current_canon_version: Optional[int] = None
    bootstrap_status: str


class Chapter(APIModel):
    id: str
    novel_id: str
    chapter_no: int
    title: Optional[str] = None
    status: str
    target_word_count: int
    approved_version_id: Optional[str] = None
    current_version_id: Optional[str] = None
    canon_version_used: Optional[int] = None


class AllowedEntity(APIModel):
    name: str
    activation: str
    mention_budget: Optional[int] = None


class ActivationSummary(APIModel):
    active_cast: list[str]
    allowed_names_count: int
    mention_budget_total: int
    new_named_character_policy: str


class StructuredPrompt(APIModel):
    id: str
    chapter_id: str
    chapter_goal: str
    must_happen: list[str]
    must_not_happen: list[str]
    allowed_named_entities: list[AllowedEntity]
    narrative_style: str
    activation_summary: Optional[ActivationSummary] = None
    version: int


class AuditIssue(APIModel):
    id: str
    severity: str
    type: str
    location: Optional[str] = None
    message: str
    suggestion: Optional[str] = None


class AuditSummary(APIModel):
    s0_count: int
    s1_count: int
    s2_count: int
    illegal_named_entity_count: int
    inactive_character_appearance_count: int
    knowledge_violation_count: int
    new_named_entity_count: int
    issues: list[AuditIssue]


class Draft(APIModel):
    id: str
    chapter_id: str
    version_no: int
    text: str
    word_count: int
    audit_summary: Optional[AuditSummary] = None
    created_at: float


class ContextPackSnapshot(APIModel):
    id: str
    chapter_id: str
    payload: dict
    created_at: float


class AgentRun(APIModel):
    id: str
    chapter_id: str
    agent_name: str
    summary: str
    status: str
    timestamp_label: str
    payload: dict
    created_at: float


class AuditReport(APIModel):
    id: str
    chapter_id: str
    draft_id: str
    named_entity_result: dict
    knowledge_result: dict
    continuity_result: dict
    summary: AuditSummary
    created_at: float


class CanonPatchItem(APIModel):
    id: str
    target: str
    title: str
    summary: str
    proposed_action: str
    editable_payload: Optional[str] = None


class CanonUpdatePatch(APIModel):
    id: str
    chapter_id: str
    target_canon_version: int
    items: list[CanonPatchItem]


class WorldBibleSection(APIModel):
    id: str
    title: str
    content: str
    tags: list[str]
    importance: str
    activation_policy: str
    canon_version: int
    updated_at: float


class CharacterRelationship(APIModel):
    id: str
    target_character_name: str
    relationship_summary: str
    current_tension: Optional[str] = None
    last_changed_chapter_no: Optional[int] = None


class CharacterCard(APIModel):
    id: str
    name: str
    aliases: list[str]
    role: str
    stable_traits: list[str]
    current_state: str
    dialogue_style: str
    relationships: list[CharacterRelationship]
    forbidden_behavior: list[str]
    last_active_chapter_no: Optional[int] = None
    canon_version: int


class CharacterKnowledge(APIModel):
    character_id: str
    character_name: str
    state: str


class KnowledgeMatrixEntry(APIModel):
    id: str
    fact_title: str
    truth_status: str
    author_knowledge: str
    reader_knowledge: str
    character_knowledge: list[CharacterKnowledge]
    allowed_narration: str
    canon_version: int


class MemoryFact(APIModel):
    id: str
    chapter_no: int
    fact_type: str
    summary: str
    participants: list[str]
    location: Optional[str] = None
    evidence: str
    canon_status: str
    canon_version: int


class UserPromptRequest(APIModel):
    prompt: str


class DraftReviewRequest(APIModel):
    decision: Literal["revise", "approve"]
    feedback: Optional[str] = None
