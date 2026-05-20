from __future__ import annotations

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class WritingAgent:
    name = "Writing Agent"
    run_type = "draft"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        draft = agent_input.payload["draft"]
        if config.llm_mode() == "live" and draft is None:
            chapter = agent_input.payload.get("chapter")
            structured_prompt = agent_input.payload.get("structured_prompt") or {}
            context_payload = agent_input.payload.get("context_payload") or {}
            target_word_count = getattr(chapter, "target_word_count", 3000)
            result = self.gateway.complete_text(
                (
                    f"目标字数：约 {target_word_count} 字。\n\n"
                    f"结构化 Prompt：{structured_prompt}\n\n"
                    f"Context Pack：{context_payload}\n\n"
                    "请直接输出正文，不要附加解释。"
                ),
                system=(
                    "你是长篇小说正文写作 Agent。必须遵守 Context Pack 的人物白名单、"
                    "知识边界和结构化 Prompt。不要新增命名角色，不要提前泄露真相。"
                    "如人物处于校园或未成年人语境，只能写非露骨的情绪、关系和边界试探，"
                    "不得描写性行为、露骨性细节或成人化凝视。"
                ),
                metadata={"agent": self.name, "chapter_id": agent_input.chapter_id},
            )
            text = result.content.strip()
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary=f"生成正文，字数 {len(text)}。",
                status="draft_generated",
                payload={"text": text, "word_count": len(text), "version_no": 1},
                model=result.model,
                token_usage=result.token_usage,
            )

        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary=f"生成正文 v{draft.version_no}，字数 {draft.word_count}，S0=0。",
            status="draft_generated",
            payload={"draft_id": draft.id, "version_no": draft.version_no},
        )
