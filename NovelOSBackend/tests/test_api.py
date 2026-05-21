from __future__ import annotations

from collections.abc import Generator
import json
from pathlib import Path

from alembic import command
from alembic.config import Config
import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import BaseModel, Field
from sqlalchemy import JSON, Column, Float, ForeignKey, Integer, MetaData, String, Table, Text, UniqueConstraint, create_engine, inspect, select
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_session
from app.main import create_app
from app.models import (
    AgentRunModel,
    BootstrapImportModel,
    ChapterModel,
    DraftModel,
    KnowledgeMatrixEntryModel,
    MemoryFactModel,
    NovelModel,
    WorldBibleSectionModel,
)
from app.seed import seed_database
from app.services import run_audit_pipeline
from app.llm.errors import LLMAuthError, LLMGatewayError, LLMJSONParseError
from app.llm.gateway import LLMResult, LLMStreamChunk, OpenAICompatibleGateway


def json_from_request(request: httpx.Request) -> dict:
    return json.loads(request.content.decode("utf-8"))


class UnitSchema(BaseModel):
    ok: bool
    value: int


class StrictUnitSchema(BaseModel):
    required_text: str = Field(min_length=3)


class FakeGateway:
    def __init__(self) -> None:
        self.calls: list[str] = []

    def complete_text(self, prompt: str, *, system=None, metadata=None) -> LLMResult:
        self.calls.append((metadata or {}).get("agent", "text"))
        return LLMResult(
            content="这是 live fake 正文。",
            model="fake-live",
            token_usage={"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3},
        )

    def complete_structured(self, prompt: str, *, schema_name: str, system=None, metadata=None, schema=None) -> LLMResult:
        self.calls.append(schema_name)
        payload_by_schema = {
            "intent_parser": {
                "entities": ["A", "B", "旧码头"],
                "tone": "冷感",
                "chapter_goal": "A 试探 B。",
                "must_not_happen": ["不要揭露真相"],
            },
            "context_pack_summary": {
                "summary": "本章只允许 A、B 和旧码头。",
                "risk_notes": ["不要新增角色"],
                "focus_entities": ["A", "B"],
            },
            "structured_prompt": {
                "chapter_goal": "A 在旧码头试探 B。",
                "must_happen": ["A 到旧码头", "B 回避问题"],
                "must_not_happen": ["不要揭露旧案完整真相"],
                "allowed_named_entities": [
                    {"name": "A", "activation": "ACTIVE", "mention_budget": None},
                    {"name": "B", "activation": "ACTIVE", "mention_budget": None},
                    {"name": "旧码头", "activation": "ACTIVE", "mention_budget": None},
                ],
                "narrative_style": "第三人称有限视角，冷感克制。",
                "version": 1,
            },
            "bootstrap_canon": {
                "chapter_count": 3,
                "total_characters": 30,
                "detected_status": "ready_for_canon_bootstrap",
                "world_bible_sections": [
                    {
                        "section_key": "tone_and_style",
                        "title": "开篇基调",
                        "content": "旧码头是开篇核心地点，后续叙事必须保持冷感克制和现实约束。",
                        "tags": ["旧码头"],
                        "importance": "high",
                        "activation_policy": "always_in_context_brief",
                    },
                    {
                        "section_key": "real_world_background",
                        "title": "现实背景",
                        "content": "故事按现实城市规则推进，人物调查和行动都需要受到公共规则约束。",
                        "tags": ["现实"],
                        "importance": "medium",
                        "activation_policy": "tag_matched",
                    },
                    {
                        "section_key": "forbidden_patterns",
                        "title": "禁忌写法",
                        "content": "不能直接揭露旧案真相，也不能让人物突然知道前三章没有写明的信息。",
                        "tags": ["禁忌"],
                        "importance": "high",
                        "activation_policy": "always_considered",
                    },
                    {
                        "section_key": "time_and_place",
                        "title": "时空信息",
                        "content": "前三章围绕旧码头线索推进，后续章节沿着既有时间线自然前进。",
                        "tags": ["时间线"],
                        "importance": "medium",
                        "activation_policy": "tag_matched",
                    },
                    {
                        "section_key": "themes",
                        "title": "主题母题",
                        "content": "主题围绕怀疑、克制和未公开真相展开，冲突应来自人物选择。",
                        "tags": ["主题"],
                        "importance": "medium",
                        "activation_policy": "tag_matched",
                    },
                    {
                        "section_key": "profession_and_society",
                        "title": "职业与社会规则",
                        "content": "警方、学校或公共机构相关内容必须遵守现实程序，不能游戏化推进。",
                        "tags": ["社会规则"],
                        "importance": "medium",
                        "activation_policy": "tag_matched",
                    },
                    {
                        "section_key": "value_boundary",
                        "title": "价值边界",
                        "content": "人物互动保持边界和现实伦理，旁白不能替角色确认未知事实。",
                        "tags": ["边界"],
                        "importance": "high",
                        "activation_policy": "always_considered",
                    },
                ],
                "character_cards": [
                    {
                        "name": "A",
                        "aliases": [],
                        "role": "protagonist",
                        "stable_traits": ["克制", "敏锐"],
                        "current_state": {"physical": "正常", "emotional": "警觉", "goal": "调查旧案线索"},
                        "voice": {"dialogue_style": "短句。", "forbidden": ["不能突然全知旧案真相"]},
                        "relationships": [],
                        "knowledge_summary": {"knows": [], "suspects": ["B 与旧案有关"], "does_not_know": ["旧案真相"]},
                        "forbidden_behavior": ["不能突然全知旧案真相"],
                        "last_active_chapter_no": 3,
                    }
                ],
                "memory_facts": [
                    {
                        "chapter_no": 1,
                        "fact_type": "event",
                        "time_in_story": "第一章",
                        "summary": "A 收到旧码头线索。",
                        "participants": ["A"],
                        "location": "旧码头",
                        "evidence": "第一章",
                    }
                ],
                "knowledge_matrix": [
                    {
                        "fact": "B 可能知道旧案线索。",
                        "truth_status": "hinted",
                        "visibility": {"author": "known", "reader": "hinted", "A": "suspects"},
                        "allowed_narration": {"summary": "只能写 A 的怀疑，不能确认。"},
                        "source": "第二章",
                    }
                ],
            },
            "canon_extraction": {
                "candidate_facts": ["林骁扬在晚自习后克制处理与蒋语笛的误会。"],
                "knowledge_entries": ["读者已知道林骁扬没有越过校园边界。"],
                "world_bible_updates": ["高三晚自习后的纪律检查会影响人物行动。"],
                "character_updates": ["林骁扬在压力下更明确自己的边界感。"],
            },
        }
        return LLMResult(
            content=json.dumps(payload_by_schema[schema_name], ensure_ascii=False),
            model="fake-live",
            token_usage={"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3},
        )

    def stream_text(self, prompt: str, *, system=None, metadata=None):
        yield LLMStreamChunk(content="这是 ", model="fake-live")
        yield LLMStreamChunk(content="stream fake 正文。", model="fake-live")
        yield LLMStreamChunk(
            content="",
            model="fake-live",
            token_usage={"prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 3},
        )


class FailingGateway:
    def complete_text(self, prompt: str, *, system=None, metadata=None) -> LLMResult:
        raise LLMGatewayError("test provider failed")

    def complete_structured(self, prompt: str, *, schema_name: str, system=None, metadata=None, schema=None) -> LLMResult:
        raise LLMGatewayError("test provider failed")

    def stream_text(self, prompt: str, *, system=None, metadata=None):
        raise LLMGatewayError("test provider failed")


@pytest.fixture()
def client(tmp_path, monkeypatch) -> Generator[TestClient, None, None]:
    monkeypatch.setenv("NOVEL_OS_ENV_PATH", str(tmp_path / ".env"))
    monkeypatch.setenv("NOVEL_OS_IMPORT_STORAGE_DIR", str(tmp_path / "imports"))
    monkeypatch.setenv("NOVEL_OS_LLM_MODE", "mock")
    monkeypatch.setenv("NOVEL_OS_REQUIRE_OWNER_TOKEN", "false")
    monkeypatch.setenv("OPENAI_COMPATIBLE_API_KEY", "")
    monkeypatch.setenv("OPENAI_COMPATIBLE_BASE_URL", "https://api.openai.com/v1")
    monkeypatch.setenv("OPENAI_COMPATIBLE_MODEL", "gpt-4.1-mini")
    monkeypatch.delenv("NOVEL_OS_LLM_PROVIDERS_JSON", raising=False)
    monkeypatch.delenv("NOVEL_OS_ACTIVE_LLM_PROVIDER", raising=False)
    engine = create_engine(
        f"sqlite:///{tmp_path / 'novelos_test.db'}",
        connect_args={"check_same_thread": False},
        future=True,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
    Base.metadata.create_all(bind=engine)
    with TestingSessionLocal() as session:
        seed_database(session)

    app = create_app(init_on_startup=False)

    def override_get_session():
        with TestingSessionLocal() as session:
            yield session

    app.dependency_overrides[get_session] = override_get_session
    app.state.testing_session_factory = TestingSessionLocal

    with TestClient(app) as test_client:
        yield test_client


def test_health_and_seeded_reads(client: TestClient):
    assert client.get("/healthz").json() == {"status": "ok"}

    world = client.get("/api/novels/novel_001/world-bible")
    assert world.status_code == 200
    assert any(section["activation_policy"] == "always_in_context_brief" for section in world.json())

    characters = client.get("/api/novels/novel_001/characters")
    assert characters.status_code == 200
    assert characters.json()[0]["relationships"][0]["target_character_name"] == "B"
    assert characters.json()[0]["current_state"]["summary"].startswith("对 B 的怀疑")

    memory = client.get("/api/novels/novel_001/memory")
    assert memory.status_code == 200
    assert memory.json()[0]["canon_status"] == "confirmed"
    assert memory.json()[0]["metadata"]["source"] == "seed"

    matrix = client.get("/api/novels/novel_001/knowledge-matrix")
    assert matrix.status_code == 200
    assert matrix.json()[0]["visibility"]["char_A"] == "suspects"
    assert "character_knowledge" not in matrix.json()[0]

    chapters = client.get("/api/novels/novel_001/chapters")
    assert chapters.status_code == 200
    assert [chapter["chapter_no"] for chapter in chapters.json()] == [1, 2, 3, 4]

    imported_draft = client.get("/api/chapters/chapter_001/draft/latest")
    assert imported_draft.status_code == 200
    assert "没有署名的邮件" in imported_draft.json()["text"]


def test_owner_token_protects_api_when_enabled(tmp_path, monkeypatch):
    monkeypatch.setenv("NOVEL_OS_ENV_PATH", str(tmp_path / ".env"))
    monkeypatch.setenv("NOVEL_OS_REQUIRE_OWNER_TOKEN", "true")
    monkeypatch.setenv("NOVEL_OS_OWNER_TOKEN", "owner-secret")
    engine = create_engine(
        f"sqlite:///{tmp_path / 'token_test.db'}",
        connect_args={"check_same_thread": False},
        future=True,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
    Base.metadata.create_all(bind=engine)
    with TestingSessionLocal() as session:
        seed_database(session)

    app = create_app(init_on_startup=False)

    def override_get_session():
        with TestingSessionLocal() as session:
            yield session

    app.dependency_overrides[get_session] = override_get_session
    with TestClient(app) as token_client:
        assert token_client.get("/healthz").status_code == 200
        assert token_client.get("/api/novels").status_code == 401
        assert token_client.get("/api/novels", headers={"X-NovelOS-Owner-Token": "bad"}).status_code == 401
        assert token_client.get(
            "/api/novels",
            headers={"X-NovelOS-Owner-Token": "owner-secret"},
        ).status_code == 200


def test_llm_provider_admin_api_writes_env_and_hides_keys(client: TestClient, monkeypatch):
    class FakeAdminGateway:
        def __init__(self, **kwargs):
            self.provider = kwargs["provider"]

        def complete_text(self, prompt: str, *, system=None, metadata=None) -> LLMResult:
            return LLMResult(
                content="ok",
                model=self.provider.model,
                token_usage={"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
            )

    monkeypatch.setattr("app.routers.admin.OpenAICompatibleGateway", FakeAdminGateway)

    created = client.put(
        "/api/admin/llm/providers/deepseek",
        json={
            "name": "DeepSeek",
            "base_url": "https://api.deepseek.com/v1",
            "model": "deepseek-chat",
            "api_key": "secret-key",
            "timeout_seconds": 45,
        },
    )
    assert created.status_code == 200
    provider = next(item for item in created.json()["providers"] if item["id"] == "deepseek")
    assert provider["has_api_key"] is True
    assert "api_key" not in provider

    switched = client.post("/api/admin/llm/active-provider", json={"provider_id": "deepseek"})
    assert switched.status_code == 200
    assert switched.json()["active_provider_id"] == "deepseek"

    tested = client.post("/api/admin/llm/test", json={"provider_id": "deepseek"})
    assert tested.status_code == 200
    assert tested.json()["ok"] is True
    assert tested.json()["model"] == "deepseek-chat"

    deleted = client.delete("/api/admin/llm/providers/deepseek")
    assert deleted.status_code == 200
    remaining_id = deleted.json()["providers"][0]["id"]
    rejected = client.delete(f"/api/admin/llm/providers/{remaining_id}")
    assert rejected.status_code == 409


def test_novel_crud_and_bootstrap_flow(client: TestClient):
    created = client.post(
        "/api/novels",
        json={"id": "novel_test", "title": "测试长篇", "genre": "悬疑"},
    )
    assert created.status_code == 200
    assert created.json()["bootstrap_status"] == "not_started"

    listed = client.get("/api/novels").json()
    assert any(novel["id"] == "novel_test" for novel in listed)

    patched = client.patch("/api/novels/novel_test", json={"genre": "现实悬疑"})
    assert patched.status_code == 200
    assert patched.json()["genre"] == "现实悬疑"

    status = client.get("/api/novels/novel_test/bootstrap/status").json()
    assert status["status"] == "not_started"
    assert status["imported_chapter_count"] == 0

    bad_import = client.post(
        "/api/novels/novel_test/bootstrap/import-first-three-chapters",
        json={"chapters": [{"chapter_no": 1, "title": "一", "text": "第一章"}]},
    )
    assert bad_import.status_code == 400

    import_payload = {
        "chapters": [
            {"chapter_no": 1, "title": "第一章", "text": "第一章正文"},
            {"chapter_no": 2, "title": "第二章", "text": "第二章正文"},
            {"chapter_no": 3, "title": "第三章", "text": "第三章正文"},
        ]
    }
    imported = client.post(
        "/api/novels/novel_test/bootstrap/import-first-three-chapters",
        json=import_payload,
    )
    assert imported.status_code == 200
    assert imported.json()["status"] == "imported"
    assert imported.json()["imported_chapter_count"] == 3

    first_chapter_draft = client.get("/api/chapters/novel_test_chapter_001/draft/latest")
    assert first_chapter_draft.status_code == 200
    assert first_chapter_draft.json()["text"] == "第一章正文"

    analyzed = client.post("/api/novels/novel_test/bootstrap/analyze")
    assert analyzed.status_code == 200
    assert analyzed.json()["status"] == "analyzed"
    assert analyzed.json()["analysis"]["chapter_count"] == 3
    assert analyzed.json()["analysis"]["world_bible_sections"]
    assert analyzed.json()["analysis"]["character_cards"]
    assert analyzed.json()["analysis"]["memory_facts"]
    assert analyzed.json()["analysis"]["knowledge_matrix"]

    world = client.get("/api/novels/novel_test/world-bible").json()
    characters = client.get("/api/novels/novel_test/characters").json()
    memory = client.get("/api/novels/novel_test/memory").json()
    matrix = client.get("/api/novels/novel_test/knowledge-matrix").json()
    assert world[0]["title"]
    assert {section["section_key"] for section in world} == {
        "tone_and_style",
        "real_world_background",
        "forbidden_patterns",
        "time_and_place",
        "themes",
        "profession_and_society",
        "value_boundary",
    }
    assert characters[0]["name"]
    assert memory[0]["created_by"] == "import_agent"
    assert matrix[0]["allowed_narration"]["summary"] or matrix[0]["allowed_narration"]["text"]

    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        novel = session.scalar(select(NovelModel).where(NovelModel.id == "novel_test"))
        imports = session.scalars(
            select(BootstrapImportModel).where(BootstrapImportModel.novel_id == "novel_test")
        ).all()
        chapters = session.scalars(
            select(ChapterModel).where(ChapterModel.novel_id == "novel_test")
        ).all()
        drafts = session.scalars(
            select(DraftModel).where(DraftModel.chapter_id.in_([chapter.id for chapter in chapters]))
        ).all()
        import_agent = session.scalar(
            select(AgentRunModel).where(AgentRunModel.novel_id == "novel_test")
        )
        assert novel.bootstrap_status == "analyzed"
        assert len(imports) == 1
        assert Path(imports[0].storage_path).exists()
        assert {chapter.chapter_no for chapter in chapters} == {1, 2, 3}
        assert {chapter.status for chapter in chapters} == {"completed"}
        assert len(drafts) == 3
        assert import_agent.run_type == "bootstrap"
        assert import_agent.model == "mock"
        assert import_agent.input_json["import_id"] == imports[0].id

    created_chapter = client.post(
        "/api/novels/novel_test/chapters",
        json={"chapter_no": 4, "title": "第四章", "target_word_count": 1800},
    )
    assert created_chapter.status_code == 200
    assert created_chapter.json()["id"] == "novel_test_chapter_004"
    assert client.post(
        "/api/novels/novel_test/chapters",
        json={"chapter_no": 4, "title": "重复章节"},
    ).status_code == 409
    listed_chapters = client.get("/api/novels/novel_test/chapters").json()
    assert [chapter["chapter_no"] for chapter in listed_chapters] == [1, 2, 3, 4]


def test_empty_bootstrap_seed_mode(tmp_path):
    engine = create_engine(
        f"sqlite:///{tmp_path / 'empty_seed.db'}",
        connect_args={"check_same_thread": False},
        future=True,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
    Base.metadata.create_all(bind=engine)
    with TestingSessionLocal() as session:
        seed_database(session, mode="empty_bootstrap")
        novel = session.scalar(select(NovelModel).where(NovelModel.id == "novel_001"))
        chapters = session.scalars(select(ChapterModel)).all()
        assert novel.bootstrap_status == "not_started"
        assert novel.current_canon_version is None
        assert chapters == []


def test_openai_compatible_gateway_parses_structured_response():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/chat/completions"
        body = json_from_request(request)
        assert body["model"] == "test-model"
        return httpx.Response(
            200,
            json={
                "model": "test-model",
                "choices": [{"message": {"content": "{\"ok\": true, \"value\": 7}"}}],
                "usage": {"prompt_tokens": 3, "completion_tokens": 4, "total_tokens": 7},
            },
        )

    client = httpx.Client(transport=httpx.MockTransport(handler), base_url="https://example.test")
    gateway = OpenAICompatibleGateway(
        api_key="test-key",
        base_url="https://example.test/v1",
        model="test-model",
        client=client,
        retry_backoff=(0, 0, 0),
        rate_limit_backoff=(0, 0, 0),
    )
    result = gateway.complete_structured("hello", schema_name="unit_test", schema=UnitSchema)
    assert result.structured == {"ok": True, "value": 7}
    assert result.token_usage["total_tokens"] == 7
    assert result.token_usage["model"] == "test-model"


def test_openai_compatible_gateway_extracts_json_from_extra_text():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "model": "test-model",
                "choices": [{"message": {"content": "结果如下：\n{\"ok\": true}\n完毕"}}],
                "usage": {},
            },
        )

    client = httpx.Client(transport=httpx.MockTransport(handler), base_url="https://example.test")
    gateway = OpenAICompatibleGateway(
        api_key="test-key",
        base_url="https://example.test/v1",
        model="test-model",
        client=client,
        retry_backoff=(0, 0, 0),
        rate_limit_backoff=(0, 0, 0),
    )
    assert gateway.complete_structured("hello", schema_name="dirty_json").structured == {"ok": True}


def test_llm_gateway_retry_on_timeout():
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        if calls["count"] == 1:
            raise httpx.ReadTimeout("slow")
        return httpx.Response(
            200,
            json={
                "model": "test-model",
                "choices": [{"message": {"content": "ok"}}],
                "usage": {"total_tokens": 2},
            },
        )

    client = httpx.Client(transport=httpx.MockTransport(handler), base_url="https://example.test")
    gateway = OpenAICompatibleGateway(
        api_key="test-key",
        base_url="https://example.test/v1",
        model="test-model",
        client=client,
        retry_backoff=(0, 0, 0),
    )
    assert gateway.complete_text("hello").content == "ok"
    assert calls["count"] == 2


def test_llm_gateway_429_backoff():
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        if calls["count"] == 1:
            return httpx.Response(429, text="rate limited")
        return httpx.Response(
            200,
            json={"model": "test-model", "choices": [{"message": {"content": "ok"}}], "usage": {}},
        )

    client = httpx.Client(transport=httpx.MockTransport(handler), base_url="https://example.test")
    gateway = OpenAICompatibleGateway(
        api_key="test-key",
        base_url="https://example.test/v1",
        model="test-model",
        client=client,
        rate_limit_backoff=(0, 0, 0),
    )
    assert gateway.complete_text("hello").content == "ok"
    assert calls["count"] == 2


def test_llm_gateway_auth_error_not_retryable():
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        return httpx.Response(401, text="bad key")

    client = httpx.Client(transport=httpx.MockTransport(handler), base_url="https://example.test")
    gateway = OpenAICompatibleGateway(
        api_key="test-key",
        base_url="https://example.test/v1",
        model="test-model",
        client=client,
        retry_backoff=(0, 0, 0),
    )
    with pytest.raises(LLMAuthError):
        gateway.complete_text("hello")
    assert calls["count"] == 1


def test_structured_output_schema_validation_retries_once():
    calls = {"count": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        content = "{\"required_text\":\"ok\"}" if calls["count"] == 1 else "{\"required_text\":\"okay\"}"
        return httpx.Response(
            200,
            json={"model": "test-model", "choices": [{"message": {"content": content}}], "usage": {}},
        )

    client = httpx.Client(transport=httpx.MockTransport(handler), base_url="https://example.test")
    gateway = OpenAICompatibleGateway(
        api_key="test-key",
        base_url="https://example.test/v1",
        model="test-model",
        client=client,
        retry_backoff=(0, 0, 0),
    )
    assert gateway.complete_structured("hello", schema_name="strict", schema=StrictUnitSchema).structured == {
        "required_text": "okay"
    }
    assert calls["count"] == 2


def test_live_mode_agents_use_injected_gateway(monkeypatch):
    monkeypatch.setenv("NOVEL_OS_LLM_MODE", "live")
    from app.orchestrator import ChapterWorkflowOrchestrator

    gateway = FakeGateway()
    results = ChapterWorkflowOrchestrator(gateway).run_prompt(
        novel_id="novel_live",
        chapter_id="chapter_live",
        prompt="A 去旧码头见 B。",
        context_payload={"allowed_named_entities": ["A", "B", "旧码头"]},
    )
    assert results[0].model == "local"
    assert results[1].model == "local"
    assert results[2].model == "fake-live"
    assert results[0].payload["entities"] == ["A", "B", "旧码头"]
    assert results[2].payload["chapter_id"] == "chapter_live"
    assert gateway.calls == ["structured_prompt"]


def test_live_mode_import_agent_generates_bootstrap_canon(monkeypatch):
    monkeypatch.setenv("NOVEL_OS_LLM_MODE", "live")
    from app.orchestrator import ChapterWorkflowOrchestrator

    gateway = FakeGateway()
    result = ChapterWorkflowOrchestrator(gateway).run_bootstrap_analysis(
        novel_id="novel_live",
        chapters=[
            {"chapter_no": 1, "title": "一", "text": "A 收到旧码头线索。"},
            {"chapter_no": 2, "title": "二", "text": "B 回避 A 的追问。"},
            {"chapter_no": 3, "title": "三", "text": "C 提供目击者线索。"},
        ],
    )
    assert result.model == "fake-live"
    assert result.payload["world_bible_sections"][0]["title"] == "开篇基调"
    assert result.payload["character_cards"][0]["name"] == "A"
    assert gateway.calls == ["bootstrap_canon"]


def test_bootstrap_analysis_records_retryable_llm_failure(client: TestClient, monkeypatch):
    monkeypatch.setenv("NOVEL_OS_LLM_MODE", "live")
    monkeypatch.setattr("app.orchestrator.make_llm_gateway", lambda: FailingGateway())

    created = client.post(
        "/api/novels",
        json={"id": "novel_failure", "title": "失败测试", "genre": "悬疑"},
    )
    assert created.status_code == 200
    imported = client.post(
        "/api/novels/novel_failure/bootstrap/import-first-three-chapters",
        json={
            "chapters": [
                {"chapter_no": 1, "title": "一", "text": "第一章正文"},
                {"chapter_no": 2, "title": "二", "text": "第二章正文"},
                {"chapter_no": 3, "title": "三", "text": "第三章正文"},
            ]
        },
    )
    assert imported.status_code == 200

    failed = client.post("/api/novels/novel_failure/bootstrap/analyze")
    assert failed.status_code == 502
    assert failed.json()["error"]["kind"] == "llm"
    assert failed.json()["error"]["retryable"] is True
    assert "test provider failed" in failed.json()["error"]["message"]

    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        failure_run = session.scalar(
            select(AgentRunModel).where(
                AgentRunModel.novel_id == "novel_failure",
                AgentRunModel.status == "failed",
            )
        )
        assert failure_run is not None
        assert failure_run.agent_name == "Import Agent"
        assert failure_run.error_message
        assert failure_run.payload["retryable"] is True


def test_bootstrap_schema_validation_fails_records_parse_error(client: TestClient, monkeypatch):
    class InvalidBootstrapGateway:
        def complete_text(self, prompt: str, *, system=None, metadata=None) -> LLMResult:
            return LLMResult(content="unused", model="invalid")

        def complete_structured(self, prompt: str, *, schema_name: str, system=None, metadata=None, schema=None) -> LLMResult:
            raise LLMJSONParseError("LLM response failed schema validation.", raw_preview="{bad}")

    monkeypatch.setenv("NOVEL_OS_LLM_MODE", "live")
    monkeypatch.setattr("app.orchestrator.make_llm_gateway", lambda: InvalidBootstrapGateway())

    assert client.post(
        "/api/novels",
        json={"id": "novel_parse_failure", "title": "格式失败", "genre": "悬疑"},
    ).status_code == 200
    assert client.post(
        "/api/novels/novel_parse_failure/bootstrap/import-first-three-chapters",
        json={
            "chapters": [
                {"chapter_no": 1, "title": "一", "text": "第一章正文"},
                {"chapter_no": 2, "title": "二", "text": "第二章正文"},
                {"chapter_no": 3, "title": "三", "text": "第三章正文"},
            ]
        },
    ).status_code == 200

    failed = client.post("/api/novels/novel_parse_failure/bootstrap/analyze")
    assert failed.status_code == 502
    assert failed.json()["error"]["kind"] == "parse"
    assert failed.json()["error"]["retryable"] is True

    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        failure_run = session.scalar(
            select(AgentRunModel).where(
                AgentRunModel.novel_id == "novel_parse_failure",
                AgentRunModel.status == "failed",
            )
        )
        assert failure_run is not None
        assert failure_run.payload["kind"] == "parse"
        assert failure_run.payload["retryable"] is True


def test_base_documents_crud_and_character_delete_is_absent(client: TestClient):
    section = {
        "id": "wb_test",
        "title": "测试 Section",
        "content": "测试内容",
        "tags": ["test"],
        "importance": "medium",
        "activation_policy": "manual_only",
        "canon_version": 12,
        "updated_at": 800000001,
    }
    created_section = client.post("/api/novels/novel_001/world-bible/sections", json=section)
    assert created_section.status_code == 200
    section["title"] = "测试 Section Updated"
    updated_section = client.patch("/api/novels/novel_001/world-bible/sections/wb_test", json=section)
    assert updated_section.json()["title"] == "测试 Section Updated"
    assert client.delete("/api/novels/novel_001/world-bible/sections/wb_test").status_code == 204

    card = client.get("/api/novels/novel_001/characters").json()[0]
    card["id"] = "char_test"
    card["name"] = "测试人物"
    created_card = client.post("/api/novels/novel_001/characters", json=card)
    assert created_card.status_code == 200
    card["current_state"] = {"summary": "测试状态", "goal": "测试目标"}
    updated_card = client.patch("/api/novels/novel_001/characters/char_test", json=card)
    assert updated_card.json()["current_state"]["summary"] == "测试状态"
    assert client.delete("/api/novels/novel_001/characters/char_test").status_code == 405

    fact = {
        "id": "mem_test",
        "chapter_no": 4,
        "fact_type": "event",
        "summary": "测试事实",
        "time_in_story": "第 4 章",
        "participants": ["A"],
        "location": "旧码头",
        "evidence": "手动测试",
        "canon_status": "confirmed",
        "canon_version": 12,
        "metadata": {"source": "test"},
        "created_by": "test",
    }
    assert client.post("/api/novels/novel_001/memory", json=fact).status_code == 200
    fact["summary"] = "更新后的测试事实"
    assert client.patch("/api/novels/novel_001/memory/mem_test", json=fact).json()["summary"] == "更新后的测试事实"
    assert client.delete("/api/novels/novel_001/memory/mem_test").status_code == 204


def test_knowledge_matrix_crud(client: TestClient):
    entry = {
        "id": "km_test",
        "fact": "测试事实",
        "fact_title": "测试事实",
        "truth_status": "author_only",
        "author_knowledge": "known",
        "reader_knowledge": "reader_unknown",
        "character_knowledge": [
            {"character_id": "char_A", "character_name": "A", "state": "unknown"}
        ],
        "allowed_narration": {"text": "不能确认。"},
        "canon_version": 12,
    }

    created = client.post("/api/novels/novel_001/knowledge-matrix", json=entry)
    assert created.status_code == 200
    assert created.json()["fact_title"] == "测试事实"
    assert created.json()["visibility"]["A"] == "unknown"
    assert "character_knowledge" not in created.json()

    entry["allowed_narration"] = {"text": "只能写怀疑。"}
    entry["visibility"] = {"author": "known", "reader": "hinted", "A": "suspects"}
    updated = client.patch("/api/novels/novel_001/knowledge-matrix/km_test", json=entry)
    assert updated.json()["allowed_narration"]["text"] == "只能写怀疑。"
    assert updated.json()["visibility"] == {"author": "known", "reader": "hinted", "A": "suspects"}

    assert client.delete("/api/novels/novel_001/knowledge-matrix/km_test").status_code == 204


def test_km_visibility_dict_roundtrip_and_legacy_list_input(client: TestClient):
    legacy_entry = {
        "id": "km_visibility_legacy",
        "fact": "旧请求兼容",
        "fact_title": "旧请求兼容",
        "truth_status": "hinted",
        "author_knowledge": "known",
        "reader_knowledge": "reader_unknown",
        "character_knowledge": [
            {"character_id": "char_A", "character_name": "A", "state": "suspects"}
        ],
        "allowed_narration": {"summary": "只能写怀疑。"},
        "canon_version": 1,
    }
    legacy_response = client.post("/api/novels/novel_001/knowledge-matrix", json=legacy_entry)
    assert legacy_response.status_code == 200
    assert legacy_response.json()["visibility"]["A"] == "suspects"
    assert "character_knowledge" not in legacy_response.json()

    dict_entry = {
        **legacy_entry,
        "id": "km_visibility_dict",
        "fact_title": "dict 请求",
        "visibility": {"author": "known", "reader": "reader_known", "A": "known"},
        "character_knowledge": [],
    }
    dict_response = client.post("/api/novels/novel_001/knowledge-matrix", json=dict_entry)
    assert dict_response.status_code == 200
    assert dict_response.json()["visibility"] == {"author": "known", "reader": "reader_known", "A": "known"}


def test_chapter_workflow_five_step_mock_flow(client: TestClient):
    prompt_response = client.post(
        "/api/chapters/chapter_004/user-prompt",
        json={"prompt": "下一章写旧码头调查。"},
    )
    assert prompt_response.status_code == 204

    structured = client.get("/api/chapters/chapter_004/structured-prompt")
    assert structured.status_code == 200
    structured_json = structured.json()
    assert structured_json["chapter_id"] == "chapter_004"
    assert structured_json["allowed_named_entities"][0]["activation"] == "ACTIVE"

    context_pack = client.get("/api/chapters/chapter_004/context-pack").json()
    assert context_pack["payload"]["active_entities"] == ["A", "B", "C"]
    assert "allowed_named_entities" in context_pack["payload"]

    prompt_runs = client.get("/api/chapters/chapter_004/agent-runs").json()
    assert [run["agent_name"] for run in prompt_runs] == [
        "Intent Parser",
        "Context Compiler",
        "Prompt Expander",
    ]
    assert prompt_runs[0]["novel_id"] == "novel_001"
    assert prompt_runs[0]["run_type"] == "prompt"
    assert prompt_runs[0]["output_json"]["entities"] == ["A", "B", "C", "旧码头", "旧案"]
    assert prompt_runs[1]["payload"]["new_entity_policy"] == "allow_minor_unnamed_only"

    structured_json["chapter_goal"] += " 加强结尾悬念。"
    saved_prompt = client.patch("/api/chapters/chapter_004/structured-prompt", json=structured_json)
    assert saved_prompt.json()["chapter_goal"].endswith("加强结尾悬念。")
    assert client.post("/api/chapters/chapter_004/structured-prompt/approve").status_code == 204

    assert client.post("/api/chapters/chapter_004/draft/generate").status_code == 204
    draft = client.get("/api/chapters/chapter_004/draft/latest").json()
    assert draft["version_no"] == 3
    assert draft["audit_summary"]["s0_count"] == 0
    assert isinstance(draft["created_at"], (int, float))

    writing_runs = client.get("/api/chapters/chapter_004/agent-runs").json()
    agent_names = [run["agent_name"] for run in writing_runs]
    assert "Writing Agent" in agent_names
    assert "Named Entity Auditor" in agent_names
    assert "Knowledge Auditor" in agent_names
    assert "Continuity Auditor" in agent_names
    assert next(run for run in writing_runs if run["agent_name"] == "Writing Agent")["payload"]["draft_id"] == "draft_004_v3"

    audit = client.get("/api/chapters/chapter_004/audit/latest").json()
    assert audit["draft_id"] == "draft_004_v3"
    assert audit["summary"]["s0_count"] == 0
    assert audit["named_entity_result"]["illegal_named_entity_count"] == 0
    assert audit["passed"] is True
    assert audit["highest_severity"] == "S1"

    revise = client.post(
        "/api/chapters/chapter_004/draft/review",
        json={"decision": "revise", "feedback": "B 再克制一点。"},
    )
    assert revise.status_code == 204
    revised_draft = client.get("/api/chapters/chapter_004/draft/latest").json()
    assert revised_draft["version_no"] == draft["version_no"] + 1
    revised_runs = client.get("/api/chapters/chapter_004/agent-runs").json()
    assert any(run["agent_name"] == "Revision Agent" for run in revised_runs)
    revised_audit = client.get("/api/chapters/chapter_004/audit/latest").json()
    assert revised_audit["draft_id"] == revised_draft["id"]

    assert client.post("/api/chapters/chapter_004/draft/review", json={"decision": "approve"}).status_code == 204
    assert client.post("/api/chapters/chapter_004/approve-final-text").status_code == 204
    extraction_runs = client.get("/api/chapters/chapter_004/agent-runs").json()
    assert any(run["agent_name"] == "Extraction Agent" for run in extraction_runs)

    patch = client.get("/api/chapters/chapter_004/canon-update-patch").json()
    assert patch["target_canon_version"] == 13
    patch["items"][0]["proposed_action"] = "modify"
    updated_patch = client.patch("/api/chapters/chapter_004/canon-update-patch", json=patch)
    assert updated_patch.json()["items"][0]["proposed_action"] == "modify"
    assert client.post("/api/chapters/chapter_004/canon-update-patch/confirm").status_code == 204

    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        novel = session.scalar(select(NovelModel).where(NovelModel.id == "novel_001"))
        chapter = session.scalar(select(ChapterModel).where(ChapterModel.id == "chapter_004"))
        canon_merge_run = session.scalar(
            select(AgentRunModel).where(AgentRunModel.agent_name == "Canon Merge Agent")
        )
        assert novel.current_canon_version == 13
        assert chapter.status == "completed"
        assert canon_merge_run is not None


def test_live_canon_patch_uses_extraction_and_merges_base_docs(client: TestClient, monkeypatch):
    monkeypatch.setenv("NOVEL_OS_LLM_MODE", "live")
    monkeypatch.setattr("app.orchestrator.make_llm_gateway", lambda: FakeGateway())

    created = client.post(
        "/api/novels",
        json={
            "id": "novel_live_patch",
            "title": "真实补丁测试",
            "genre": "青春校园",
            "current_canon_version": 2,
            "bootstrap_status": "analyzed",
        },
    )
    assert created.status_code == 200
    chapter = client.post(
        "/api/novels/novel_live_patch/chapters",
        json={"chapter_no": 4, "title": "第四章", "target_word_count": 1200},
    )
    assert chapter.status_code == 200

    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        live_chapter = session.scalar(select(ChapterModel).where(ChapterModel.id == "novel_live_patch_chapter_004"))
        live_chapter.status = "draftApproved"
        session.add(
            DraftModel(
                id="draft_live_patch_v1",
                chapter_id="novel_live_patch_chapter_004",
                version_no=1,
                text="林骁扬在晚自习后克制处理与蒋语笛的误会，最后回到教室准备接受纪律检查。",
                word_count=39,
                audit_summary={"s0_count": 0, "s1_count": 0, "s2_count": 0, "issues": []},
                source="test",
                created_at=800000010,
            )
        )
        session.commit()

    assert client.post("/api/chapters/novel_live_patch_chapter_004/approve-final-text").status_code == 204
    patch = client.get("/api/chapters/novel_live_patch_chapter_004/canon-update-patch").json()
    assert patch["id"] == "patch_novel_live_patch_chapter_004"
    assert patch["target_canon_version"] == 3
    assert all("旧码头" not in item["summary"] for item in patch["items"])
    assert {item["target"] for item in patch["items"]} >= {"Memory", "Knowledge", "WorldBible", "Character"}

    assert client.post("/api/chapters/novel_live_patch_chapter_004/canon-update-patch/confirm").status_code == 204

    with session_factory() as session:
        novel = session.scalar(select(NovelModel).where(NovelModel.id == "novel_live_patch"))
        memory = session.scalars(
            select(MemoryFactModel).where(MemoryFactModel.novel_id == "novel_live_patch")
        ).all()
        knowledge = session.scalars(
            select(KnowledgeMatrixEntryModel).where(KnowledgeMatrixEntryModel.novel_id == "novel_live_patch")
        ).all()
        world = session.scalars(
            select(WorldBibleSectionModel).where(WorldBibleSectionModel.novel_id == "novel_live_patch")
        ).all()
        assert novel.current_canon_version == 3
        assert any("林骁扬" in item.summary for item in memory)
        assert any("边界" in (item.fact or "") for item in knowledge)
        assert any("纪律检查" in item.content for item in world)


def test_s0_audit_blocks_draft_approval(client: TestClient):
    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        chapter = session.scalar(select(ChapterModel).where(ChapterModel.id == "chapter_004"))
        chapter.status = "structuredPromptApproved"
        session.commit()

    assert client.post("/api/chapters/chapter_004/draft/generate").status_code == 204

    with session_factory() as session:
        draft = session.scalar(select(DraftModel).where(DraftModel.id == "draft_004_v3"))
        draft.audit_summary = {
            **draft.audit_summary,
            "s0_count": 1,
            "issues": [
                *draft.audit_summary["issues"],
                {
                    "id": "audit_s0_001",
                    "severity": "S0",
                    "type": "非法命名实体",
                    "location": "第 1 段",
                    "message": "出现未允许命名人物。",
                    "suggestion": "删除该命名人物。",
                },
            ],
        }
        session.commit()

    response = client.post("/api/chapters/chapter_004/draft/review", json={"decision": "approve"})
    assert response.status_code == 409
    assert "S0" in response.json()["error"]["message"]


def test_workflow_state_machine_rejects_skip(client: TestClient):
    response = client.post("/api/chapters/chapter_004/draft/generate")
    assert response.status_code == 409
    assert response.json()["error"] == {
        "kind": "workflow",
        "message": "请先完成上一步：无法从 draftInput 跳到 draftGenerated。",
        "retryable": False,
    }


def test_stream_draft_generation_emits_events_and_admin_runs(client: TestClient):
    response = client.post("/api/chapters/chapter_004/user-prompt", json={"prompt": "让 A 在旧码头试探 B。"})
    assert response.status_code == 204
    assert client.post("/api/chapters/chapter_004/structured-prompt/approve").status_code == 204

    stream = client.post("/api/chapters/chapter_004/draft/generate/stream")
    assert stream.status_code == 200
    events = [
        json.loads(line.removeprefix("data:").strip())
        for line in stream.text.splitlines()
        if line.startswith("data:")
    ]
    assert any(event["event"] == "delta" for event in events)
    assert any(event["event"] == "word_count" for event in events)
    assert events[-1]["event"] == "done"
    assert events[-1]["draft_id"]

    draft = client.get("/api/chapters/chapter_004/draft/latest").json()
    assert draft["id"] == events[-1]["draft_id"]
    assert draft["word_count"] > 0

    runs = client.get("/api/admin/agent-runs?chapter_id=chapter_004").json()
    writing_run = next(run for run in runs if run["agent_name"] == "Writing Agent")
    assert writing_run["run_type"] == "draft"
    assert writing_run["latency_ms"] is not None
    assert writing_run["token_usage"]["model"] == "mock"


def test_s0_auto_revision_caps_at_two_attempts(client: TestClient, monkeypatch):
    from app import services

    original = services.run_audit_pipeline

    def always_s0(session, chapter, draft, *, timestamp_prefix):
        report = original(session, chapter, draft, timestamp_prefix=timestamp_prefix)
        summary = dict(report.summary)
        summary["s0_count"] = 1
        summary["illegal_named_entity_count"] = 1
        summary["issues"] = [
            {
                "id": f"forced_s0_{draft.version_no}",
                "severity": "S0",
                "type": "测试硬错误",
                "location": "测试",
                "message": "强制 S0 用于验证自动修复上限。",
                "suggestion": "重写。",
            }
        ]
        draft.audit_summary = summary
        report.summary = summary
        report.passed = False
        report.highest_severity = "S0"
        return report

    monkeypatch.setattr(services, "run_audit_pipeline", always_s0)

    assert client.post("/api/chapters/chapter_004/user-prompt", json={"prompt": "让 A 在旧码头试探 B。"}).status_code == 204
    assert client.post("/api/chapters/chapter_004/structured-prompt/approve").status_code == 204
    response = client.post("/api/chapters/chapter_004/draft/generate")
    assert response.status_code == 204

    draft = client.get("/api/chapters/chapter_004/draft/latest").json()
    assert draft["version_no"] == 5
    runs = client.get("/api/chapters/chapter_004/agent-runs").json()
    revision_runs = [run for run in runs if run["agent_name"] == "Revision Agent"]
    assert len(revision_runs) == 2


def test_deterministic_safety_audit_flags_illegal_names_and_knowledge_leaks(client: TestClient):
    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        chapter = session.scalar(select(ChapterModel).where(ChapterModel.id == "chapter_004"))
        draft = DraftModel(
            id="draft_safety_v1",
            chapter_id=chapter.id,
            version_no=99,
            text="D 在码头出现，并直接说旧案真正凶手就是 B。A 的母亲也反复出现。A 的母亲。",
            word_count=36,
            audit_summary=None,
            source="safety_test",
            created_at=800000002,
        )
        session.add(draft)
        report = run_audit_pipeline(session, chapter, draft, timestamp_prefix="13:00")
        session.commit()
        assert report.passed is False
        assert report.highest_severity == "S0"
        assert report.summary["s0_count"] >= 3
        assert report.summary["illegal_named_entity_count"] == 1
        assert report.summary["knowledge_violation_count"] == 1

        geometry_draft = DraftModel(
            id="draft_geometry_v1",
            chapter_id=chapter.id,
            version_no=100,
            text="这道题的辅助线从C点到D点，不涉及其他人物。",
            word_count=22,
            audit_summary=None,
            source="safety_test",
            created_at=800000003,
        )
        session.add(geometry_draft)
        geometry_report = run_audit_pipeline(session, chapter, geometry_draft, timestamp_prefix="13:01")
        assert geometry_report.summary["illegal_named_entity_count"] == 0


def test_alembic_migration_upgrade_and_downgrade(tmp_path):
    db_path = tmp_path / "migration.db"
    engine = create_engine(f"sqlite:///{db_path}", future=True)
    _create_legacy_schema(engine)

    repo_root = Path(__file__).resolve().parents[1]
    config = Config(str(repo_root / "alembic.ini"))
    config.set_main_option("script_location", str(repo_root / "alembic"))
    config.set_main_option("sqlalchemy.url", f"sqlite:///{db_path}")

    command.upgrade(config, "head")
    inspector = inspect(engine)
    assert "bootstrap_imports" in inspector.get_table_names()
    assert "structured_prompts" in inspector.get_table_names()
    assert "canon_update_patches" in inspector.get_table_names()
    assert "canon_edit_history" in inspector.get_table_names()
    agent_run_columns = {column["name"] for column in inspector.get_columns("agent_runs")}
    assert {"novel_id", "run_type", "model", "input_json", "output_json", "token_usage", "completed_at"} <= agent_run_columns
    assert "timestamp_label" not in agent_run_columns
    audit_columns = {column["name"] for column in inspector.get_columns("audit_reports")}
    assert {"pass", "highest_severity"} <= audit_columns
    matrix_columns = {column["name"] for column in inspector.get_columns("knowledge_matrix_entries")}
    assert "visibility" in matrix_columns
    visibility_column = next(column for column in inspector.get_columns("knowledge_matrix_entries") if column["name"] == "visibility")
    assert visibility_column["nullable"] is False

    command.downgrade(config, "base")
    inspector = inspect(engine)
    assert "bootstrap_imports" not in inspector.get_table_names()
    assert "structured_prompts" not in inspector.get_table_names()
    assert "visibility" not in {column["name"] for column in inspector.get_columns("knowledge_matrix_entries")}


def _create_legacy_schema(engine):
    metadata = MetaData()
    Table(
        "novels",
        metadata,
        Column("id", String, primary_key=True),
        Column("title", String, nullable=False),
        Column("genre", String),
        Column("current_chapter_no", Integer),
        Column("current_canon_version", Integer),
        Column("bootstrap_status", String, nullable=False),
    )
    Table(
        "chapters",
        metadata,
        Column("id", String, primary_key=True),
        Column("novel_id", String, ForeignKey("novels.id"), nullable=False),
        Column("chapter_no", Integer, nullable=False),
    )
    Table(
        "chapter_versions",
        metadata,
        Column("id", String, primary_key=True),
        Column("chapter_id", String, ForeignKey("chapters.id"), nullable=False),
        Column("version_no", Integer, nullable=False),
        Column("text", Text, nullable=False),
        Column("word_count", Integer, nullable=False),
        Column("audit_summary", JSON),
        Column("source", String, nullable=False),
        Column("created_at", Float, nullable=False),
    )
    Table(
        "context_packs",
        metadata,
        Column("id", String, primary_key=True),
        Column("chapter_id", String, ForeignKey("chapters.id"), nullable=False),
        Column("payload", JSON, nullable=False),
        Column("created_at", Float, nullable=False),
        UniqueConstraint("chapter_id", name="uq_context_pack_chapter"),
    )
    Table(
        "agent_runs",
        metadata,
        Column("id", String, primary_key=True),
        Column("chapter_id", String, ForeignKey("chapters.id"), nullable=False),
        Column("agent_name", String, nullable=False),
        Column("summary", Text, nullable=False),
        Column("status", String, nullable=False),
        Column("timestamp_label", String, nullable=False),
        Column("payload", JSON, nullable=False),
        Column("created_at", Float, nullable=False),
    )
    Table(
        "audit_reports",
        metadata,
        Column("id", String, primary_key=True),
        Column("chapter_id", String, ForeignKey("chapters.id"), nullable=False),
        Column("draft_id", String, ForeignKey("chapter_versions.id"), nullable=False),
        Column("named_entity_result", JSON, nullable=False),
        Column("knowledge_result", JSON, nullable=False),
        Column("continuity_result", JSON, nullable=False),
        Column("summary", JSON, nullable=False),
        Column("created_at", Float, nullable=False),
    )
    Table(
        "world_bible_sections",
        metadata,
        Column("id", String, primary_key=True),
        Column("novel_id", String, ForeignKey("novels.id"), nullable=False),
        Column("title", String, nullable=False),
        Column("content", Text, nullable=False),
        Column("tags", JSON, nullable=False),
        Column("importance", String, nullable=False),
        Column("activation_policy", String, nullable=False),
        Column("canon_version", Integer, nullable=False),
        Column("updated_at", Float, nullable=False),
    )
    Table(
        "characters",
        metadata,
        Column("id", String, primary_key=True),
        Column("novel_id", String, ForeignKey("novels.id"), nullable=False),
        Column("name", String, nullable=False),
        Column("aliases", JSON, nullable=False),
        Column("role", String, nullable=False),
        Column("stable_traits", JSON, nullable=False),
        Column("current_state", Text, nullable=False),
        Column("dialogue_style", Text, nullable=False),
        Column("relationships", JSON, nullable=False),
        Column("forbidden_behavior", JSON, nullable=False),
        Column("last_active_chapter_no", Integer),
        Column("canon_version", Integer, nullable=False),
    )
    Table(
        "knowledge_matrix_entries",
        metadata,
        Column("id", String, primary_key=True),
        Column("novel_id", String, ForeignKey("novels.id"), nullable=False),
        Column("fact_title", String, nullable=False),
        Column("truth_status", String, nullable=False),
        Column("author_knowledge", String, nullable=False),
        Column("reader_knowledge", String, nullable=False),
        Column("character_knowledge", JSON, nullable=False),
        Column("allowed_narration", Text, nullable=False),
        Column("canon_version", Integer, nullable=False),
    )
    Table(
        "memory_facts",
        metadata,
        Column("id", String, primary_key=True),
        Column("novel_id", String, ForeignKey("novels.id"), nullable=False),
        Column("chapter_no", Integer, nullable=False),
        Column("fact_type", String, nullable=False),
        Column("summary", Text, nullable=False),
        Column("participants", JSON, nullable=False),
        Column("location", String),
        Column("evidence", Text, nullable=False),
        Column("canon_status", String, nullable=False),
        Column("canon_version", Integer, nullable=False),
    )
    metadata.create_all(engine)
