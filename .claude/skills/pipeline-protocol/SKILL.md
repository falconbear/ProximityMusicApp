---
name: pipeline-protocol
description: claude-harness-dev の骨格 (PIPELINE.md) を運用に落とすスキル。状態機械の遷移ルール、`bin/controller.py` 経由の状態更新、`.ai/work/<id>/` のファイル所有権の enforcement を全エージェント共通で扱う。どのロールを担うエージェントもこのスキルを最初に読む。
---

# pipeline-protocol — 骨格運用ガイド

`docs/PIPELINE.md` を参照して動く全エージェントの共通スキル。本スキルは PIPELINE.md の抽象契約を**具体的な書き方**に落とす。

## 起動時のチェックリスト

どのフェーズで呼ばれたかに関わらず、以下を最初に確認する:

```bash
pwd                                         # 作業ディレクトリ確認
test -f docs/PIPELINE.md || echo "FATAL: PIPELINE.md missing"
test -f docs/spec.md || echo "WARN: spec.md missing (planner 未実行?)"
python3 bin/controller.py list || echo "WARN: no .ai/work/ initialized"
git branch --show-current                   # ブランチ確認
git status --porcelain                      # 汚染確認
```

- `docs/PIPELINE.md` が無ければ**即停止** — ハーネスが展開されていない
- `main` / `master` 上にいるなら、feature / sprint ブランチに切り替える (hook で push が block される)
- `.ai/work/` に Issue が無ければ planner を起動 (新規プロジェクト)

## 状態機械の更新ルール (controller 経由)

**`.ai/work/<id>/state.json` は `bin/controller.py` のみが書き込む**。エージェントは以下の CLI を呼ぶ:

| 現在状態 | 駆動エージェント | 次状態 | controller コマンド |
|---|---|---|---|
| `PLANNED` | generator (Phase 1 / 2) | `CONTRACT_REVIEW` | `submit-contract --issue-id <N> --actor generator` |
| `CONTRACT_REVIEW` | evaluator (契約モード) | `CONTRACT_APPROVED` | `approve-contract --issue-id <N> --actor evaluator` |
| `CONTRACT_REVIEW` | evaluator (契約モード) | `PLANNED` (拒否) | `reject-contract --issue-id <N> --actor evaluator` |
| `CONTRACT_APPROVED` | generator (Phase 3.1 RED) | `IN_PROGRESS_RED` | `record-tdd --phase red --commit-sha <sha>` |
| `IN_PROGRESS_RED` | generator (Phase 3.2 GREEN) | `IN_PROGRESS_GREEN` | `record-tdd --phase green --commit-sha <sha>` |
| `IN_PROGRESS_GREEN` | generator (Phase 3.3 完成) | `READY_FOR_REVIEW` | `submit-impl --issue-id <N> --actor generator` |
| `READY_FOR_REVIEW` | evaluator (実装モード) | `PASSED` | `pass --issue-id <N> --actor evaluator` |
| `READY_FOR_REVIEW` | evaluator (実装モード) | `NEEDS_FIX` | `needs-fix --issue-id <N> --actor evaluator` |
| `NEEDS_FIX` | generator (Phase 4 修正) | `READY_FOR_REVIEW` | `submit-impl --issue-id <N> --actor generator` |
| 任意 (escape hatch) | 誰でも | `BLOCKED` | `block --issue-id <N> --reason <reason>` |
| `BLOCKED` | human | `PLANNED` 等 | `unblock --issue-id <N> --to <state>` |

リトライ予算は controller が自動管理 (`contract_attempts` 上限 3 / `attempts` 上限 5)。上限到達時に reject / needs-fix を出すと `BLOCKED` に自動遷移する。

**直接 `state.json` を編集しない**。validate-state.py が schema 違反を検出する。

## ファイル所有権の遵守

`docs/PIPELINE.md §6` の表に従う。違反を発見したら:

1. 書き込みは行わない (自分の所有外は触らない)
2. `docs/spec-issues.md` に違反の事実を記録
3. 親エージェントに 1 行で報告して停止

| 領域 | 書ける人 |
|---|---|
| `state.json` / `progress.jsonl` | `bin/controller.py` のみ |
| `contract.json` | generator (PLANNED / CONTRACT_REVIEW のみ、それ以外は hook で block) |
| `qa.json` | evaluator |
| `handoff.md` | generator |
| `docs/feedback/issue-<id>.md` | evaluator (実装モード) |
| `docs/feedback/issue-<id>-contract.md` | evaluator (契約モード) |
| `docs/spec.md` | planner のみ |
| `docs/spec-issues.md` | generator |
| 実装コード | generator |
| 既存テスト | 不可 (hook が block) |
| `.harness/instincts/` | observer のみ |

## Issue 選択順 (generator / evaluator 共通)

最若 `issue_id` から以下の優先順:

1. `NEEDS_FIX` (修正フェーズ、generator Phase 4)
2. `IN_PROGRESS_GREEN` (handoff.md + submit-impl、generator Phase 3.4)
3. `IN_PROGRESS_RED` (GREEN 実装、generator Phase 3.2)
4. `CONTRACT_APPROVED` (RED 着手、generator Phase 3.1)
5. `READY_FOR_REVIEW` (実装レビュー、evaluator 実装モード)
6. `CONTRACT_REVIEW` (契約審査、evaluator 契約モード)
7. `PLANNED` かつ `contract_attempts > 0` (契約修正、generator Phase 2)
8. `PLANNED` かつ `contract_attempts = 0` (新規契約起草、generator Phase 1)

1 呼び出しで**1 Issue の 1 フェーズのみ**を処理する。複数フェーズを 1 度にやらない。

## エラーハンドリング

| 事象 | 対応 |
|---|---|
| `validate-state.py` が schema 違反を報告 | 親に通知、自分は触らない (controller 経由で修正) |
| `controller.py` が exit 2 で拒否 (無効遷移 / 予算超過) | 親に報告して停止 |
| `docs/spec.md` と `.ai/work/` の Issue 数が不一致 | 親に報告。spec を正とする (planner が再分割) |
| 前提ファイル欠落 (`init.sh`, `docs/PIPELINE.md`, `bin/controller.py`) | 報告して停止。修復は独断で行わない |

## scaling: 大量 Issue の運用

JSON ベースなので `docs/progress.md` のような肥大化問題は無い。各 Issue は `.ai/work/<id>/` に閉じており、新規 Issue を増やしても既存ディレクトリのサイズに影響しない。

PASSED した Issue を archived に移したい場合は git の履歴で十分 (`git log -- .ai/work/<id>/`)。実体ファイルは残しておけば検索性が良い。

## 参照

- `docs/PIPELINE.md` §4 (状態機械), §5 (リトライ予算), §6 (ファイル所有権), §7 (エスカレーション)
- `schemas/state.schema.json` / `contract.schema.json` / `qa.schema.json` / `event.schema.json`
- `bin/controller.py` (状態遷移の唯一の書き手)
- `bin/validate-state.py` (スキーマ検証)
