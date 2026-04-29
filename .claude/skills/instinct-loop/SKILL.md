---
name: instinct-loop
description: Observer agent の学習ループ実装。Sprint 完了後に MEMORY.md と feedback からパターンを抽出し、project-scoped な `.harness/instincts/` に YAML として保存する。信頼度スコア更新ルールと cross-project 境界を定義する。
user-invocable: false
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# instinct-loop — Project-Scoped Learning Loop

Observer agent が使う学習ループの実装手順。Generator と Evaluator が蓄積した MEMORY.md と feedback から Instinct を抽出し、`.harness/instincts/` 配下に YAML として保存する。

## 境界線 (重要)

- **保存先**: `<project>/.harness/instincts/` のみ
- **cross-project への書き込み禁止**: `~/.claude/instincts/` や他プロジェクトの `.harness/` は触らない
- **自動昇格なし**: Instinct は project-scoped のまま。別プロジェクトで使いたければユーザーが手動でコピーする
- **理由**: 「チーム混成の弊害」回避。プロジェクトごとの文脈を尊重する

## ディレクトリ構造

```
<project>/.harness/
└── instincts/
    ├── generator/
    │   └── <id>.yaml
    ├── evaluator/
    │   └── <id>.yaml
    └── planner/
        └── <id>.yaml
```

## Instinct YAML スキーマ

```yaml
---
id: <kebab-case-identifier>          # 一意識別子
trigger: "<発火条件>"                  # 日本語 1-2 文
confidence: 0.3                       # 0.1 - 0.9
domain: <code-quality|testing|architecture|ux|performance|security|process>
source: <evaluator-feedback|generator-memory|sprint-analysis|session-observation>
agent: <generator|evaluator|planner>  # 学ぶべきエージェント
observation_count: 1
created: <ISO-8601 date>
last_observed: <ISO-8601 date>
sprints: [5]                          # 観測された Sprint 番号
---

# <Instinct のタイトル>

## Action
<このパターンに遭遇したときに取るべき行動>

## Evidence
- Sprint 05: <観測事実>

## Anti-Pattern
<やってはいけないことの例 (あれば)>
```

## 抽出ワークフロー

### Step 1: 情報収集

以下を全て読む:

```bash
bin/controller.py list                        # 全 Issue の現在状態
.ai/work/<id>/state.json                      # 各 Issue の最終状態
.ai/work/<id>/qa.json                         # 構造化判定 (scores, bugs, tdd_verified)
.ai/work/<id>/contract.json                   # 承認された契約
.ai/work/<id>/progress.jsonl                  # 全イベント時系列
.ai/work/<id>/handoff.md                      # generator 引き継ぎ
docs/feedback/issue-<id>.md                   # 実装レビュー散文
docs/feedback/issue-<id>-contract.md          # 契約レビュー散文
.claude/agent-memory/generator/MEMORY.md
.claude/agent-memory/evaluator/MEMORY.md
.harness/instincts/**/*.yaml                  # 既存 Instinct (重複検知)
```

`progress.jsonl` には reject / approve / TDD commit の時系列が完全に残っているので、「contract が 2 回 reject されてから approve された」「RED commit から GREEN commit までの時間」など機械的な事実が拾える。

### Step 2: 4 カテゴリのパターン抽出

#### A. Generator の盲点 (Evaluator → Generator Instinct)

Evaluator が NEEDS_FIX で指摘したバグの**種類**を拾う。単発のバグではなく、再発しそうなパターンを探す。

例:
- 非同期処理のレースコンディション
- エラーハンドリングの欠如
- 境界値の未考慮 (空配列、null、max int)
- マルチバイト文字・絵文字の扱い

#### B. Evaluator の見落とし (Generator → Evaluator Instinct)

Generator の `[SUCCESS]` / `[FAILURE]` タグのうち、Evaluator が PASSED を出した後に発覚したリグレッションの原因。

#### C. 成功パターン

1 回で PASSED した Sprint の共通点:
- 契約 Scope が小さい
- Test plan が具体的
- テスト先行が厳守された

#### D. プロセスパターン (Planner Instinct)

- Sprint 粒度の最適サイズ
- 依存関係の扱い方
- Out of scope の設定方法

### Step 3: Instinct の作成 / 更新

`bin/instinct-cli.py` を使う。直接 YAML を編集しない。

```bash
# 新規作成 (既存 id があれば observe として扱う)
python bin/instinct-cli.py create \
  --agent generator \
  --id avoid-async-state-race \
  --trigger "非同期処理で state を更新するとき" \
  --domain code-quality \
  --source evaluator-feedback \
  --sprint 05 \
  --action "関数形式の setState を使い、stale closure を避ける" \
  --evidence "Issue #05 で Evaluator が指摘した setState race"

# 既存 Instinct の観測カウント + confidence 増加
python bin/instinct-cli.py observe \
  --id avoid-async-state-race \
  --sprint 08 \
  --evidence "Issue #08 で同じパターンを Generator が回避 → PASSED"

# ユーザーが明示的に否定した場合
python bin/instinct-cli.py reject --id <id>
```

### Step 4: 信頼度更新ルール

CLI が自動適用:

```
新規作成:                  confidence = 0.3
2 回目の観測:              confidence = min(0.5, confidence + 0.15)
3 回目以降:                confidence = min(0.9, confidence + 0.1)
ユーザーが明示的に否定:    confidence = max(0.1, confidence - 0.3)
```

### Step 5: 報告

親エージェントに 1-3 行で報告:

```
observer: Issue #NN 学習完了
  - 新規: X 件 (gen: N, eval: M)
  - 更新: Y 件 (平均 confidence: 0.XX)
  - 高信頼 (>= 0.8): Z 件
```

## Generator / Evaluator からの Instinct 参照

Generator と Evaluator は起動時に自分の Instinct ディレクトリを読む:

```
.harness/instincts/generator/*.yaml (confidence 順)
```

**confidence >= 0.7 の Instinct は自動適用**すべき指針として context に取り込む。
**confidence 0.3 - 0.6 の Instinct は参考情報**として扱い、矛盾があれば判断を残す。

## 禁止事項

- `~/.claude/instincts/` への書き込み
- 他プロジェクトの `.harness/` への書き込み
- YAML の直接編集 (必ず CLI 経由)
- エビデンスなしで Instinct を作る (必ず観測事実と紐づける)
- 同じ観測を複数 Instinct に分割する (原子的、1 Instinct = 1 trigger + 1 action)
