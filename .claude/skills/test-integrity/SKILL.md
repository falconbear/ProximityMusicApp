---
name: test-integrity
description: 既存テストの改変禁止ルールと diff 監視手法。generator は既存テストを削除・skip・緩和してはならず、evaluator は毎回の評価時にテストファイルの diff をチェックする。違反検知は契約の Success criteria より優先される最重要ルール。
---

# test-integrity — テスト整合性プロトコル

## なぜ必要か

evaluator の合否基準を欺くために、generator がテストを無効化してしまうリスクを機械的に封じる。契約で定めた Success criteria は**生きたテスト**で検証されてこそ意味がある。

## generator への制約 (絶対禁止)

以下は**すべて契約違反**。発覚したら即 NEEDS_FIX (契約の Success criteria より優先される):

- 既存テストファイルの削除
- 既存テストの `.skip` / `.only` / `.todo` 追加
- 既存アサーションの緩和 (例: `toBe(5)` → `toBeGreaterThan(0)`)
- 既存テストのコメントアウト
- 既存テストの意味改変 (入力・期待値の変更、mock への置き換え)

### 許可される操作

- **新規テストの追加** (generator が自分で書いた失敗テストの調整も可)
- **テストユーティリティの拡張** (既存の assertion ヘルパを増やす等)
- **明らかに壊れたフィクスチャの修復** — ただし spec-issues.md に記録し、evaluator が確認できる状態にする

### 例外: 契約内で明示されている場合

契約の `### 契約` 内で「Sprint X で追加した test-foo.spec.ts を削除/置換する」と明文化されていれば許可。暗黙的な整理は禁止。

## evaluator の diff 監視手法

評価開始時、以下のコマンドで**テストファイルの変更を必ず確認**:

```bash
# 主要フレームワーク共通で拾えるパターン
git diff --name-only HEAD~1 HEAD -- \
  'test/**' 'tests/**' \
  '**/*.test.*' '**/*.spec.*' \
  '**/__tests__/**' \
  'e2e/**' 'cypress/**' 'playwright/**'
```

変更が検出されたら、内容を精査:

```bash
git diff HEAD~1 HEAD -- <上記で出たファイル>
```

### 違反判定フローチャート

```
テストファイルに変更あり?
├── No  → OK (通常の評価へ)
└── Yes
    ├── 新規追加のみ? → OK
    ├── 追加 + 拡張のみ? → OK
    ├── .skip / .only / .todo が増えた? → 違反 (即 NEEDS_FIX)
    ├── test/it/describe ブロックが削除された? → 違反
    ├── expect(...).toXxx が弱くなった? → 違反
    ├── 既存アサーションの期待値が変わった? → 違反
    └── 契約内で明示的に許可されている? → OK
```

## evaluator の違反通知

違反を検知したら:

1. `docs/feedback/issue-<id>.md` に以下を**最優先項目**として記録:

```markdown
## 🚫 CRITICAL: テスト整合性違反 (test-integrity skill)

**違反内容:** <具体的な改変 — 例: `tests/user.test.ts` の 15 行目に `.skip` が追加された>
**違反した行:** 
```diff
- it('should reject empty email', () => {
+ it.skip('should reject empty email', () => {
```

**契約の Success criteria より優先される違反のため即 NEEDS_FIX とする。**

**修正指示:**
1. 該当の改変を元に戻す
2. 契約の Success criteria が失敗するなら、実装側を直す (テストを直すのではない)
```

2. `bin/controller.py needs-fix --issue-id <id> --actor evaluator` で状態を `NEEDS_FIX` に
3. PR コメント (`github-publishing` skill) でも明示

## 参照

- `docs/PIPELINE.md` §1 (ネガティブプロンプト), §5 (ファイル所有権)
- `skills/skeptical-evaluation/` (原則 6: テストコードの diff 監視)
- `skills/contract-first/` (契約に明示すれば例外可)
