from __future__ import annotations

from typing import Any

from app import mock_data
from app.agents.base import AgentInput, AgentResult
from app.agents.safety import deterministic_audit_summary
from app.llm.gateway import LLMGateway, MockLLMGateway


class IntentParserAgent:
    name = "Intent Parser"
    run_type = "prompt"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="识别 A/B/C、旧码头、旧案、冷感基调。",
            status="pass",
            payload={
                "prompt": agent_input.user_prompt or "",
                "entities": ["A", "B", "C", "旧码头", "旧案"],
            },
        )


class ContextCompilerAgent:
    name = "Context Compiler"
    run_type = "prompt"

    def run(self, agent_input: AgentInput) -> AgentResult:
        context_payload = dict(agent_input.payload["context_payload"])
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="生成 allowed names，隐藏非本章人物。",
            status="pass",
            payload=context_payload,
        )


class PromptExpanderAgent:
    name = "Prompt Expander"
    run_type = "prompt"

    def run(self, agent_input: AgentInput) -> AgentResult:
        structured_prompt = dict(mock_data.STRUCTURED_PROMPT)
        structured_prompt["chapter_id"] = agent_input.chapter_id
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary="生成结构化 Prompt。",
            status="ready_for_review",
            payload=structured_prompt,
        )


class WritingAgent:
    name = "Writing Agent"
    run_type = "draft"

    def run(self, agent_input: AgentInput) -> AgentResult:
        draft = agent_input.payload["draft"]
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary=f"生成正文 v{draft.version_no}，字数 {draft.word_count}，S0=0。",
            status="draft_generated",
            payload={"draft_id": draft.id, "version_no": draft.version_no},
        )


class RevisionAgent:
    name = "Revision Agent"
    run_type = "draft"

    def run(self, agent_input: AgentInput) -> AgentResult:
        current = agent_input.payload["current"]
        revision = agent_input.payload["revision"]
        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary=f"按用户意见生成 v{revision.version_no}，保留正文审核步骤。",
            status="revision_generated",
            payload={
                "from_draft_id": current.id,
                "draft_id": revision.id,
                "feedback": agent_input.payload.get("feedback") or "",
                "version_no": revision.version_no,
            },
        )


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


def safety_summary_for_draft(
    draft_text: str,
    context_payload: dict[str, Any],
    *,
    base_summary: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return deterministic_audit_summary(draft_text, context_payload, base_summary=base_summary)
