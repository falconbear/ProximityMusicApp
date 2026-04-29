---
description: 現在のパイプライン状態を一覧表示。各 Issue の state、attempts、PR 情報、Instinct 統計。
---

以下を順に実行して、人間が読める形式で報告してください。

1. `python3 bin/controller.py list` で全 Issue の state テーブルを取得
2. 各 Issue について `bin/controller.py read --issue-id <N> --field pr_number` で PR 番号を確認
3. `python3 bin/instinct-cli.py list --min-confidence 0.5` で高信頼 Instinct を表示
4. 次のアクション候補 (どの subagent を動かすべきか) を 1 行で提案

判断基準は CLAUDE.md の「ディスパッチ判断表」を参照。

**subagent dispatch は不要**。親 Claude が直接読む。
