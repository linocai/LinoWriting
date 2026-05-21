from __future__ import annotations

from app.errors import APIError


class LLMGatewayError(APIError):
    http_status = 502
    kind = "llm"
    retryable = True


class LLMAuthError(LLMGatewayError):
    kind = "auth"
    retryable = False


class LLMRateLimitError(LLMGatewayError):
    kind = "rate_limit"
    retryable = True


class LLMTimeoutError(LLMGatewayError):
    kind = "timeout"
    retryable = True


class LLMJSONParseError(LLMGatewayError):
    kind = "parse"
    retryable = True


class LLMProviderError(LLMGatewayError):
    kind = "provider"
    retryable = True
