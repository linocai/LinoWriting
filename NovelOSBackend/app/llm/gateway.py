from __future__ import annotations

from typing import Any, Protocol


class LLMGateway(Protocol):
    def complete_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        ...

    def complete_structured(
        self,
        prompt: str,
        *,
        schema_name: str,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        ...


class MockLLMGateway:
    """Deterministic gateway used until real model credentials are configured."""

    def complete_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        return prompt

    def complete_structured(
        self,
        prompt: str,
        *,
        schema_name: str,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return {
            "schema_name": schema_name,
            "prompt": prompt,
            "system": system,
            "metadata": metadata or {},
        }
