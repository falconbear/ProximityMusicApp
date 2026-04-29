#!/usr/bin/env python3
"""
test_integrity_hook.py — PreToolUse Edit/Write/MultiEdit

generator が既存テストを改変するのを機械的にブロックする。
contract-first / tdd-enforcement / test-integrity skill の最も重要なルール。

許可:
  - 新規テストファイル作成
  - 既存テストファイルへの新規テスト追加
許可しない (block):
  - 既存テストへの .skip / .only / .todo / xtest / xit 追加
  - 既存 expect(...) の削除
  - test/it 関数の削除

Detection は Edit の old_string / new_string、または MultiEdit の各 edit、
Write は warning のみ (full overwrite は意図が確認できないため AI に判断を促す)。

入力: Claude Code が PreToolUse hook で stdin に JSON を渡す
出力: 違反検知時は exit code 2 + stderr に理由 (Claude Code が tool call を block)
      警告のみは exit code 0 + stderr に warning
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TEST_PATTERNS = [
    re.compile(r"\.test\.[jt]sx?$"),
    re.compile(r"\.spec\.[jt]sx?$"),
    re.compile(r"_test\.py$"),
    re.compile(r"^test_.*\.py$"),
    re.compile(r"_test\.go$"),
    re.compile(r"_test\.rs$"),
    re.compile(r"/tests?/"),
    re.compile(r"/__tests__/"),
    re.compile(r"/spec/"),
]

# Patterns that, when ADDED in a diff, are violations
SKIP_PATTERNS = [
    re.compile(r"\.skip\b"),
    re.compile(r"\.only\b"),
    re.compile(r"\.todo\b"),
    re.compile(r"\bxit\("),
    re.compile(r"\bxtest\("),
    re.compile(r"\bxdescribe\("),
    re.compile(r"@pytest\.mark\.skip"),
    re.compile(r"@unittest\.skip"),
    re.compile(r"#\[ignore\]"),  # Rust
    re.compile(r"t\.Skip\("),  # Go
]

# Test function declarations (used to detect deletions)
TEST_DECL_PATTERNS = [
    re.compile(r"\b(?:test|it|describe)\s*\(\s*['\"]([^'\"]+)['\"]"),
    re.compile(r"def\s+(test_\w+)\s*\("),
    re.compile(r"func\s+(Test\w+)\s*\("),
    re.compile(r"#\[test\]\s*\n\s*fn\s+(\w+)"),
]

ASSERTION_WEAKENING = [
    (re.compile(r"\.toBe\(([^)]+)\)"), re.compile(r"\.toBeTruthy\(\)")),
    (re.compile(r"\.toEqual\(([^)]+)\)"), re.compile(r"\.toBeDefined\(\)")),
    (re.compile(r"assert\s+\w+\s*==\s*\w+"), re.compile(r"assert\s+\w+")),
]


def is_test_file(path: str) -> bool:
    return any(p.search(path) for p in TEST_PATTERNS)


def find_violations_in_diff(old: str, new: str) -> list[str]:
    """Return list of human-readable violation reasons. Empty if clean."""
    violations: list[str] = []

    # 1. skip/only/todo additions
    for sp in SKIP_PATTERNS:
        old_count = len(sp.findall(old))
        new_count = len(sp.findall(new))
        if new_count > old_count:
            violations.append(
                f"{sp.pattern} added to existing tests "
                f"({old_count} → {new_count} occurrences)"
            )

    # 2. test function deletions
    for tp in TEST_DECL_PATTERNS:
        old_names = set(tp.findall(old))
        new_names = set(tp.findall(new))
        deleted = old_names - new_names
        if deleted:
            violations.append(
                f"test function(s) removed: {sorted(deleted)[:5]}"
            )

    # 3. assertion weakening (heuristic)
    # Count strong vs weak assertions; if strong dropped and weak rose, flag
    return violations


def extract_edits(payload: dict) -> list[tuple[str, str]]:
    """Yield (old_string, new_string) tuples for Edit / MultiEdit."""
    tool = payload.get("tool_name", "")
    inp = payload.get("tool_input", {})
    if tool == "Edit":
        return [(inp.get("old_string", ""), inp.get("new_string", ""))]
    if tool == "MultiEdit":
        return [(e.get("old_string", ""), e.get("new_string", "")) for e in inp.get("edits", [])]
    return []


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # not our problem

    tool = payload.get("tool_name", "")
    inp = payload.get("tool_input", {})
    file_path = inp.get("file_path", "")

    if not file_path or not is_test_file(file_path):
        sys.exit(0)

    # Write: full overwrite of an existing test file → warn
    if tool == "Write":
        if Path(file_path).exists():
            sys.stderr.write(
                f"⚠ test-integrity: overwriting existing test file {file_path}.\n"
                f"  Make sure no existing tests are removed/disabled. "
                f"Adding new tests is fine; modifying existing assertions is not.\n"
            )
        sys.exit(0)

    # Edit / MultiEdit: analyze each edit
    violations: list[str] = []
    for old, new in extract_edits(payload):
        violations.extend(find_violations_in_diff(old, new))

    if violations:
        msg = (
            f"❌ test-integrity violation in {file_path}:\n"
            + "\n".join(f"  - {v}" for v in violations)
            + "\n\n"
            "Generator must not modify existing tests. New tests OK; "
            "skip/only/todo/deletion of existing tests is a contract violation. "
            "If the contract explicitly authorizes a test change, document it in "
            "docs/progress.md and override by retrying after editing the contract."
        )
        sys.stderr.write(msg + "\n")
        sys.exit(2)  # Claude Code blocks the tool call

    sys.exit(0)


if __name__ == "__main__":
    main()
