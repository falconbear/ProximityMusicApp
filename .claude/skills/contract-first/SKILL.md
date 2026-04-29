---
name: contract-first
description: Contract First プロトコル。generator と evaluator (契約モード) が共有する契約の起草・審査・不変・再交渉ルール。Anthropic の sprint contract negotiation ベストプラクティスに準拠し、実装着手前に evaluator と合意する 7 観点審査を提供する。
---

# contract-first — 契約プロトコル

## コア原則

> *"the generator and evaluator negotiated a sprint contract: agreeing on what 'done' looked like for that chunk of work before any code was written"*
> — Anthropic, Harness Design for Long-Running Apps (March 2026)

実装前に**何が done か**を合意することで、実装後の手戻りコストを大幅に下げる。合意なきコードは書かない。

## 契約の保存場所

`.ai/work/<issue-id>/contract.json` (`schemas/contract.schema.json` 準拠)。MD ではなく **JSON で持つ理由**は機械検証可能性 + atomic update + 状態と一体管理するため。

## 契約の必須フィールド

| フィールド | 情報源 | 書き方 |
|---|---|---|
| `scope` | `docs/spec.md` の Scope | コピーして必要なら詳細化 (ただし spec 範囲内) |
| `out_of_scope` | `docs/spec.md` の Out of scope | コピー |
| `success_criteria` | `docs/spec.md` の受け入れ基準 | コピー。曖昧語を排除し binary 判定可能な形に |
| `test_plan` | generator が新規起草 | Playwright / API 呼び出しで実行可能な粒度の操作手順 + 期待結果 |

`status` / `locked` / `approved_at` / `approved_by` / `revision_history` は controller (経由のレビュー記録) または手動更新時に書き込む。

## Phase 1: 契約起草 (generator, PLANNED → CONTRACT_REVIEW)

新規 Issue で初めて契約を書くフェーズ。**コードは 1 行も書かない**。

1. `docs/spec.md` の該当節と GitHub Issue body を読む
2. `.ai/work/<id>/contract.json` を作成 (status="review", locked=false, revision_history に attempt 1 を追加)
3. `bin/controller.py submit-contract --issue-id <id> --actor generator` を実行
   - controller が `contract_attempts` を 1 に、`current_state` を `CONTRACT_REVIEW` に遷移
4. 終了 — evaluator (契約モード) が次に呼ばれる

## Phase 2: 契約修正 (generator, PLANNED + contract_attempts>0 → CONTRACT_REVIEW)

evaluator (契約モード) に拒否された場合。

1. `docs/feedback/issue-<id>-contract.md` を精読して拒否理由と改善指示を把握
2. `.ai/work/<id>/contract.json` を指示に従って書き直す。**元の契約を無条件に捨てない** — 指摘点のみ修正
3. `revision_history` に attempt N を追加 (`status: "drafted"`)
4. `bin/controller.py submit-contract --issue-id <id> --actor generator`
   - controller が `contract_attempts++` (3/3 で再拒否なら自動 BLOCKED)

## Phase 3: 契約審査 (evaluator (契約モード))

**契約段階で曖昧なものを通すと実装フェーズで必ず火を噴く**。疑わしきは拒否。

### 7 観点

全 7 つの PASS で承認。1 つでも FAIL で拒否。

| # | 観点 | qa.json key | 合格条件 | 不合格の典型例 |
|---|---|---|---|---|
| 1 | **Scope の明確性** | `scope_clarity` | 曖昧語なし、1 読で理解可能 | 「良い感じに」「適切に」「自然な」「必要に応じて」 |
| 2 | **Out of scope の明示性** | `out_of_scope_explicit` | やらないことが列挙 | "N/A"、空欄、抽象論 |
| 3 | **Success criteria の測定可能性** | `success_measurable` | 全項目が binary (yes/no) で判定可能 | 「使いやすい」「高速である」等の主観 |
| 4 | **Test plan の実行可能性** | `test_plan_executable` | Playwright / API / CLI で実行可能な粒度、期待結果あり | 「動作確認」のような曖昧手順 |
| 5 | **Coverage** | `coverage` | Test plan が Success criteria を 100% カバー | criteria 5 個に対し test plan 2 個 |
| 6 | **spec.md との整合性** | `spec_aligned` | 契約が planner の spec の範囲を超えていない | spec にない機能を Scope に追加 |
| 7 | **他 Issue との整合性** | `prior_sprint_aligned` | PASSED 済み Issue との依存関係に矛盾なし | 既に PASSED の機能を再実装 |

### 審査の振る舞い

- `.ai/work/<id>/qa.json` に構造化判定を書く (mode=contract、seven_point を埋める)
- `docs/feedback/issue-<id>-contract.md` に散文の理由を書く (雛形: `templates/contract-feedback.md`)
- 状態遷移は controller 経由:
  - 承認 → `bin/controller.py approve-contract --issue-id <id> --actor evaluator --feedback-ref docs/feedback/issue-<id>-contract.md`
  - 拒否 → `bin/controller.py reject-contract --issue-id <id> --actor evaluator --feedback-ref docs/feedback/issue-<id>-contract.md`
  - (3/3 で再拒否の場合 controller が自動 BLOCKED に遷移)
- **`contract.json` を直接編集しない**。書き直しは generator の責務 (hook が承認後の編集を block)
- **`docs/spec.md` を編集しない**。spec 不整合は「spec 不整合」として拒否する
- Playwright を起動しない。実装コードを読まない。軽量テキストレビューに徹する

### 迷ったら拒否

契約段階は contract_attempts が 3 回あり、厳しめに差し戻しても generator は追随できる。実装後の NEEDS_FIX は時間を食うが、契約レベルの差し戻しは安い。

## 契約の不変性 (PIPELINE.md §6)

`CONTRACT_APPROVED` 以降、`contract.json` は**書き換えない** (hook が block):

- generator は Phase 3 / 4 で契約を見直したくなっても触らない
- 実装中に契約の根本的な不備が判明したら `docs/spec-issues.md` に記録して `bin/controller.py block --issue-id <id> --reason human_judgment_required`
- 評価は必ず元の契約基準で行われる — 契約を書き換えて評価を通すのは禁止

## 再交渉パス (BLOCKED 後)

契約自体に不備があると判明した場合:

1. generator が `docs/spec-issues.md` に根本原因を記録
2. controller で BLOCKED に遷移
3. GitHub Issue を `spec-issue,critical` ラベルで作成 (`github-publishing` skill)
4. 人間判断を待つ
5. 人間が spec を直したら planner を再起動、または `controller.py unblock --to PLANNED` で Phase 1 から仕切り直し

## 参照

- `schemas/contract.schema.json` (契約のスキーマ定義)
- `templates/contract-feedback.md` (契約レビュー feedback の雛形)
- `docs/PIPELINE.md` §4 (状態機械), §5 (リトライ予算)
