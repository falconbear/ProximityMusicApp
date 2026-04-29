---
name: initializer-protocol
description: プロジェクト初期化と毎回の Startup Protocol。Sprint 01 で `init.sh` を必ず作成し、以降の Sprint で generator / evaluator が冪等に起動できる状態を保つ。evaluator が `init.sh` でアプリを起こせなければ即 NEEDS_FIX とする。
---

# initializer-protocol — 初期化と起動契約

## 背景

evaluator は毎回「手元で動く generator の成果物」をテストする。起動方法が Sprint ごとにブレると評価コストが爆発し、回帰検出も難しくなる。`init.sh` を契約化することでこれを機械的に防ぐ。

## `init.sh` の要件 (generator が守る)

Sprint 01 の成果物として、プロジェクトルートに `init.sh` を作成:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. 依存関係インストール
<パッケージマネージャ install>

# 2. DB / 外部サービスセットアップ (必要に応じて)
<migration / seed 等>

# 3. 最後にフォアグラウンドで dev サーバーを起動
<npm run dev / expo start / uvicorn 等>
```

### 要件

- `chmod +x init.sh` で実行権限を付与
- 先頭に `#!/usr/bin/env bash` と `set -euo pipefail`
- **冪等性**: 2 回目以降の実行で壊れない (`npm install` は idempotent、migration は `IF NOT EXISTS` など)
- **最後にフォアグラウンド**: バックグラウンド化しない。evaluator 側が `&` で制御する
- **環境変数**: `.env.example` を用意。`.env` が必要なら起動時にチェックして親切なエラーを出す
- **README に記載**: `./init.sh` で起動可能であることを明記

### 新しい依存関係を追加した Sprint では `init.sh` を更新

冪等性を保ったまま追記。過去の実行で壊れないことを確認する。

## Startup Protocol (generator / evaluator 共通)

毎回の呼び出しの冒頭で以下を実行:

```bash
pwd                                  # 作業ディレクトリ確認
git log --oneline -n 20              # 直近の履歴を把握
test -x init.sh || echo "warn: init.sh missing"
```

- Sprint 02 以降で `init.sh` が無い / 実行できない場合は**Sprint 01 の成果物欠落**として扱う
- generator の場合: Sprint 01 に戻って修正する、または現在 Sprint の契約に init.sh 修正を含める
- evaluator の場合: **即 NEEDS_FIX** を Sprint 01 または現在 Sprint に対して発行 (欠落が誰のせいかを明記)

## evaluator の起動手順

```bash
# 1. Startup Protocol
pwd
git log --oneline -n 20
test -x init.sh || { echo "FATAL: init.sh missing"; exit 1; }

# 2. init.sh 内容と .ai/work/<id>/handoff.md の「起動方法」が一致しているか確認
#    不一致は NEEDS_FIX (起動方法が契約から外れている)

# 3. バックグラウンド起動
./init.sh &
INIT_PID=$!

# 4. 起動確認 (URL に curl / Playwright で疎通)
sleep 3
curl -fsS http://localhost:<port>/ > /dev/null || { echo "startup failed"; kill $INIT_PID; exit 1; }

# 5. テスト実施
# ...

# 6. 終了時に必ず kill
kill $INIT_PID 2>/dev/null || true
# プロセスツリーで残骸があれば追加で kill
pkill -P $INIT_PID 2>/dev/null || true
```

**テスト終了時に起動したプロセスを残さない**。PID を控えて終了前に kill する。

## generator の `.ai/work/<id>/handoff.md` への記載

各 Issue の `handoff.md` の「起動方法」セクションに以下を書く:

```markdown
## 起動方法

```bash
./init.sh         # 初回セットアップ (冪等)
npm run dev       # 開発サーバ起動
```

- URL: http://localhost:3000
- 停止方法: フォアグラウンドなら Ctrl+C / バックグラウンドなら `kill $!`
```

この記述と `init.sh` の実体が一致していることを evaluator が確認する。

## よくある違反と対処

| 違反 | 対処 |
|---|---|
| `init.sh` が無い | Sprint 01 成果物欠落で即 NEEDS_FIX |
| `init.sh` がエラーで終わる | 起動失敗で即 NEEDS_FIX |
| 2 回目の実行で壊れる (冪等性違反) | NEEDS_FIX |
| 起動方法の記載と実体がズレている | NEEDS_FIX (契約不履行) |
| バックグラウンド化していて `init.sh` が即座に終了する | NEEDS_FIX (evaluator が起動成否を判定できない) |
| `.env` が必須なのにエラーメッセージが不親切 | 改善提案 (合否には影響させない) |

## 参照

- `docs/PIPELINE.md` §5 (ファイル所有権), §6 (エスカレーション)
- `skills/skeptical-evaluation/` (評価ワークフロー内で呼ばれる)
- `templates/handoff.md` (起動方法セクションの雛形)
