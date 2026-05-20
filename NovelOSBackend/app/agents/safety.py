from __future__ import annotations

import re
from typing import Any


SEVERITY_RANK = {"none": 0, "S2": 1, "S1": 2, "S0": 3}


def highest_severity(summary: dict[str, Any]) -> str:
    highest = "none"
    for issue in summary.get("issues", []):
        severity = str(issue.get("severity", "none"))
        if SEVERITY_RANK.get(severity, 0) > SEVERITY_RANK.get(highest, 0):
            highest = severity
    if int(summary.get("s0_count", 0)) > 0:
        return "S0"
    if int(summary.get("s1_count", 0)) > 0 and SEVERITY_RANK[highest] < SEVERITY_RANK["S1"]:
        return "S1"
    if int(summary.get("s2_count", 0)) > 0 and SEVERITY_RANK[highest] < SEVERITY_RANK["S2"]:
        return "S2"
    return highest


def summary_passed(summary: dict[str, Any]) -> bool:
    return int(summary.get("s0_count", 0)) == 0


def deterministic_audit_summary(
    draft_text: str,
    context_payload: dict[str, Any],
    *,
    base_summary: dict[str, Any] | None = None,
) -> dict[str, Any]:
    summary = _empty_summary() if base_summary is None else _copy_summary(base_summary)
    issues: list[dict[str, Any]] = list(summary.get("issues", []))

    forbidden_names = context_payload.get("forbidden_named_entities") or ["D", "陌生角色", "新角色"]
    illegal_names = [name for name in forbidden_names if name and _contains_forbidden_name(str(name), draft_text)]
    if illegal_names:
        issues.append(
            {
                "id": "audit_s0_illegal_named_entity",
                "severity": "S0",
                "type": "非法命名实体",
                "location": "全文",
                "message": f"出现未允许命名实体：{', '.join(illegal_names)}。",
                "suggestion": "删除该命名实体，或先在结构化 Prompt 中明确批准。",
            }
        )
        summary["illegal_named_entity_count"] = int(summary.get("illegal_named_entity_count", 0)) + len(illegal_names)

    mention_entities = context_payload.get("mention_allowed_entities") or []
    for entity in mention_entities:
        name = str(entity.get("name", ""))
        budget = int(entity.get("budget", 0) or 0)
        if name and budget >= 0 and draft_text.count(name) > budget:
            issues.append(
                {
                    "id": f"audit_s0_mention_budget_{name}",
                    "severity": "S0",
                    "type": "弱提及额度超限",
                    "location": "全文",
                    "message": f"{name} 的提及次数超过本章额度 {budget}。",
                    "suggestion": "压缩提及，或在结构化 Prompt 中调整提及额度。",
                }
            )
            summary["inactive_character_appearance_count"] = int(
                summary.get("inactive_character_appearance_count", 0)
            ) + 1

    leak_markers = ["旧案真正凶手", "完整真相是", "B 就是凶手"]
    if any(marker in draft_text for marker in leak_markers):
        issues.append(
            {
                "id": "audit_s0_knowledge_leak",
                "severity": "S0",
                "type": "旧案真相泄露",
                "location": "全文",
                "message": "正文直接确认了当前章节不应公开的旧案真相。",
                "suggestion": "改为角色怀疑、观察或误导，不让旁白确认真相。",
            }
        )
        summary["knowledge_violation_count"] = int(summary.get("knowledge_violation_count", 0)) + 1

    s0_count = sum(1 for issue in issues if issue.get("severity") == "S0")
    summary["issues"] = issues
    summary["s0_count"] = s0_count
    return summary


def _empty_summary() -> dict[str, Any]:
    return {
        "s0_count": 0,
        "s1_count": 0,
        "s2_count": 0,
        "illegal_named_entity_count": 0,
        "inactive_character_appearance_count": 0,
        "knowledge_violation_count": 0,
        "new_named_entity_count": 0,
        "issues": [],
    }


def _copy_summary(summary: dict[str, Any]) -> dict[str, Any]:
    copied = dict(summary)
    copied["issues"] = [dict(issue) for issue in copied.get("issues", [])]
    return copied


def _contains_forbidden_name(name: str, draft_text: str) -> bool:
    if len(name) == 1 and name.isascii() and name.isalpha():
        pattern = re.compile(rf"(?<![A-Za-z]){re.escape(name)}(?![A-Za-z])")
        for match in pattern.finditer(draft_text):
            next_char = draft_text[match.end() : match.end() + 1]
            if next_char in {"点", "项", "题"}:
                continue
            return True
        return False
    return name in draft_text
