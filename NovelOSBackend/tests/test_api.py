from __future__ import annotations

from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_session
from app.main import create_app
from app.models import ChapterModel, NovelModel
from app.seed import seed_database


@pytest.fixture()
def client(tmp_path) -> Generator[TestClient, None, None]:
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

    memory = client.get("/api/novels/novel_001/memory")
    assert memory.status_code == 200
    assert memory.json()[0]["canon_status"] == "confirmed"

    matrix = client.get("/api/novels/novel_001/knowledge-matrix")
    assert matrix.status_code == 200
    assert matrix.json()[0]["character_knowledge"][0]["character_id"] == "char_A"


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
    card["current_state"] = "测试状态"
    updated_card = client.patch("/api/novels/novel_001/characters/char_test", json=card)
    assert updated_card.json()["current_state"] == "测试状态"
    assert client.delete("/api/novels/novel_001/characters/char_test").status_code == 405

    fact = {
        "id": "mem_test",
        "chapter_no": 4,
        "fact_type": "event",
        "summary": "测试事实",
        "participants": ["A"],
        "location": "旧码头",
        "evidence": "手动测试",
        "canon_status": "confirmed",
        "canon_version": 12,
    }
    assert client.post("/api/novels/novel_001/memory", json=fact).status_code == 200
    fact["summary"] = "更新后的测试事实"
    assert client.patch("/api/novels/novel_001/memory/mem_test", json=fact).json()["summary"] == "更新后的测试事实"
    assert client.delete("/api/novels/novel_001/memory/mem_test").status_code == 204


def test_knowledge_matrix_crud(client: TestClient):
    entry = {
        "id": "km_test",
        "fact_title": "测试事实",
        "truth_status": "author_only",
        "author_knowledge": "known",
        "reader_knowledge": "reader_unknown",
        "character_knowledge": [
            {"character_id": "char_A", "character_name": "A", "state": "unknown"}
        ],
        "allowed_narration": "不能确认。",
        "canon_version": 12,
    }

    created = client.post("/api/novels/novel_001/knowledge-matrix", json=entry)
    assert created.status_code == 200
    assert created.json()["fact_title"] == "测试事实"

    entry["allowed_narration"] = "只能写怀疑。"
    updated = client.patch("/api/novels/novel_001/knowledge-matrix/km_test", json=entry)
    assert updated.json()["allowed_narration"] == "只能写怀疑。"

    assert client.delete("/api/novels/novel_001/knowledge-matrix/km_test").status_code == 204


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

    structured_json["chapter_goal"] += " 加强结尾悬念。"
    saved_prompt = client.patch("/api/chapters/chapter_004/structured-prompt", json=structured_json)
    assert saved_prompt.json()["chapter_goal"].endswith("加强结尾悬念。")
    assert client.post("/api/chapters/chapter_004/structured-prompt/approve").status_code == 204

    assert client.post("/api/chapters/chapter_004/draft/generate").status_code == 204
    draft = client.get("/api/chapters/chapter_004/draft/latest").json()
    assert draft["version_no"] == 3
    assert draft["audit_summary"]["s0_count"] == 0
    assert isinstance(draft["created_at"], (int, float))

    revise = client.post(
        "/api/chapters/chapter_004/draft/review",
        json={"decision": "revise", "feedback": "B 再克制一点。"},
    )
    assert revise.status_code == 204
    revised_draft = client.get("/api/chapters/chapter_004/draft/latest").json()
    assert revised_draft["version_no"] == draft["version_no"] + 1

    assert client.post("/api/chapters/chapter_004/draft/review", json={"decision": "approve"}).status_code == 204
    assert client.post("/api/chapters/chapter_004/approve-final-text").status_code == 204

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
        assert novel.current_canon_version == 13
        assert chapter.status == "completed"
