#!/usr/bin/env python3
"""
project-sync.py — GitHub Projects v2 helper for Sprint board.

Sprint の状態遷移を GitHub Project のカンバン (Status field) に反映する。

前提: 以下のいずれかで事前に Project が用意されている。
  1. 人間が GitHub UI から Project を作成し、Status field に以下のオプションを追加:
     Planned / Contract / In Progress / In Review / Needs Fix / Blocked / Done
  2. 親 Claude が `project-sync.py setup` で自動作成 (要: gh CLI + project:write scope)

プロジェクト番号は `.harness/project.yaml` に保存される:
  number: 5
  owner: falconbear
  type: user       # user or org

Usage:
  project-sync.py setup --title "Sprint Board" --owner falconbear [--org]
    Project を作成し .harness/project.yaml を書き出す。Status field オプションを
    セットアップする (既存なら skip)。

  project-sync.py add --issue <issue-number>
    既存 Issue を Project に追加。

  project-sync.py move --issue NN --status "In Progress"
    Sprint の item の Status field を指定ステータスに変更。

  project-sync.py list
    現在の Project items を表示。

  project-sync.py state-to-status <STATE>
    state machine の state 名 (PLANNED, IN_PROGRESS_RED など) を
    Project の Status カラム名に変換して stdout に出す。
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

CONFIG_PATH = Path(".harness/project.yaml")

STATUS_COLUMNS = [
    "Planned",
    "Contract",
    "In Progress",
    "In Review",
    "Needs Fix",
    "Blocked",
    "Done",
]

# state machine → project kanban column
STATE_TO_STATUS = {
    "PLANNED": "Planned",
    "CONTRACT_REVIEW": "Contract",
    "CONTRACT_APPROVED": "Contract",
    "IN_PROGRESS_RED": "In Progress",
    "IN_PROGRESS_GREEN": "In Progress",
    "READY_FOR_REVIEW": "In Review",
    "NEEDS_FIX": "Needs Fix",
    "BLOCKED": "Blocked",
    "PASSED": "Done",
}


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def read_config() -> dict[str, Any]:
    if not CONFIG_PATH.exists():
        sys.exit(
            f"error: {CONFIG_PATH} not found. run `project-sync.py setup` first, "
            f"or create it manually with `number` / `owner` / `type` keys."
        )
    return parse_simple_yaml(CONFIG_PATH.read_text(encoding="utf-8"))


def write_config(cfg: dict[str, Any]) -> None:
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{k}: {v}" for k, v in cfg.items()]
    CONFIG_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_simple_yaml(text: str) -> dict[str, Any]:
    """Parse a tiny YAML subset: top-level key: value lines only."""
    data: dict[str, Any] = {}
    for line in text.splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        v = v.strip()
        if v.isdigit():
            data[k.strip()] = int(v)
        else:
            data[k.strip()] = v
    return data


def project_url(cfg: dict[str, Any]) -> str:
    base = "orgs" if cfg.get("type") == "org" else "users"
    return f"https://github.com/{base}/{cfg['owner']}/projects/{cfg['number']}"


def field_list(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    out = run(
        [
            "gh",
            "project",
            "field-list",
            str(cfg["number"]),
            "--owner",
            cfg["owner"],
            "--format",
            "json",
            "--limit",
            "100",
        ]
    )
    return json.loads(out.stdout)["fields"]


def find_status_field(cfg: dict[str, Any]) -> dict[str, Any]:
    fields = field_list(cfg)
    for f in fields:
        if f.get("name") == "Status" and f.get("type") == "ProjectV2SingleSelectField":
            return f
    sys.exit("error: Status field not found on the project")


def item_list(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    out = run(
        [
            "gh",
            "project",
            "item-list",
            str(cfg["number"]),
            "--owner",
            cfg["owner"],
            "--format",
            "json",
            "--limit",
            "200",
        ]
    )
    return json.loads(out.stdout)["items"]


def find_item_by_issue(cfg: dict[str, Any], issue_number: str) -> dict[str, Any] | None:
    """Locate a project item by its linked Issue number."""
    target = str(issue_number).lstrip("#")
    for item in item_list(cfg):
        content = item.get("content", {})
        # gh project item-list returns content.number for linked issues
        if str(content.get("number", "")) == target:
            return item
    return None


def cmd_setup(args: argparse.Namespace) -> None:
    """Create a new Project v2 and initialize Status field options."""
    owner = args.owner
    proj_type = "org" if args.org else "user"

    if CONFIG_PATH.exists():
        print(f"note: {CONFIG_PATH} already exists. skipping project creation.")
        cfg = read_config()
    else:
        print(f"creating Project '{args.title}' under {proj_type} {owner}...")
        out = run(
            [
                "gh",
                "project",
                "create",
                "--owner",
                owner,
                "--title",
                args.title,
                "--format",
                "json",
            ]
        )
        proj = json.loads(out.stdout)
        cfg = {"number": proj["number"], "owner": owner, "type": proj_type}
        write_config(cfg)
        print(f"✓ project created: {project_url(cfg)}")

    # Ensure Status field has all columns
    status_field = find_status_field(cfg)
    existing_options = {opt["name"] for opt in status_field.get("options", [])}
    missing = [s for s in STATUS_COLUMNS if s not in existing_options]

    if missing:
        print(f"adding Status options: {missing}")
        # gh project field-edit via GraphQL
        field_id = status_field["id"]
        # Keep existing options and add missing ones
        all_options = list(status_field.get("options", []))
        for name in missing:
            all_options.append({"name": name, "color": "GRAY", "description": ""})
        # Build mutation
        options_arg = json.dumps(
            [{"name": o["name"], "color": o.get("color", "GRAY").upper(),
              "description": o.get("description", "")} for o in all_options]
        )
        graphql = (
            'mutation($fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]!) { '
            'updateProjectV2Field(input: {fieldId: $fieldId, singleSelectOptions: $options}) '
            '{ projectV2Field { ... on ProjectV2SingleSelectField { options { id name } } } } }'
        )
        run(
            [
                "gh",
                "api",
                "graphql",
                "-f",
                f"query={graphql}",
                "-F",
                f"fieldId={field_id}",
                "-f",
                f"options={options_arg}",
            ]
        )
        print("✓ Status options synced")
    else:
        print("✓ Status field already has all columns")

    print(f"\nproject: {project_url(cfg)}")


def cmd_add(args: argparse.Namespace) -> None:
    """Add an existing Issue to the Project."""
    cfg = read_config()
    # Resolve issue URL
    if args.issue.startswith("http"):
        issue_url = args.issue
    else:
        num = args.issue.lstrip("#")
        # Use current repo
        out = run(["gh", "repo", "view", "--json", "url", "-q", ".url"])
        repo_url = out.stdout.strip()
        issue_url = f"{repo_url}/issues/{num}"
    run(
        [
            "gh",
            "project",
            "item-add",
            str(cfg["number"]),
            "--owner",
            cfg["owner"],
            "--url",
            issue_url,
        ]
    )
    print(f"✓ added {issue_url} to {project_url(cfg)}")


def cmd_move(args: argparse.Namespace) -> None:
    """Change the Status field of an Issue's project item."""
    cfg = read_config()
    issue_num = str(args.issue).lstrip("#")

    # Resolve status
    if args.status in STATE_TO_STATUS:
        # User passed a state machine name
        status_name = STATE_TO_STATUS[args.status]
    elif args.status in STATUS_COLUMNS:
        status_name = args.status
    else:
        sys.exit(
            f"error: status {args.status!r} is neither a state name nor a column. "
            f"columns: {STATUS_COLUMNS}. states: {list(STATE_TO_STATUS)}"
        )

    item = find_item_by_issue(cfg, issue_num)
    if item is None:
        sys.exit(
            f"error: Issue #{issue_num} not found in project. "
            f"add it first with `project-sync.py add --issue {issue_num}`"
        )

    status_field = find_status_field(cfg)
    option = next(
        (o for o in status_field.get("options", []) if o["name"] == status_name),
        None,
    )
    if option is None:
        sys.exit(
            f"error: Status option {status_name!r} not found. "
            f"run `project-sync.py setup` to ensure all columns exist."
        )

    # project-id via query
    out = run(
        [
            "gh",
            "api",
            "graphql",
            "-f",
            'query={user(login: "' + cfg["owner"] + '") '
            '{projectV2(number: ' + str(cfg["number"]) + ') {id}}}',
        ],
        check=False,
    )
    # Try org if user failed or returned null
    payload = json.loads(out.stdout) if out.stdout else {}
    proj_node = (payload.get("data") or {}).get("user") or {}
    proj_id = (proj_node.get("projectV2") or {}).get("id")
    if proj_id is None:
        out = run(
            [
                "gh",
                "api",
                "graphql",
                "-f",
                'query={organization(login: "' + cfg["owner"] + '") '
                '{projectV2(number: ' + str(cfg["number"]) + ') {id}}}',
            ]
        )
        payload = json.loads(out.stdout)
        proj_id = payload["data"]["organization"]["projectV2"]["id"]

    run(
        [
            "gh",
            "project",
            "item-edit",
            "--id",
            item["id"],
            "--project-id",
            proj_id,
            "--field-id",
            status_field["id"],
            "--single-select-option-id",
            option["id"],
        ]
    )
    print(f"✓ Issue #{issue_num} → {status_name}")


def cmd_list(args: argparse.Namespace) -> None:
    cfg = read_config()
    items = item_list(cfg)
    if not items:
        print("(no items)")
        return
    status_field = find_status_field(cfg)
    field_name = "Status"
    print(f"{'issue':<8} {'title':<50} {'status':<15}")
    for item in items:
        content = item.get("content", {})
        title = content.get("title", "")
        number = content.get("number", "")
        status = "—"
        for fv in item.get("fieldValues", {}).get("nodes", []):
            if fv.get("field", {}).get("name") == field_name:
                status = fv.get("name", "—")
                break
        issue = f"#{number}" if number else "—"
        print(f"{issue:<8} {title[:48]:<50} {status:<15}")


def cmd_state_to_status(args: argparse.Namespace) -> None:
    state = args.state.upper()
    if state not in STATE_TO_STATUS:
        sys.exit(f"error: unknown state {state!r}. known: {list(STATE_TO_STATUS)}")
    print(STATE_TO_STATUS[state])


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="project-sync")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("setup")
    s.add_argument("--title", required=True)
    s.add_argument("--owner", required=True)
    s.add_argument("--org", action="store_true", help="treat owner as org (default: user)")
    s.set_defaults(func=cmd_setup)

    a = sub.add_parser("add")
    a.add_argument("--issue", required=True, help="issue number (e.g. 42) or URL")
    a.set_defaults(func=cmd_add)

    m = sub.add_parser("move")
    m.add_argument("--issue", required=True, help="issue number (e.g. 42)")
    m.add_argument(
        "--status",
        required=True,
        help=f"column name ({STATUS_COLUMNS}) or state name ({list(STATE_TO_STATUS)})",
    )
    m.set_defaults(func=cmd_move)

    ls = sub.add_parser("list")
    ls.set_defaults(func=cmd_list)

    st = sub.add_parser("state-to-status")
    st.add_argument("state")
    st.set_defaults(func=cmd_state_to_status)

    return p


def main() -> None:
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
