from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv


BACKEND_ROOT = Path(__file__).resolve().parents[1]


def load_environment() -> None:
    load_dotenv(BACKEND_ROOT / ".env")


load_environment()


def env_flag(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.lower() in {"1", "true", "yes", "on"}


def env_list(name: str, default: list[str]) -> list[str]:
    raw = os.getenv(name)
    if raw is None:
        return default
    values = [item.strip() for item in raw.split(",") if item.strip()]
    return values or default


def llm_mode() -> str:
    return os.getenv("NOVEL_OS_LLM_MODE", "mock").strip().lower()


def openai_compatible_base_url() -> str:
    return os.getenv("OPENAI_COMPATIBLE_BASE_URL", "https://api.openai.com/v1").rstrip("/")


def openai_compatible_api_key() -> str | None:
    value = os.getenv("OPENAI_COMPATIBLE_API_KEY")
    return value.strip() if value else None


def openai_compatible_model() -> str:
    return os.getenv("OPENAI_COMPATIBLE_MODEL", "gpt-4.1-mini")


def openai_compatible_timeout_seconds() -> float:
    raw = os.getenv("OPENAI_COMPATIBLE_TIMEOUT_SECONDS", "60")
    try:
        return float(raw)
    except ValueError:
        return 60.0
