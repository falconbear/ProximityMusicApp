# Issue #<id> 評価結果 (実装モード)

**判定:** PASSED / NEEDS_FIX / BLOCKED
**評価日:** YYYY-MM-DD
**評価対象:** Issue #<id> - <タイトル>
**Attempts:** X/5

## スコア

<!-- 閾値はプロジェクト側で調整可。デフォルトは skeptical-evaluation skill 参照 -->

| 基準 | スコア | 閾値 | 判定 |
|------|--------|------|------|
| 契約適合性 (contract_compliance) | X/5 | 4 | PASS/FAIL |
| 動作安定性 (operational_stability) | X/5 | 4 | PASS/FAIL |
| 品質 UX/可読性 (quality_ux) | X/5 | 3 | PASS/FAIL |
| エッジケース対応 (edge_cases) | X/5 | 3 | PASS/FAIL |
| 回帰なし (no_regressions) | X/5 | 5 | PASS/FAIL |

これらは `.ai/work/<id>/qa.json` の `implementation_review.scores` にも記録する。

## TDD 順序検証

- `state.tdd.red_commit_sha`: <sha> ✓ / null ✗
- RED commit に実装ファイル混入: あり / なし
- `state.tdd.green_commit_sha`: <sha> ✓ / null ✗
- GREEN 後にテスト全通過: yes / no

違反があれば `qa.json.implementation_review.tdd_verified = false` で記録。

## 契約ベーステスト結果

### 合格した項目
- <Success criterion 1>: 正常に動作 (根拠: <具体観測>)
- <Success criterion 2>: 正常に動作

### 不合格の項目
- <Success criterion N>: <具体的な問題>
  - **再現手順:** <操作手順>
  - **期待される動作:** <契約上の期待>
  - **実際の動作:** <観測結果>
  - **スクリーンショット/ログ:** <あれば>

## Adversarial findings (契約外の能動的検査)

- <境界値・Unicode・連打・競合状態などで見つけた問題>

## バグ一覧

| # | 重要度 | 内容 | 再現手順 |
|---|--------|------|----------|
| 1 | critical / major / minor | <内容> | <手順> |

これらは `qa.json.implementation_review.bugs` にも記録する。

## 改善提案 (契約外、合否には影響しない)
- <パフォーマンス、UX、コード品質に関する提案>

## Generator への指示
<!-- NEEDS_FIX の場合、Critical → Major → Minor の順で何を修正すべきかを具体的に書く -->
<!-- 「もっと良くして」のような抽象指摘は禁止 -->
