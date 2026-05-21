from __future__ import annotations

from typing import Any

from fastapi.responses import JSONResponse


class APIError(Exception):
    http_status = 500
    kind = "unknown"
    retryable = False

    def __init__(
        self,
        message: str,
        *,
        kind: str | None = None,
        retryable: bool | None = None,
        http_status: int | None = None,
        agent_run_id: str | None = None,
        raw_preview: str | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.kind = kind or self.kind
        self.retryable = self.retryable if retryable is None else retryable
        self.http_status = http_status or self.http_status
        self.agent_run_id = agent_run_id
        self.raw_preview = raw_preview

    def with_agent_run(self, agent_run_id: str) -> "APIError":
        self.agent_run_id = agent_run_id
        return self


class ValidationFailedError(APIError):
    http_status = 422
    kind = "validation"
    retryable = False


class WorkflowStateError(APIError):
    http_status = 409
    kind = "workflow"
    retryable = False


def http_error_payload(status_code: int, detail: object) -> dict[str, Any]:
    message = str(detail)
    kind = {
        400: "validation",
        401: "auth",
        403: "auth",
        404: "not_found",
        409: "workflow",
        422: "validation",
        503: "unavailable",
    }.get(status_code, "http")
    retryable = status_code in {429, 502, 503, 504}
    return {"error": {"kind": kind, "message": message, "retryable": retryable}}


def api_error_payload(error: APIError) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "error": {
            "kind": error.kind,
            "message": error.message,
            "retryable": error.retryable,
        }
    }
    if error.agent_run_id:
        payload["error"]["agent_run_id"] = error.agent_run_id
    if error.raw_preview:
        payload["error"]["raw_preview"] = error.raw_preview
    return payload


def api_error_response(error: APIError) -> JSONResponse:
    return JSONResponse(status_code=error.http_status, content=api_error_payload(error))


def llm_error_detail(error: Exception) -> str:
    message = str(error).strip() or "未知大模型错误。"
    if isinstance(error, APIError):
        message = error.message
    return f"大模型调用失败：{message}"
