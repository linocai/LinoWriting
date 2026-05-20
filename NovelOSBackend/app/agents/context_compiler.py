from __future__ import annotations

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class ContextCompilerAgent:
    name = "Context Compiler"
    run_type = "prompt"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        context_payload = dict(agent_input.payload["context_payload"])
        if config.llm_mode() == "live":
            prompt = agent_input.user_prompt or ""
            active_entities = context_payload.get("active_entities") or []
            focus_entities = [name for name in active_entities if name and name in prompt] or active_entities[:5]
            context_payload["llm_summary"] = {
                "summary": "本章上下文已按基础文件编译；生成时必须遵守人物白名单、知识边界和校园规则。",
                "risk_notes": [
                    "不新增命名角色",
                    "不让旁白确认 Knowledge Matrix 中读者未知的信息",
                    "校园/未成年人语境只允许非露骨的情绪、关系和边界描写",
                ],
                "focus_entities": focus_entities,
            }
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary="本地编译本章上下文摘要。",
                status="pass",
                payload=context_payload,
                model="local",
                token_usage={"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
            )

        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="生成 allowed names，隐藏非本章人物。",
            status="pass",
            payload=context_payload,
        )
