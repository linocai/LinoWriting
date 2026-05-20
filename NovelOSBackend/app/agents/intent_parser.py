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
            prompt = agent_input.user_prompt or ""
            context_payload = agent_input.payload.get("context_payload", {})
            allowed_names = context_payload.get("allowed_named_entities") or []
            entities = [name for name in allowed_names if name and name in prompt]
            must_not_happen = [
                "不新增命名角色",
                "不泄露角色未知信息",
            ]
            if "露骨" in prompt or "性" in prompt or "越界" in prompt:
                must_not_happen.append("禁止露骨性描写、性行为和成人化凝视")
            payload = {
                "prompt": prompt,
                "entities": entities,
                "tone": _tone_from_prompt(prompt),
                "chapter_goal": prompt,
                "must_not_happen": must_not_happen,
            }
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary=f"本地识别 {len(entities)} 个显式实体，基调：{payload.get('tone', '未标注')}。",
                status="pass",
                payload=payload,
                model="local",
                token_usage={"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
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


def _tone_from_prompt(prompt: str) -> str:
    if "克制" in prompt:
        return "克制"
    if "紧张" in prompt:
        return "紧张"
    if "轻松" in prompt:
        return "轻松"
    return "未标注"
