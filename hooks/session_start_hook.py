#!/usr/bin/env python3
"""
session_start_hook.py — SessionStart

Inject a project snapshot at session start so parent Claude knows the current
location without manual file reads.

Injected:
  1. Current branch + latest commit
  2. Active issues table (from .ai/work/<id>/state.json)
  3. High-confidence instincts (≥0.7) — max 10
  4. Project config hint (.harness/project.yaml)

All data comes from state.json (canonical). No regex-parsed markdown.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def repo_root() -> Path:
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env).resolve()
    return Path.cwd().resolve()


def run(cmd: List[str], timeout: int = 3) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=str(repo_root()))
        return out.stdout.strip()
    except Exception:
        return ""


def get_branch_and_commit() -> Tuple[str, str]:
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    commit = run(["git", "log", "-1", "--oneline"])
    return branch, commit


def load_all_states() -> List[Dict]:
    base = repo_root() / ".ai" / "work"
    if not base.exists():
        return []
    out = []
    for d in sorted(base.iterdir(), key=lambda p: int(p.name) if p.name.isdigit() else 0):
        if not d.is_dir():
            continue
        sp = d / "state.json"
        if not sp.exists():
            continue
        try:
            out.append(json.loads(sp.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError):
            continue
    return out


def get_high_confidence_instincts() -> List[Tuple[str, str, float]]:
    base = repo_root() / ".harness" / "instincts"
    if not base.exists():
        return []
    results: List[Tuple[str, str, float]] = []
    for agent_dir in base.iterdir():
        if not agent_dir.is_dir():
            continue
        for yaml_file in agent_dir.glob("*.yaml"):
            try:
                text = yaml_file.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            conf_m = re.search(r"^confidence:\s*([\d.]+)", text, re.MULTILINE)
            id_m = re.search(r"^id:\s*(\S+)", text, re.MULTILINE)
            if conf_m and id_m:
                try:
                    conf = float(conf_m.group(1))
                except ValueError:
                    continue
                if conf >= 0.7:
                    results.append((agent_dir.name, id_m.group(1), conf))
    results.sort(key=lambda r: -r[2])
    return results[:10]


def read_initial_brief(root: Path) -> Optional[str]:
    p = root / ".ai" / "initial-brief.md"
    if not p.exists():
        return None
    try:
        return p.read_text(encoding="utf-8")
    except OSError:
        return None


def main() -> int:
    root = repo_root()
    project_yaml = root / ".harness" / "project.yaml"

    lines: List[str] = ["# project state snapshot", ""]

    branch, commit = get_branch_and_commit()
    if branch:
        lines.append(f"**Branch:** `{branch}`")
    if commit:
        lines.append(f"**Last commit:** {commit}")

    states = load_all_states()

    # --- fresh-project session 検出 ---
    # 条件: harness 展開済み (.claude/agents/ 存在) + brief 不在 or 空 + Issues ゼロ
    agents_dir = root / ".claude" / "agents"
    brief = read_initial_brief(root)
    is_fresh = (
        agents_dir.exists()
        and (brief is None or not brief.strip())
        and not states
    )

    if is_fresh:
        lines.append("")
        lines.append("---")
        lines.append("")
        lines.append("🆕 **新規プロジェクト session を検出しました**")
        lines.append("")
        lines.append("ハーネスは展開済み、まだプロジェクトの中身は決まっていません。")
        lines.append("ユーザーが何かを入力する前に、以下を**自分から**話しかけて要件定義 dialogue を始めてください:")
        lines.append("")
        lines.append("> こんにちは。新しいプロジェクトの session ですね。")
        lines.append("> 何を作りたいですか? ざっくりで大丈夫です — 一緒に詰めていきましょう。")
        lines.append("")
        lines.append("**詰めるべき項目** (3-5 ターンで):")
        lines.append("- 作るもの (1-2 文サマリ)")
        lines.append("- コア機能 3-5 個")
        lines.append("- 言語 / プラットフォーム (任意、generator 判断でも可)")
        lines.append("- out of scope (明示的にやらないこと)")
        lines.append("- repo 名 (kebab-case 推奨)")
        lines.append("")
        lines.append("**合意できたら**: `commands/newproject.md` の手順を Bash + Write で**直接実行** (slash コマンドで叩かせない):")
        lines.append("1. `.ai/initial-brief.md` 書き込み")
        lines.append("2. `git add -A && git commit -m \"initial brief: <repo-name>\"`")
        lines.append("3. `gh repo create <repo-name> --private --source=. --push`")
        lines.append("4. `/auto` を続けて発火")
        lines.append("")
        lines.append("詳細フローは `CLAUDE.md` の「新規プロジェクト session の挙動」節参照。")
        lines.append("")
        lines.append("---")
        lines.append("")
    elif brief and not states:
        # Brief 存在 + Issues ゼロ → 即 /auto OK の状態 (旧フロー互換)
        brief_preview = "\n".join(brief.splitlines()[:30])
        lines.append("")
        lines.append("---")
        lines.append("")
        lines.append("⚡ **Initial brief detected + no Issues yet.** 以下のアイデアで自律開発を開始できます:")
        lines.append("")
        lines.append("```")
        lines.append(brief_preview)
        lines.append("```")
        lines.append("")
        lines.append("**次のアクション:** `/auto` を実行すると planner が起動して Issue を分解 → 自律ループが回り、PR まで到達します。")
        lines.append("")
        lines.append("---")
        lines.append("")
    active = [
        s for s in states
        if s.get("current_state") not in ("PASSED",)  # PASSED is done, don't clutter
    ]
    if active:
        lines.append("")
        lines.append("**Active issues:**")
        lines.append("")
        lines.append("| # | State | ATT | CON | PR | Title |")
        lines.append("|---|---|---|---|---|---|")
        for s in active[-15:]:
            pr = f"#{s['pr_number']}" if s.get("pr_number") else "—"
            lines.append(
                f"| {s['issue_id']} | {s['current_state']} | {s['attempts']}/5 | "
                f"{s['contract_attempts']}/3 | {pr} | {s.get('title','')[:40]} |"
            )

    done = [s for s in states if s.get("current_state") == "PASSED"]
    if done:
        lines.append("")
        lines.append(f"**Done:** {len(done)} issue(s) PASSED — "
                     f"{', '.join('#' + s['issue_id'] for s in done[-10:])}")

    if project_yaml.exists():
        lines.append("")
        lines.append("**Project config:** `.harness/project.yaml` present (sync via `bin/project-sync.py`)")

    insts = get_high_confidence_instincts()
    if insts:
        lines.append("")
        lines.append("**High-confidence instincts (≥0.7):**")
        for agent, iid, conf in insts:
            lines.append(f"- {agent}/{iid} ({conf:.2f})")
        lines.append("")
        lines.append("Read full body via `python3 bin/instinct-cli.py show --id <id>` if relevant.")

    if len(lines) <= 2:
        return 0  # nothing useful to share

    sys.stdout.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
