#!/usr/bin/env python3
"""
sprint_state_hook.py — PostToolUse Edit/Write

When any file under .ai/work/<issue-id>/ is modified, read each issue's
state.json and emit next-action reminders for states that need parent Claude
to dispatch the next agent or run sync work.

Reminder priority (emit at most one per state type per run):
  PASSED             -> dispatch observer, update PR, sync Project
  BLOCKED            -> inspect feedback, possibly spec-issue, notify human
  READY_FOR_REVIEW   -> dispatch evaluator (implementation mode)
  CONTRACT_REVIEW    -> dispatch evaluator (contract mode)
  NEEDS_FIX          -> dispatch generator (fix phase)

Exit 0 always (informational).
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional

WORK_PATH_RE = re.compile(r"[\\/]\.ai[\\/]work[\\/](\d+)[\\/]")


def repo_root() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env).resolve()
    return Path.cwd().resolve()


def issue_id_from_path(file_path: str) -> Optional[str]:
    m = WORK_PATH_RE.search(file_path.replace("\\", "/"))
    return m.group(1) if m else None


def load_state(issue_id: str) -> Optional[Dict]:
    p = repo_root() / ".ai" / "work" / issue_id / "state.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


REMINDERS = {
    "CONTRACT_APPROVED": (
        "Issue #{id} is CONTRACT_APPROVED. "
        "Dispatch generator (/implement) to start TDD (Phase 3: RED → GREEN → REFACTOR)."
    ),
    "PASSED": (
        "Issue #{id} ({title}) is now PASSED.\n"
        "Next steps for parent Claude:\n"
        "  1. dispatch observer (/learn) to extract Instincts to .harness/instincts/\n"
        "  2. update PR via github-publishing skill "
        "(if all tracked issues PASSED → mark ready-for-review)\n"
        "  3. if .harness/project.yaml exists, run: "
        "python3 bin/project-sync.py move --issue {id} --status PASSED"
    ),
    "BLOCKED": (
        "⚠ Issue #{id} ({title}) is BLOCKED (reason={reason}).\n"
        "Next steps for parent Claude:\n"
        "  1. inspect docs/feedback/issue-{id}.md (or issue-{id}-contract.md) for failure details\n"
        "  2. if spec-side: dispatch planner to revise docs/spec.md\n"
        "  3. if impl-side: file a spec-issue via github-publishing\n"
        "  4. update Project status to Blocked\n"
        "  5. notify human — this requires judgment (not automatic)"
    ),
    "READY_FOR_REVIEW": (
        "Issue #{id} is READY_FOR_REVIEW. "
        "Dispatch evaluator (/eval) — implementation mode."
    ),
    "CONTRACT_REVIEW": (
        "Issue #{id} is CONTRACT_REVIEW. "
        "Dispatch evaluator (/eval) — contract mode (no Playwright)."
    ),
    "NEEDS_FIX": (
        "Issue #{id} is NEEDS_FIX. Dispatch generator (/fix) for corrections."
    ),
}


def gather_all_states() -> List[Dict]:
    base = repo_root() / ".ai" / "work"
    if not base.exists():
        return []
    states = []
    for d in sorted(base.iterdir()):
        if not d.is_dir():
            continue
        sp = d / "state.json"
        if not sp.exists():
            continue
        try:
            states.append(json.loads(sp.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError):
            continue
    return states


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    # only react if the write touched .ai/work/**
    if ".ai/work" not in file_path.replace("\\", "/"):
        return 0

    # Prefer the directly-modified issue, fall back to scanning all
    target_id = issue_id_from_path(file_path)
    states = []
    if target_id:
        s = load_state(target_id)
        if s:
            states.append(s)
    else:
        states = gather_all_states()

    seen = set()
    out: List[str] = []
    # Sort by issue id for deterministic output
    states.sort(key=lambda s: int(s["issue_id"]))
    for s in states:
        cs = s.get("current_state")
        if cs not in REMINDERS or cs in seen:
            continue
        seen.add(cs)
        out.append(
            REMINDERS[cs].format(
                id=s["issue_id"],
                title=s.get("title", ""),
                reason=s.get("blocked_reason") or "unspecified",
            )
        )
        if {
            "PASSED", "BLOCKED", "READY_FOR_REVIEW", "CONTRACT_REVIEW",
            "NEEDS_FIX", "CONTRACT_APPROVED",
        } <= seen:
            break

    if out:
        sys.stdout.write("\n---\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
