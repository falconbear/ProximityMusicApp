#!/usr/bin/env python3
"""
validate-state.py — JSON Schema validator for .ai/work/<issue-id>/*.json.

Called as a PostToolUse hook. Also usable standalone:
    bin/validate-state.py                # validate everything
    bin/validate-state.py --issue 42     # validate one issue
    bin/validate-state.py --strict       # exit 2 on violations (default: 0 on warn)

Uses jsonschema if installed. Falls back to a minimal structural checker that
enforces: required keys, enum values, types, nested required keys. Enough to
catch common corruption from bad hand-edits.

Hook contract: reads stdin for tool_use JSON; inspects file_path; validates if
it's a *.json file under .ai/work/. Exit 0 (non-blocking) unless --strict.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

SCHEMAS_DIR = Path(__file__).resolve().parent.parent / "schemas"
STATE_SCHEMA = SCHEMAS_DIR / "state.schema.json"
CONTRACT_SCHEMA = SCHEMAS_DIR / "contract.schema.json"
QA_SCHEMA = SCHEMAS_DIR / "qa.schema.json"
EVENT_SCHEMA = SCHEMAS_DIR / "event.schema.json"

FILE_TO_SCHEMA = {
    "state.json": STATE_SCHEMA,
    "contract.json": CONTRACT_SCHEMA,
    "qa.json": QA_SCHEMA,
}


def repo_root() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env).resolve()
    return Path.cwd().resolve()


# --------------------------------------------------------------------------- #
# Validation
# --------------------------------------------------------------------------- #


def _try_jsonschema() -> Optional[Any]:
    try:
        import jsonschema  # type: ignore

        return jsonschema
    except ImportError:
        return None


def validate_with_jsonschema(data: Dict[str, Any], schema: Dict[str, Any]) -> List[str]:
    """Use jsonschema if available. Returns list of error messages."""
    js = _try_jsonschema()
    if js is None:
        return validate_basic(data, schema, path="$")
    validator = js.Draft202012Validator(schema)
    errors = []
    for err in sorted(validator.iter_errors(data), key=lambda e: e.path):
        loc = "$" + "".join(f".{p}" if isinstance(p, str) else f"[{p}]" for p in err.path)
        errors.append(f"{loc}: {err.message}")
    return errors


def validate_basic(
    data: Any, schema: Dict[str, Any], *, path: str = "$"
) -> List[str]:
    """Minimal structural checker. Not as thorough as jsonschema, but no deps."""
    errors: List[str] = []

    expected_type = schema.get("type")
    if expected_type:
        types = expected_type if isinstance(expected_type, list) else [expected_type]
        ok = any(_match_type(data, t) for t in types)
        if not ok:
            errors.append(f"{path}: type mismatch, want {expected_type}, got {type(data).__name__}")
            return errors  # can't recurse further

    if "const" in schema and data != schema["const"]:
        errors.append(f"{path}: want const {schema['const']!r}, got {data!r}")

    if "enum" in schema and data not in schema["enum"]:
        errors.append(f"{path}: value {data!r} not in enum {schema['enum']}")

    if "pattern" in schema and isinstance(data, str):
        import re

        if not re.match(schema["pattern"], data):
            errors.append(f"{path}: value {data!r} does not match pattern {schema['pattern']}")

    if isinstance(data, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in data:
                errors.append(f"{path}: missing required key '{key}'")
        props = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        if additional is False:
            for key in data:
                if key not in props:
                    errors.append(f"{path}: unexpected property '{key}'")
        for key, sub in props.items():
            if key in data:
                errors.extend(validate_basic(data[key], sub, path=f"{path}.{key}"))

    if isinstance(data, list):
        items = schema.get("items")
        if items:
            for i, v in enumerate(data):
                errors.extend(validate_basic(v, items, path=f"{path}[{i}]"))
        if "minItems" in schema and len(data) < schema["minItems"]:
            errors.append(f"{path}: needs at least {schema['minItems']} items")

    if isinstance(data, int) and not isinstance(data, bool):
        if "minimum" in schema and data < schema["minimum"]:
            errors.append(f"{path}: {data} < minimum {schema['minimum']}")
        if "maximum" in schema and data > schema["maximum"]:
            errors.append(f"{path}: {data} > maximum {schema['maximum']}")

    if isinstance(data, str) and "minLength" in schema and len(data) < schema["minLength"]:
        errors.append(f"{path}: string shorter than minLength {schema['minLength']}")

    return errors


def _match_type(value: Any, t: str) -> bool:
    if t == "string":
        return isinstance(value, str)
    if t == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if t == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if t == "boolean":
        return isinstance(value, bool)
    if t == "null":
        return value is None
    if t == "array":
        return isinstance(value, list)
    if t == "object":
        return isinstance(value, dict)
    return False


# --------------------------------------------------------------------------- #
# Cross-file consistency checks
# --------------------------------------------------------------------------- #


def cross_checks(issue_dir: Path) -> List[str]:
    """Checks spanning multiple files in one issue dir."""
    errors: List[str] = []
    state_p = issue_dir / "state.json"
    contract_p = issue_dir / "contract.json"
    if not state_p.exists():
        return errors
    try:
        state = json.loads(state_p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"{state_p}: JSON parse error: {e}")
        return errors

    # contract.json must exist once state leaves PLANNED
    if state.get("current_state") not in ("PLANNED", None) and not contract_p.exists():
        errors.append(
            f"{issue_dir}: state.current_state={state.get('current_state')} but contract.json missing"
        )

    # contract locked check
    if contract_p.exists():
        try:
            contract = json.loads(contract_p.read_text(encoding="utf-8"))
            if state.get("current_state") not in ("PLANNED", "CONTRACT_REVIEW"):
                if contract.get("locked") is not True:
                    errors.append(
                        f"{contract_p}: must have locked=true when state={state.get('current_state')}"
                    )
        except json.JSONDecodeError as e:
            errors.append(f"{contract_p}: JSON parse error: {e}")

    # TDD coherence
    tdd = state.get("tdd", {})
    if state.get("current_state") in ("IN_PROGRESS_GREEN", "READY_FOR_REVIEW", "PASSED"):
        if not tdd.get("red_commit_sha"):
            errors.append(
                f"{state_p}: state={state.get('current_state')} but tdd.red_commit_sha is null"
            )
    if state.get("current_state") in ("READY_FOR_REVIEW", "PASSED"):
        if not tdd.get("green_commit_sha"):
            errors.append(
                f"{state_p}: state={state.get('current_state')} but tdd.green_commit_sha is null"
            )

    return errors


# --------------------------------------------------------------------------- #
# File discovery
# --------------------------------------------------------------------------- #


def find_targets(root: Path, issue_id: Optional[str] = None) -> List[Path]:
    base = root / ".ai" / "work"
    if not base.exists():
        return []
    targets: List[Path] = []
    for d in sorted(base.iterdir()):
        if not d.is_dir():
            continue
        if issue_id and d.name != issue_id:
            continue
        for name in FILE_TO_SCHEMA:
            p = d / name
            if p.exists():
                targets.append(p)
    return targets


def load_schema(schema_path: Path) -> Dict[str, Any]:
    return json.loads(schema_path.read_text(encoding="utf-8"))


def validate_file(path: Path) -> List[str]:
    schema_path = FILE_TO_SCHEMA.get(path.name)
    if schema_path is None:
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [f"{path}: JSON parse error: {e}"]
    try:
        schema = load_schema(schema_path)
    except (json.JSONDecodeError, OSError) as e:
        return [f"{schema_path}: schema load error: {e}"]
    errors = validate_with_jsonschema(data, schema)
    return [f"{path}: {msg}" for msg in errors]


# --------------------------------------------------------------------------- #
# Hook mode
# --------------------------------------------------------------------------- #


def hook_mode() -> int:
    """Parse tool_use JSON from stdin. Return 0 (non-blocking) always."""
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path") or ""
    if ".ai/work/" not in file_path:
        return 0
    if not file_path.endswith(".json"):
        return 0
    p = Path(file_path)
    if not p.exists():
        return 0
    errors = validate_file(p)
    if errors:
        print("⚠ validate-state:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        # also run cross-checks for the issue dir
        if p.parent.name.isdigit():
            cross = cross_checks(p.parent)
            for e in cross:
                print(f"  - {e}", file=sys.stderr)
    return 0


def standalone_mode(args: argparse.Namespace) -> int:
    root = repo_root()
    targets = find_targets(root, args.issue)
    if not targets and not args.issue:
        print("(no .ai/work/ files to validate)")
        return 0

    total_errors = 0
    for path in targets:
        errors = validate_file(path)
        if errors:
            total_errors += len(errors)
            for e in errors:
                print(e)

    # cross-checks per issue dir
    seen_dirs = set()
    for path in targets:
        d = path.parent
        if d in seen_dirs:
            continue
        seen_dirs.add(d)
        for e in cross_checks(d):
            total_errors += 1
            print(e)

    if total_errors == 0:
        print(f"OK: {len(targets)} file(s) valid")
        return 0
    print(f"\n{total_errors} error(s)")
    return 2 if args.strict else 0


def main() -> int:
    if not sys.stdin.isatty() and os.environ.get("CLAUDE_HOOK", "") != "":
        return hook_mode()

    parser = argparse.ArgumentParser()
    parser.add_argument("--issue", default=None, help="validate a single issue id")
    parser.add_argument("--strict", action="store_true", help="exit 2 on errors")
    parser.add_argument("--hook", action="store_true", help="force hook mode (read stdin)")
    args = parser.parse_args()

    if args.hook:
        return hook_mode()
    return standalone_mode(args)


if __name__ == "__main__":
    sys.exit(main())
