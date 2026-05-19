from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field


class APIModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class Novel(APIModel):
    id: str
    title: str
    genre: Optional[str] = None
    status: str = "active"
    language: str = "zh-Hans"
    current_chapter_no: Optional[int] = None
    current_canon_version: Optional[int] = None
    bootstrap_status: str


class NovelCreate(APIModel):
    id: Optional[str] = None
    title: str
    genre: Optional[str] = None
    status: str = "active"
    language: str = "zh-Hans"
    current_chapter_no: Optional[int] = None
    current_canon_version: Optional[int] = None
    bootstrap_status: str = "not_started"


class NovelUpdate(APIModel):
    title: Optional[str] = None
    genre: Optional[str] = None
    status: Optional[str] = None
    language: Optional[str] = None
    current_chapter_no: Optional[int] = None
    current_canon_version: Optional[int] = None
    bootstrap_status: Optional[str] = None


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


class ChapterCreate(APIModel):
    id: Optional[str] = None
    chapter_no: int
    title: Optional[str] = None
    target_word_count: int = 3000


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
    canon_version: int = 1
    payload: dict
    created_at: float


class AgentRun(APIModel):
    id: str
    novel_id: Optional[str] = None
    chapter_id: Optional[str] = None
    agent_name: str
    run_type: str = "workflow"
    model: Optional[str] = None
    summary: str
    status: str
    payload: dict
    input_payload: dict = Field(default_factory=dict)
    output_payload: dict = Field(default_factory=dict)
    input_json: dict = Field(default_factory=dict)
    output_json: dict = Field(default_factory=dict)
    token_usage: dict = Field(default_factory=dict)
    error_message: Optional[str] = None
    started_at: Optional[float] = None
    completed_at: Optional[datetime] = None
    created_at: float


class AuditReport(APIModel):
    id: str
    chapter_id: str
    draft_id: str
    named_entity_result: dict
    knowledge_result: dict
    continuity_result: dict
    summary: AuditSummary
    passed: bool = True
    highest_severity: str = "none"
    created_at: float


class BootstrapChapterInput(APIModel):
    chapter_no: int
    title: Optional[str] = None
    text: str


class BootstrapImportRequest(APIModel):
    chapters: list[BootstrapChapterInput]


class BootstrapStatus(APIModel):
    novel_id: str
    status: str
    import_id: Optional[str] = None
    imported_chapter_count: int = 0
    analysis_ready: bool = False
    updated_at: Optional[float] = None


class BootstrapAnalyzeResponse(APIModel):
    novel_id: str
    status: str
    import_id: str
    analysis: dict


class LLMProviderPublic(APIModel):
    id: str
    name: str
    base_url: str
    model: str
    timeout_seconds: float = 60.0
    has_api_key: bool = False
    is_active: bool = False


class LLMProviderUpsert(APIModel):
    name: str
    base_url: str
    model: str
    api_key: Optional[str] = None
    timeout_seconds: float = 60.0


class LLMProvidersResponse(APIModel):
    active_provider_id: Optional[str] = None
    providers: list[LLMProviderPublic]


class ActiveLLMProviderRequest(APIModel):
    provider_id: str


class LLMTestRequest(APIModel):
    provider_id: Optional[str] = None
    prompt: str = "ping"


class LLMTestResponse(APIModel):
    ok: bool
    provider_id: str
    model: str
    message: str
    token_usage: dict = Field(default_factory=dict)


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
    section_key: Optional[str] = None
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
    current_state: Union[dict, str]
    dialogue_style: Union[dict, str]
    knowledge_summary: dict = Field(default_factory=dict)
    do_not_auto_mention: bool = False
    default_visibility: str = "manual_only"
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
    fact: Optional[str] = None
    fact_title: str
    truth_status: str
    author_knowledge: str
    reader_knowledge: str
    character_knowledge: list[CharacterKnowledge]
    visibility: Optional[dict] = None
    allowed_narration: Union[dict, str]
    canon_version: int


class MemoryFact(APIModel):
    id: str
    chapter_no: int
    fact_type: str
    time_in_story: Optional[str] = None
    summary: str
    participants: list[str]
    location: Optional[str] = None
    evidence: str
    canon_status: str
    canon_version: int
    metadata: dict = Field(default_factory=dict)
    created_by: str = "system"


class UserPromptRequest(APIModel):
    prompt: str


class DraftReviewRequest(APIModel):
    decision: Literal["revise", "approve"]
    feedback: Optional[str] = None
