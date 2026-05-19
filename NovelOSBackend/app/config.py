from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path

from dotenv import load_dotenv, set_key


BACKEND_ROOT = Path(__file__).resolve().parents[1]


def env_file_path() -> Path:
    override = os.getenv("NOVEL_OS_ENV_PATH")
    if override:
        return Path(override)
    return BACKEND_ROOT / ".env"


def load_environment() -> None:
    load_dotenv(env_file_path())


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


def owner_token() -> str | None:
    value = os.getenv("NOVEL_OS_OWNER_TOKEN")
    return value.strip() if value else None


def require_owner_token() -> bool:
    return env_flag("NOVEL_OS_REQUIRE_OWNER_TOKEN", True)


@dataclass(frozen=True)
class LLMProviderConfig:
    provider_id: str
    name: str
    base_url: str
    model: str
    api_key: str | None = None
    timeout_seconds: float = 60.0

    @property
    def has_api_key(self) -> bool:
        return bool(self.api_key)

    def to_env_payload(self) -> dict:
        return {
            "id": self.provider_id,
            "name": self.name,
            "base_url": self.base_url.rstrip("/"),
            "model": self.model,
            "api_key": self.api_key or "",
            "timeout_seconds": self.timeout_seconds,
        }


def llm_providers(include_legacy: bool = True) -> list[LLMProviderConfig]:
    providers = _providers_from_json(os.getenv("NOVEL_OS_LLM_PROVIDERS_JSON"))
    if providers:
        return providers
    if not include_legacy:
        return []

    return [
        LLMProviderConfig(
            provider_id="default",
            name="Default",
            base_url=openai_compatible_base_url(),
            model=openai_compatible_model(),
            api_key=openai_compatible_api_key(),
            timeout_seconds=openai_compatible_timeout_seconds(),
        )
    ]


def active_llm_provider_id() -> str | None:
    configured = os.getenv("NOVEL_OS_ACTIVE_LLM_PROVIDER")
    providers = llm_providers()
    provider_ids = {provider.provider_id for provider in providers}
    if configured and configured in provider_ids:
        return configured
    return providers[0].provider_id if providers else None


def active_llm_provider() -> LLMProviderConfig | None:
    active_id = active_llm_provider_id()
    for provider in llm_providers():
        if provider.provider_id == active_id:
            return provider
    return None


def save_llm_provider_configs(providers: list[LLMProviderConfig], active_provider_id: str) -> None:
    payload = [provider.to_env_payload() for provider in providers]
    providers_json = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    persist_env_values(
        {
            "NOVEL_OS_LLM_MODE": "live",
            "NOVEL_OS_ACTIVE_LLM_PROVIDER": active_provider_id,
            "NOVEL_OS_LLM_PROVIDERS_JSON": providers_json,
        }
    )


def persist_env_values(values: dict[str, str]) -> None:
    path = env_file_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.touch(mode=0o600, exist_ok=True)
    for key, value in values.items():
        set_key(str(path), key, value, quote_mode="always")
        os.environ[key] = value


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


def _providers_from_json(raw: str | None) -> list[LLMProviderConfig]:
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return []

    items: list[dict] = []
    if isinstance(parsed, list):
        items = [item for item in parsed if isinstance(item, dict)]
    elif isinstance(parsed, dict):
        items = [
            {**value, "id": value.get("id") or key}
            for key, value in parsed.items()
            if isinstance(value, dict)
        ]

    providers: list[LLMProviderConfig] = []
    for item in items:
        provider = _provider_from_mapping(item)
        if provider is not None:
            providers.append(provider)
    return providers


def _provider_from_mapping(item: dict) -> LLMProviderConfig | None:
    provider_id = str(item.get("id") or item.get("provider_id") or "").strip()
    base_url = str(item.get("base_url") or "").strip().rstrip("/")
    model = str(item.get("model") or "").strip()
    if not provider_id or not base_url or not model:
        return None
    timeout_raw = item.get("timeout_seconds", 60)
    try:
        timeout_seconds = float(timeout_raw)
    except (TypeError, ValueError):
        timeout_seconds = 60.0
    api_key = item.get("api_key")
    return LLMProviderConfig(
        provider_id=provider_id,
        name=str(item.get("name") or provider_id).strip() or provider_id,
        base_url=base_url,
        model=model,
        api_key=str(api_key).strip() if api_key else None,
        timeout_seconds=timeout_seconds,
    )
