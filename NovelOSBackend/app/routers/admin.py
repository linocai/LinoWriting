from __future__ import annotations

import re

from fastapi import APIRouter, HTTPException

from app import config
from app.llm.gateway import LLMGatewayError, OpenAICompatibleGateway
from app.schemas import (
    ActiveLLMProviderRequest,
    LLMProviderPublic,
    LLMProvidersResponse,
    LLMProviderUpsert,
    LLMTestRequest,
    LLMTestResponse,
)

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.get("/llm/providers", response_model=LLMProvidersResponse)
def list_llm_providers():
    return _providers_response()


@router.put("/llm/providers/{provider_id}", response_model=LLMProvidersResponse)
def upsert_llm_provider(provider_id: str, request: LLMProviderUpsert):
    _validate_provider_id(provider_id)
    existing = {provider.provider_id: provider for provider in config.llm_providers()}
    providers = dict(existing)
    previous = providers.get(provider_id)
    api_key = request.api_key
    if api_key is None and previous is not None:
        api_key = previous.api_key

    providers[provider_id] = config.LLMProviderConfig(
        provider_id=provider_id,
        name=request.name.strip() or provider_id,
        base_url=_required_text(request.base_url, "base_url").rstrip("/"),
        model=_required_text(request.model, "model"),
        api_key=api_key.strip() if api_key else None,
        timeout_seconds=max(1.0, float(request.timeout_seconds or 60.0)),
    )
    active_id = config.active_llm_provider_id() or provider_id
    if active_id not in providers:
        active_id = provider_id
    config.save_llm_provider_configs(_sorted_providers(providers), active_id)
    return _providers_response()


@router.delete("/llm/providers/{provider_id}", response_model=LLMProvidersResponse)
def delete_llm_provider(provider_id: str):
    providers = {provider.provider_id: provider for provider in config.llm_providers()}
    if provider_id not in providers:
        raise HTTPException(status_code=404, detail=f"LLM provider not found: {provider_id}")
    if len(providers) <= 1:
        raise HTTPException(status_code=409, detail="At least one LLM provider is required.")
    del providers[provider_id]
    active_id = config.active_llm_provider_id()
    if active_id == provider_id or active_id not in providers:
        active_id = sorted(providers)[0]
    config.save_llm_provider_configs(_sorted_providers(providers), active_id)
    return _providers_response()


@router.post("/llm/active-provider", response_model=LLMProvidersResponse)
def set_active_llm_provider(request: ActiveLLMProviderRequest):
    providers = {provider.provider_id: provider for provider in config.llm_providers()}
    if request.provider_id not in providers:
        raise HTTPException(status_code=404, detail=f"LLM provider not found: {request.provider_id}")
    config.save_llm_provider_configs(_sorted_providers(providers), request.provider_id)
    return _providers_response()


@router.post("/llm/test", response_model=LLMTestResponse)
def test_llm_provider(request: LLMTestRequest):
    provider = _provider_for_test(request.provider_id)
    try:
        result = OpenAICompatibleGateway(provider=provider).complete_text(
            request.prompt,
            system="Reply with a short plain-text acknowledgement.",
            metadata={"purpose": "admin_llm_test", "provider_id": provider.provider_id},
        )
    except LLMGatewayError as exc:
        return LLMTestResponse(
            ok=False,
            provider_id=provider.provider_id,
            model=provider.model,
            message=str(exc),
            token_usage={},
        )

    return LLMTestResponse(
        ok=True,
        provider_id=provider.provider_id,
        model=result.model,
        message=result.content[:200],
        token_usage=result.token_usage,
    )


def _providers_response() -> LLMProvidersResponse:
    active_id = config.active_llm_provider_id()
    return LLMProvidersResponse(
        active_provider_id=active_id,
        providers=[
            LLMProviderPublic(
                id=provider.provider_id,
                name=provider.name,
                base_url=provider.base_url,
                model=provider.model,
                timeout_seconds=provider.timeout_seconds,
                has_api_key=provider.has_api_key,
                is_active=provider.provider_id == active_id,
            )
            for provider in config.llm_providers()
        ],
    )


def _provider_for_test(provider_id: str | None) -> config.LLMProviderConfig:
    active_id = provider_id or config.active_llm_provider_id()
    for provider in config.llm_providers():
        if provider.provider_id == active_id:
            return provider
    raise HTTPException(status_code=404, detail=f"LLM provider not found: {active_id}")


def _validate_provider_id(provider_id: str) -> None:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{1,63}", provider_id):
        raise HTTPException(status_code=400, detail="Provider id must be 2-64 URL-safe characters.")


def _required_text(value: str, field_name: str) -> str:
    trimmed = value.strip()
    if not trimmed:
        raise HTTPException(status_code=400, detail=f"{field_name} is required.")
    return trimmed


def _sorted_providers(providers: dict[str, config.LLMProviderConfig]) -> list[config.LLMProviderConfig]:
    return [providers[key] for key in sorted(providers)]
