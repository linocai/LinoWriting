from __future__ import annotations

from dataclasses import dataclass, field
import json
import re
from typing import Any, Protocol

import httpx

from app import config


class LLMGatewayError(RuntimeError):
    pass


@dataclass(frozen=True)
class LLMResult:
    content: str
    model: str = "mock"
    token_usage: dict[str, int] = field(default_factory=dict)
    raw: dict[str, Any] = field(default_factory=dict)

    @property
    def structured(self) -> dict[str, Any]:
        return _parse_json_object(self.content)


class LLMGateway(Protocol):
    def complete_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> LLMResult:
        ...

    def complete_structured(
        self,
        prompt: str,
        *,
        schema_name: str,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> LLMResult:
        ...


class MockLLMGateway:
    """Deterministic gateway used until real model credentials are configured."""

    def complete_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> LLMResult:
        return LLMResult(content=prompt, model="mock", token_usage={})

    def complete_structured(
        self,
        prompt: str,
        *,
        schema_name: str,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> LLMResult:
        return LLMResult(content=json.dumps({
            "schema_name": schema_name,
            "prompt": prompt,
            "system": system,
            "metadata": metadata or {},
        }, ensure_ascii=False), model="mock", token_usage={})


class OpenAICompatibleGateway:
    def __init__(
        self,
        *,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        timeout_seconds: float | None = None,
        client: httpx.Client | None = None,
    ) -> None:
        self.api_key = api_key or config.openai_compatible_api_key()
        self.base_url = (base_url or config.openai_compatible_base_url()).rstrip("/")
        self.model = model or config.openai_compatible_model()
        self.timeout_seconds = timeout_seconds or config.openai_compatible_timeout_seconds()
        self.client = client

    def complete_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> LLMResult:
        return self._chat(prompt, system=system, metadata=metadata)

    def complete_structured(
        self,
        prompt: str,
        *,
        schema_name: str,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> LLMResult:
        structured_system = "\n".join(
            part
            for part in [
                system,
                f"Return only one valid JSON object for schema `{schema_name}`.",
                "Do not wrap JSON in Markdown fences. Do not include commentary.",
            ]
            if part
        )
        result = self._chat(
            prompt,
            system=structured_system,
            metadata={**(metadata or {}), "schema_name": schema_name},
            response_format={"type": "json_object"},
        )
        _parse_json_object(result.content)
        return result

    def _chat(
        self,
        prompt: str,
        *,
        system: str | None,
        metadata: dict[str, Any] | None,
        response_format: dict[str, Any] | None = None,
    ) -> LLMResult:
        if not self.api_key:
            raise LLMGatewayError("OPENAI_COMPATIBLE_API_KEY is required when NOVEL_OS_LLM_MODE=live.")

        messages: list[dict[str, str]] = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        body: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.4,
            "metadata": metadata or {},
        }
        if response_format:
            body["response_format"] = response_format

        client = self.client or httpx.Client(timeout=self.timeout_seconds)
        should_close = self.client is None
        try:
            response = client.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
            response.raise_for_status()
            payload = response.json()
        except httpx.HTTPError as exc:
            raise LLMGatewayError(f"LLM request failed: {exc}") from exc
        except ValueError as exc:
            raise LLMGatewayError("LLM response was not valid JSON.") from exc
        finally:
            if should_close:
                client.close()

        try:
            content = payload["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LLMGatewayError("LLM response did not include choices[0].message.content.") from exc

        usage = payload.get("usage") or {}
        return LLMResult(
            content=content,
            model=payload.get("model") or self.model,
            token_usage={
                "prompt_tokens": int(usage.get("prompt_tokens", 0) or 0),
                "completion_tokens": int(usage.get("completion_tokens", 0) or 0),
                "total_tokens": int(usage.get("total_tokens", 0) or 0),
            },
            raw=payload,
        )


def make_llm_gateway() -> LLMGateway:
    if config.llm_mode() == "live":
        return OpenAICompatibleGateway()
    return MockLLMGateway()


def _parse_json_object(content: str) -> dict[str, Any]:
    stripped = content.strip()
    fenced = re.fullmatch(r"```(?:json)?\s*(.*?)\s*```", stripped, flags=re.DOTALL)
    if fenced:
        stripped = fenced.group(1).strip()
    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError as exc:
        raise LLMGatewayError("LLM response was not a valid JSON object.") from exc
    if not isinstance(parsed, dict):
        raise LLMGatewayError("LLM response JSON must be an object.")
    return parsed
