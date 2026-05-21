from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field

from app import config
from app import mock_data
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class AllowedNamedEntitySchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    name: str
    activation: str = "ACTIVE"
    mention_budget: Optional[int] = None


class ActivationSummarySchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    active_cast: list[str] = Field(default_factory=list)
    allowed_names_count: int = 0
    mention_budget_total: int = 0
    new_named_character_policy: str = "禁止，除非结构化 Prompt 明确批准"


class StructuredPromptSchema(BaseModel):
    model_config = ConfigDict(extra="ignore")

    chapter_goal: str
    must_happen: list[str] = Field(default_factory=list)
    must_not_happen: list[str] = Field(default_factory=list)
    allowed_named_entities: list[AllowedNamedEntitySchema] = Field(default_factory=list)
    narrative_style: str = ""
    activation_summary: Optional[ActivationSummarySchema] = None
    version: int = 1


class PromptExpanderAgent:
    name = "Prompt Expander"
    run_type = "prompt"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        if config.llm_mode() == "live":
            context_payload = agent_input.payload.get("context_payload", {}) or {}
            style_directives = context_payload.get("style_directives") or []
            directives_hint = ""
            if style_directives:
                joined = "; ".join(str(d) for d in style_directives if d)
                directives_hint = (
                    f"本书 World Bible 题材与文风约束：{joined}。"
                    "must_not_happen 必须显式包含这些约束的反向条目。"
                )
            result = self.gateway.complete_structured(
                (
                    f"用户本章方向：{agent_input.user_prompt or ''}\n\n"
                    f"Context Pack：{context_payload}"
                ),
                schema_name="structured_prompt",
                schema=StructuredPromptSchema,
                system=(
                    "你是长篇小说结构化 Prompt 扩展器。输出 JSON，字段必须包含："
                    "chapter_goal string, must_happen string[], must_not_happen string[], "
                    "allowed_named_entities [{name, activation, mention_budget}], narrative_style string, "
                    "activation_summary {active_cast, allowed_names_count, mention_budget_total, new_named_character_policy}, version number."
                    f"{directives_hint}"
                ),
                metadata={"agent": self.name, "chapter_id": agent_input.chapter_id},
            )
            structured_prompt = _normalized_structured_prompt(result.structured, agent_input.chapter_id)
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary="生成结构化 Prompt。",
                status="ready_for_review",
                payload=structured_prompt,
                model=result.model,
                token_usage=result.token_usage,
            )

        structured_prompt = dict(mock_data.STRUCTURED_PROMPT)
        structured_prompt["chapter_id"] = agent_input.chapter_id
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="生成结构化 Prompt。",
            status="ready_for_review",
            payload=structured_prompt,
        )


def _normalized_structured_prompt(payload: dict[str, Any], chapter_id: str | None) -> dict:
    allowed = [
        {
            **item,
            "activation": _normalize_activation(item.get("activation")),
        }
        for item in payload.get("allowed_named_entities") or []
        if isinstance(item, dict)
    ]
    active_cast = [
        item.get("name")
        for item in allowed
        if item.get("activation") == "ACTIVE"
    ]
    mention_budget_total = sum(
        int(item.get("mention_budget") or 0)
        for item in allowed
    )
    return {
        "id": payload.get("id") or f"sp_{chapter_id or 'chapter'}_live",
        "chapter_id": chapter_id or payload.get("chapter_id") or "",
        "chapter_goal": payload.get("chapter_goal") or "",
        "must_happen": payload.get("must_happen") or [],
        "must_not_happen": payload.get("must_not_happen") or [],
        "allowed_named_entities": allowed,
        "narrative_style": payload.get("narrative_style") or "",
        "activation_summary": payload.get("activation_summary") or {
            "active_cast": active_cast,
            "allowed_names_count": len(allowed),
            "mention_budget_total": mention_budget_total,
            "new_named_character_policy": "禁止，除非结构化 Prompt 明确批准",
        },
        "version": int(payload.get("version") or 1),
    }


def _normalize_activation(value: object) -> str:
    raw = str(value or "ACTIVE").strip().upper().replace("-", "_").replace(" ", "_")
    aliases = {
        "ACTIVE": "ACTIVE",
        "MENTION": "MENTION_ALLOWED",
        "MENTION_ALLOWED": "MENTION_ALLOWED",
        "MENTIONALLOWED": "MENTION_ALLOWED",
        "BACKGROUND": "BACKGROUND",
        "LOCKED_OUT": "LOCKED_OUT",
        "LOCKEDOUT": "LOCKED_OUT",
        "NEW_ALLOWED": "NEW_ALLOWED",
        "NEWALLOWED": "NEW_ALLOWED",
    }
    return aliases.get(raw, "ACTIVE")
