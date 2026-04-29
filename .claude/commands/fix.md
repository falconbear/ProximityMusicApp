---
description: NEEDS_FIX 状態の Issue を generator (Phase 4) に修正させる。`/implement` のエイリアスだが修正フェーズ専用。
---

generator subagent を Phase 4 (修正) モードで起動してください。

起動時の指示:

1. `docs/PIPELINE.md` を読む
2. `bin/controller.py list --state NEEDS_FIX` で対象 Issue を特定
3. `bin/controller.py read --issue-id <N>` で attempts を確認
4. `docs/feedback/issue-<N>.md` の指摘を全件読む (Critical → Major → Minor の順)
5. 指摘に沿って修正
6. `.ai/work/<N>/handoff.md` の「修正ログ」節に attempt N の対応内容を追記
7. `bin/controller.py submit-impl --issue-id <N> --actor generator` で `READY_FOR_REVIEW` に遷移
   (controller が attempts++、5/5 到達時は自動 BLOCKED)
8. 既存テストの整合性を崩さない、TDD 順序を破らない

完了後、修正項目数と次の状態を親に報告。
