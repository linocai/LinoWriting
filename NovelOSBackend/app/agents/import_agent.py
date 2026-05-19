from __future__ import annotations

import json
from typing import Any

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


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
                system=(
                    "你是长篇小说前三章导入分析 Agent。根据前三章正文生成初始 Canon 基础文件。"
                    "只返回一个 JSON object，不要 Markdown。字段必须包含："
                    "chapter_count number, total_characters number, detected_status string, "
                    "world_bible_sections array, character_cards array, memory_facts array, knowledge_matrix array。"
                    "world_bible_sections 每项包含 title, content, tags, importance, activation_policy。"
                    "character_cards 每项包含 name, aliases, role, stable_traits, current_state, dialogue_style, "
                    "relationships, forbidden_behavior, last_active_chapter_no。"
                    "memory_facts 每项包含 chapter_no, fact_type, time_in_story, summary, participants, location, evidence。"
                    "knowledge_matrix 每项包含 fact_title, fact, truth_status, author_knowledge, reader_knowledge, "
                    "character_knowledge, allowed_narration。"
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
    normalized = {
        "chapter_count": int(payload.get("chapter_count") or len(chapters)),
        "total_characters": int(payload.get("total_characters") or total_chars),
        "detected_status": str(payload.get("detected_status") or "ready_for_canon_bootstrap"),
        "world_bible_sections": _list_or_fallback(payload.get("world_bible_sections"), fallback["world_bible_sections"]),
        "character_cards": _list_or_fallback(payload.get("character_cards"), fallback["character_cards"]),
        "memory_facts": _list_or_fallback(payload.get("memory_facts"), fallback["memory_facts"]),
        "knowledge_matrix": _list_or_fallback(payload.get("knowledge_matrix"), fallback["knowledge_matrix"]),
    }
    return normalized


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
        "world_bible_sections": [
            {
                "title": "开篇三章总览",
                "content": "前三章已导入。章节包括：" + "、".join(chapter_titles) + "。后续写作应延续这些章节已经建立的叙事事实、人物关系和语气。",
                "tags": ["bootstrap", "opening"],
                "importance": "high",
                "activation_policy": "always_in_context_brief",
            },
            {
                "title": "叙事基调",
                "content": "保持前三章已有的叙事视角、节奏和语言密度。不要在后续章节中突然切换成聊天式、百科式或全知解释式写法。",
                "tags": ["style", "tone"],
                "importance": "medium",
                "activation_policy": "always_considered",
            },
        ],
        "character_cards": [
            {
                "name": "主角",
                "aliases": [],
                "role": "核心视角人物",
                "stable_traits": ["由前三章导入内容初始化，等待人工或大模型补全"],
                "current_state": "已完成前三章导入，后续需基于原文细化当前状态。",
                "dialogue_style": "沿用前三章原文中的说话方式。",
                "relationships": [],
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
                "truth_status": "confirmed",
                "author_knowledge": "known",
                "reader_knowledge": "reader_known",
                "character_knowledge": [],
                "allowed_narration": "后续章节可以引用前三章已经写明的事实，但不能把未写明的推断当成已确认事实。",
            }
        ],
    }


def _trim_text(value: object, limit: int) -> str:
    text = " ".join(str(value or "").split())
    if len(text) <= limit:
        return text
    return text[:limit].rstrip() + "..."
