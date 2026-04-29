# Issue #<id> 契約レビュー結果

**判定:** ✅ 承認 (CONTRACT_APPROVED) / ❌ 拒否 (→ PLANNED で revise) / 🚫 BLOCKED
**レビュー日:** YYYY-MM-DD
**Contract attempts:** X/3

## 7 観点チェック

<!-- 詳細は skills/contract-first/ 参照。全項目 PASS で承認 -->

| # | 観点 | 判定 | 根拠 |
|---|---|---|---|
| 1 | Scope の明確性 (scope_clarity) | PASS / FAIL | <1 行> |
| 2 | Out of scope の明示性 (out_of_scope_explicit) | PASS / FAIL | <1 行> |
| 3 | Success criteria の測定可能性 (success_measurable) | PASS / FAIL | <1 行> |
| 4 | Test plan の実行可能性 (test_plan_executable) | PASS / FAIL | <1 行> |
| 5 | Coverage (criteria が test plan に全網羅) | PASS / FAIL | <1 行> |
| 6 | spec.md との整合性 (spec_aligned) | PASS / FAIL | <1 行> |
| 7 | 他 Issue との整合性 (prior_sprint_aligned) | PASS / FAIL | <1 行> |

これらは `.ai/work/<id>/qa.json` の `contract_review.seven_point` にも記録する。

## 備考 (承認時)
- <契約の良かった点、リスクのヒント>

## 拒否理由と改善指示 (拒否時)

### 問題 1: <観点番号>
- **何が問題か:** <具体的記述>
- **なぜ問題か:** <観点の合格条件に照らした説明>
- **どう書き直すか:** <具体例または書き直し案>
- **参照すべき箇所:** <docs/spec.md の該当セクション>

### 問題 2: ...

## Generator への指示 (拒否時)

次のラウンドで以下を修正:
1. <具体的アクション 1>
2. <具体的アクション 2>
