from __future__ import annotations

from typing import Any

from app.agents.base import AgentInput, AgentResult
from app.agents.audit import ContinuityAuditorAgent, KnowledgeAuditorAgent, NamedEntityAuditorAgent
from app.llm.gateway import LLMGateway, make_llm_gateway
from app.agents.canon_merge_agent import CanonMergeAgent
from app.agents.context_compiler import ContextCompilerAgent
from app.agents.extraction_agent import ExtractionAgent
from app.agents.import_agent import ImportAgent
from app.agents.intent_parser import IntentParserAgent
from app.agents.prompt_expander import PromptExpanderAgent
from app.agents.revision_agent import RevisionAgent
from app.agents.safety import deterministic_audit_summary
from app.agents.writing_agent import WritingAgent


class ChapterWorkflowOrchestrator:
    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or make_llm_gateway()

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
            ContextCompilerAgent(self.gateway).run(agent_input),
            PromptExpanderAgent(self.gateway).run(agent_input),
        ]

    def run_writing(
        self,
        *,
        novel_id: str,
        chapter_id: str,
        draft: Any | None,
        chapter: Any | None = None,
        structured_prompt: dict[str, Any] | None = None,
        context_payload: dict[str, Any] | None = None,
    ) -> AgentResult:
        return WritingAgent(self.gateway).run(
            AgentInput(
                novel_id=novel_id,
                chapter_id=chapter_id,
                payload={
                    "draft": draft,
                    "chapter": chapter,
                    "structured_prompt": structured_prompt or {},
                    "context_payload": context_payload or {},
                },
            )
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
        return RevisionAgent(self.gateway).run(
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
        summary = deterministic_audit_summary(
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
        return ImportAgent(self.gateway).run(
            AgentInput(novel_id=novel_id, payload={"chapters": chapters})
        )

    def run_extraction(self, *, novel_id: str, chapter_id: str, draft: Any) -> AgentResult:
        return ExtractionAgent(self.gateway).run(
            AgentInput(novel_id=novel_id, chapter_id=chapter_id, payload={"draft": draft})
        )

    def run_canon_merge(self, *, novel_id: str, chapter_id: str, patch: dict[str, Any]) -> AgentResult:
        return CanonMergeAgent().run(
            AgentInput(novel_id=novel_id, chapter_id=chapter_id, payload={"patch": patch})
        )
