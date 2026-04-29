---
description: 新規プロジェクトの bootstrap 手順書。**通常はユーザーが叩かない**。CLAUDE.md / session_start_hook の指示に従って、要件 dialogue で repo 名 + idea が固まった後に、親 Claude が裏で実行する手順。slash として叩かれた場合も同じ動作で OK。
---

## 位置づけ (重要)

この `/newproject` は**ユーザーが叩く想定ではない**。**親 Claude が要件定義 dialogue の後に裏で実行する手順書**として設計されている。

- ✅ **想定 1**: 親 Claude が dialogue で repo 名 + idea を固めた後、Bash + Write でこの手順を実行 (slash として呼び出さない)
- ✅ **想定 2**: ユーザーが明示的に「`/newproject foo bar baz`」と叩いた場合 (パワーユーザー)
- ❌ **想定外**: dialogue を経ずに、ハーネス起動直後にいきなり叩かせる

新規 session が起動したら、`session_start_hook.py` が `🆕 新規プロジェクト session を検出` の reminder を出す。それを受けて親 Claude は:

1. ユーザーに自己紹介 + 要件 dialogue を始める (CLAUDE.md「新規プロジェクト session の挙動」)
2. 詰めた結果から repo 名と idea を確定
3. **以下の手順を粛々と実行** (この commands/newproject.md の中身)

つまり**この手順は内部 procedure**。

## 前提チェック

```bash
test -f CLAUDE.md && test -f docs/PIPELINE.md && test -x bin/controller.py && test -d .claude/agents
```

全て true でなければ: 「この session は dispatcher 経由で立ち上げられた環境ではありません。dispatcher session で `/spawn <dir-name>` を先に叩いてから、そこで生成された session 内でこのコマンドを実行してください」と返して停止。

## 入力 (slash 経由の場合)

`$ARGUMENTS` 形式: `<repo-name> <idea...>`

```
/newproject todo-cli Python で TODO CLI を作って。add/list/done の 3 コマンド、JSON 永続化。
```

slash 経由でない場合 (= dialogue 後の内部実行) は、親 Claude が dialogue で確定した repo 名と idea を内部変数として保持して進める。

## 前提チェック

起動時に以下を確認してください:

```bash
test -f CLAUDE.md && test -f docs/PIPELINE.md && test -x bin/controller.py && test -d .claude/agents
```

**全て true でなければ**: 「この session は dispatcher 経由で立ち上げられた環境ではありません。dispatcher session で `/spawn <dir-name>` を先に叩いてから、そこで生成された session 内でこのコマンドを実行してください」と返して停止。

## 入力仕様

`$ARGUMENTS` は以下の形式を期待:

```
<repo-name> <idea...>
```

例:
```
/newproject todo-cli Python で TODO CLI を作って。add/list/done の 3 コマンド、JSON 永続化。
```

- `<repo-name>` は 1 語 (kebab-case 推奨、GitHub repo 名として使用)
- `<idea>` は以降の全文。planner に渡されるアイデア

空 or repo-name が推測できない場合は、ユーザーに 1 行で質問して停止。

## 実行ステップ

### 1. `.ai/initial-brief.md` の書き込み

```markdown
# <repo-name>

<idea を原文のまま>

---

**自律開発起動用のアイデア記述。planner がこれを起点に `docs/spec.md` を起草し、Issue を分解します。**
```

### 2. 初回 commit

```bash
git add -A
git commit -q -m "initial brief: <repo-name>"
```

(dispatcher が initial commit を済ませているので、これは brief 追加の差分 commit)

### 3. GitHub private repo 作成 + push

```bash
gh auth status || { echo "gh auth エラー"; exit 1; }
gh repo create <repo-name> --private --source=. --push
```

SSH push が失敗したら HTTPS にフォールバック:

```bash
gh repo view <repo-name> --json owner,name -q '"\(.owner.login)/\(.name)"'  \
  | xargs -I{} git remote set-url origin "https://github.com/{}.git"
git push -u origin main
```

`.github/no-issues` が存在するプロジェクトは Issue 作成系が skip される前提。

### 4. /auto 自律ループの起動

`/auto` コマンドを続けて発行する (同 session 内、context は残る):

```
/auto
```

`/auto` が以下を自走:

- planner dispatch → `docs/spec.md` 起草 + GitHub Issue 起票 + `bin/controller.py init` で `.ai/work/<id>/` 初期化
- 各 Issue について generator → evaluator → ... → PASSED
- 全 Issue PASSED で ship → PR ready
- observer dispatch で Instinct 抽出

自走条件と停止条件は `commands/auto.md` 参照。

## 完了報告

以下の形式で 3-5 行に収める:

```
==> /newproject 完了
    repo:       github.com/<owner>/<repo-name>
    branch:     main
    brief:      .ai/initial-brief.md
    次:         /auto が自走中。PR ready 通知を待つか、`/status` で進捗確認。
```

## 禁止事項

- `install.sh` を再実行しない (dispatcher が済ませている、重複コピーで上書きリスク)
- `git init` を再実行しない (dispatcher が済ませている)
- dir 名変更をしない (cwd rename は Claude Code で不可)
- 複数 repo を同時に作らない (1 invocation = 1 repo)
- ユーザーに多数の確認を求めない (repo 名 / idea 不明時に 1 回だけ)

## エラー時の扱い

| エラー | 対応 |
|---|---|
| 前提チェック失敗 (ハーネス未展開) | dispatcher からの起動を促して停止 |
| `gh auth` 失敗 | 「gh auth login を実行してください」と案内、ローカルのみで続行するか確認 |
| `gh repo create` 失敗 (名前重複) | 別名を提案、または `<repo-name>-<timestamp>` を自動採用 |
| SSH push 失敗 | HTTPS に自動切替 (stdout で明示) |
| /auto 起動失敗 | エラーを報告、手動で `/plan` から流す旨を案内 |

## 関連

- dispatcher 側の `/spawn <dir-name>` — この session を立ち上げた元
- `/auto` — 自律ループ (このコマンドの延長で起動)
- `install.sh` は dispatcher の `scripts/spawn-env.sh` 内で既に実行済み
