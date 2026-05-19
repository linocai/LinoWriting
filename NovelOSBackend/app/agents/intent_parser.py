from __future__ import annotations

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class IntentParserAgent:
    name = "Intent Parser"
    run_type = "prompt"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        if config.llm_mode() == "live":
            result = self.gateway.complete_structured(
                agent_input.user_prompt or "",
                schema_name="intent_parser",
                system=(
                    "你是长篇小说章节意图解析器。解析用户本章方向，输出 JSON："
                    "entities: string[], tone: string, chapter_goal: string, must_not_happen: string[]."
                ),
                metadata={"agent": self.name, "chapter_id": agent_input.chapter_id},
            )
            payload = result.structured
            entities = payload.get("entities") or payload.get("named_entities") or []
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary=f"识别 {len(entities)} 个显式实体，基调：{payload.get('tone', '未标注')}。",
                status="pass",
                payload={**payload, "entities": entities},
                model=result.model,
                token_usage=result.token_usage,
            )

        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="识别 A/B/C、旧码头、旧案、冷感基调。",
            status="pass",
            payload={
                "prompt": agent_input.user_prompt or "",
                "entities": ["A", "B", "C", "旧码头", "旧案"],
            },
        )
