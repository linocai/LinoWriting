from __future__ import annotations

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class ExtractionAgent:
    name = "Extraction Agent"
    run_type = "canon"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        draft = agent_input.payload["draft"]
        if config.llm_mode() == "live":
            result = self.gateway.complete_structured(
                draft.text,
                schema_name="canon_extraction",
                system=(
                    "你是长篇小说 Canon 抽取 Agent。根据已批准正文抽取可写入基础文件的变化。"
                    "只返回 JSON object，字段包含 candidate_facts string[]、knowledge_entries string[]、"
                    "world_bible_updates string[]、character_updates string[]。"
                    "只抽取正文明确发生或强暗示的信息，不要编造。"
                ),
                metadata={"agent": self.name, "chapter_id": agent_input.chapter_id},
            )
            payload = result.structured
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary="从批准正文提取候选 Canon 更新。",
                status="candidate_facts_ready",
                payload={
                    "draft_id": draft.id,
                    "candidate_facts": _string_list(payload.get("candidate_facts")),
                    "knowledge_entries": _string_list(payload.get("knowledge_entries")),
                    "world_bible_updates": _string_list(payload.get("world_bible_updates")),
                    "character_updates": _string_list(payload.get("character_updates")),
                },
                model=result.model,
                token_usage=result.token_usage,
            )

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


def _string_list(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]
