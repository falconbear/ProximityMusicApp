# PIPELINE.md — claude-harness-dev 骨格契約 (Source of Truth)

状態機械・責任境界・リトライ予算・エスカレーションを規定。agent / skill の記述と矛盾があれば**本ファイル優先**。技術的手続きは `skills/` 配下に分離。

## §0 パス規約

- ルートは相対パス (`docs/spec.md`)
- 作業 dir は Issue スコープ: `.ai/work/<issue-id>/` (1 Issue = 1 branch = 1 Draft PR)
- プロジェクト固有パス (`expo/`, `web/` 等) は CLAUDE.md に書く

## §1 MD と JSON の分担

- **JSON = 状態 / 構造化データ** (機械が canonical source として読み書き)
- **MD = 指示 / 散文 / rationale** (AI が読んで従う)

| 用途 | 形式 | 例 |
|---|---|---|
| 状態 / 契約 / QA / イベントログ | JSON / JSONL | `state.json` / `contract.json` / `qa.json` / `progress.jsonl` |
| 引き継ぎ / レビュー / 仕様 / AI 指示 | MD | `handoff.md` / `docs/feedback/` / `docs/spec.md` / CLAUDE.md |

## §2 エージェントと責任境界

| エージェント | 責任 | 触らないもの |
|---|---|---|
| **planner** | ユーザー意図 → `docs/spec.md` + Issue + `controller.py init` | 実装、技術選定、`contract.json` / `qa.json` |
| **generator** | `contract.json` 起草、TDD 実装、修正 | `docs/spec.md`、既存テスト、承認済み契約、`state.json` 直接編集 |
| **evaluator** | 契約モード = 7 観点審査 / 実装モード = 3 層検証 + TDD 順序 | 実装、契約本文、`docs/spec.md`、`state.json` 直接編集 |
| **observer** | progress.jsonl / feedback から Instinct 抽出 → `.harness/instincts/` | コード、契約、spec、state、feedback |
| **controller** (`bin/controller.py`) | `state.json` 書き込み、`progress.jsonl` append | 契約 / 実装 / spec / feedback |

PR 操作は親 Claude が `skills/github-publishing/` で直接実行 (Bash + gh CLI)。

### ネガティブプロンプト (絶対禁止)

- planner は HOW に踏み込まない
- generator は spec.md を編集しない (疑義は `docs/spec-issues.md`)、既存テストを無効化しない、TDD 順序を破らない
- evaluator は実装・承認済み契約を書き換えない、契約モードで Playwright を起動しない
- generator / evaluator / observer は `state.json` を直接編集しない (`controller.py` 経由)
- observer は実行パイプラインに介入しない
- 親 Claude は generator / evaluator の領域を侵さない

## §3 作業ディレクトリ `.ai/work/<issue-id>/`

```
state.json      # controller.py 単独 (state.schema.json)
contract.json   # generator、CONTRACT_APPROVED 後不変 (contract.schema.json)
qa.json         # evaluator (qa.schema.json)
progress.jsonl  # controller.py append-only (event.schema.json)
handoff.md      # generator (READY_FOR_REVIEW 時)
```

```
docs/feedback/issue-<id>.md            # evaluator 実装モード
docs/feedback/issue-<id>-contract.md   # evaluator 契約モード
```

`issue-id` は GitHub Issue 番号と 1:1。新規作成は `bin/controller.py init`。

## §4 状態機械

```
PLANNED → CONTRACT_REVIEW → CONTRACT_APPROVED
       → IN_PROGRESS_RED → IN_PROGRESS_GREEN → READY_FOR_REVIEW
       → PASSED / NEEDS_FIX (Phase 4 修正) / BLOCKED (上限到達)
```

`BLOCKED` は人間が `controller.py unblock` で解除。自動復帰なし。

### 遷移テーブル (`bin/controller.py` がハードコード)

| 遷移 | コマンド | アクター |
|---|---|---|
| `PLANNED → CONTRACT_REVIEW` | `submit-contract` | generator |
| `CONTRACT_REVIEW → CONTRACT_APPROVED` | `approve-contract` | evaluator |
| `CONTRACT_REVIEW → PLANNED` | `reject-contract` (attempts<3) | evaluator |
| `CONTRACT_REVIEW → BLOCKED` | `reject-contract` (attempts=3) | evaluator |
| `CONTRACT_APPROVED → IN_PROGRESS_RED` | `record-tdd --phase red` | generator |
| `IN_PROGRESS_RED → IN_PROGRESS_GREEN` | `record-tdd --phase green` | generator |
| `IN_PROGRESS_GREEN → READY_FOR_REVIEW` | `submit-impl` | generator |
| `NEEDS_FIX → READY_FOR_REVIEW` | `submit-impl` | generator |
| `READY_FOR_REVIEW → PASSED` | `pass` | evaluator |
| `READY_FOR_REVIEW → NEEDS_FIX` | `needs-fix` (attempts<5) | evaluator |
| `READY_FOR_REVIEW → BLOCKED` | `needs-fix` (attempts=5) | evaluator |
| `NEEDS_FIX → BLOCKED` | `block` | evaluator |
| `BLOCKED → {PLANNED,CONTRACT_REVIEW,READY_FOR_REVIEW,NEEDS_FIX}` | `unblock --to <state>` | human |

無効遷移は exit 2 で拒否。

## §5 リトライ予算

| 予算 | 上限 | カウント |
|---|---|---|
| `contract_attempts` | 3 | `submit-contract` ごとに +1 |
| `attempts` | 5 | `submit-impl` ごとに +1 (NEEDS_FIX 由来は NEEDS_FIX 時点で +1) |

上限到達で controller が自動 `BLOCKED` + `blocked_reason` (`contract_attempts_exhausted` / `impl_attempts_exhausted`)。

### BLOCKED 解除

人間判断: (1) `docs/spec.md` 修正 + planner 再起動 / (2) `unblock --to PLANNED` で Phase 1 仕切り直し / (3) Issue close。

## §6 ファイル所有権

| ファイル | 書き込み可 | 役割 |
|---|---|---|
| `docs/spec.md` | planner | 仕様本体 |
| `docs/spec-issues.md` | generator | 仕様疑義ログ |
| `.ai/work/<id>/state.json` | **`controller.py` のみ** | 状態機械 canonical |
| `.ai/work/<id>/contract.json` | generator (承認後 hook で block) | 契約本文 |
| `.ai/work/<id>/qa.json` | evaluator | 判定 |
| `.ai/work/<id>/progress.jsonl` | **`controller.py` append-only** | イベントログ |
| `.ai/work/<id>/handoff.md` | generator | 引き継ぎ |
| `docs/feedback/issue-<id>.md` | evaluator (実装) | 実装レビュー |
| `docs/feedback/issue-<id>-contract.md` | evaluator (契約) | 契約レビュー |
| 実装コード | generator | 成果物 |
| 既存テスト | **不可** (hook で block) | test-integrity |
| 新規テスト (TDD RED) | generator | tdd-enforcement |
| `.harness/instincts/**/*.yaml` | observer | Instinct |

読み取りは全員可。交差書き込みは契約違反 → 即停止して親に報告。

## §7 エスカレーションと停止条件

以下発生で**無条件停止 + 親へ報告**:

1. `controller.py` exit 2 (無効遷移 / 予算超過)
2. `docs/spec.md` 不在で planner 以外が呼ばれた
3. `PIPELINE.md` 不在 / スキーマ破損
4. `git status` 汚染等の環境破損
5. generator が既存テスト改変 (hook / diff 監視で発覚)
6. 親の明示指示 (`STOP`)

停止時情報は `docs/spec-issues.md` か親への 1 行報告。独断回復禁止。

## §8 Skill Manifest

| 実行者 | スキル |
|---|---|
| planner | pipeline-protocol, spec-authoring |
| generator | pipeline-protocol, contract-first, tdd-enforcement, test-integrity, initializer-protocol |
| evaluator | pipeline-protocol, contract-first, skeptical-evaluation, tdd-enforcement, test-integrity, initializer-protocol + ターゲット別 1 つ |
| observer | instinct-loop |
| 親 Claude | pipeline-protocol, github-publishing, context-strategy |

**汎用**: `pipeline-protocol` (状態機械・所有権) / `spec-authoring` / `contract-first` / `tdd-enforcement` / `skeptical-evaluation` (9 原則・5 基準) / `test-integrity` / `initializer-protocol` (`init.sh` 冪等性) / `github-publishing` (PR ライフサイクル) / `context-strategy` (compaction) / `instinct-loop`

**ターゲット別 (evaluator 1 つ)**: `evaluator-web` (Playwright) / `evaluator-mobile` / `evaluator-code` (API / CLI / lib)

**実装支援**: `systematic-debugging` (4 フェーズ根本原因追及) / `frontend-design`

**メタ (必要時)**: `skill-creator` / `claude-md-improver`

**advisory**: `ui-design-quality` (合否に影響しない)

## §9 学習の境界

Instinct は **project-scoped**、`.harness/instincts/<role>/<id>.yaml` (git 管理)。cross-project 自動昇格なし、必要なら手動コピー。理由: チーム混成の弊害回避。詳細は `skills/instinct-loop/SKILL.md`。

## §10 機械的強制 (hooks)

skill = AI 判断ベースの "ソフト指針"、hook = ツール呼び出しを機械的に block / warn する強制層。

| イベント | hook | 役割 |
|---|---|---|
| SessionStart | `session_start_hook.py` | branch / Issue state / PR / 高 confidence Instinct 注入 |
| PreToolUse Edit/Write | `security_reminder_hook.py` | セキュリティパターン警告 |
| PreToolUse Edit/Write | `test_integrity_hook.py` | 既存テストへの `.skip/.only/.todo` 追加・削除を block |
| PreToolUse Edit/Write | `contract_immutability_hook.py` | 承認後 `contract.json` 編集を block |
| PreToolUse Edit/Write | `instinct_scope_hook.py` | `~/.claude/instincts/` / 他プロジェクト `.harness/` 書き込み block |
| PreToolUse Bash | `git_safety_hook.py` | `main`/`master` push、`--force`、`--no-verify` を block |
| PreToolUse Bash | `tdd_order_hook.py` | GREEN commit に対応する RED が無ければ警告 |
| PostToolUse Edit/Write | `bin/validate-state.py` | `.ai/work/*/*.json` schema 検証 |
| PostToolUse Edit/Write | `sprint_state_hook.py` | state 更新時に次アクション注入 |

設計原則: block と warn の区別 (契約違反級は exit 2、判断要は exit 0 + stderr) / 判断要は hook 化しない / opt-in 尊重 (`[TDD: test-first]` で bypass)。

## §11 関連文書

- `CLAUDE.md` — 親 Claude entrypoint
- `README.md` — 人間向け概要
- `agents/*.md` — 各エージェント詳細契約
- `skills/*/SKILL.md` — 運用手続き
- `schemas/*.schema.json` — JSON Schema

本ファイルの改訂は骨格に影響するため慎重に。追加機能は skill / template に吸収する。
