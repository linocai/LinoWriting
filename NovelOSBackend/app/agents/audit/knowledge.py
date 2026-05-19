from __future__ import annotations

from app.agents.base import AgentInput, AgentResult


class KnowledgeAuditorAgent:
    name = "Knowledge Auditor"
    run_type = "audit"

    def run(self, agent_input: AgentInput) -> AgentResult:
        summary = agent_input.payload["summary"]
        result = {
            "knowledge_violation_count": summary["knowledge_violation_count"],
            "checked_limits": [
                "A cannot know the full truth of the old case",
                "Narration cannot confirm B's full involvement",
            ],
            "passed": summary["knowledge_violation_count"] == 0,
        }
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="检查 Knowledge Matrix 限制和旁白泄露风险。",
            status="pass" if result["passed"] else "block",
            payload={"draft_id": agent_input.payload["draft_id"], **result},
        )
