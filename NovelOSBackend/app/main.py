from __future__ import annotations

from contextlib import asynccontextmanager
import os
import secrets

from fastapi import FastAPI, Request
from fastapi.exceptions import HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401
from app.config import env_flag, env_list, load_environment, owner_token, require_owner_token
from app.database import Base, SessionLocal, engine
from app.errors import APIError, api_error_response, http_error_payload
from app.routers import admin, base_documents, chapter_workflow, knowledge_matrix, novels
from app.seed import seed_database


load_environment()


def init_database(
    bind_engine=engine,
    session_factory: sessionmaker = SessionLocal,
    seed: bool = True,
    seed_mode: str = "completed_mock",
) -> None:
    Base.metadata.create_all(bind=bind_engine)
    if seed:
        with session_factory() as session:
            seed_database(session, mode=seed_mode)


def create_app(init_on_startup: bool = True) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if init_on_startup and env_flag("NOVEL_OS_CREATE_TABLES_ON_STARTUP", False):
            init_database(
                seed=env_flag("NOVEL_OS_SEED_ON_STARTUP", True),
                seed_mode=os.getenv("NOVEL_OS_SEED_MODE", "completed_mock"),
            )
        yield

    app = FastAPI(title="NovelOS Backend", version="0.1.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=env_list("NOVEL_OS_CORS_ALLOW_ORIGINS", ["http://127.0.0.1", "http://localhost"]),
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/healthz")
    def healthz():
        return {"status": "ok"}

    @app.exception_handler(APIError)
    async def api_error_handler(request: Request, exc: APIError):
        return api_error_response(exc)

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        return JSONResponse(status_code=exc.status_code, content=http_error_payload(exc.status_code, exc.detail))

    @app.middleware("http")
    async def owner_token_middleware(request: Request, call_next):
        if not require_owner_token() or request.url.path == "/healthz" or request.method == "OPTIONS":
            return await call_next(request)

        expected = owner_token()
        if not expected:
            return JSONResponse(
                status_code=503,
                content=http_error_payload(
                    503,
                    "Owner token is required but NOVEL_OS_OWNER_TOKEN is not configured.",
                ),
            )
        provided = request.headers.get("X-NovelOS-Owner-Token", "")
        if not secrets.compare_digest(provided, expected):
            return JSONResponse(status_code=401, content=http_error_payload(401, "Invalid owner token."))
        return await call_next(request)

    app.include_router(chapter_workflow.router)
    app.include_router(novels.router)
    app.include_router(base_documents.router)
    app.include_router(knowledge_matrix.router)
    app.include_router(admin.router)
    return app


app = create_app()
