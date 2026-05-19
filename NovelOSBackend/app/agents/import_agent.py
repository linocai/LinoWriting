from __future__ import annotations

from typing import Any

from app.agents.base import AgentInput, AgentResult


class ImportAgent:
    name = "Import Agent"
    run_type = "bootstrap"

    def run(self, agent_input: AgentInput) -> AgentResult:
        chapters: list[dict[str, Any]] = agent_input.payload["chapters"]
        total_chars = sum(len(chapter.get("text", "")) for chapter in chapters)
        analysis = {
            "chapter_count": len(chapters),
            "total_characters": total_chars,
            "detected_status": "ready_for_canon_bootstrap",
        }
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="导入前三章并生成基础分析占位结果。",
            status="analysis_ready",
            payload=analysis,
        )
