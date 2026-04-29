#!/usr/bin/env python3
"""
instinct_scope_hook.py — PreToolUse Write/Edit

instinct-loop skill のコアルール:
  Instinct は project-scoped。`.harness/instincts/` にだけ書く。
  以下は禁止:
    - ~/.claude/instincts/ への書き込み (cross-project 汚染)
    - 他プロジェクトの .harness/instincts/ への書き込み
    - その他 home directory 配下の機密ファイル (.ssh, .aws, .env, .gnupg)

入力: Claude Code が PreToolUse hook で stdin に JSON を渡す
出力: block 時は exit code 2 + stderr で理由
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def expand(path: str) -> str:
    return os.path.expanduser(os.path.expandvars(path))


def project_root() -> Path:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=2,
        )
        if out.returncode == 0:
            return Path(out.stdout.strip())
    except Exception:
        pass
    return Path.cwd()


# Forbidden write targets (regex against absolute path)
FORBIDDEN_WRITE_PATTERNS = [
    (re.compile(r"/\.claude/instincts/"), "global Instinct store (~/.claude/instincts/) — Instinct は project-scoped"),
    (re.compile(r"/\.ssh/"), "SSH credentials directory"),
    (re.compile(r"/\.aws/"), "AWS credentials directory"),
    (re.compile(r"/\.gnupg/"), "GPG keyring directory"),
    (re.compile(r"/\.env(\.|$)"), "environment file (.env / .env.*)"),
]


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool = payload.get("tool_name", "")
    if tool not in {"Write", "Edit", "MultiEdit"}:
        sys.exit(0)

    file_path = payload.get("tool_input", {}).get("file_path", "")
    if not file_path:
        sys.exit(0)

    abs_path = str(Path(expand(file_path)).resolve())

    # Check global forbidden patterns
    for pat, reason in FORBIDDEN_WRITE_PATTERNS:
        if pat.search(abs_path):
            sys.stderr.write(
                f"❌ instinct-scope / safety: refusing to write {abs_path}\n"
                f"  Reason: {reason}\n"
                f"  This path is outside project scope or contains secrets.\n"
            )
            sys.exit(2)

    # Check write to other project's .harness/
    if "/.harness/instincts/" in abs_path:
        root = project_root()
        expected_prefix = str(root / ".harness" / "instincts")
        if not abs_path.startswith(expected_prefix):
            sys.stderr.write(
                f"❌ instinct-scope: refusing to write {abs_path}\n"
                f"  Reason: target is in a different project's .harness/.\n"
                f"  Current project: {root}\n"
                f"  Instincts must stay project-scoped. To share, copy YAMLs manually.\n"
            )
            sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
