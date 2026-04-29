---
description: observer を起動して直近 PASSED Issue の学習を抽出・蓄積する。
---

observer subagent を Agent tool で起動してください (model: haiku)。

起動時の指示:

1. `skills/instinct-loop/SKILL.md` を読む
2. `bin/controller.py list --state PASSED` で直近の PASSED Issue を特定 (複数可)
3. 各 Issue について以下を読む:
   - `.ai/work/<N>/state.json` (state スナップショット)
   - `.ai/work/<N>/qa.json` (構造化判定: scores, bugs, tdd_verified)
   - `.ai/work/<N>/progress.jsonl` (全イベント時系列)
   - `.ai/work/<N>/contract.json` (契約)
   - `.ai/work/<N>/handoff.md` (generator 引き継ぎ)
   - `docs/feedback/issue-<N>.md` (実装レビュー散文)
   - `docs/feedback/issue-<N>-contract.md` (契約レビュー散文、あれば)
   - `.claude/agent-memory/generator/MEMORY.md`
   - `.claude/agent-memory/evaluator/MEMORY.md`
4. 4 カテゴリ (Generator 盲点 / Evaluator 見落とし / 成功パターン / プロセスパターン) でパターン抽出
5. `bin/instinct-cli.py create / observe / reject` を使って `.harness/instincts/` に保存 (YAML 直接編集禁止)
6. 新規・更新・高 confidence の件数を 1-3 行で親に報告

**cross-project の書き込み禁止**。`~/.claude/instincts/` や他プロジェクトの `.harness/` には書かない (hook が block する)。
