from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


@dataclass(frozen=True)
class AgentInput:
    novel_id: str | None = None
    chapter_id: str | None = None
    user_prompt: str | None = None
    draft_text: str | None = None
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class AgentResult:
    agent_name: str
    summary: str
    status: str
    payload: dict[str, Any] = field(default_factory=dict)
    run_type: str = "workflow"
    error_message: str | None = None
    model: str | None = None
    token_usage: dict[str, Any] = field(default_factory=dict)


class BaseAgent(Protocol):
    name: str
    run_type: str

    def run(self, agent_input: AgentInput) -> AgentResult:
        ...
