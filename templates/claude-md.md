# <プロジェクト名> — Claude Code オーケストレーション

## プロジェクト概要

<1〜3 文でプロダクトの目的とターゲットユーザーを記述>

## ドメイン

ソフトウェア開発 (<スタック、例: Node.js / TypeScript / React>)

## 参照

- パイプライン契約: `docs/PIPELINE.md`
- プロジェクト仕様: `docs/spec.md`
- 状態機械: `bin/controller.py list` (canonical state は `.ai/work/<id>/state.json`)
- 仕様課題ログ: `docs/spec-issues.md`
- 評価フィードバック: `docs/feedback/issue-*.md`
- 学習ストレージ: `.harness/instincts/`

## エージェント編成

`.claude/agents/` に 4 エージェント:

- **Planner** (opus): `docs/spec.md` 起草 + GitHub Issue 起票 + `controller.py init` (WHAT/WHY)
- **Generator** (opus): 実装 (HOW 自律、Contract First、TDD 強制、テスト改変禁止)
- **Evaluator** (opus): 2 モード自動切替 — 契約モード (7 観点審査) / 実装モード (3 層検証 + TDD 順序検証)
- **Observer** (haiku): PASSED 後に Instinct 抽出 (`.harness/instincts/` に YAML)

親エージェント (セッション本体) が唯一のディスパッチャ。エージェント同士は直接呼ばない。PR 操作 (Draft 作成 / 更新 / Ready 昇格) は親 Claude が `github-publishing` skill に従って直接 `gh` コマンドを実行する。

## 入口の正規化

- ユーザーがチャットで依頼 → 親 Claude が planner に渡す → Issue 起票 + `.ai/work/<id>/` 初期化
- **チャット内容を即実装しない**。必ず Issue + `contract.json` に正規化してから着手

## 語彙

- 作業単位: **Issue** (GitHub Issue 番号 = `.ai/work/<id>/` のディレクトリ名)
- 成果物: 機能 (feature)
- 検証: <プロジェクトに応じて。例: 型チェック + 単体テスト + E2E + CI>

## 状態機械

`docs/PIPELINE.md §4` 参照:

```
PLANNED → CONTRACT_REVIEW → CONTRACT_APPROVED
       → IN_PROGRESS_RED → IN_PROGRESS_GREEN → READY_FOR_REVIEW
       → PASSED (成功) / NEEDS_FIX (差し戻し) / BLOCKED (上限到達)
```

状態遷移は `bin/controller.py` 経由のみ。`.ai/work/<id>/state.json` を直接編集しない。

## プロジェクト固有の禁則事項

- `docs/spec.md` の本文は **planner のみ** が書き換える
- `.ai/work/<id>/state.json` / `progress.jsonl` は `bin/controller.py` のみが書く
- `.ai/work/<id>/contract.json` は generator が起草、CONTRACT_APPROVED 後は hook で block
- 既存テストは generator が改変してはならない (`test-integrity` skill + hook)
- `rm -rf /` / 強制 push / 本番データベースへの破壊的操作は禁止
- ブランチは `feature/spec-<slug>` または `sprint/<id>-<slug>` で切り、`main` への直接 push は禁止 (hook で block)

## 品質基準

<プロジェクト固有の品質基準>

- <Web / iOS / Android で主要フローが動作する>
- <既存のインタフェース契約を壊さない>
- <型チェックとリンタがエラーなく通る>

## プロジェクト固有のスキル注入

`.claude/agents/*.md` の frontmatter `skills:` で追加注入:

- Generator に: `<例: react-native-patterns, supabase-patterns>`
- Evaluator に: `<例: evaluator-web / evaluator-mobile / evaluator-code を 1 つ、UI プロジェクトなら ui-design-quality も>`

ハーネスの基本スキル (pipeline-protocol, contract-first, tdd-enforcement, skeptical-evaluation, test-integrity, initializer-protocol, github-publishing, context-strategy, spec-authoring, instinct-loop) は agents/ 側で既に宣言済み。

## 記憶の運用

- `.claude/agent-memory/<agent-name>/MEMORY.md` に各エージェントが learnings を蓄積 (subagent frontmatter の `memory: project` 指定により自動生成)
- 成功・失敗の両方を記録し、古い知見は `archived/` に退避
- PASSED 後に observer が MEMORY.md + `.ai/work/<id>/qa.json` + `progress.jsonl` + `docs/feedback/` からパターン抽出 → `.harness/instincts/<agent>/<id>.yaml` として保存 (project-scoped、cross-project 自動昇格なし)

## エフェメラルコンテナ運用 (推奨)

Issue 単位の作業は Docker コンテナで実施:

```bash
docker compose run --rm sprint
```

コンテナには `.harness/` と `.ai/` が volume mount されているので Instinct と作業ディレクトリは永続化される。コンテナ自体は完了で破棄。
