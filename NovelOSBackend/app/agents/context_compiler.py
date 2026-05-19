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
            result = self.gateway.complete_structured(
                str(context_payload),
                schema_name="context_pack_summary",
                system=(
                    "你是小说上下文编译器。根据输入 context pack，输出 JSON："
                    "summary: string, risk_notes: string[], focus_entities: string[]."
                ),
                metadata={"agent": self.name, "chapter_id": agent_input.chapter_id},
            )
            context_payload["llm_summary"] = result.structured
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary=result.structured.get("summary", "已生成本章上下文摘要。"),
                status="pass",
                payload=context_payload,
                model=result.model,
                token_usage=result.token_usage,
            )

        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="生成 allowed names，隐藏非本章人物。",
            status="pass",
            payload=context_payload,
        )
