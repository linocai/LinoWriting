from __future__ import annotations

from typing import Optional

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import JSON

from app.database import Base


class NovelModel(Base):
    __tablename__ = "novels"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    genre: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="active")
    language: Mapped[str] = mapped_column(String, nullable=False, default="zh-Hans")
    current_chapter_no: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    current_canon_version: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    bootstrap_status: Mapped[str] = mapped_column(String, nullable=False, default="not_started")


class ChapterModel(Base):
    __tablename__ = "chapters"
    __table_args__ = (UniqueConstraint("novel_id", "chapter_no", name="uq_chapter_number"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    chapter_no: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False, default="draftInput")
    target_word_count: Mapped[int] = mapped_column(Integer, nullable=False, default=3000)
    approved_version_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    current_version_id: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    canon_version_used: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    user_prompt: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    structured_prompt: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    canon_patch: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)


class StructuredPromptModel(Base):
    __tablename__ = "structured_prompts"
    __table_args__ = (UniqueConstraint("chapter_id", "version", name="uq_structured_prompt_version"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="draft")
    created_by: Mapped[str] = mapped_column(String, nullable=False, default="prompt_expander")
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class CanonUpdatePatchModel(Base):
    __tablename__ = "canon_update_patches"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False)
    target_canon_version: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending_user_confirmation")
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)
    confirmed_at: Mapped[Optional[float]] = mapped_column(Float, nullable=True)


class CanonEditHistoryModel(Base):
    __tablename__ = "canon_edit_history"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    chapter_id: Mapped[Optional[str]] = mapped_column(String, ForeignKey("chapters.id"), nullable=True)
    target: Mapped[str] = mapped_column(String, nullable=False)
    action: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    created_by: Mapped[str] = mapped_column(String, nullable=False, default="canon_merge_agent")
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class DraftModel(Base):
    __tablename__ = "chapter_versions"
    __table_args__ = (UniqueConstraint("chapter_id", "version_no", name="uq_draft_version"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False)
    version_no: Mapped[int] = mapped_column(Integer, nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    word_count: Mapped[int] = mapped_column(Integer, nullable=False)
    audit_summary: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    source: Mapped[str] = mapped_column(String, nullable=False, default="initial_generation")
    user_feedback: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class ContextPackModel(Base):
    __tablename__ = "context_packs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False)
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class AgentRunModel(Base):
    __tablename__ = "agent_runs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[Optional[str]] = mapped_column(String, ForeignKey("novels.id"), nullable=True)
    chapter_id: Mapped[Optional[str]] = mapped_column(String, ForeignKey("chapters.id"), nullable=True)
    agent_name: Mapped[str] = mapped_column(String, nullable=False)
    run_type: Mapped[str] = mapped_column(String, nullable=False, default="workflow")
    model: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    input_payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    output_payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    input_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    output_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    token_usage: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    started_at: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)

    @property
    def latency_ms(self) -> Optional[float]:
        if self.started_at is None or self.completed_at is None:
            return None
        completed_at = self.completed_at
        if completed_at.tzinfo is None:
            completed_at = completed_at.replace(tzinfo=timezone.utc)
        apple_reference = datetime(2001, 1, 1, tzinfo=timezone.utc)
        completed_seconds = (completed_at - apple_reference).total_seconds()
        return max(0.0, (completed_seconds - self.started_at) * 1000)


class AuditReportModel(Base):
    __tablename__ = "audit_reports"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False)
    draft_id: Mapped[str] = mapped_column(String, ForeignKey("chapter_versions.id"), nullable=False, unique=True)
    named_entity_result: Mapped[dict] = mapped_column(JSON, nullable=False)
    knowledge_result: Mapped[dict] = mapped_column(JSON, nullable=False)
    continuity_result: Mapped[dict] = mapped_column(JSON, nullable=False)
    summary: Mapped[dict] = mapped_column(JSON, nullable=False)
    passed: Mapped[bool] = mapped_column("pass", Boolean, nullable=False, default=True)
    highest_severity: Mapped[str] = mapped_column(String, nullable=False, default="none")
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class BootstrapImportModel(Base):
    __tablename__ = "bootstrap_imports"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="imported")
    source_type: Mapped[str] = mapped_column(String, nullable=False, default="first_three_chapters")
    storage_path: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    chapters_payload: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    analysis_payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)
    updated_at: Mapped[float] = mapped_column(Float, nullable=False)


class WorldBibleSectionModel(Base):
    __tablename__ = "world_bible_sections"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    section_key: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    tags: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    importance: Mapped[str] = mapped_column(String, nullable=False, default="medium")
    activation_policy: Mapped[str] = mapped_column(String, nullable=False, default="tag_matched")
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    updated_at: Mapped[float] = mapped_column(Float, nullable=False)


class CharacterCardModel(Base):
    __tablename__ = "characters"
    __table_args__ = (UniqueConstraint("novel_id", "name", name="uq_character_name"),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    aliases: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    role: Mapped[str] = mapped_column(String, nullable=False)
    stable_traits: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    current_state: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    dialogue_style: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    knowledge_summary: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    do_not_auto_mention: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    default_visibility: Mapped[str] = mapped_column(String, nullable=False, default="manual_only")
    relationships: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    forbidden_behavior: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    last_active_chapter_no: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class KnowledgeMatrixEntryModel(Base):
    __tablename__ = "knowledge_matrix_entries"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    fact: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    fact_title: Mapped[str] = mapped_column(String, nullable=False)
    truth_status: Mapped[str] = mapped_column(String, nullable=False)
    author_knowledge: Mapped[str] = mapped_column(String, nullable=False)
    reader_knowledge: Mapped[str] = mapped_column(String, nullable=False)
    character_knowledge: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    visibility: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    allowed_narration: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class MemoryFactModel(Base):
    __tablename__ = "memory_facts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    chapter_no: Mapped[int] = mapped_column(Integer, nullable=False)
    fact_type: Mapped[str] = mapped_column(String, nullable=False)
    time_in_story: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    participants: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    location: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    evidence: Mapped[str] = mapped_column(Text, nullable=False)
    canon_status: Mapped[str] = mapped_column(String, nullable=False, default="confirmed")
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    metadata_json: Mapped[dict] = mapped_column("metadata", JSON, nullable=False, default=dict)
    created_by: Mapped[str] = mapped_column(String, nullable=False, default="system")
