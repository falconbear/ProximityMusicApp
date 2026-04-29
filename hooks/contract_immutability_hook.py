#!/usr/bin/env python3
"""
contract_immutability_hook.py — PreToolUse Edit/Write/MultiEdit

Contract is immutable once state leaves {PLANNED, CONTRACT_REVIEW}.

Target: .ai/work/<issue-id>/contract.json
Oracle: .ai/work/<issue-id>/state.json -> current_state

Mutable states (generator may edit contract):
  - PLANNED (drafting)
  - CONTRACT_REVIEW (revising during review)

Immutable states (block):
  - CONTRACT_APPROVED, IN_PROGRESS_RED, IN_PROGRESS_GREEN,
    READY_FOR_REVIEW, NEEDS_FIX, PASSED, BLOCKED

To re-negotiate an approved contract, the issue must transition back through
BLOCKED (evaluator decides) or be unblocked by a human to PLANNED.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Optional

MUTABLE_STATES = {"PLANNED", "CONTRACT_REVIEW"}

ISSUE_WORK_RE = re.compile(r"[\\/]\.ai[\\/]work[\\/](\d+)[\\/]contract\.json$")


def repo_root() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env).resolve()
    return Path.cwd().resolve()


def issue_id_from_contract_path(file_path: str) -> Optional[str]:
    m = ISSUE_WORK_RE.search(file_path.replace("\\", "/"))
    if m:
        return m.group(1)
    # Also accept relative paths
    norm = file_path.replace("\\", "/")
    parts = norm.split("/")
    try:
        i = parts.index(".ai")
        if parts[i + 1] == "work" and parts[i + 3] == "contract.json":
            return parts[i + 2]
    except (ValueError, IndexError):
        return None
    return None


def read_current_state(issue_id: str) -> Optional[str]:
    state_p = repo_root() / ".ai" / "work" / issue_id / "state.json"
    if not state_p.exists():
        return None
    try:
        data = json.loads(state_p.read_text(encoding="utf-8"))
        return data.get("current_state")
    except (json.JSONDecodeError, OSError):
        return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path:
        return 0

    issue_id = issue_id_from_contract_path(file_path)
    if issue_id is None:
        return 0  # not a contract.json under .ai/work/

    current = read_current_state(issue_id)
    if current is None:
        # Contract exists without state? Let it through; validate-state will flag
        return 0

    if current in MUTABLE_STATES:
        return 0

    msg = (
        f"❌ contract-immutability violation\n"
        f"  Issue {issue_id}: state={current}\n"
        f"  The contract is immutable once state leaves PLANNED / CONTRACT_REVIEW.\n"
        f"  To re-negotiate, the issue must be unblocked back to PLANNED via:\n"
        f"    bin/controller.py block --issue-id {issue_id} --reason human_judgment_required\n"
        f"    bin/controller.py unblock --issue-id {issue_id} --to PLANNED\n"
    )
    sys.stderr.write(msg)
    return 2


if __name__ == "__main__":
    sys.exit(main())
