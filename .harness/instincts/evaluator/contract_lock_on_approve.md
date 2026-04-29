---
id: contract_lock_on_approve
role: evaluator
project_scope: ProximityMusicApp
confidence: 0.9
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [1]
---

# 契約承認時に contract.json の locked=true を必ず確認する

## Pattern

`approve-contract` 実行後、`bin/validate-state.py --strict` で
`contract.json: must have locked=true when state=...` エラーが出ないか確認する。
旧 controller.py (~2026-04-30 修正前) は state を CONTRACT_APPROVED に遷移させる
だけで contract.json の `locked` フィールドを true に更新しないバグがあり、CI の
`state-validate` が後段の任意の state (PASSED 含む) で fail していた。

## Why

- `schemas/contract.schema.json` で `locked` は契約承認後の不変性を表す flag。
- `bin/validate-state.py` の `contract_p.exists()` 分岐は state ∉ {PLANNED,
  CONTRACT_REVIEW} で `locked=true` を要求する。
- harness の controller.py を修正 (2026-04-30) して `cmd_approve_contract` 内で
  `_lock_contract` を呼ぶようにし、専用の `lock-contract` backfill コマンドも
  追加した。新規 Issue では自動で lock されるが、過去 Issue の contract には
  retroactive な backfill が必要。

## How to apply

1. 契約承認 (`approve-contract`) 実行後、`python3 bin/validate-state.py --strict`
   をローカルで実行して 0 error を確認。
2. 万一エラーが出たら `bin/controller.py lock-contract --issue-id <N>` で backfill。
3. CI 上で `state-validate` workflow が同じ schema をチェックしているので、最低
   ここを通すまで PR を ready にしない。
