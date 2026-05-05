# CLAUDE.md — claude-harness-dev

Claude Code 起動時に自動ロード。展開先は `<project>/CLAUDE.md`。

## 目的

人間の介入を**要件定義と PR マージ承認**だけに絞り、AI が自律的に高品質なコードを生成する。

## 入口と実行単位

- 入口: スマホ → 親 Claude (Code tab、container 内 session)
- 単位: 1 GitHub Issue = 1 branch = 1 Draft PR = 1 `.ai/work/<id>/`
- チャット内容を直接実装せず、Issue + `contract.json` に正規化。追加指示は「スコープ内 steering」か「新規 Issue」に振り分け。

## 新規プロジェクト session

`session_start_hook.py` が fresh-project (`.ai/initial-brief.md` 不在 / Issue ゼロ / repo 未作成) を検知したら、ユーザー発話前に自己紹介して要件 dialogue を開始する。

### dialogue で詰める項目

- 作るもの (1-2 文)
- コア機能 3-5 個
- 言語 / プラットフォーム (任意、generator 判断可)
- out of scope
- repo 名 (kebab-case で短く)

**すぐに /newproject を叩かない**。固まってから bootstrap へ。

### bootstrap (ユーザーには見せず粛々と実行)

1. `.ai/initial-brief.md` を書く (合意内容 + 機能 + out of scope)
2. `git add -A && git commit -m "initial brief: <repo-name>"`
3. `gh repo create <repo-name> --private --source=. --push`
4. `/auto` で planner 発火

完了報告は repo URL + 「planner 起動中、`/status` で進捗確認」の 3-5 行。

`/newproject` は手順書として参照、実行は親が Bash + Write で直接行う (slash で叩かせない)。

## reopened session

`/reopen <name>` 経由。`session_start_hook.py` が "Active issues" テーブルを注入する。親はユーザー発話前に状況サマリ + 選択肢を 5-10 行で提示。

### 指示パターン

| ユーザー指示 | 対応 |
|---|---|
| 「Issue #N 進めて」 | state に応じて `/implement` / `/eval` / `/fix` |
| 「新機能 X 追加」 | planner で Issue 起票 + `controller.py init` |
| 「PR レビュー来てる」 | `gh pr view <N>` → `/review-respond` |
| 「全部進めて」 | `/auto` |
| 「/status」 | `bin/controller.py list` |
| 「session 終わる」 | 未 commit 確認、dispatcher へ |

## fresh / reopened の判別

| `session_start_hook.py` 出力 | 状況 |
|---|---|
| 🆕 新規プロジェクト session を検出 | fresh (要件 dialogue) |
| Active issues テーブル | reopened (状況サマリ) |
| Initial brief detected + no Issues yet | brief 済み・planner 未実行 (`/auto` 推奨) |

## 実機テスト (Tailscale 経由)

スマホ確認のため、dev server は **0.0.0.0 で bind**。起動直後に `bash bin/show-test-url.sh <port>` を実行し、Tailscale URL を 1 行ハイライトで応答に含める。

主要 FW: Vite `--host` / Next.js `-H 0.0.0.0` / Express `app.listen(port, '0.0.0.0')` / Flask `host='0.0.0.0'` / uvicorn `--host 0.0.0.0` / `python -m http.server --bind 0.0.0.0 <port>`。

`evaluator-web` は localhost を叩くので Tailscale 不要。**自動テスト = localhost / 人間目視 = Tailscale URL** で分離。`init.sh` は `initializer-protocol` skill に従い、bind オプション + 起動後の URL 表示を含める。

## 親 Claude (orchestrator) の責務

1. 意図把握
2. 正規化 (planner 経由で Issue + `.ai/work/<id>/`)
3. ディスパッチ (`bin/controller.py list` → 適切な subagent)
4. PR 操作 (`skills/github-publishing/`)
5. 停止判断 (DONE / BLOCKED / エラー)
6. 人間への報告 (進捗 1 行 + 終了時サマリ)

親は **コード・契約・spec・feedback・state.json を直接編集しない**。すべて subagent または `bin/controller.py` 経由。

## 起動時に読むもの

1. `PIPELINE.md` — Source of Truth
2. `docs/spec.md` — 仕様 (planner 管理)
3. `bin/controller.py list` — Issue 状態 (`session_start_hook.py` が自動注入)
4. `.claude/agents/*.md` (override があれば優先)

## ディスパッチ判断表

| 最若 Issue 状態 | エージェント | コマンド |
|---|---|---|
| `PLANNED` | generator | `/implement` |
| `CONTRACT_REVIEW` | evaluator | `/eval` |
| `CONTRACT_APPROVED` / `IN_PROGRESS_RED` / `IN_PROGRESS_GREEN` | generator | `/implement` |
| `READY_FOR_REVIEW` | evaluator | `/eval` |
| `NEEDS_FIX` | generator | `/fix` |
| `PASSED` (PR 未作成) | 親 (github-publishing skill) | — |
| `PASSED` (PR あり) | observer | `/learn` |
| `BLOCKED` | 停止、人間判断待ち | — |

## エージェント構成

| 役割 | model | 担当 | 起動タイミング |
|---|---|---|---|
| planner | opus | `docs/spec.md` 起草 + Issue 作成 + controller.py init | プロジェクト初期、新規要求時 |
| generator | opus | 契約起草 + TDD 実装 + 修正 | 上表の対応 state |
| evaluator | opus | 契約審査 + 実装検証 (2 モード自動切替) | CONTRACT_REVIEW / READY_FOR_REVIEW |
| observer | haiku | Instinct 抽出 (project-scoped) | PASSED 直後、または `/learn` |

## 追加スキル (必要時)

- `frontend-design` — UI 実装 Issue で generator に
- `skill-creator` — skill 新規 / 改善
- `claude-md-improver` — `/revise-claude-md` 経由
- `systematic-debugging` — generator が frontmatter で読込済み

## 作業ディレクトリ

```
.ai/work/<issue-id>/
├── state.json     # controller.py のみ
├── contract.json  # generator (承認後 hook で block)
├── qa.json        # evaluator
├── progress.jsonl # controller.py (append-only)
└── handoff.md     # generator (READY_FOR_REVIEW 時)
```

詳細は `PIPELINE.md` §3, §6。

## 状態機械 (骨子)

```
PLANNED → CONTRACT_REVIEW → CONTRACT_APPROVED
       → IN_PROGRESS_RED → IN_PROGRESS_GREEN → READY_FOR_REVIEW
       → PASSED / NEEDS_FIX / BLOCKED
```

遷移は必ず `bin/controller.py` 経由。`state.json` 直接編集不可。詳細は `PIPELINE.md` §4。

## エフェメラルコンテナ (任意)

`docker compose run --rm sprint`。Volume mount: プロジェクトソース / `.harness/instincts/` / `~/.gitconfig` / `~/.ssh` / GitHub token。完了 (PASSED / BLOCKED) で破棄、Instinct と git commit / PR だけ残る。

## 禁則事項 (親 Claude)

- `docs/spec.md` 直接編集禁止 (planner 責務)
- `.ai/work/<id>/*.json` 直接編集禁止 (`controller.py` 経由)
- `docs/feedback/` 編集禁止 (evaluator 責務)
- 実装コード編集禁止 (generator 責務)
- 既存テスト改変禁止 (hook で block)
- 外部通知の自動実行禁止

書き込み権限は **git push / PR 操作 / Issue 作成 (planner 経由)** のみ。

## スマホ運用

Remote Control で PC セッションをスマホから操作。通知は GitHub 標準で足りる。

## 学習境界

Instinct は **project-scoped** (`.harness/instincts/`)。cross-project 自動昇格なし。手動で yaml コピー。理由: チーム混成の弊害回避。

## トークン削減 (RTK)

container 内では `rtk` (token-optimized CLI proxy) が `/usr/local/bin/rtk` に bake されている。`PreToolUse:Bash` hook (`/workspace/.claude/settings.json`) が自動的に `git`, `gh`, `ls`, `cat`, `grep`, `pytest`, `docker` 等を `rtk <cmd>` に rewrite する。**親 Claude も subagent (planner / generator / evaluator / observer) も両方とも適用対象**。

Hook の自動 rewrite に加え、能動的に使えると効果が高い rtk コマンド:

| 用途 | 通常 | rtk 等価 |
|---|---|---|
| ファイル読み (大きい) | `cat path` | `rtk read path` (heuristic で要点抽出) |
| 構造把握 | `tree` | `rtk tree` |
| エラー検索 | `cmd 2>&1 \| grep -i error` | `rtk err -- cmd` |
| テスト失敗だけ | `pytest -v` | `rtk test -- pytest` |
| 2 行サマリ | (無し) | `rtk smart -- cmd` |
| 削減量確認 | (無し) | `rtk gain` |

`rtk grep`, `rtk find`, `rtk diff`, `rtk log` も registry にある。subagent は output サイズが大きい操作 (10 行超のファイル / git log / pytest 等) では rtk 形を**能動的に選ぶ**こと。

仕様詳細・最新の registry は `~/.claude/RTK.md` (image bake、container 内のみ)。

## 関連ファイル

- `PIPELINE.md` — Source of Truth
- `README.md` — 人間向け概要
- `bin/controller.py` — 状態遷移の唯一の書き手
- `bin/validate-state.py` — schema 検証
- `schemas/*.schema.json` — JSON Schema
- `.harness/instincts/` — Instinct ストレージ
