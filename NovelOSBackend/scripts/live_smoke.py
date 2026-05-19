from __future__ import annotations

import json
import os
from pathlib import Path
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

BASE_URL = os.getenv("NOVEL_OS_API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")


def request(method: str, path: str, payload: dict | None = None):
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = Request(
        f"{BASE_URL}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urlopen(req, timeout=120) as response:
            body = response.read().decode("utf-8")
            return None if not body else json.loads(body)
    except HTTPError as exc:
        detail = exc.read().decode("utf-8")
        raise RuntimeError(f"{method} {path} failed: {exc.code} {detail}") from exc


def main() -> None:
    suffix = int(time.time())
    novel_id = f"live_smoke_{suffix}"
    chapter_id = f"{novel_id}_chapter_004"

    print("healthz", request("GET", "/healthz"))
    print("create novel")
    request("POST", "/api/novels", {"id": novel_id, "title": "雨夜旧码头 Smoke", "genre": "现实悬疑"})

    print("import first three chapters")
    request(
        "POST",
        f"/api/novels/{novel_id}/bootstrap/import-first-three-chapters",
        {
            "chapters": [
                {"chapter_no": 1, "title": "雨夜来信", "text": "A 收到一封没有署名的信，第一次听见旧码头这个地点。"},
                {"chapter_no": 2, "title": "旧案回声", "text": "B 回避 A 关于旧案的问题，C 在远处短暂出现。"},
                {"chapter_no": 3, "title": "断裂证词", "text": "A 发现旧案证词存在断裂，B 知道不该知道的细节。"},
            ]
        },
    )
    print("analyze bootstrap")
    request("POST", f"/api/novels/{novel_id}/bootstrap/analyze")

    print("create chapter 4")
    request(
        "POST",
        f"/api/novels/{novel_id}/chapters",
        {"id": chapter_id, "chapter_no": 4, "title": "旧码头", "target_word_count": 1200},
    )

    print("generate structured prompt")
    request(
        "POST",
        f"/api/chapters/{chapter_id}/user-prompt",
        {"prompt": "A 去旧码头调查，遇到 B，发现 B 对旧案有所隐瞒。C 在结尾给出目击者线索。不要揭露完整真相。"},
    )
    structured = request("GET", f"/api/chapters/{chapter_id}/structured-prompt")
    print("structured prompt goal:", structured["chapter_goal"][:80])
    request("POST", f"/api/chapters/{chapter_id}/structured-prompt/approve")

    print("generate draft")
    request("POST", f"/api/chapters/{chapter_id}/draft/generate")
    draft = request("GET", f"/api/chapters/{chapter_id}/draft/latest")
    print("draft chars:", len(draft["text"]))

    print("approve draft and final text")
    request("POST", f"/api/chapters/{chapter_id}/draft/review", {"decision": "approve"})
    request("POST", f"/api/chapters/{chapter_id}/approve-final-text")

    patch = request("GET", f"/api/chapters/{chapter_id}/canon-update-patch")
    print("canon patch items:", len(patch["items"]))
    request("POST", f"/api/chapters/{chapter_id}/canon-update-patch/confirm")

    runs = request("GET", f"/api/chapters/{chapter_id}/agent-runs")
    print("agent runs:", [run["agent_name"] for run in runs])
    print("live smoke complete:", novel_id)


if __name__ == "__main__":
    main()
