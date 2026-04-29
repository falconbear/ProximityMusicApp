#!/usr/bin/env python3
"""
tdd_order_hook.py — PreToolUse Bash on git commit

tdd-enforcement skill のコアルール:
  GREEN commit (実装) の前に RED commit (failing test) が存在しなければならない。

検査:
  commit message が `sprint-NN: GREEN` (実装フェーズ) のとき、
  git log から `sprint-NN: RED` commit がブランチ上に既に存在することを確認する。

  存在しなければ警告 (block ではない、evaluator が最終判定する)。

理由 (block しない):
  - プロジェクト固有の緩和で 1 commit TDD を許可している場合がある
  - hooks レベルでは判断材料が少ない (test がそもそも書かれているか確認できない)
  - evaluator (実装モード) が最終的な合否を出す

入力: Claude Code が PreToolUse hook で stdin に JSON を渡す
出力: 警告は exit code 0 + stderr (警告メッセージは context に入る)
"""

from __future__ import annotations

import json
import re
import shlex
import subprocess
import sys


SPRINT_GREEN_PATTERN = re.compile(r"sprint[- ]?(\d+).*GREEN", re.IGNORECASE)
SPRINT_RED_PATTERN_TEMPLATE = r"sprint[- ]?{n}.*RED"
SPRINT_FREE_TDD_PATTERN = re.compile(r"\[TDD:\s*test-first\]", re.IGNORECASE)


def extract_commit_message(args: list[str]) -> str | None:
    """Extract commit message from `git commit -m '...'` style args."""
    # find -m / --message
    for i, a in enumerate(args):
        if a == "-m" or a == "--message":
            if i + 1 < len(args):
                return args[i + 1]
        if a.startswith("--message="):
            return a.split("=", 1)[1]
    return None


def red_commit_exists(sprint_n: str) -> bool:
    """Check git log on current branch for a RED commit for this sprint."""
    pattern = SPRINT_RED_PATTERN_TEMPLATE.format(n=re.escape(sprint_n))
    try:
        # Search the last 50 commits on the current branch
        out = subprocess.run(
            ["git", "log", "--oneline", "-50", "--grep", pattern, "-iE"],
            capture_output=True, text=True, timeout=5,
        )
        return bool(out.stdout.strip())
    except Exception:
        return True  # if git fails, don't block


def parse_git_command(cmd: str) -> list[str] | None:
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return None
    for i, t in enumerate(tokens):
        if t == "git" or t.endswith("/git"):
            return tokens[i + 1 :]
    return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    if payload.get("tool_name") != "Bash":
        sys.exit(0)

    cmd = payload.get("tool_input", {}).get("command", "")
    git_args = parse_git_command(cmd)
    if git_args is None or not git_args or git_args[0] != "commit":
        sys.exit(0)

    message = extract_commit_message(git_args[1:])
    if message is None:
        sys.exit(0)

    # If the message uses the explicit single-commit TDD opt-in marker, allow
    if SPRINT_FREE_TDD_PATTERN.search(message):
        sys.exit(0)

    m = SPRINT_GREEN_PATTERN.search(message)
    if m is None:
        sys.exit(0)

    sprint_n = m.group(1)

    if not red_commit_exists(sprint_n):
        sys.stderr.write(
            f"⚠ tdd-order: about to create GREEN commit for Sprint {sprint_n} "
            f"but no matching 'sprint-{sprint_n}: RED' commit was found in git log.\n"
            f"  Per tdd-enforcement skill, RED (failing test) must precede GREEN (implementation).\n"
            f"  If this commit was authorized as single-commit TDD by the project's CLAUDE.md, "
            f"include '[TDD: test-first]' in the message to bypass this check.\n"
            f"  Otherwise: cancel, write a failing test first, RED-commit it, then GREEN-commit.\n"
        )
        # Don't block — evaluator will catch via 3-layer review

    sys.exit(0)


if __name__ == "__main__":
    main()
