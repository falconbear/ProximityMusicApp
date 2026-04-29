#!/usr/bin/env python3
"""
controller.py — sole state transition authority for Issue-scoped work.

Layout: .ai/work/<issue-id>/{state,contract,qa}.json + progress.jsonl + handoff.md

All state transitions MUST go through this CLI. Agents never write state.json
directly; they call `controller.py <command>` and the controller validates the
transition, updates state.json atomically, and appends an event to progress.jsonl.

Design principles:
- Valid-transitions table is the single source of truth for the state machine.
- Atomic writes: write to tmp file, os.replace() to target.
- Append-only progress.jsonl: never rewrite, only append.
- Exit 0 on success, non-zero with message on error.

Usage:
  controller.py init --issue-id 42 --title "..." --branch sprint/42-x
  controller.py submit-contract --issue-id 42
  controller.py approve-contract --issue-id 42
  controller.py reject-contract --issue-id 42 [--blocked]
  controller.py record-tdd --issue-id 42 --phase red|green|refactor --commit-sha <sha>
  controller.py submit-impl --issue-id 42
  controller.py pass --issue-id 42
  controller.py needs-fix --issue-id 42
  controller.py block --issue-id 42 --reason <reason> [--note <text>]
  controller.py unblock --issue-id 42 --to <state>
  controller.py set-pr --issue-id 42 --pr-number 123 [--project-item-id <id>]
  controller.py read --issue-id 42 [--field current_state]
  controller.py list [--state <STATE>] [--json]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

SCHEMA_VERSION = "1.0"

# --------------------------------------------------------------------------- #
# State machine
# --------------------------------------------------------------------------- #

STATES = [
    "PLANNED",
    "CONTRACT_REVIEW",
    "CONTRACT_APPROVED",
    "IN_PROGRESS_RED",
    "IN_PROGRESS_GREEN",
    "READY_FOR_REVIEW",
    "NEEDS_FIX",
    "PASSED",
    "BLOCKED",
]

# Edges: (from_state, to_state) -> required actor role
# Controller does not enforce actor identity (no auth), but records it.
VALID_TRANSITIONS: Dict[Tuple[str, str], str] = {
    # contract lifecycle
    ("PLANNED", "CONTRACT_REVIEW"): "generator",
    ("CONTRACT_REVIEW", "CONTRACT_APPROVED"): "evaluator",
    ("CONTRACT_REVIEW", "PLANNED"): "evaluator",  # rejected, redraft
    ("CONTRACT_REVIEW", "BLOCKED"): "evaluator",  # attempts exhausted
    # impl lifecycle
    ("CONTRACT_APPROVED", "IN_PROGRESS_RED"): "generator",
    ("IN_PROGRESS_RED", "IN_PROGRESS_GREEN"): "generator",
    ("IN_PROGRESS_GREEN", "READY_FOR_REVIEW"): "generator",
    ("READY_FOR_REVIEW", "PASSED"): "evaluator",
    ("READY_FOR_REVIEW", "NEEDS_FIX"): "evaluator",
    ("READY_FOR_REVIEW", "BLOCKED"): "evaluator",
    ("NEEDS_FIX", "READY_FOR_REVIEW"): "generator",
    ("NEEDS_FIX", "BLOCKED"): "evaluator",
    # unblock (human override)
    ("BLOCKED", "PLANNED"): "human",
    ("BLOCKED", "CONTRACT_REVIEW"): "human",
    ("BLOCKED", "READY_FOR_REVIEW"): "human",
    ("BLOCKED", "NEEDS_FIX"): "human",
}

MAX_CONTRACT_ATTEMPTS = 3
MAX_IMPL_ATTEMPTS = 5


# --------------------------------------------------------------------------- #
# Filesystem
# --------------------------------------------------------------------------- #


def repo_root() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env).resolve()
    return Path.cwd().resolve()


def work_dir(issue_id: str) -> Path:
    return repo_root() / ".ai" / "work" / issue_id


def state_path(issue_id: str) -> Path:
    return work_dir(issue_id) / "state.json"


def progress_path(issue_id: str) -> Path:
    return work_dir(issue_id) / "progress.jsonl"


def all_issue_dirs() -> List[Path]:
    base = repo_root() / ".ai" / "work"
    if not base.exists():
        return []
    return sorted([d for d in base.iterdir() if d.is_dir() and (d / "state.json").exists()])


# --------------------------------------------------------------------------- #
# IO helpers
# --------------------------------------------------------------------------- #


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def atomic_write_json(path: Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def append_event(issue_id: str, actor: str, event: str, **extras: Any) -> None:
    record: Dict[str, Any] = {
        "ts": now_iso(),
        "actor": actor,
        "event": event,
        "issue_id": issue_id,
    }
    for k, v in extras.items():
        if v is not None:
            record[k] = v
    path = progress_path(issue_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def load_state(issue_id: str) -> Dict[str, Any]:
    path = state_path(issue_id)
    if not path.exists():
        die(f"no state.json for issue {issue_id} (path: {path})")
    return json.loads(path.read_text(encoding="utf-8"))


def die(msg: str, code: int = 2) -> None:
    print(f"controller: {msg}", file=sys.stderr)
    sys.exit(code)


# --------------------------------------------------------------------------- #
# Transition core
# --------------------------------------------------------------------------- #


def transition(
    state: Dict[str, Any],
    to_state: str,
    actor: str,
    *,
    allow_same: bool = False,
) -> Dict[str, Any]:
    frm = state["current_state"]
    if frm == to_state and allow_same:
        return state
    if (frm, to_state) not in VALID_TRANSITIONS:
        die(f"invalid transition {frm} -> {to_state}")
    state["previous_state"] = frm
    state["current_state"] = to_state
    state["last_transition_at"] = now_iso()
    state["last_transition_by"] = actor
    state["timestamps"]["updated_at"] = state["last_transition_at"]
    return state


# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #


def cmd_init(args: argparse.Namespace) -> int:
    path = state_path(args.issue_id)
    if path.exists() and not args.force:
        die(f"state.json already exists at {path} (use --force to overwrite)")
    now = now_iso()
    data = {
        "schema_version": SCHEMA_VERSION,
        "issue_id": args.issue_id,
        "title": args.title,
        "branch": args.branch,
        "pr_number": None,
        "project_item_id": None,
        "current_state": "PLANNED",
        "previous_state": None,
        "last_transition_at": None,
        "last_transition_by": None,
        "contract_attempts": 0,
        "attempts": 0,
        "tdd": {
            "red_commit_sha": None,
            "green_commit_sha": None,
            "refactor_commit_sha": None,
        },
        "blocked_reason": None,
        "blocked_note": None,
        "timestamps": {
            "created_at": now,
            "updated_at": now,
        },
    }
    atomic_write_json(path, data)
    append_event(
        args.issue_id,
        "controller",
        "issue_initialized",
        data={"title": args.title, "branch": args.branch},
    )
    print(f"initialized {path}")
    return 0


def cmd_submit_contract(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] != "PLANNED":
        die(f"submit-contract requires PLANNED, current={state['current_state']}")
    state["contract_attempts"] += 1
    if state["contract_attempts"] > MAX_CONTRACT_ATTEMPTS:
        die(
            f"contract attempts exceed max ({state['contract_attempts']} > {MAX_CONTRACT_ATTEMPTS})"
        )
    state = transition(state, "CONTRACT_REVIEW", args.actor)
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "contract_submitted",
        from_state="PLANNED",
        to_state="CONTRACT_REVIEW",
        data={"attempt": state["contract_attempts"]},
    )
    print(f"CONTRACT_REVIEW (attempt {state['contract_attempts']}/{MAX_CONTRACT_ATTEMPTS})")
    return 0


def cmd_approve_contract(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] != "CONTRACT_REVIEW":
        die(f"approve-contract requires CONTRACT_REVIEW, current={state['current_state']}")
    state = transition(state, "CONTRACT_APPROVED", args.actor)
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "contract_approved",
        from_state="CONTRACT_REVIEW",
        to_state="CONTRACT_APPROVED",
        data={"feedback_ref": args.feedback_ref},
    )
    print("CONTRACT_APPROVED")
    return 0


def cmd_reject_contract(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] != "CONTRACT_REVIEW":
        die(f"reject-contract requires CONTRACT_REVIEW, current={state['current_state']}")
    exhausted = state["contract_attempts"] >= MAX_CONTRACT_ATTEMPTS
    if exhausted:
        state = transition(state, "BLOCKED", args.actor)
        state["blocked_reason"] = "contract_attempts_exhausted"
        state["blocked_note"] = args.note
    else:
        state = transition(state, "PLANNED", args.actor)
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "contract_rejected",
        from_state="CONTRACT_REVIEW",
        to_state=state["current_state"],
        data={"attempt": state["contract_attempts"], "feedback_ref": args.feedback_ref},
    )
    print(state["current_state"])
    return 0


def cmd_record_tdd(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    phase = args.phase.lower()
    if phase == "red":
        if state["current_state"] != "CONTRACT_APPROVED":
            die(f"record-tdd red requires CONTRACT_APPROVED, current={state['current_state']}")
        state["tdd"]["red_commit_sha"] = args.commit_sha
        state = transition(state, "IN_PROGRESS_RED", args.actor)
        event_name = "tdd_red_recorded"
    elif phase == "green":
        if state["current_state"] != "IN_PROGRESS_RED":
            die(f"record-tdd green requires IN_PROGRESS_RED, current={state['current_state']}")
        state["tdd"]["green_commit_sha"] = args.commit_sha
        state = transition(state, "IN_PROGRESS_GREEN", args.actor)
        event_name = "tdd_green_recorded"
    elif phase == "refactor":
        if state["current_state"] != "IN_PROGRESS_GREEN":
            die(
                f"record-tdd refactor requires IN_PROGRESS_GREEN, current={state['current_state']}"
            )
        state["tdd"]["refactor_commit_sha"] = args.commit_sha
        event_name = "tdd_refactor_recorded"
    else:
        die(f"unknown phase '{phase}' (expected: red|green|refactor)")
    state["timestamps"]["updated_at"] = now_iso()
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        event_name,
        data={"commit_sha": args.commit_sha, "phase": phase},
    )
    print(f"{state['current_state']} (tdd.{phase}={args.commit_sha})")
    return 0


def cmd_submit_impl(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] not in ("IN_PROGRESS_GREEN", "NEEDS_FIX"):
        die(
            "submit-impl requires IN_PROGRESS_GREEN or NEEDS_FIX, "
            f"current={state['current_state']}"
        )
    if state["current_state"] == "NEEDS_FIX":
        state["attempts"] += 1
        if state["attempts"] > MAX_IMPL_ATTEMPTS:
            die(f"impl attempts exceed max ({state['attempts']} > {MAX_IMPL_ATTEMPTS})")
    else:
        state["attempts"] = max(state["attempts"], 1)
    state = transition(state, "READY_FOR_REVIEW", args.actor)
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "implementation_submitted",
        to_state="READY_FOR_REVIEW",
        data={"attempt": state["attempts"]},
    )
    print(f"READY_FOR_REVIEW (attempt {state['attempts']}/{MAX_IMPL_ATTEMPTS})")
    return 0


def cmd_pass(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] != "READY_FOR_REVIEW":
        die(f"pass requires READY_FOR_REVIEW, current={state['current_state']}")
    state = transition(state, "PASSED", args.actor)
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "implementation_passed",
        from_state="READY_FOR_REVIEW",
        to_state="PASSED",
        data={"qa_ref": args.qa_ref, "feedback_ref": args.feedback_ref},
    )
    print("PASSED")
    return 0


def cmd_needs_fix(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] != "READY_FOR_REVIEW":
        die(f"needs-fix requires READY_FOR_REVIEW, current={state['current_state']}")
    exhausted = state["attempts"] >= MAX_IMPL_ATTEMPTS
    if exhausted:
        state = transition(state, "BLOCKED", args.actor)
        state["blocked_reason"] = "impl_attempts_exhausted"
        state["blocked_note"] = args.note
    else:
        state = transition(state, "NEEDS_FIX", args.actor)
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "implementation_needs_fix",
        from_state="READY_FOR_REVIEW",
        to_state=state["current_state"],
        data={"qa_ref": args.qa_ref, "feedback_ref": args.feedback_ref},
    )
    print(state["current_state"])
    return 0


def cmd_block(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    frm = state["current_state"]
    # block can happen from many states; transition table allows limited set
    if frm == "BLOCKED":
        die("already BLOCKED")
    # Use direct assignment; block can be invoked from anywhere as an escape hatch
    state["previous_state"] = frm
    state["current_state"] = "BLOCKED"
    state["last_transition_at"] = now_iso()
    state["last_transition_by"] = args.actor
    state["timestamps"]["updated_at"] = state["last_transition_at"]
    state["blocked_reason"] = args.reason
    state["blocked_note"] = args.note
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        args.actor,
        "blocked",
        from_state=frm,
        to_state="BLOCKED",
        data={"reason": args.reason, "note": args.note},
    )
    print(f"BLOCKED (reason={args.reason})")
    return 0


def cmd_unblock(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if state["current_state"] != "BLOCKED":
        die(f"unblock requires BLOCKED, current={state['current_state']}")
    state = transition(state, args.to, "human")
    state["blocked_reason"] = None
    state["blocked_note"] = None
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        "human",
        "unblocked",
        from_state="BLOCKED",
        to_state=args.to,
    )
    print(args.to)
    return 0


def cmd_set_pr(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if args.pr_number is not None:
        state["pr_number"] = args.pr_number
    if args.project_item_id is not None:
        state["project_item_id"] = args.project_item_id
    state["timestamps"]["updated_at"] = now_iso()
    atomic_write_json(state_path(args.issue_id), state)
    append_event(
        args.issue_id,
        "parent",
        "pr_opened" if args.pr_number is not None else "note",
        data={"pr_number": args.pr_number, "project_item_id": args.project_item_id},
    )
    print(
        f"set-pr: pr_number={state['pr_number']}, project_item_id={state['project_item_id']}"
    )
    return 0


def cmd_read(args: argparse.Namespace) -> int:
    state = load_state(args.issue_id)
    if args.field:
        val = state
        for part in args.field.split("."):
            if isinstance(val, dict) and part in val:
                val = val[part]
            else:
                die(f"field '{args.field}' not found")
        if isinstance(val, (dict, list)):
            print(json.dumps(val, ensure_ascii=False, indent=2))
        else:
            print(val if val is not None else "")
        return 0
    print(json.dumps(state, ensure_ascii=False, indent=2))
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    issues = []
    for d in all_issue_dirs():
        try:
            s = json.loads((d / "state.json").read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        if args.state and s.get("current_state") != args.state:
            continue
        issues.append(s)
    if args.json:
        print(json.dumps(issues, ensure_ascii=False, indent=2))
        return 0
    if not issues:
        print("(no issues)")
        return 0
    # table
    rows = [("#", "STATE", "ATT", "CON", "TITLE")]
    for s in issues:
        rows.append(
            (
                s["issue_id"],
                s["current_state"],
                f"{s['attempts']}/{MAX_IMPL_ATTEMPTS}",
                f"{s['contract_attempts']}/{MAX_CONTRACT_ATTEMPTS}",
                s["title"][:60],
            )
        )
    widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
    for r in rows:
        print(" | ".join(r[i].ljust(widths[i]) for i in range(len(r))))
    return 0


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #


def _add_issue(p: argparse.ArgumentParser) -> None:
    p.add_argument("--issue-id", required=True)


def _add_actor(p: argparse.ArgumentParser) -> None:
    p.add_argument(
        "--actor",
        default="controller",
        choices=["planner", "generator", "evaluator", "observer", "parent", "human", "controller"],
    )


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="controller.py", description=__doc__.splitlines()[1])
    sub = p.add_subparsers(dest="cmd", required=True)

    q = sub.add_parser("init", help="create a new issue work directory")
    _add_issue(q)
    q.add_argument("--title", required=True)
    q.add_argument("--branch", required=True)
    q.add_argument("--force", action="store_true")
    q.set_defaults(func=cmd_init)

    q = sub.add_parser("submit-contract", help="PLANNED -> CONTRACT_REVIEW (generator)")
    _add_issue(q)
    _add_actor(q)
    q.set_defaults(func=cmd_submit_contract)

    q = sub.add_parser("approve-contract", help="CONTRACT_REVIEW -> CONTRACT_APPROVED (evaluator)")
    _add_issue(q)
    _add_actor(q)
    q.add_argument("--feedback-ref", default=None)
    q.set_defaults(func=cmd_approve_contract)

    q = sub.add_parser(
        "reject-contract", help="CONTRACT_REVIEW -> PLANNED or BLOCKED (evaluator)"
    )
    _add_issue(q)
    _add_actor(q)
    q.add_argument("--feedback-ref", default=None)
    q.add_argument("--note", default=None)
    q.set_defaults(func=cmd_reject_contract)

    q = sub.add_parser("record-tdd", help="record a TDD commit (red/green/refactor)")
    _add_issue(q)
    _add_actor(q)
    q.add_argument("--phase", required=True, choices=["red", "green", "refactor"])
    q.add_argument("--commit-sha", required=True)
    q.set_defaults(func=cmd_record_tdd)

    q = sub.add_parser(
        "submit-impl", help="IN_PROGRESS_GREEN or NEEDS_FIX -> READY_FOR_REVIEW (generator)"
    )
    _add_issue(q)
    _add_actor(q)
    q.set_defaults(func=cmd_submit_impl)

    q = sub.add_parser("pass", help="READY_FOR_REVIEW -> PASSED (evaluator)")
    _add_issue(q)
    _add_actor(q)
    q.add_argument("--qa-ref", default=None)
    q.add_argument("--feedback-ref", default=None)
    q.set_defaults(func=cmd_pass)

    q = sub.add_parser("needs-fix", help="READY_FOR_REVIEW -> NEEDS_FIX or BLOCKED (evaluator)")
    _add_issue(q)
    _add_actor(q)
    q.add_argument("--qa-ref", default=None)
    q.add_argument("--feedback-ref", default=None)
    q.add_argument("--note", default=None)
    q.set_defaults(func=cmd_needs_fix)

    q = sub.add_parser("block", help="force BLOCKED (escape hatch)")
    _add_issue(q)
    _add_actor(q)
    q.add_argument(
        "--reason",
        required=True,
        choices=[
            "contract_attempts_exhausted",
            "impl_attempts_exhausted",
            "spec_missing",
            "spec_ambiguous",
            "human_judgment_required",
            "external_dependency",
            "tdd_order_violation",
            "test_integrity_violation",
        ],
    )
    q.add_argument("--note", default=None)
    q.set_defaults(func=cmd_block)

    q = sub.add_parser("unblock", help="BLOCKED -> <state> (human only)")
    _add_issue(q)
    q.add_argument(
        "--to",
        required=True,
        choices=["PLANNED", "CONTRACT_REVIEW", "READY_FOR_REVIEW", "NEEDS_FIX"],
    )
    q.set_defaults(func=cmd_unblock)

    q = sub.add_parser("set-pr", help="set PR number / project item id")
    _add_issue(q)
    q.add_argument("--pr-number", type=int, default=None)
    q.add_argument("--project-item-id", default=None)
    q.set_defaults(func=cmd_set_pr)

    q = sub.add_parser("read", help="print state.json (or a single field)")
    _add_issue(q)
    q.add_argument("--field", default=None, help="dotted path, e.g. current_state or tdd.red_commit_sha")
    q.set_defaults(func=cmd_read)

    q = sub.add_parser("list", help="list all issues")
    q.add_argument("--state", default=None, choices=STATES)
    q.add_argument("--json", action="store_true")
    q.set_defaults(func=cmd_list)

    return p


def main(argv: Optional[Iterable[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
