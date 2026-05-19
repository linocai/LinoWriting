from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

from alembic import command
from alembic.config import Config
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import JSON, Column, Float, ForeignKey, Integer, MetaData, String, Table, Text, create_engine, inspect, select
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_session
from app.main import create_app
from app.models import AgentRunModel, BootstrapImportModel, ChapterModel, DraftModel, NovelModel
from app.seed import seed_database
from app.services import run_audit_pipeline


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
    assert matrix.json()[0]["visibility"]["char_A"] == "suspects"


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

    analyzed = client.post("/api/novels/novel_test/bootstrap/analyze")
    assert analyzed.status_code == 200
    assert analyzed.json()["status"] == "analyzed"
    assert analyzed.json()["analysis"]["chapter_count"] == 3

    session_factory = client.app.state.testing_session_factory
    with session_factory() as session:
        novel = session.scalar(select(NovelModel).where(NovelModel.id == "novel_test"))
        imports = session.scalars(
            select(BootstrapImportModel).where(BootstrapImportModel.novel_id == "novel_test")
        ).all()
        chapters = session.scalars(
            select(ChapterModel).where(ChapterModel.novel_id == "novel_test")
        ).all()
        import_agent = session.scalar(
            select(AgentRunModel).where(AgentRunModel.novel_id == "novel_test")
        )
        assert novel.bootstrap_status == "analyzed"
        assert len(imports) == 1
        assert {chapter.chapter_no for chapter in chapters} == {1, 2, 3}
        assert import_agent.run_type == "bootstrap"


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
    assert prompt_runs[0]["output_payload"]["entities"] == ["A", "B", "C", "旧码头", "旧案"]
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


def test_s0_audit_blocks_draft_approval(client: TestClient):
    assert client.post("/api/chapters/chapter_004/draft/generate").status_code == 204

    session_factory = client.app.state.testing_session_factory
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
    assert "S0" in response.json()["detail"]


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
    agent_run_columns = {column["name"] for column in inspector.get_columns("agent_runs")}
    assert {"novel_id", "run_type", "input_payload", "output_payload"} <= agent_run_columns
    audit_columns = {column["name"] for column in inspector.get_columns("audit_reports")}
    assert {"passed", "highest_severity"} <= audit_columns
    matrix_columns = {column["name"] for column in inspector.get_columns("knowledge_matrix_entries")}
    assert "visibility" in matrix_columns

    command.downgrade(config, "base")
    inspector = inspect(engine)
    assert "bootstrap_imports" not in inspector.get_table_names()
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
    metadata.create_all(engine)
