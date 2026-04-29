---
name: github-publishing
description: Draft PR ライフサイクルと GitHub 連携を **親 Claude (セッション本体)** が直接扱うためのスキル。Publisher サブエージェントは廃止され、親 Claude が Bash + gh CLI で create-draft / update / ready の 3 モードを実行する。Issue ↔ PR 自動同期、evaluator の PR コメント投稿、planner の Issue 起票も本スキルに集約。
---

# github-publishing — GitHub 連携プロトコル (親 Claude 主体)

## 実行者

- **親 Claude (session orchestrator)** — PR lifecycle の 3 モード (create-draft / update / ready) を**直接 Bash で実行**
- **evaluator** — PR コメント投稿 (契約モード / 実装モード両方)
- **planner** — spec.md 書いた後に各 Issue を `gh issue create` で起票
- **generator** — spec-issue 作成 (critical 仕様問題時のみ)

旧 publisher サブエージェントは廃止。gh CLI + 本文合成は AI dispatch が不要なので、親 Claude が直接行う (context / コストの節約)。

## 前提

- `gh auth status` が通る状態
- `gh repo view --json nameWithOwner` が通る
- プロジェクトが GitHub にある (ローカル専用なら本スキルは skip)
- `.github/no-issues` ファイルがあれば Issue 作成系はスキップ

## PR 番号の保存場所

各 Issue の PR 番号は `.ai/work/<id>/state.json` の `pr_number` フィールドに記録する。`bin/controller.py set-pr --issue-id <N> --pr-number <PR>` で更新。

複数 Issue が同じ PR に紐づくケース (機能パッケージ単位) もある。その場合は同じ `pr_number` を該当する全 Issue の state.json に書く。

## 3 モード (親 Claude が実行)

| モード | 契機 | 主な動作 |
|---|---|---|
| `create-draft` | 初の PASSED Issue が出て、まだ PR が存在しない | Draft PR 新規作成、PR 番号を controller で記録 |
| `update` | 後続の PASSED / NEEDS_FIX / BLOCKED 直後 | 既存 Draft PR の本文を最新状態に更新 |
| `ready` | 関連する全 Issue が PASSED | 本文を最終版に更新し `gh pr ready` で Draft 昇格 |

自己判定ロジック:
- `bin/controller.py list --json | jq '[.[].pr_number] | unique - [null]'` が空 → `create-draft`
- 非空 & 未 PASSED の Issue が残る → `update`
- 全 Issue PASSED & PR あり → `ready`

## 共通前提チェック

```bash
git rev-parse --is-inside-work-tree
git branch --show-current          # feature/sprint ブランチであること
git status --porcelain             # 空であること
gh auth status
gh repo view --json nameWithOwner
```

## モード 1: create-draft

```bash
# 1. 二重作成防止
if gh pr view --json number,state 2>/dev/null; then
  echo "既存 PR あり → update にフォールバック"
fi

# 2. push
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"

# 3. PR 本文合成 (templates/pr-body.md を元に)
cat > .pr-body.md <<EOF
**Status:** 🚧 In Progress

## 概要
<docs/spec.md の概要セクション>

## 含まれる Issue
$(python3 bin/controller.py list)

## 変更ハイライト
<実装の主要ポイント 3-5 個>

## 動作確認方法
\`\`\`bash
./init.sh
\`\`\`
URL: http://localhost:3000

## 関連 Issue
Closes #<linked issue number(s)>

---
🤖 このPRは Planner/Generator/Evaluator パイプラインにより自動生成されました。
EOF

# 4. Draft PR 作成
gh pr create --draft --base main --head "$BRANCH" \
  --title "<docs/spec.md の H1 タイトル>" \
  --body-file .pr-body.md

PR=$(gh pr view --json number -q .number)

# 5. 関連する各 Issue の state.json に PR 番号を記録
for ID in $(python3 bin/controller.py list --json | jq -r '.[].issue_id'); do
  python3 bin/controller.py set-pr --issue-id "$ID" --pr-number "$PR"
done

# 6. 後始末
rm -f .pr-body.md

# 7. 報告: "Draft PR 作成: <URL>"
```

## モード 2: update

```bash
# 1. PR 番号取得 (.ai/work/*/state.json)
PR=$(python3 bin/controller.py list --json | jq -r '.[] | select(.pr_number != null) | .pr_number' | head -1)
[ -z "$PR" ] && { echo "PR 未作成 → create-draft へフォールバック"; exit 1; }

# 2. push
git push origin $(git branch --show-current)

# 3. PR 本文合成
# ステータスヘッダ:
#   進行中: "🚧 In Progress"
#   BLOCKED: "⚠ BLOCKED — Issue #<N>"
#   一時停止: "⏸ Paused"

# 4. PR 本文更新
gh pr edit "$PR" --body-file .pr-body.md

# 5. 後始末
rm -f .pr-body.md

# 6. 報告: "PR #N 更新完了"
```

## モード 3: ready

```bash
# 1. PR 番号取得
PR=$(python3 bin/controller.py list --json | jq -r '.[] | select(.pr_number != null) | .pr_number' | head -1)

# 2. コミット漏れ確認
git status --porcelain # 空でなければ停止

# 3. push
git push origin $(git branch --show-current)

# 4. PR 本文合成 (ステータスヘッダ: "✅ Ready for review")

# 5. PR 本文更新
gh pr edit "$PR" --body-file .pr-body.md

# 6. Draft → Ready
gh pr ready "$PR"

# 7. 後始末
rm -f .pr-body.md

# 8. 報告: "PR #N ready: <URL>"
```

## evaluator の PR コメント投稿

state.json に PR 番号があれば**必ず PR コメント投稿**する。これは主レビュー経路であり、ローカル `docs/feedback/*.md` は補助ログに過ぎない。

```bash
PR=$(python3 bin/controller.py read --issue-id <id> --field pr_number)
[ -z "$PR" ] || [ "$PR" = "null" ] && { echo "PR 番号なし → 投稿スキップ"; exit 0; }

# 契約モードの例
gh pr comment "$PR" --body "✅ Issue #<id>: 契約承認 (Contract attempts: X/3)"
# または
gh pr comment "$PR" --body "❌ Issue #<id>: 契約拒否 (Contract attempts: X/3)。理由は docs/feedback/issue-<id>-contract.md 参照"

# 実装モードの例 (.pr-comment.md を先に書く)
cat > .pr-comment.md <<EOF
## 🧪 Issue #<id> 評価結果: ✅ PASSED / ❌ NEEDS_FIX / 🚫 BLOCKED

**評価日:** <ISO 日付>
**対象:** Issue #<id> — <タイトル>
**Attempts:** X/5

### スコア
| 基準 | スコア | 閾値 | 判定 |
|---|---|---|---|
| 契約適合性 | X/5 | 4 | PASS/FAIL |
| 動作安定性 | X/5 | 4 | PASS/FAIL |
| UX/可読性 | X/5 | 3 | PASS/FAIL |
| エッジケース | X/5 | 3 | PASS/FAIL |
| 回帰なし | X/5 | 5 | PASS/FAIL |

### TDD 検証結果
- RED commit: <SHA>
- GREEN commit: <SHA>
- 順序違反: なし / あり (詳細)

### <判定に応じたセクション>
...

### 詳細ログ
\`docs/feedback/issue-<id>.md\` に全文あり
EOF

gh pr comment "$PR" --body-file .pr-comment.md
rm -f .pr-comment.md
```

`.pr-comment.md` は一時ファイル。`.gitignore` に含めること。

## planner の Issue 起票

`docs/spec.md` を書き終えた後、`.github/no-issues` が無ければ各機能を Issue として起票。本文は `templates/sprint-issue.md` に従う:

```bash
# templates/sprint-issue.md を元に本文を合成
# docs/spec.md の該当節から Goal / Scope / Out of scope /
# Acceptance criteria / Dependencies を転記
cat > .issue-body.md <<EOF
## Goal
<1-2 文サマリ>

## Scope
<spec.md の該当箇所を転記>

## Out of scope
<spec.md の該当箇所を転記>

## Acceptance criteria
<spec.md の受け入れ基準を転記>

## Priority / Risk
- Priority: P0 / P1 / P2
- Risk: low / medium / high (理由 1 行)

## Dependencies
<前 Issue 番号を #M で参照、無ければ "なし">

## References
- Spec: \`docs/spec.md\` の該当セクション
- Pipeline: \`docs/PIPELINE.md\`
- 作業ディレクトリ: \`.ai/work/<id>/\`

---

🤖 Planner により自動起票。進捗は同一リポジトリの Pull Request で管理される。
EOF

ISSUE_NUM=$(gh issue create \
  --title "<タイトル>" \
  --label "sprint,auto-generated" \
  --body-file .issue-body.md \
  --json number -q .number)

# 取得した Issue 番号で controller を初期化
python3 bin/controller.py init \
  --issue-id "$ISSUE_NUM" \
  --title "<タイトル>" \
  --branch "sprint/${ISSUE_NUM}-<slug>"

rm -f .issue-body.md
```

PR 本文で `Closes #<ISSUE_NUM>` として自動紐付け。

### 測定可能性の必須チェック

Acceptance criteria に「良い感じに」「適切に」のような曖昧語が含まれていたら Issue を作らずに `docs/spec-issues.md` に記録し、planner に差し戻す。Issue は**測定可能な合格条件が揃ったときのみ**起票する。

## generator / evaluator の Spec Issue 起票

Critical な仕様問題 (契約 3/3 拒否、spec 矛盾、解釈不能) を検知した場合、`templates/spec-issue.md` に従って起票。

## Issue ↔ PR 双方向同期

**配置は `install.sh` が自動で行う**: `<harness>/templates/github-workflows/*.yml` を `<target>/.github/workflows/` にコピーする。手動コピーは不要。再展開する場合は `<harness>/install.sh <target> --force`。

実体ファイル: `templates/github-workflows/issue-sync.yml`

挙動:
- **PR merge → Issue 自動 close** (GitHub native、PR 本文の `Closes #N` で動作)
- **PR reopen → Linked Issue を自動 reopen** (workflow `reopen-on-pr-reopen` job)
- **PR / Issue に `needs-rework` ラベル付与 → Issue を reopen** (workflow `reopen-on-needs-rework-label` job)
- **日次 sweep**: 06:15 UTC、`needs-rework` ラベルが付いた open PR について linked Issue が close されていれば reopen

同時に deploy される workflow:
- `ci.yml` — 言語別 build + test (Node/Python/Rust/Go 自動検出)
- `state-validate.yml` — `.ai/work/<id>/*.json` を `bin/validate-state.py` で schema 検証 (PR ブロック)
- `security.yml` — gitleaks (PR ブロック) + dep audit (週次 + PR、警告)
- `issue-sync.yml` — 上記 Issue ↔ PR 同期

## GitHub Projects 連携 (任意)

`.harness/project.yaml` が存在するプロジェクトでは、Issue の state 遷移を Project のカンバンに自動反映。

### 初回セットアップ

```bash
python3 bin/project-sync.py setup \
  --title "<プロジェクト名> Sprint Board" \
  --owner <github-user-or-org> \
  [--org]
```

これで GitHub Project v2 が作成され、Status field に 7 カラム (`Planned / Contract / In Progress / In Review / Needs Fix / Blocked / Done`) が追加される。

### Issue を Project に追加 (planner が起票後)

```bash
python3 bin/project-sync.py add --issue <N>
```

### state 遷移に応じたカラム移動

```bash
# state 名を渡すと自動でカラムを決める
python3 bin/project-sync.py move --issue 42 --status CONTRACT_APPROVED
python3 bin/project-sync.py move --issue 42 --status IN_PROGRESS_RED
python3 bin/project-sync.py move --issue 42 --status PASSED
```

state → column 対応は `python3 bin/project-sync.py state-to-status <STATE>` で確認。

### 同期のタイミング

| 契機 | 実行者 | コマンド |
|---|---|---|
| Issue 起票直後 | 親 Claude | `project-sync.py add --issue <N>` |
| state 遷移ごと | 該当 agent 終了時に親 Claude | `project-sync.py move --issue <N> --status <state>` |
| Project 未セットアップ | — | 全コマンドが skip 報告 |

`.harness/project.yaml` が無い場合、`project-sync.py` は error を返すがパイプライン自体は止まらない (Project は optional)。

## PR レビューコメントへの対応

`/review-respond` コマンドで扱う。`commands/review-respond.md` を参照。

### 分類ルール (コメントごと)

| 分類 | 対応 |
|---|---|
| small-fix (10 行以内、契約変更なし) | generator Phase 4 で修正 → commit + reply + resolve |
| spec-change (契約 / spec 変更要) | planner が新 Issue を起票 → 通常フロー |
| question (変更不要) | 事実ベースで reply、resolve は人間判断 |
| won't-fix (Out of scope 該当) | 理由と別 Issue 番号を reply、resolve しない |

### resolve の原則

- **small-fix で対応**: 親 Claude が commit push 後に `resolveReviewThread` mutation で resolve
- **spec-change / won't-fix**: resolve しない (人間が判断)
- **question**: 回答のみ。resolve は人間判断

## エラーハンドリング

| エラー | 対応 |
|---|---|
| `gh auth status` 失敗 | 「`gh auth login` を実行してください」と報告 |
| push が rejected | 「fetch + rebase を検討」と報告。自動 pull はしない |
| `gh pr create` が「既に PR 存在」で失敗 | `update` モードにフォールバック |
| `gh pr ready` 失敗 (既に ready) | 成功として扱う (冪等) |
| PR 番号が state.json に無いのに `update`/`ready` が呼ばれた | `create-draft` モードで初期化 |

いかなる場合も**履歴改変 (rebase, reset --hard) は禁止**。問題が起きたら人間判断を仰ぐ。

## `.gitignore` 必須エントリ

- `.pr-body.md`
- `.pr-comment.md`
- `.issue-body.md`
- `.pr-review-threads.json`
- `.env`

## 参照

- `docs/PIPELINE.md` §6 (ファイル所有権), §7 (エスカレーション)
- `templates/pr-body.md`
- `templates/sprint-issue.md`
- `templates/spec-issue.md`
- `templates/feedback.md`
- `bin/controller.py` (state.json の PR 番号読み書き)
- `bin/project-sync.py` (GitHub Projects カラム同期)
- `commands/review-respond.md`
