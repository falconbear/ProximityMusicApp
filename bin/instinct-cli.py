#!/usr/bin/env python3
"""
instinct-cli.py — Project-scoped Instinct store の読み書き CLI.

Observer agent が使う。Instinct の YAML ファイルを
<project>/.harness/instincts/<agent>/<id>.yaml に保存する。

信頼度更新ルール:
  新規作成:                  confidence = 0.3
  2 回目の観測:              confidence = min(0.5, confidence + 0.15)
  3 回目以降:                confidence = min(0.9, confidence + 0.1)
  ユーザーが明示的に否定:    confidence = max(0.1, confidence - 0.3)

Usage:
  instinct-cli.py create --agent generator --id <id> --trigger "<text>" \\
      --domain code-quality --source evaluator-feedback --sprint 5 \\
      --action "<text>" --evidence "<text>" [--anti-pattern "<text>"]
  instinct-cli.py observe --id <id> --sprint N --evidence "<text>"
  instinct-cli.py reject --id <id>
  instinct-cli.py list [--agent <agent>] [--min-confidence 0.7]
  instinct-cli.py show --id <id>
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

VALID_AGENTS = {"generator", "evaluator", "planner"}
VALID_DOMAINS = {
    "code-quality",
    "testing",
    "architecture",
    "ux",
    "performance",
    "security",
    "process",
}
VALID_SOURCES = {
    "evaluator-feedback",
    "generator-memory",
    "sprint-analysis",
    "session-observation",
}

ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{1,63}$")


def project_root() -> Path:
    """Find git repo root or fallback to cwd."""
    cwd = Path.cwd()
    for parent in [cwd, *cwd.parents]:
        if (parent / ".git").exists():
            return parent
    return cwd


def instinct_dir() -> Path:
    root = project_root()
    d = root / ".harness" / "instincts"
    d.mkdir(parents=True, exist_ok=True)
    return d


def instinct_path(agent: str, instinct_id: str) -> Path:
    return instinct_dir() / agent / f"{instinct_id}.yaml"


def today() -> str:
    return dt.date.today().isoformat()


def validate_id(instinct_id: str) -> None:
    if not ID_PATTERN.match(instinct_id):
        sys.exit(f"error: --id must match {ID_PATTERN.pattern}, got {instinct_id!r}")


def find_existing(instinct_id: str) -> Path | None:
    """Find an Instinct file by id across all agent dirs."""
    for agent in VALID_AGENTS:
        p = instinct_path(agent, instinct_id)
        if p.exists():
            return p
    return None


def parse_yaml(path: Path) -> tuple[dict[str, str], str]:
    """Parse the very small YAML subset used by Instinct files.

    Returns (frontmatter_dict, body_text).
    """
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        sys.exit(f"error: {path} missing YAML frontmatter")
    end = text.find("\n---\n", 4)
    if end == -1:
        sys.exit(f"error: {path} frontmatter not closed")
    head = text[4:end]
    body = text[end + 5 :]
    data: dict[str, str] = {}
    for line in head.splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        data[k.strip()] = v.strip()
    return data, body


def format_yaml(data: dict[str, str], body: str) -> str:
    order = [
        "id",
        "trigger",
        "confidence",
        "domain",
        "source",
        "agent",
        "observation_count",
        "created",
        "last_observed",
        "sprints",
    ]
    lines = ["---"]
    for k in order:
        if k in data:
            v = data[k]
            lines.append(f"{k}: {v}")
    # include any extras
    for k, v in data.items():
        if k not in order:
            lines.append(f"{k}: {v}")
    lines.append("---")
    return "\n".join(lines) + "\n" + body


def bump_confidence(current: float, observation_count: int) -> float:
    """Apply confidence progression rule."""
    if observation_count == 1:
        return 0.3
    if observation_count == 2:
        return min(0.5, current + 0.15)
    return min(0.9, current + 0.1)


def cmd_create(args: argparse.Namespace) -> None:
    validate_id(args.id)
    if args.agent not in VALID_AGENTS:
        sys.exit(f"error: --agent must be one of {sorted(VALID_AGENTS)}")
    if args.domain not in VALID_DOMAINS:
        sys.exit(f"error: --domain must be one of {sorted(VALID_DOMAINS)}")
    if args.source not in VALID_SOURCES:
        sys.exit(f"error: --source must be one of {sorted(VALID_SOURCES)}")

    existing = find_existing(args.id)
    if existing is not None:
        # fall through to observe
        print(f"note: {args.id} already exists, recording as observation")
        cmd_observe(args)
        return

    path = instinct_path(args.agent, args.id)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "id": args.id,
        "trigger": f'"{args.trigger}"',
        "confidence": "0.3",
        "domain": args.domain,
        "source": args.source,
        "agent": args.agent,
        "observation_count": "1",
        "created": today(),
        "last_observed": today(),
        "sprints": f"[{args.sprint}]",
    }
    title = args.title or args.id.replace("-", " ").capitalize()
    body_parts = [f"\n# {title}\n", "## Action", args.action, ""]
    body_parts += ["## Evidence", f"- Sprint {args.sprint:02d}: {args.evidence}", ""]
    if args.anti_pattern:
        body_parts += ["## Anti-Pattern", args.anti_pattern, ""]
    body = "\n".join(body_parts)
    path.write_text(format_yaml(data, body), encoding="utf-8")
    print(f"created: {path.relative_to(project_root())}")


def cmd_observe(args: argparse.Namespace) -> None:
    validate_id(args.id)
    path = find_existing(args.id)
    if path is None:
        sys.exit(
            f"error: {args.id} not found. use `create` first "
            f"(looked in {instinct_dir()})"
        )
    data, body = parse_yaml(path)
    count = int(data.get("observation_count", "0")) + 1
    confidence = float(data.get("confidence", "0.3"))
    confidence = bump_confidence(confidence, count)
    data["observation_count"] = str(count)
    data["confidence"] = f"{confidence:.2f}"
    data["last_observed"] = today()
    # append sprint to list
    sprints_str = data.get("sprints", "[]").strip("[]")
    sprints = [s.strip() for s in sprints_str.split(",") if s.strip()]
    if str(args.sprint) not in sprints:
        sprints.append(str(args.sprint))
    data["sprints"] = "[" + ", ".join(sprints) + "]"
    if args.evidence:
        new_line = f"- Sprint {args.sprint:02d}: {args.evidence}\n"
        if "## Evidence" in body:
            body = re.sub(
                r"(## Evidence\n(?:- .*\n)*)",
                lambda m: m.group(1) + new_line,
                body,
                count=1,
            )
        else:
            body += "\n## Evidence\n" + new_line
    path.write_text(format_yaml(data, body), encoding="utf-8")
    print(f"observed: {path.relative_to(project_root())} (count={count}, confidence={confidence:.2f})")


def cmd_reject(args: argparse.Namespace) -> None:
    validate_id(args.id)
    path = find_existing(args.id)
    if path is None:
        sys.exit(f"error: {args.id} not found")
    data, body = parse_yaml(path)
    confidence = float(data.get("confidence", "0.3"))
    confidence = max(0.1, confidence - 0.3)
    data["confidence"] = f"{confidence:.2f}"
    data["last_observed"] = today()
    path.write_text(format_yaml(data, body), encoding="utf-8")
    print(f"rejected: {path.relative_to(project_root())} (confidence={confidence:.2f})")


def cmd_list(args: argparse.Namespace) -> None:
    agents = [args.agent] if args.agent else sorted(VALID_AGENTS)
    rows = []
    for agent in agents:
        d = instinct_dir() / agent
        if not d.exists():
            continue
        for p in sorted(d.glob("*.yaml")):
            try:
                data, _ = parse_yaml(p)
            except SystemExit:
                continue
            conf = float(data.get("confidence", "0"))
            if args.min_confidence and conf < args.min_confidence:
                continue
            rows.append((agent, data.get("id", ""), conf, data.get("observation_count", "0")))
    if not rows:
        print("(no instincts)")
        return
    rows.sort(key=lambda r: (-r[2], r[0], r[1]))
    print(f"{'agent':<10} {'id':<40} {'conf':>6} {'obs':>4}")
    for agent, iid, conf, obs in rows:
        print(f"{agent:<10} {iid:<40} {conf:>6.2f} {obs:>4}")


def cmd_show(args: argparse.Namespace) -> None:
    validate_id(args.id)
    path = find_existing(args.id)
    if path is None:
        sys.exit(f"error: {args.id} not found")
    print(path.read_text(encoding="utf-8"))


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="instinct-cli")
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("create")
    c.add_argument("--agent", required=True)
    c.add_argument("--id", required=True)
    c.add_argument("--trigger", required=True)
    c.add_argument("--domain", required=True)
    c.add_argument("--source", required=True)
    c.add_argument("--sprint", type=int, required=True)
    c.add_argument("--action", required=True)
    c.add_argument("--evidence", required=True)
    c.add_argument("--anti-pattern", default="")
    c.add_argument("--title", default="")
    c.set_defaults(func=cmd_create)

    o = sub.add_parser("observe")
    o.add_argument("--id", required=True)
    o.add_argument("--sprint", type=int, required=True)
    o.add_argument("--evidence", default="")
    o.set_defaults(func=cmd_observe)

    r = sub.add_parser("reject")
    r.add_argument("--id", required=True)
    r.set_defaults(func=cmd_reject)

    ls = sub.add_parser("list")
    ls.add_argument("--agent", choices=sorted(VALID_AGENTS))
    ls.add_argument("--min-confidence", type=float, default=0.0)
    ls.set_defaults(func=cmd_list)

    sh = sub.add_parser("show")
    sh.add_argument("--id", required=True)
    sh.set_defaults(func=cmd_show)

    return p


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
