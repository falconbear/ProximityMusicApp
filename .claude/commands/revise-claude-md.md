---
description: claude-md-improver skill を起動し、プロジェクトの全 CLAUDE.md を監査して quality report を出し、承認を経て最小限の更新を適用する。
---

`claude-md-improver` skill に従って以下を実行してください。

## Phase 1: Discovery

```bash
find . -name "CLAUDE.md" -o -name ".claude.md" -o -name ".claude.local.md" 2>/dev/null | head -50
```

## Phase 2: Quality Assessment

各 CLAUDE.md を以下の 6 基準で評価:

| 基準 | 重み | 確認 |
|---|---|---|
| Commands/workflows | High | build / test / deploy コマンド |
| Architecture clarity | High | コードベース構造の理解 |
| Non-obvious patterns | Medium | gotcha と癖の記載 |
| Conciseness | Medium | 冗長な説明や自明な情報なし |
| Currency | High | 現在のコードベース状態を反映 |
| Actionability | High | 実行可能な指示 (vague でない) |

スコア帯:
- A (90-100): 包括的・最新・実行可能
- B (70-89): 良好、軽微なギャップ
- C (50-69): 基本情報のみ、重要セクション欠落
- D (30-49): 疎または古い
- F (0-29): 欠如または深刻に古い

## Phase 3: Quality Report

**更新前に必ずレポートを出す**。ユーザーに承認を得てから Phase 4 に進む。

## Phase 4: Targeted Updates

承認後、最小限の targeted addition だけを適用:

- コマンド / ワークフローで見つかった実行可能な追加事項
- コードから見つかった gotcha / 非自明パターン
- 明確でなかったパッケージ間の関係
- 効いているテスト手法
- 設定の癖

**避けるもの**:
- コードから自明な内容の再記述
- 既にカバーされた汎用ベストプラクティス
- 再発しそうにない 1 回限りの修正
- 1 行で済むのに冗長な説明

## Phase 5: Apply Updates

Edit tool で既存構造を保ったまま適用。

## 出力フォーマット

```
## CLAUDE.md Quality Report

### Summary
- Files found: X
- Average score: X/100
- Files needing update: X

### File-by-File Assessment

#### 1. ./CLAUDE.md (Project Root)
**Score: XX/100 (Grade: X)**

| Criterion | Score | Notes |
|---|---|---|
| Commands/workflows | X/20 | ... |
| Architecture clarity | X/20 | ... |
| Non-obvious patterns | X/15 | ... |
| Conciseness | X/15 | ... |
| Currency | X/15 | ... |
| Actionability | X/15 | ... |

**Issues**:
- <具体的な問題>

**Recommended additions**:
- <追加すべき内容>
```

詳細な基準とテンプレートは `skills/claude-md-improver/references/` 参照。
