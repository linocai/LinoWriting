from __future__ import annotations

from typing import Any

from app.agents.base import AgentInput, AgentResult
from app.agents.mock_agents import (
    ContextCompilerAgent,
    ContinuityAuditorAgent,
    ImportAgent,
    IntentParserAgent,
    KnowledgeAuditorAgent,
    NamedEntityAuditorAgent,
    PromptExpanderAgent,
    RevisionAgent,
    WritingAgent,
    safety_summary_for_draft,
)
from app.llm.gateway import LLMGateway, MockLLMGateway


class ChapterWorkflowOrchestrator:
    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run_prompt(
        self,
        *,
        novel_id: str,
        chapter_id: str,
        prompt: str,
        context_payload: dict[str, Any],
    ) -> list[AgentResult]:
        agent_input = AgentInput(
            novel_id=novel_id,
            chapter_id=chapter_id,
            user_prompt=prompt,
            payload={"context_payload": context_payload},
        )
        return [
            IntentParserAgent(self.gateway).run(agent_input),
            ContextCompilerAgent().run(agent_input),
            PromptExpanderAgent().run(agent_input),
        ]

    def run_writing(self, *, novel_id: str, chapter_id: str, draft: Any) -> AgentResult:
        return WritingAgent().run(
            AgentInput(novel_id=novel_id, chapter_id=chapter_id, payload={"draft": draft})
        )

    def run_revision(
        self,
        *,
        novel_id: str,
        chapter_id: str,
        current: Any,
        revision: Any,
        feedback: str | None,
    ) -> AgentResult:
        return RevisionAgent().run(
            AgentInput(
                novel_id=novel_id,
                chapter_id=chapter_id,
                payload={"current": current, "revision": revision, "feedback": feedback or ""},
            )
        )

    def run_audit(
        self,
        *,
        novel_id: str,
        chapter_id: str,
        draft_id: str,
        draft_text: str,
        context_payload: dict[str, Any],
        base_summary: dict[str, Any] | None,
    ) -> tuple[dict[str, Any], list[AgentResult]]:
        summary = safety_summary_for_draft(
            draft_text,
            context_payload,
            base_summary=base_summary,
        )
        agent_input = AgentInput(
            novel_id=novel_id,
            chapter_id=chapter_id,
            draft_text=draft_text,
            payload={"draft_id": draft_id, "summary": summary},
        )
        return summary, [
            NamedEntityAuditorAgent().run(agent_input),
            KnowledgeAuditorAgent().run(agent_input),
            ContinuityAuditorAgent().run(agent_input),
        ]

    def run_bootstrap_analysis(
        self,
        *,
        novel_id: str,
        chapters: list[dict[str, Any]],
    ) -> AgentResult:
        return ImportAgent().run(
            AgentInput(novel_id=novel_id, payload={"chapters": chapters})
        )
