from __future__ import annotations

from contextlib import asynccontextmanager
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401
from app.database import Base, SessionLocal, engine
from app.routers import base_documents, chapter_workflow, knowledge_matrix, novels
from app.seed import seed_database


def env_flag(name: str, default: bool = True) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.lower() in {"1", "true", "yes", "on"}


def init_database(bind_engine=engine, session_factory: sessionmaker = SessionLocal, seed: bool = True) -> None:
    Base.metadata.create_all(bind=bind_engine)
    if seed:
        with session_factory() as session:
            seed_database(session)


def create_app(init_on_startup: bool = True) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if init_on_startup and env_flag("NOVEL_OS_CREATE_TABLES_ON_STARTUP", True):
            init_database(seed=env_flag("NOVEL_OS_SEED_ON_STARTUP", True))
        yield

    app = FastAPI(title="NovelOS Backend", version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}

    app.include_router(chapter_workflow.router)
    app.include_router(novels.router)
    app.include_router(base_documents.router)
    app.include_router(knowledge_matrix.router)
    return app


app = create_app()
