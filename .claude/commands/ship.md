---
description: PASSED した Issue を PR 化する。初 PASSED なら Draft PR 作成、以降は更新、全 Issue PASSED なら Ready 昇格。
---

親 Claude (=あなた自身) が `skills/github-publishing/` に従って直接 gh CLI を実行してください。

判定ロジック:

1. `bin/controller.py list` で全 Issue の状態を確認
2. 各 Issue の `pr_number` フィールド (`bin/controller.py read --issue-id <N> --field pr_number`) で PR の有無を確認
3. 3 モードを選択:
   - **create-draft**: 初の PASSED Issue でまだ PR が無い場合 → Draft PR 作成 → `bin/controller.py set-pr --issue-id <N> --pr-number <PR>` で記録
   - **update**: PR が既にあり、新規 PASSED または NEEDS_FIX が発生した場合 → PR 本文更新 + PR コメント
   - **ready**: 関連する全 Issue が PASSED → Draft → Ready 昇格 + Issue close
4. 実行後、PR URL と状態変化を 1 行で報告

**subagent dispatch は不要**。親 Claude が直接 `gh` コマンドを実行する。

テンプレ:
- PR 本文: `templates/pr-body.md`

PR 本文に記載すべき情報:
- 含まれる Issue 一覧 (`bin/controller.py list` から)
- 各 Issue の qa.json から scores と bugs を要約
- 動作確認方法 (handoff.md から)
- Closes #<N> でリンク (マージ時に GitHub が自動 close)
