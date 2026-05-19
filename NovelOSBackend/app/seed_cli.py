from __future__ import annotations

import os

from app.database import SessionLocal
from app.seed import seed_database


def main() -> None:
    if os.getenv("NOVEL_OS_SEED_ON_STARTUP", "true").lower() not in {"1", "true", "yes", "on"}:
        return
    with SessionLocal() as session:
        seed_database(session, mode=os.getenv("NOVEL_OS_SEED_MODE", "completed_mock"))


if __name__ == "__main__":
    main()
