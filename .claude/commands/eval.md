---
description: evaluator を起動して契約または実装を敵対的に検証する。state に応じて 2 モード自動切替。
---

evaluator subagent を Agent tool で起動してください。

起動時の指示:

1. `docs/PIPELINE.md` を読む
2. `bin/controller.py list` で対象 Issue を特定:
   - `CONTRACT_REVIEW` → 契約モード (7 観点審査、Playwright 起動しない)
   - `READY_FOR_REVIEW` → 実装モード (3 層検証 + TDD 順序検証)
   - 両方ある場合は契約モード優先 (軽量なので先に消化)
3. `bin/controller.py read --issue-id <N>` で対象 Issue の state を取得
4. `.ai/work/<N>/contract.json` (契約モード) または `handoff.md` + 実装コード (実装モード) を読む
5. `.harness/instincts/evaluator/*.yaml` の confidence >= 0.7 を参照
6. 審査結果は以下の 2 形式で出力:
   - **構造化**: `.ai/work/<N>/qa.json` (schemas/qa.schema.json 準拠)
   - **散文**: `docs/feedback/issue-<N>.md` または `docs/feedback/issue-<N>-contract.md`
7. 状態遷移は必ず `bin/controller.py` 経由:
   - 契約承認: `approve-contract --issue-id <N> --actor evaluator --feedback-ref <md path>`
   - 契約拒否: `reject-contract --issue-id <N> --actor evaluator --feedback-ref <md path>` (3/3 到達なら controller が自動 BLOCKED)
   - 実装合格: `pass --issue-id <N> --actor evaluator --qa-ref .ai/work/<N>/qa.json --feedback-ref <md path>`
   - 実装不合格: `needs-fix --issue-id <N> --actor evaluator --qa-ref ... --feedback-ref ...` (5/5 到達なら controller が自動 BLOCKED)
8. 審査完了後、判定と指摘件数を親に報告

**Guilty until proven innocent**。Generator の `handoff.md` の自己評価は鵜呑みにしない。迷ったら拒否。
