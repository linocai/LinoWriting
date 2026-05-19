from __future__ import annotations

from app import config
from app import mock_data
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class PromptExpanderAgent:
    name = "Prompt Expander"
    run_type = "prompt"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        if config.llm_mode() == "live":
            result = self.gateway.complete_structured(
                (
                    f"用户本章方向：{agent_input.user_prompt or ''}\n\n"
                    f"Context Pack：{agent_input.payload.get('context_payload', {})}"
                ),
                schema_name="structured_prompt",
                system=(
                    "你是长篇小说结构化 Prompt 扩展器。输出 JSON，字段必须包含："
                    "chapter_goal string, must_happen string[], must_not_happen string[], "
                    "allowed_named_entities [{name, activation, mention_budget}], narrative_style string, "
                    "activation_summary {active_cast, allowed_names_count, mention_budget_total, new_named_character_policy}, version number."
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


def _normalized_structured_prompt(payload: dict, chapter_id: str | None) -> dict:
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
