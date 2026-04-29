---
description: planner を起動して docs/spec.md を起草・更新し、GitHub Issue + .ai/work/<id>/ を作成する。
---

planner subagent を Agent tool で起動してください。

起動時の指示:

1. `docs/PIPELINE.md` を読む
2. `<project>/CLAUDE.md` を読む
3. `bin/controller.py list` で既存 Issue の状態を確認
4. ユーザーのアイデア (会話文脈またはプロジェクト README) を起点に `docs/spec.md` を作成・更新
5. `skills/spec-authoring/` に従い、機能を Issue 単位に分割 (size constraints 準拠)
6. 各 Issue を GitHub に登録 (`gh issue create`、`templates/sprint-issue.md` 準拠)
7. 取得した Issue 番号で `bin/controller.py init --issue-id <N> --title "<title>" --branch "sprint/<N>-<slug>"` を実行
8. Issue 01 (初番) には init.sh 作成を含める
9. 完了後、作成 Issue 数・重要な判断・スコープ外事項を 3-5 行で親に報告

**HOW には踏み込まない**。フレームワーク選定・実装詳細・DB スキーマは書かない。
