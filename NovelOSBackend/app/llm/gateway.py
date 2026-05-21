from __future__ import annotations

from dataclasses import dataclass, field
import json
import re
import time
from collections.abc import Iterator
from typing import Any, Protocol

import httpx
from pydantic import BaseModel, ValidationError

from app import config
from app.llm.errors import (
    LLMAuthError,
    LLMGatewayError,
    LLMJSONParseError,
    LLMProviderError,
    LLMRateLimitError,
    LLMTimeoutError,
)


@dataclass(frozen=True)
class LLMResult:
    content: str
    model: str = "mock"
    token_usage: dict[str, Any] = field(default_factory=dict)
    raw: dict[str, Any] = field(default_factory=dict)

    @property
    def structured(self) -> dict[str, Any]:
        return _parse_json_object(self.content)


@dataclass(frozen=True)
class LLMStreamChunk:
    content: str = ""
    model: str = "mock"
    token_usage: dict[str, Any] = field(default_factory=dict)
    raw: dict[str, Any] = field(default_factory=dict)


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
        schema: type[BaseModel] | None = None,
    ) -> LLMResult:
        ...

    def stream_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> Iterator[LLMStreamChunk]:
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
        schema: type[BaseModel] | None = None,
    ) -> LLMResult:
        payload = {
            "schema_name": schema_name,
            "prompt": prompt,
            "system": system,
            "metadata": metadata or {},
        }
        if schema is not None:
            payload = schema.model_validate(payload).model_dump(mode="json")
        return LLMResult(
            content=json.dumps(payload, ensure_ascii=False),
            model="mock",
            token_usage={"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0, "model": "mock"},
        )

    def stream_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> Iterator[LLMStreamChunk]:
        for start in range(0, len(prompt), 160):
            yield LLMStreamChunk(content=prompt[start : start + 160], model="mock")
        yield LLMStreamChunk(
            content="",
            model="mock",
            token_usage={"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0, "model": "mock"},
        )


class OpenAICompatibleGateway:
    def __init__(
        self,
        *,
        provider: config.LLMProviderConfig | None = None,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
        timeout_seconds: float | None = None,
        client: httpx.Client | None = None,
        max_attempts: int = 3,
        retry_backoff: tuple[float, ...] = (0.5, 1.5, 4.0),
        rate_limit_backoff: tuple[float, ...] = (4.0, 8.0, 16.0),
    ) -> None:
        active_provider = provider or config.active_llm_provider()
        self.api_key = api_key or (active_provider.api_key if active_provider else None) or config.openai_compatible_api_key()
        self.base_url = (
            base_url
            or (active_provider.base_url if active_provider else None)
            or config.openai_compatible_base_url()
        ).rstrip("/")
        self.model = model or (active_provider.model if active_provider else None) or config.openai_compatible_model()
        self.timeout_seconds = (
            timeout_seconds
            or (active_provider.timeout_seconds if active_provider else None)
            or config.openai_compatible_timeout_seconds()
        )
        self.client = client
        self.max_attempts = max(1, max_attempts)
        self.retry_backoff = retry_backoff
        self.rate_limit_backoff = rate_limit_backoff

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
        schema: type[BaseModel] | None = None,
    ) -> LLMResult:
        schema_prompt = _schema_instruction(schema_name, schema)
        structured_system = _join_system(system, schema_prompt)
        last_error: LLMGatewayError | None = None
        for attempt in range(2):
            attempt_system = structured_system
            if attempt:
                attempt_system = _join_system(
                    structured_system,
                    "上一次输出没有通过 JSON schema 校验。必须严格输出符合 schema 的单个 JSON object，不要解释。",
                )
            result = self._chat(
                prompt,
                system=attempt_system,
                metadata={**(metadata or {}), "schema_name": schema_name},
                response_format={"type": "json_object"},
            )
            try:
                parsed = _parse_json_object(result.content)
                if schema is None:
                    return result
                model = schema.model_validate(parsed)
                return LLMResult(
                    content=json.dumps(model.model_dump(mode="json"), ensure_ascii=False),
                    model=result.model,
                    token_usage=result.token_usage,
                    raw=result.raw,
                )
            except (LLMJSONParseError, ValidationError) as exc:
                if isinstance(exc, LLMJSONParseError):
                    last_error = exc
                else:
                    last_error = LLMJSONParseError(
                        "LLM response failed schema validation.",
                        raw_preview=result.content[:500],
                    )
                if attempt == 0:
                    continue
                raise last_error
        raise last_error or LLMJSONParseError("LLM response was not a valid JSON object.")

    def stream_text(
        self,
        prompt: str,
        *,
        system: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> Iterator[LLMStreamChunk]:
        if not self.api_key:
            raise LLMAuthError("OPENAI_COMPATIBLE_API_KEY is required when NOVEL_OS_LLM_MODE=live.")

        messages: list[dict[str, str]] = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        body: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.4,
            "metadata": metadata or {},
            "stream": True,
            "stream_options": {"include_usage": True},
        }

        client = self.client or httpx.Client(timeout=self.timeout_seconds)
        should_close = self.client is None
        try:
            with client.stream(
                "POST",
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
            ) as response:
                response.raise_for_status()
                for line in response.iter_lines():
                    if not line:
                        continue
                    if isinstance(line, bytes):
                        line = line.decode("utf-8", errors="replace")
                    if not line.startswith("data:"):
                        continue
                    data = line.removeprefix("data:").strip()
                    if data == "[DONE]":
                        break
                    try:
                        payload = json.loads(data)
                    except json.JSONDecodeError as exc:
                        raise LLMProviderError("LLM stream emitted invalid JSON.", retryable=True) from exc
                    choice = (payload.get("choices") or [{}])[0] if payload.get("choices") else {}
                    delta = choice.get("delta") or {}
                    content = delta.get("content") or ""
                    usage = payload.get("usage") or {}
                    yield LLMStreamChunk(
                        content=content,
                        model=payload.get("model") or self.model,
                        token_usage={
                            "prompt_tokens": int(usage.get("prompt_tokens", 0) or 0),
                            "completion_tokens": int(usage.get("completion_tokens", 0) or 0),
                            "total_tokens": int(usage.get("total_tokens", 0) or 0),
                            "model": payload.get("model") or self.model,
                        }
                        if usage
                        else {},
                        raw=payload,
                    )
        except httpx.TimeoutException as exc:
            raise LLMTimeoutError("正文流式生成超时，请重试。") from exc
        except httpx.HTTPStatusError as exc:
            raise _error_from_http_status(exc) from exc
        except httpx.RequestError as exc:
            raise LLMProviderError(f"无法连接模型接口：{exc}") from exc
        finally:
            if should_close:
                client.close()

    def _chat(
        self,
        prompt: str,
        *,
        system: str | None,
        metadata: dict[str, Any] | None,
        response_format: dict[str, Any] | None = None,
    ) -> LLMResult:
        if not self.api_key:
            raise LLMAuthError("OPENAI_COMPATIBLE_API_KEY is required when NOVEL_OS_LLM_MODE=live.")

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

        payload = self._post_with_retry(body)

        try:
            content = payload["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LLMProviderError("LLM response did not include choices[0].message.content.") from exc

        usage = payload.get("usage") or {}
        return LLMResult(
            content=content,
            model=payload.get("model") or self.model,
            token_usage={
                "prompt_tokens": int(usage.get("prompt_tokens", 0) or 0),
                "completion_tokens": int(usage.get("completion_tokens", 0) or 0),
                "total_tokens": int(usage.get("total_tokens", 0) or 0),
                "model": payload.get("model") or self.model,
            },
            raw=payload,
        )

    def _post_with_retry(self, body: dict[str, Any]) -> dict[str, Any]:
        last_error: LLMGatewayError | None = None
        for attempt in range(self.max_attempts):
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
                return response.json()
            except httpx.TimeoutException as exc:
                last_error = LLMTimeoutError("请求超时，请稍后重试或调高 Provider timeout。")
                if not _should_retry(last_error, attempt, self.max_attempts):
                    raise last_error from exc
                self._sleep_before_retry(last_error, attempt)
            except httpx.HTTPStatusError as exc:
                last_error = _error_from_http_status(exc)
                if not _should_retry(last_error, attempt, self.max_attempts):
                    raise last_error from exc
                self._sleep_before_retry(last_error, attempt)
            except httpx.RequestError as exc:
                last_error = LLMProviderError(f"无法连接模型接口：{exc}")
                if not _should_retry(last_error, attempt, self.max_attempts):
                    raise last_error from exc
                self._sleep_before_retry(last_error, attempt)
            except ValueError as exc:
                raise LLMProviderError("LLM response was not valid JSON.", retryable=True) from exc
            finally:
                if should_close:
                    client.close()
        raise last_error or LLMProviderError("模型接口请求失败。")

    def _sleep_before_retry(self, error: LLMGatewayError, attempt: int) -> None:
        backoff = self.rate_limit_backoff if isinstance(error, LLMRateLimitError) else self.retry_backoff
        if not backoff:
            return
        delay = backoff[min(attempt, len(backoff) - 1)]
        if delay > 0:
            time.sleep(delay)


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
        start = stripped.find("{")
        end = stripped.rfind("}")
        if start >= 0 and end > start:
            try:
                parsed = json.loads(stripped[start : end + 1])
            except json.JSONDecodeError:
                raise LLMJSONParseError(
                    "LLM response was not a valid JSON object.",
                    raw_preview=stripped[:500],
                ) from exc
        else:
            raise LLMJSONParseError(
                "LLM response was not a valid JSON object.",
                raw_preview=stripped[:500],
            ) from exc
    if not isinstance(parsed, dict):
        raise LLMJSONParseError("LLM response JSON must be an object.", raw_preview=stripped[:500])
    return parsed


def _join_system(*parts: str | None) -> str:
    return "\n".join(part for part in parts if part)


def _schema_instruction(schema_name: str, schema: type[BaseModel] | None) -> str:
    parts = [
        f"Return only one valid JSON object for schema `{schema_name}`.",
        "Do not wrap JSON in Markdown fences. Do not include commentary.",
    ]
    if schema is not None:
        parts.append("The JSON object must satisfy this JSON Schema:")
        parts.append(json.dumps(schema.model_json_schema(), ensure_ascii=False))
    return "\n".join(parts)


def _should_retry(error: LLMGatewayError, attempt: int, max_attempts: int) -> bool:
    return bool(error.retryable and attempt < max_attempts - 1)


def _error_from_http_status(exc: httpx.HTTPStatusError) -> LLMGatewayError:
    status = exc.response.status_code
    body_preview = exc.response.text[:500] if exc.response is not None else ""
    if status in {401, 403}:
        return LLMAuthError(
            f"模型接口认证失败 HTTP {status}，请检查 Provider API Key。",
            raw_preview=body_preview,
        )
    if status == 429:
        return LLMRateLimitError(
            "上游模型限流 HTTP 429，已自动等待后重试。",
            raw_preview=body_preview,
        )
    if status >= 500 or status in {502, 503, 504}:
        return LLMProviderError(
            f"模型接口返回 HTTP {status}，上游服务暂不可用。",
            raw_preview=body_preview,
        )
    return LLMProviderError(
        f"模型接口返回 HTTP {status}：{body_preview}",
        retryable=False,
        raw_preview=body_preview,
    )
