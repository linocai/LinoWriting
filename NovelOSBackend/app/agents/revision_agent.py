from __future__ import annotations

from app import config
from app.agents.base import AgentInput, AgentResult
from app.llm.gateway import LLMGateway, MockLLMGateway


class RevisionAgent:
    name = "Revision Agent"
    run_type = "draft"

    def __init__(self, gateway: LLMGateway | None = None) -> None:
        self.gateway = gateway or MockLLMGateway()

    def run(self, agent_input: AgentInput) -> AgentResult:
        current = agent_input.payload["current"]
        revision = agent_input.payload["revision"]
        feedback = agent_input.payload.get("feedback") or ""
        if config.llm_mode() == "live" and revision is None:
            result = self.gateway.complete_text(
                (
                    f"当前正文：\n{current.text}\n\n"
                    f"用户修改意见：{feedback}\n\n"
                    "请输出修改后的完整正文，不要附加解释。"
                ),
                system=(
                    "你是长篇小说修订 Agent。必须保留 canon 约束，并严格回应用户反馈。"
                    "如人物处于校园或未成年人语境，只能写非露骨的情绪、关系和边界试探，"
                    "不得描写性行为、露骨性细节或成人化凝视。"
                ),
                metadata={"agent": self.name, "chapter_id": agent_input.chapter_id},
            )
            text = result.content.strip()
            return AgentResult(
                agent_name=self.name,
                run_type=self.run_type,
                summary=f"按用户意见生成修订正文，字数 {len(text)}。",
                status="revision_generated",
                payload={
                    "from_draft_id": current.id,
                    "text": text,
                    "word_count": len(text),
                    "feedback": feedback,
                    "version_no": current.version_no + 1,
                },
                model=result.model,
                token_usage=result.token_usage,
            )

        return AgentResult(
            agent_name=self.name,
            run_type=self.run_type,
            summary=f"按用户意见生成 v{revision.version_no}，保留正文审核步骤。",
            status="revision_generated",
            payload={
                "from_draft_id": current.id,
                "draft_id": revision.id,
                "feedback": feedback,
                "version_no": revision.version_no,
            },
        )
