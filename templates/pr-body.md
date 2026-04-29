<!-- 親 Claude (github-publishing skill) が先頭に 1 行のステータスヘッダを差し込む: -->
<!-- - 🚧 In Progress — 進行中 -->
<!-- - ⚠ BLOCKED — Issue #N — BLOCKED 発生中 -->
<!-- - ⏸ Paused — cycle limit reached — 一時停止 -->
<!-- - ✅ Ready for review — 最終版 -->

**Status:** _(親 Claude が設定)_

## 概要

<!-- docs/spec.md の「概要」をそのまま引用 -->

## 含まれる Issue

| # | タイトル | 状態 | Attempts | 契約適合 | 回帰 | 主要な判断 |
|---|----------|------|----------|----------|------|------------|
| <id> | <タイトル> | PASSED | 1/5 | 5/5 | 5/5 | <判断の要約> |
| <id> | <タイトル> | PASSED | 2/5 | 4/5 | 5/5 | <判断の要約> |

<!-- bin/controller.py list の出力 + .ai/work/<id>/qa.json から集計 -->

## 変更ハイライト

<!-- 実装の主要ポイントを 3〜5 個。ファイル名ではなく「何が達成されたか」を書く -->
-
-
-

## Evaluator レビュー結果

<!-- docs/feedback/issue-<id>.md の要約。詳細は各 Issue の PR コメント参照 -->

### 合格時の主要コメント
-

### 途中 NEEDS_FIX になった項目と対処
-

## 動作確認方法

<!-- 最新 PASSED Issue の handoff.md の「起動方法」を転記 -->

```
# コマンド例
./init.sh
```

- URL: <URL>
- 前提条件: <あれば>

## 既知の課題 / スコープ外

<!-- handoff.md の「既知の課題」+ docs/spec.md の「制約事項」を集約 -->
-

## 関連 Issue

<!-- 例: Closes #1, Closes #2 — マージ時に GitHub が自動 close -->

---

🤖 このPRは Planner / Generator / Evaluator / Observer パイプラインにより自動生成されました。
