from __future__ import annotations

from app.agents.base import AgentInput, AgentResult


class ExtractionAgent:
    name = "Extraction Agent"
    run_type = "canon"

    def run(self, agent_input: AgentInput) -> AgentResult:
        draft = agent_input.payload["draft"]
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="从批准正文提取候选 Canon 更新。",
            status="candidate_facts_ready",
            payload={
                "draft_id": draft.id,
                "candidate_facts": [
                    "A 在旧码头发现门锁被更换。",
                    "B 在旧案相关细节上反应异常。",
                    "C 给出目击者线索。",
                ],
            },
        )
