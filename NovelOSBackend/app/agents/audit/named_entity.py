from __future__ import annotations

from app.agents.base import AgentInput, AgentResult


class NamedEntityAuditorAgent:
    name = "Named Entity Auditor"
    run_type = "audit"

    def run(self, agent_input: AgentInput) -> AgentResult:
        summary = agent_input.payload["summary"]
        result = {
            "illegal_named_entity_count": summary["illegal_named_entity_count"],
            "inactive_character_appearance_count": summary["inactive_character_appearance_count"],
            "new_named_entity_count": summary["new_named_entity_count"],
            "passed": summary["s0_count"] == 0,
        }
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="检查非法命名实体、未激活人物和新增命名角色。",
            status="pass" if result["passed"] else "block",
            payload={"draft_id": agent_input.payload["draft_id"], **result},
        )
