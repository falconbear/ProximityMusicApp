---
name: tdd-enforcement
description: TDD (RED-GREEN-REFACTOR) を pipeline 骨格として強制するスキル。Generator は failing test を先に書いて commit してから実装する。Evaluator は git log で TDD 順序を検証し、違反を即 NEEDS_FIX とする。契約の Success criteria より優先される最重要ルール。
---

# tdd-enforcement — TDD 強制プロトコル

## なぜ必要か

契約 (Contract First) は「何を満たせば Done か」を定義するが、**その Done を満たすコードがどう書かれたか**は保証しない。TDD を骨格化することで:

1. テストが**実装前**に存在することを保証 (後付けテストが無効化されるリスクを物理的に排除)
2. 契約の Test plan と実装テストの対応が明示される
3. Evaluator は「実装が通るテスト」ではなく「先に書かれ、後で通ったテスト」を見れる → 品質の客観的担保

## 状態機械拡張 (PIPELINE.md §3 参照)

従来:
```
CONTRACT_APPROVED → IN_PROGRESS → READY_FOR_REVIEW
```

TDD 強制版:
```
CONTRACT_APPROVED
  → IN_PROGRESS_RED    (failing test を書いて commit)
  → IN_PROGRESS_GREEN  (実装を書いて test が通る)
  → READY_FOR_REVIEW
```

## Generator の遵守事項

### Phase 3.1: RED (failing test commit)

Generator は `CONTRACT_APPROVED` を受けたら**実装コードを一行も書かずに**以下を実施:

1. 契約の `**Test plan (for evaluator):**` を読む
2. 各 Test plan 項目に 1:1 対応する自動テストを書く
   - Unit test / Integration test / E2E test のレベルは契約の性質に合わせて選択
   - フレームワーク: jest / vitest / pytest / cargo test / go test など言語慣例
3. テストを実行して**実際に失敗することを確認** (RED)
4. commit:
   ```bash
   git add <test files>
   git commit -m "sprint-<id>: RED - failing tests for <契約 Scope 要約>"
   ```
5. `bin/controller.py record-tdd --issue-id <id> --actor generator --phase red --commit-sha $(git rev-parse HEAD)` で `IN_PROGRESS_RED` に遷移

**許容例外**: 既存のテストランナー環境が無い場合 (Issue 01 の初期セットアップ時のみ)、最初に test runner 導入コミットを含めてよい。ただし**その直後に RED commit が必要**。

### Phase 3.2: GREEN (最小実装)

1. 書いた failing test を通すために**最小限のコード**を実装
2. **YAGNI**: テストで要求されていない機能は実装しない (契約外のことをやらない)
3. テストが全て通ることを確認 (GREEN)
4. commit:
   ```bash
   git add <implementation files>
   git commit -m "sprint-<id>: GREEN - implement to satisfy contract"
   ```
5. `bin/controller.py record-tdd --issue-id <id> --actor generator --phase green --commit-sha $(git rev-parse HEAD)` で `IN_PROGRESS_GREEN` に遷移

### Phase 3.3: REFACTOR (任意)

テストが通ったまま改善可能なら実施。commit:
```bash
git commit -m "sprint-<id>: REFACTOR - <改善内容>"
```

### Phase 3.4: READY_FOR_REVIEW

`.ai/work/<id>/handoff.md` を埋めて (起動方法、自己評価、技術判断、既知の課題)、`bin/controller.py submit-impl --issue-id <id> --actor generator` で `READY_FOR_REVIEW` に遷移。

Evaluator は `state.json.tdd.{red,green}_commit_sha` と git log を突き合わせて TDD 順序を検証する。

## Evaluator の検証プロトコル

実装モード (READY_FOR_REVIEW) の**最初のステップ**として TDD 検証を実施:

### Step 1: git log で RED commit を特定

```bash
# 対象 Issue に関連するコミットを抽出 (state.json.tdd.{red,green}_commit_sha と照合)
git log --oneline --all | grep -i "sprint-<id>"
# または
git log --oneline HEAD~10..HEAD
```

以下を確認:

| チェック | 期待 | 違反時の判定 |
|---|---|---|
| RED commit (`"RED"` or `"failing tests"`) が存在するか | YES | NO → **即 NEEDS_FIX** (Critical, TDD 違反) |
| RED commit が GREEN commit より**時系列で先**か | YES | NO → **即 NEEDS_FIX** (後付けテスト疑惑) |
| RED commit の diff に test ファイルのみが含まれるか | YES | NO → 警告 (test と impl が混在、TDD 順序疑わしい) |
| GREEN commit で test が追加・削除されていないか | YES (impl のみ) | NO → `test-integrity` 違反の疑い |

### Step 2: 実際に RED commit の時点でテストが失敗するか

```bash
# RED commit をチェックアウトして実行
git checkout <RED commit sha>
./init.sh  # または適切なセットアップ
<test command>  # 期待: 失敗
git checkout -  # 元のブランチに戻る
```

RED commit でテストが通っていたら、それは**既に実装が存在していた** = TDD 偽装。違反として NEEDS_FIX。

**注**: 上記の手動チェックアウトは重いので、実務では以下の簡易チェックで代用可:
- RED commit の diff に実装ファイル (test 以外) が含まれていないこと
- commit メッセージに "RED" / "failing test" が含まれること
- 次の commit (GREEN) で test が追加/変更されずに実装だけが追加されていること

### Step 3: 違反時の feedback

`docs/feedback/issue-<id>.md` の**最優先項目**として記録:

```markdown
## 🚫 CRITICAL: TDD 違反 (tdd-enforcement skill)

**違反内容:** <具体的な違反 — 例: "RED commit が存在しない。実装 commit に test と impl が同時に追加されている">
**違反 commit:** <SHA>
**Diff の抜粋:**
\`\`\`diff
<問題の diff>
\`\`\`

**契約の Success criteria より優先される違反のため即 NEEDS_FIX。**

**修正指示:**
1. 現在のブランチを reset (または revert) して、Sprint 開始点に戻る
2. 契約の Test plan から failing test を先に書いて commit
3. その後で実装を別 commit として追加
4. 再度 READY_FOR_REVIEW に遷移する
```

## 例外と緩和

### 完全に test が書けない場合

一部の成果物 (例: UI の視覚的デザイン、Playwright の探索的操作) は事前 test が書きにくい。その場合:

- 契約の `**Test plan:**` に **明示的に** 「視覚検証のみ (TDD 対象外)」と書く
- Evaluator は当該項目を TDD 検証の対象から外す
- ただし**契約にこの記載が無ければ TDD 必須**

### テストランナーを持たないプロジェクト

Sprint 01 で init.sh + テストランナーをセットアップする際は:
- Commit 1: `sprint-01: setup test runner` (runner + 空のテスト)
- Commit 2: `sprint-01: RED - failing tests for <Sprint 01 Scope>`
- Commit 3: `sprint-01: GREEN - implement to satisfy contract`

この 3 commit 体制を許容する。

### プロジェクト固有の緩和

プロジェクトの CLAUDE.md で明示的に許可された場合のみ、1 commit で test + impl が同時に追加されることを許容する。

条件:
- commit message に `[TDD: test-first]` と明示する
- diff を逆順に展開したときに、test のみの状態でテストが失敗することを Evaluator がローカル検証する
- これが確認できない場合は通常の RED/GREEN 分離に戻す

オプトインしない場合 (デフォルト) は RED/GREEN を必ず別 commit に分ける。

## Generator と Evaluator の責任分担

| 責任 | Generator | Evaluator |
|---|---|---|
| failing test を書く | ○ | ✗ |
| RED commit を作る | ○ | ✗ |
| 実装を書く | ○ | ✗ |
| GREEN commit を作る | ○ | ✗ |
| TDD 順序を検証する | ✗ | ○ |
| 違反を検知して NEEDS_FIX | ✗ | ○ |
| 契約の Test plan を作る | ○ (Phase 1 契約起草時) | ✗ (契約モードで審査のみ) |

## 参照

- `docs/PIPELINE.md` §3 (状態機械), §5 (ファイル所有権)
- `skills/contract-first/` (契約の Test plan フィールド)
- `skills/test-integrity/` (既存テスト改変禁止 — tdd-enforcement と姉妹スキル)
- `~/.claude/skills/tdd-workflow/` (RED-GREEN-REFACTOR の技法詳細)
