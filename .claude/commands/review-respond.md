---
description: 人間が PR に残したレビューコメントを拾い、Generator が各コメントに対応する。小さな指摘は直接コミット、大きな指摘は新 Sprint として Planner に戻す。
---

親 Claude (=あなた自身) が以下を順に実行してください。subagent は必要な場合のみ dispatch する。

## Step 1: 未解決レビューコメントを取得

```bash
PR=$(python3 bin/controller.py list --json | jq -r '.[] | select(.pr_number != null) | .pr_number' | head -1)
[ -z "$PR" ] && { echo "controller に PR 番号付きの Issue なし"; exit 1; }

# 未解決スレッドだけを JSON で取得
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            path
            line
            comments(first: 20) {
              nodes { id author { login } body createdAt }
            }
          }
        }
      }
    }
  }' -F owner=$(gh repo view --json owner -q .owner.login) \
     -F repo=$(gh repo view --json name -q .name) \
     -F pr=$PR \
  | jq '.data.repository.pullRequest.reviewThreads.nodes | map(select(.isResolved == false))' \
  > .pr-review-threads.json
```

生成された `.pr-review-threads.json` を読み、各スレッドを以下のいずれかに分類:

## Step 2: 各コメントを分類

| 分類 | 条件 | 対応 |
|---|---|---|
| **small-fix** | 変更が 10 行以内、既存の契約・テスト・設計を変えない | Step 3-A に進む |
| **spec-change** | 契約や spec.md の変更を要する、または複数ファイルの設計変更 | Step 3-B に進む |
| **question** | コメントが質問・意見確認のみで変更を求めていない | Step 3-C に進む |
| **won't-fix** | 契約の Out of scope に該当、または合理的に対応不可 | Step 3-D に進む |

曖昧なら **spec-change** として扱う (安全側に倒す)。

## Step 3-A: small-fix の対応

Generator subagent を Phase 4 (修正) モードで起動:

起動時の指示:
1. `.pr-review-threads.json` を読み、`small-fix` 分類されたスレッドを対象に修正
2. スレッドごとに commit を分ける: `git commit -m "review: address @<author> — <short desc>"`
3. 既存テストは改変しない (test-integrity)
4. 既存の TDD 順序を破らない (新規テストが必要なら RED → GREEN の順)
5. 修正完了後 `git push` (親 Claude が後段で行う)

修正後、親 Claude がスレッドごとに `gh api` で返信 + resolve:

```bash
# 各 thread ID について
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
      comment { id }
    }
  }' -F threadId=<THREAD_ID> -F body="commit <SHA> で対応しました。"

gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { isResolved }
    }
  }' -F threadId=<THREAD_ID>
```

## Step 3-B: spec-change の対応

契約や spec の変更を要するので、新 Issue として扱う。Planner subagent を起動:

起動時の指示:
1. `.pr-review-threads.json` の `spec-change` 分類スレッドを入力に、新 Issue を `gh issue create` で起票 (`templates/sprint-issue.md` 準拠)
2. 該当するレビュースレッドの本文を Goal / Scope に引用
3. `docs/spec.md` に該当節を追記
4. 取得 Issue 番号で `bin/controller.py init --issue-id <N> --title "..." --branch "sprint/<N>-..."` を実行
5. 完了後、親 Claude が通常の `/implement` → `/eval` → `/ship` フローに戻る

スレッドへの即時返信 (resolve はしない):

```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
      comment { id }
    }
  }' -F threadId=<THREAD_ID> \
     -F body="指摘を Issue #NN として受け止めました。対応完了時に再度お知らせします。"
```

resolve は**新 Issue が PASSED してから**行う。

## Step 3-C: question の対応

コードを変えず、質問に回答するだけ:

```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
      comment { id }
    }
  }' -F threadId=<THREAD_ID> -F body="<回答本文>"
```

事実ベースで回答。推測で答えない。不明なら「確認して新 Issue で扱います」と言って **spec-change** に再分類する。

## Step 3-D: won't-fix の対応

契約の Out of scope と照合して理由を明示:

```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
      comment { id }
    }
  }' -F threadId=<THREAD_ID> \
     -F body="本 Issue の Out of scope (docs/spec.md の該当行参照) のため、別 Issue で扱います。該当 Issue: #<NNN>"
```

won't-fix のスレッドは**resolve しない**。人間レビュアーが納得したら resolve する。

## Step 4: GitHub Projects の同期 (任意)

`.harness/project.yaml` があれば該当 Issue の Status を更新:

```bash
# spec-change で新 Issue を作った場合
python3 bin/project-sync.py add --issue <新Issue番号>
python3 bin/project-sync.py move --issue <新Issue番号> --status Planned

# small-fix で修正中
python3 bin/project-sync.py move --issue <現Issue> --status "In Review"
```

## Step 5: PR 本文更新 + 報告

```bash
# github-publishing skill の update モード
# (変更があれば PR 本文の「Evaluator レビュー結果」セクションに
#  "## レビュー対応" サブセクションを追加)

# 後始末
rm -f .pr-review-threads.json
```

親の報告 (1-3 行):

```
review-respond: PR #<N> の未解決 <X> 件対応
  - small-fix: Y 件 (commit <SHA1>, <SHA2>)
  - spec-change: Z 件 → Issue #<NN> / #<MM> として追加
  - question: W 件 (回答のみ)
  - won't-fix: V 件 (新 Issue #<NNN> 作成)
```

## 禁止事項

- **無分類のまま resolve しない** (small-fix で対応したコメントのみ resolve)
- **spec-change を小手先で潰さない** (契約の範囲外は必ず新 Issue)
- **返信を書かずに commit する** (人間レビュアーが何が対応されたか追えない)
- **古い `.pr-review-threads.json` を残す** (次回実行時に混乱)
