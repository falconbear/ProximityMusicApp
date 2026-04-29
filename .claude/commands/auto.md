---
description: 1 回の指示で全 Issue が PASSED → PR ready まで到達するまで自律ループを回す。親 Claude が controller state を見ながら次 agent を dispatch し続ける。
---

あなたは **orchestrator loop** に入ります。以下の state machine を自律で回し、**停止条件を満たすまで subagent を連続 dispatch してください**。

## 入力処理 (最初の 1 回)

ユーザーの入力 `$ARGUMENTS` は以下のいずれかとして扱う:

- **空** または「続きから」相当 → 既存の Issue 群の続きを回す
- **アイデア文** → planner を dispatch して新規 Issue を起こす
- `.ai/initial-brief.md` が存在し、かつ `.ai/work/` に Issue が 1 つも無い → brief.md の内容をアイデアとして planner を dispatch

## 初回 Issue 生成 (必要なとき)

新規アイデアが渡された / brief.md があって Issue が無い場合:

1. `Agent` tool で subagent_type=`planner` を起動
2. 指示: `<アイデア文>` + 「`docs/spec.md` を起草し、GitHub Issue を登録し、各 Issue について `bin/controller.py init` を呼ぶこと。size constraints を必ず守り、大きすぎる場合は分割すること」
3. 終了後に `python3 bin/controller.py list` で Issue が作成されたことを確認
4. 1 つも Issue が無ければ stop (`PLANNER_FAILED`)

## ループ本体

`python3 bin/controller.py list --json` を定期的に叩いて状態を読み、**最若の対象 Issue** について次のアクションを決定する。

### ディスパッチ判断表

| 最若 Issue の current_state | 次に dispatch / 実行するもの |
|---|---|
| `PLANNED` (contract_attempts=0) | `Agent(generator)` Phase 1 |
| `PLANNED` (contract_attempts>0) | `Agent(generator)` Phase 2 |
| `CONTRACT_REVIEW` | `Agent(evaluator)` 契約モード |
| `CONTRACT_APPROVED` | `Agent(generator)` Phase 3 (RED) |
| `IN_PROGRESS_RED` | `Agent(generator)` Phase 3 (GREEN) |
| `IN_PROGRESS_GREEN` | `Agent(generator)` Phase 3 完成 + submit-impl |
| `READY_FOR_REVIEW` | `Agent(evaluator)` 実装モード |
| `NEEDS_FIX` | `Agent(generator)` Phase 4 |
| `PASSED` かつ **PR 未作成** | `Bash: github-publishing skill の create-draft モード` |
| `PASSED` かつ PR 作成済、かつ他に未 PASSED の Issue あり | 次の Issue のループに進む |
| `PASSED` かつ全 Issue が PASSED | `Agent(observer)` を 1 回 dispatch → `Bash: github-publishing ready モード` → stop `ALL_DONE` |
| `BLOCKED` | stop `BLOCKED: #<issue-id>, reason=<reason>` |

### 各 dispatch の実施

**Agent dispatch の指針:**
- `description`: `<agent> Issue #<id>: <phase>`
- `prompt`: 既存の `.claude/commands/<agent>.md` の指示本文を**そのまま埋め込み**、対象 Issue 番号と現在の state を明記
- subagent の**終了後**、controller.py で state が期待通り遷移しているかを確認
- 遷移していなければ loop に差し戻し (ただし無限 loop 防止、後述)

**Bash (PR 操作) の指針:**
- `skills/github-publishing/` の手順通りに実行
- 完了後、`bin/controller.py set-pr --issue-id <id> --pr-number <PR>` で state.json に記録

### Observer dispatch

- 全 Issue PASSED になった直後に 1 回だけ dispatch (final summary として)
- PASSED が出るたびに毎回 dispatch はしない (cost 節約。必要なら頻度を調整)

## 停止条件

以下のいずれかを満たしたら loop を exit し、ユーザーに**1-3 行のサマリ**を報告する:

| 停止 code | 条件 | サマリ内容 |
|---|---|---|
| `ALL_DONE` | 全 Issue が PASSED + PR ready 昇格完了 | 「N 件の Issue を完了、PR #M ready 済: <url>」 |
| `BLOCKED` | どれか 1 つの Issue が BLOCKED | 「Issue #X が BLOCKED (reason=...)。docs/feedback/ 参照」 |
| `ITERATION_LIMIT` | ループ 40 回を超過 | 「40 iteration に到達した。controller.py list で状態確認を」 |
| `NO_PROGRESS` | 連続 3 iteration で state 変化なし | 「Issue #X で進展なし (state=...)。手動介入を検討」 |
| `PLANNER_FAILED` | planner 後も Issue が 0 件 | 「planner が Issue を作成できなかった」 |
| `STOP_REQUESTED` | ユーザーからの STOP 指示 | 「停止しました」 |
| `HOOK_VIOLATION` | hook (contract_immutability / git_safety 等) が block を返した | 「hook 違反を検出。該当操作を人手で確認」 |

## ループ制御

- **max_iterations = 40** (安全上限)
- **no_progress_threshold = 3** (同じ state が連続 3 回なら停止)
- 各 iteration で:
  1. state 取得 → 次アクション決定
  2. dispatch / 実行
  3. state を再取得し、**変化があれば** カウンタリセット、**なければ** no_progress++
  4. limits チェック

## ユーザーへの進捗報告

各 iteration の末尾に、短い進捗を 1 行で出力する:

```
[auto #3] Issue #1: CONTRACT_REVIEW → CONTRACT_APPROVED (evaluator passed 7/7)
```

冗長な dispatch 結果は出さない。ユーザーは**全体の進捗を眺めたい**のであって、各 agent の作業内容をステップごとに読みたい訳ではない。

## 例外処理

- subagent がエラーを返したら: 1 回だけ retry、それでも失敗なら `BLOCKED` に escape (`bin/controller.py block --issue-id <id> --reason external_dependency`)
- `controller.py` が exit 2 (無効遷移) を返したら: stop + `HOOK_VIOLATION` 相当で報告
- `gh` コマンド失敗: 停止せず次 iteration に進むが、3 回連続失敗なら stop

## 禁止事項

- **subagent の終了を待たずに次に進む** (race 条件を防ぐ)
- **ユーザーへの確認要求** (auto mode の精神に反する。BLOCKED で停止する以外の割り込みは不可)
- **自分で実装コードを書く** (generator の責務)
- **自分で契約を書く** (generator の責務)
- **自分で state.json を編集する** (必ず `bin/controller.py` 経由)
- **skeptical-evaluation の基準を緩める** (evaluator の判断に介入しない)

## ヒント: Issue 初期 state (空プロジェクト) の扱い

`.ai/work/` が空で `.ai/initial-brief.md` もない場合、`$ARGUMENTS` を見る:
- 空なら stop `NEEDS_IDEA` (ユーザーにアイデアを求める)
- ある場合 planner dispatch

`.ai/initial-brief.md` がある場合、それをそのまま planner に渡す (アイデア + brief)。

## session_start_hook との連携

`session_start_hook.py` が `.ai/initial-brief.md` + `.ai/work/` 空 を検出した場合、「`/auto` を起動せよ」という reminder を context に流す。ユーザーが `/auto` を叩くのは 1 回だけで済む。

---

**重要**: これは `/plan` / `/implement` / `/eval` 等の個別コマンドを代替する**最上位の指示**。ユーザーが個別コマンドを使いたい場合は明示的にそちらを叩く。`/auto` は全自律モード。
