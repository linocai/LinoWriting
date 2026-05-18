from __future__ import annotations

from typing import Optional

from sqlalchemy import Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.types import JSON

from app.database import Base


class NovelModel(Base):
    __tablename__ = "novels"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    genre: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    current_chapter_no: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    current_canon_version: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    bootstrap_status: Mapped[str] = mapped_column(String, nullable=False, default="completed")


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
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class ContextPackModel(Base):
    __tablename__ = "context_packs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False, unique=True)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class AgentRunModel(Base):
    __tablename__ = "agent_runs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    chapter_id: Mapped[str] = mapped_column(String, ForeignKey("chapters.id"), nullable=False)
    agent_name: Mapped[str] = mapped_column(String, nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False)
    timestamp_label: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    created_at: Mapped[float] = mapped_column(Float, nullable=False)


class WorldBibleSectionModel(Base):
    __tablename__ = "world_bible_sections"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
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
    current_state: Mapped[str] = mapped_column(Text, nullable=False, default="")
    dialogue_style: Mapped[str] = mapped_column(Text, nullable=False, default="")
    relationships: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    forbidden_behavior: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    last_active_chapter_no: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class KnowledgeMatrixEntryModel(Base):
    __tablename__ = "knowledge_matrix_entries"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    fact_title: Mapped[str] = mapped_column(String, nullable=False)
    truth_status: Mapped[str] = mapped_column(String, nullable=False)
    author_knowledge: Mapped[str] = mapped_column(String, nullable=False)
    reader_knowledge: Mapped[str] = mapped_column(String, nullable=False)
    character_knowledge: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    allowed_narration: Mapped[str] = mapped_column(Text, nullable=False, default="")
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)


class MemoryFactModel(Base):
    __tablename__ = "memory_facts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    novel_id: Mapped[str] = mapped_column(String, ForeignKey("novels.id"), nullable=False)
    chapter_no: Mapped[int] = mapped_column(Integer, nullable=False)
    fact_type: Mapped[str] = mapped_column(String, nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    participants: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    location: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    evidence: Mapped[str] = mapped_column(Text, nullable=False)
    canon_status: Mapped[str] = mapped_column(String, nullable=False, default="confirmed")
    canon_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
