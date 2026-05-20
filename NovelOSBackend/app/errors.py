from __future__ import annotations

from typing import Any

from fastapi.responses import JSONResponse


def llm_error_detail(error: Exception) -> str:
    message = str(error).strip() or "未知大模型错误。"
    return f"大模型调用失败：{message}"


def llm_error_payload(error: Exception) -> dict[str, Any]:
    return {
        "detail": llm_error_detail(error),
        "code": "llm_gateway_error",
        "retryable": True,
    }


def llm_error_response(error: Exception) -> JSONResponse:
    return JSONResponse(status_code=502, content=llm_error_payload(error))
