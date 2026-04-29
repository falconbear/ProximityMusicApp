---
description: generator を起動して契約起草・TDD 実装・修正を実行する。現在の Issue 状態に応じてフェーズを自動判定。
---

generator subagent を Agent tool で起動してください。

起動時の指示:

1. `docs/PIPELINE.md` と `docs/spec.md` を読む
2. `bin/controller.py list` で全 Issue の状態を確認、最若番の未完 Issue を特定
3. `bin/controller.py read --issue-id <N>` で対象 Issue の詳細を取得
4. フェーズ判定 (agents/generator.md §フェーズ判定):
   - `NEEDS_FIX` → Phase 4 (修正)
   - `CONTRACT_APPROVED` → Phase 3 Step 3.1 (RED)
   - `IN_PROGRESS_RED` → Phase 3 Step 3.2 (GREEN)
   - `IN_PROGRESS_GREEN` → Phase 3 Step 3.4 (handoff.md + submit-impl)
   - `PLANNED` かつ contract_attempts > 0 → Phase 2 (契約修正)
   - `PLANNED` かつ contract_attempts = 0 → Phase 1 (契約起草)
5. `.harness/instincts/generator/*.yaml` の confidence >= 0.7 を参照
6. 状態遷移は必ず `bin/controller.py` 経由で行う:
   - Phase 1/2 完了: `submit-contract --issue-id <N> --actor generator`
   - Phase 3 RED: `record-tdd --issue-id <N> --actor generator --phase red --commit-sha <sha>`
   - Phase 3 GREEN: `record-tdd --issue-id <N> --actor generator --phase green --commit-sha <sha>`
   - Phase 3.4: `submit-impl --issue-id <N> --actor generator`
   - Phase 4 完了: `submit-impl --issue-id <N> --actor generator`
7. フェーズ完了後、状態遷移と次フェーズへの申し送りを親に報告

**既存テスト改変禁止**、**TDD 順序厳守**、**承認済み契約の書き換え禁止** (hook が block する)。
