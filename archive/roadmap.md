# NovelOS Backend Roadmap

## Phase A - Deterministic Mock Runtime

Current phase. The backend exposes durable REST APIs for the macOS app, stores workflow artifacts, records agent runs, and uses deterministic mock agents instead of real model calls.

Key responsibilities:

- Keep the five-step chapter workflow stable for the app.
- Persist structured prompts, context packs, drafts, audit reports, canon update patches, and canon edit history.
- Support Novel CRUD and first-three-chapter bootstrap import/analyze/status.
- Keep Agent, LLM Gateway, and Orchestrator interfaces replaceable.

## Phase B - Real LLM Agents

- Replace mock agent internals with LLMGateway-backed implementations.
- Add structured output validation, retry policy, model fallback, token accounting, and error surfaces.
- Make Context Compiler read World Bible, Characters, Memory, and Knowledge Matrix instead of static fixtures.

## Phase C - Retrieval And Canon Services

- Add pgvector-backed retrieval for Memory, World Bible, and Knowledge Matrix.
- Move canon merge behavior into a dedicated Canon Service.
- Add conflict detection and human-confirmed edit history for every base document update.

## Phase D - Production Operations

- Add auth, scoped CORS, observability dashboards, background job execution, and failure recovery.
- Replace startup table creation with migrations-only deployment.
- Add migration smoke tests against Postgres in CI.
