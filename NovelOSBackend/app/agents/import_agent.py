from __future__ import annotations

import json
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


WORLD_BIBLE_SECTION_KEYS = [
    "tone_and_style",
    "real_world_background",
    "forbidden_patterns",
    "time_and_place",
    "themes",
    "profession_and_society",
    "value_boundary",
]


class WorldBibleSectionSchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    section_key: Literal[
        "tone_and_style",
        "real_world_background",
        "forbidden_patterns",
        "time_and_place",
        "themes",
        "profession_and_society",
        "value_boundary",
    ]
    title: str
    content: str = Field(..., min_length=20, max_length=800)
    tags: list[str] = Field(default_factory=list)
    importance: Literal["low", "medium", "high"] = "medium"
    activation_policy: Literal[
        "always_in_context_brief",
        "always_considered",
        "tag_matched",
        "manual_only",
    ] = "tag_matched"


class CharacterCardSchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: str
    aliases: list[str] = Field(default_factory=list)
    role: Literal["protagonist", "deuteragonist", "antagonist", "supporting"]
    stable_traits: list[str] = Field(..., min_length=2, max_length=6)
    current_state: dict[str, Any]
    voice: dict[str, Any] = Field(default_factory=dict)
    relationships: list[dict[str, Any]] = Field(default_factory=list)
    knowledge_summary: dict[str, Any] = Field(default_factory=dict)
    forbidden_behavior: list[str] = Field(default_factory=list)
    last_active_chapter_no: Optional[int] = None


class MemoryFactSchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    chapter_no: int
    fact_type: str = "event"
    time_in_story: Optional[str] = None
    summary: str = Field(..., min_length=1)
    participants: list[str] = Field(default_factory=list)
    location: Optional[str] = None
    evidence: str = ""


class KnowledgeEntrySchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    fact: str
    truth_status: Literal[
        "confirmed_open",
        "confirmed_author_only",
        "hinted",
        "misdirection",
        "uncertain",
    ]
    visibility: dict[str, str] = Field(default_factory=dict)
    allowed_narration: dict[str, Any] = Field(default_factory=dict)
    source: str = ""


class BootstrapCanonSchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    chapter_count: int
    total_characters: int
    detected_status: str = "ready_for_canon_bootstrap"
    world_bible_sections: list[WorldBibleSectionSchema]
    character_cards: list[CharacterCardSchema]
    memory_facts: list[MemoryFactSchema]
    knowledge_matrix: list[KnowledgeEntrySchema]


class ImportAgent:
    name = "Import Agent"
    run_type = "bootstrap"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        chapters: list[dict[str, Any]] = agent_input.payload["chapters"]
        if config.llm_mode() == "live":
            result = self.gateway.complete_structured(
                json.dumps({"chapters": chapters}, ensure_ascii=False),
                schema_name="bootstrap_canon",
                schema=BootstrapCanonSchema,
                system=(
                    "你是长篇小说前三章导入分析 Agent。根据前三章正文生成初始 Canon 基础文件。"
                    "只返回一个 JSON object，不要 Markdown。必须严格按 JSON Schema 输出。"
                    "World Bible 必须覆盖七个 section_key："
                    + "、".join(WORLD_BIBLE_SECTION_KEYS)
                    + "。Character current_state 必须拆成 physical/emotional/goal；"
                    "voice 必须包含 dialogue_style 和 forbidden；Knowledge visibility 必须是 dict。"
                    "不要新增正文中没有依据的重大设定；不确定的信息写成怀疑、暗示或作者限定。"
                ),
                metadata={"agent": self.name, "novel_id": agent_input.novel_id},
            )
            analysis = _normalized_analysis(result.structured, chapters)
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary="已用大模型分析前三章并生成初始基础文件。",
                status="analysis_ready",
                payload=analysis,
                model=result.model,
                token_usage=result.token_usage,
            )

        analysis = _fallback_analysis(chapters)
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="导入前三章并生成确定性基础分析结果。",
            status="analysis_ready",
            payload=analysis,
        )


def _normalized_analysis(payload: dict[str, Any], chapters: list[dict[str, Any]]) -> dict[str, Any]:
    fallback = _fallback_analysis(chapters)
    total_chars = sum(len(str(chapter.get("text", ""))) for chapter in chapters)
    return {
        "chapter_count": int(payload.get("chapter_count") or len(chapters)),
        "total_characters": int(payload.get("total_characters") or total_chars),
        "detected_status": str(payload.get("detected_status") or "ready_for_canon_bootstrap"),
        "world_bible_sections": _normalized_world_sections(
            payload.get("world_bible_sections"),
            fallback["world_bible_sections"],
        ),
        "character_cards": _normalized_character_cards(payload.get("character_cards"), fallback["character_cards"]),
        "memory_facts": _list_or_fallback(payload.get("memory_facts"), fallback["memory_facts"]),
        "knowledge_matrix": _normalized_knowledge_entries(
            payload.get("knowledge_matrix"),
            fallback["knowledge_matrix"],
        ),
    }


def _normalized_world_sections(value: object, fallback: list[dict[str, Any]]) -> list[dict[str, Any]]:
    raw_items = _list_or_fallback(value, fallback)
    by_key = {
        str(item.get("section_key") or ""): dict(item)
        for item in raw_items
        if isinstance(item, dict) and item.get("section_key")
    }
    fallback_by_key = {item["section_key"]: item for item in fallback}
    sections = []
    for key in WORLD_BIBLE_SECTION_KEYS:
        item = dict(by_key.get(key) or fallback_by_key.get(key) or _placeholder_world_section(key))
        item["section_key"] = key
        sections.append(item)
    return sections


def _normalized_character_cards(value: object, fallback: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cards = []
    for item in _list_or_fallback(value, fallback):
        card = dict(item)
        voice = card.pop("voice", None)
        if voice is not None and "dialogue_style" not in card:
            card["dialogue_style"] = voice
        if isinstance(card.get("current_state"), str):
            card["current_state"] = {
                "physical": "",
                "emotional": card["current_state"],
                "goal": "",
            }
        cards.append(card)
    return cards


def _normalized_knowledge_entries(value: object, fallback: list[dict[str, Any]]) -> list[dict[str, Any]]:
    entries = []
    for item in _list_or_fallback(value, fallback):
        entry = dict(item)
        fact = entry.get("fact") or entry.get("fact_title") or "未命名知识条目"
        entry["fact"] = fact
        entry["fact_title"] = entry.get("fact_title") or fact
        entry["visibility"] = _visibility_dict(entry)
        entry["author_knowledge"] = entry["visibility"].get("author", entry.get("author_knowledge", "known"))
        entry["reader_knowledge"] = entry["visibility"].get("reader", entry.get("reader_knowledge", "reader_unknown"))
        entry["character_knowledge"] = []
        entries.append(entry)
    return entries


def _visibility_dict(entry: dict[str, Any]) -> dict[str, str]:
    visibility = dict(entry.get("visibility") or {})
    if entry.get("author_knowledge"):
        visibility.setdefault("author", str(entry["author_knowledge"]))
    if entry.get("reader_knowledge"):
        visibility.setdefault("reader", str(entry["reader_knowledge"]))
    for item in entry.get("character_knowledge") or []:
        if isinstance(item, dict):
            key = item.get("character_name") or item.get("character_id")
            if key:
                visibility[str(key)] = str(item.get("state") or "unknown")
    visibility.setdefault("author", "known")
    visibility.setdefault("reader", "reader_unknown")
    return visibility


def _list_or_fallback(value: object, fallback: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if isinstance(value, list) and value:
        return [item for item in value if isinstance(item, dict)]
    return fallback


def _fallback_analysis(chapters: list[dict[str, Any]]) -> dict[str, Any]:
    total_chars = sum(len(chapter.get("text", "")) for chapter in chapters)
    chapter_titles = [chapter.get("title") or f"第 {chapter.get('chapter_no', '?')} 章" for chapter in chapters]
    chapter_summaries = [
        {
            "chapter_no": int(chapter.get("chapter_no") or index + 1),
            "title": chapter.get("title") or f"第 {index + 1} 章",
            "summary": _trim_text(chapter.get("text", ""), 80),
        }
        for index, chapter in enumerate(chapters)
    ]
    return {
        "chapter_count": len(chapters),
        "total_characters": total_chars,
        "detected_status": "ready_for_canon_bootstrap",
        "world_bible_sections": [_fallback_world_section(key, chapter_titles) for key in WORLD_BIBLE_SECTION_KEYS],
        "character_cards": [
            {
                "name": "主角",
                "aliases": [],
                "role": "protagonist",
                "stable_traits": ["沿用前三章行为逻辑", "等待人工或大模型补全细节"],
                "current_state": {
                    "physical": "待补充",
                    "emotional": "已完成前三章导入，后续需基于原文细化当前状态。",
                    "goal": "延续前三章已经建立的行动目标。",
                },
                "dialogue_style": {"dialogue_style": "沿用前三章原文中的说话方式。", "forbidden": []},
                "relationships": [],
                "knowledge_summary": {"knows": [], "suspects": [], "does_not_know": []},
                "forbidden_behavior": ["不能突然知道前三章没有交代的信息。"],
                "last_active_chapter_no": 3,
            }
        ],
        "memory_facts": [
            {
                "chapter_no": item["chapter_no"],
                "fact_type": "bootstrap_chapter_summary",
                "time_in_story": item["title"],
                "summary": item["summary"],
                "participants": [],
                "location": None,
                "evidence": item["title"],
            }
            for item in chapter_summaries
        ],
        "knowledge_matrix": [
            {
                "fact_title": "前三章 Canon 已导入",
                "fact": "前三章原文已经作为当前小说 Canon 的起点。",
                "truth_status": "confirmed_open",
                "author_knowledge": "known",
                "reader_knowledge": "reader_known",
                "visibility": {"author": "known", "reader": "reader_known"},
                "allowed_narration": "后续章节可以引用前三章已经写明的事实，但不能把未写明的推断当成已确认事实。",
                "source": "bootstrap_fallback",
            }
        ],
    }


def _fallback_world_section(key: str, chapter_titles: list[str]) -> dict[str, Any]:
    title_by_key = {
        "tone_and_style": "叙事基调与文风",
        "real_world_background": "现实背景",
        "forbidden_patterns": "禁忌写法",
        "time_and_place": "时空信息",
        "themes": "主题母题",
        "profession_and_society": "职业与社会规则",
        "value_boundary": "价值边界",
    }
    content_by_key = {
        "tone_and_style": "保持前三章已有的叙事视角、节奏和语言密度，避免突然切换成聊天式、百科式或全知解释式写法。",
        "real_world_background": "前三章已导入，后续写作必须延续原文建立的现实逻辑、人物关系和社会规则。",
        "forbidden_patterns": "不能把前三章没有写明的推断当成事实，不能突然新增重大设定或破坏人物既有行为逻辑。",
        "time_and_place": "前三章包括：" + "、".join(chapter_titles) + "。后续章节按原文时间线自然推进。",
        "themes": "主题与人物关系需从前三章既有冲突中生长，避免为了制造戏剧性而脱离已导入文本。",
        "profession_and_society": "涉及学校、家庭、职业或公共机构时，按前三章呈现的现实约束处理，不使用游戏任务式推进。",
        "value_boundary": "人物互动必须遵守故事已经建立的伦理边界与知识边界，尤其不能用旁白泄露角色未知信息。",
    }
    return {
        "section_key": key,
        "title": title_by_key[key],
        "content": content_by_key[key],
        "tags": ["bootstrap", key],
        "importance": "high" if key in {"tone_and_style", "forbidden_patterns", "value_boundary"} else "low",
        "activation_policy": "always_considered" if key in {"forbidden_patterns", "value_boundary"} else "tag_matched",
    }


def _placeholder_world_section(key: str) -> dict[str, Any]:
    item = _fallback_world_section(key, ["前三章"])
    item["content"] = f"{item['title']}待补充；当前先保留模板位置，避免基础文件缺段。"
    item["importance"] = "low"
    return item


def _trim_text(value: object, limit: int) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= limit:
        return text
    return text[:limit].rstrip() + "..."
