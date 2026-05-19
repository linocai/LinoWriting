from __future__ import annotations

from app.agents.base import AgentInput, AgentResult


class ContinuityAuditorAgent:
    name = "Continuity Auditor"
    run_type = "audit"

    def run(self, agent_input: AgentInput) -> AgentResult:
        summary = agent_input.payload["summary"]
        result = {
            "s1_count": summary["s1_count"],
            "s2_count": summary["s2_count"],
            "issues": summary["issues"],
            "passed": summary["s0_count"] == 0,
        }
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary=f"S0={summary['s0_count']}，S1={summary['s1_count']}，S2={summary['s2_count']}。",
            status="suggest" if summary["s1_count"] or summary["s2_count"] else "pass",
            payload={"draft_id": agent_input.payload["draft_id"], **result},
        )
