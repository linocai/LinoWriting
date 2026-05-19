from __future__ import annotations

from app.agents.base import AgentInput, AgentResult


class CanonMergeAgent:
    name = "Canon Merge Agent"
    run_type = "canon"

    def run(self, agent_input: AgentInput) -> AgentResult:
        patch = agent_input.payload["patch"]
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="确认 Canon 更新补丁并记录编辑历史。",
            status="merged",
            payload={
                "patch_id": patch["id"],
                "target_canon_version": patch["target_canon_version"],
                "item_count": len(patch.get("items", [])),
            },
        )
