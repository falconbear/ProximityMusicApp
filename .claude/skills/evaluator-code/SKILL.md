---
name: evaluator-code
description: UI を持たないプロジェクト (API サーバー / CLI / ライブラリ) を対象とする evaluator の実装技術。テストランナー・型チェック・リンタ・API エンドポイント呼び出し・CLI 出力検証・ライブラリのインポート確認を定義する。skeptical-evaluation の 3 層テストを非 UI 環境で実行するためのプロトコル。
---

# evaluator-code — コードのみプロジェクトの検証

UI を持たないプロジェクト (REST / GraphQL API サーバー、CLI ツール、ライブラリ、バックエンド処理) の実装モード evaluator が使う。Playwright やシミュレータを使わず、プロセス実行と出力検証だけで合否を判定する。

## プロジェクト種別の判定

```bash
# エントリーポイント
test -f package.json && jq -r '.bin // empty' package.json        # Node CLI
test -f package.json && jq -r '.main // .exports // empty' package.json  # Node library
test -f pyproject.toml && grep -A3 '\[project.scripts\]' pyproject.toml   # Python CLI
test -f Cargo.toml && grep -q '\[\[bin\]\]' Cargo.toml             # Rust CLI
test -f go.mod && test -d cmd/                                     # Go CLI
# API サーバー
grep -rE "express\(|fastify\(|FastAPI\(|http\.createServer|actix-web" src/ 2>/dev/null
```

種別から評価戦略を決める:

| 種別 | 主要検証 |
|---|---|
| CLI | バイナリ実行、標準出力、exit code |
| ライブラリ | import / require、エクスポート型、example 実行 |
| REST / GraphQL API | サーバー起動、curl / httpie でエンドポイント呼び出し |
| バックエンド処理 (cron, worker) | 入力投入 → 副作用 (DB 状態、ファイル、queue) を検証 |

## テストランナー実行 (必須、baseline)

プロジェクトのテストランナーを**全件**実行する。1 件でも failing があれば即 NEEDS_FIX。

```bash
# Node
npm test            # Jest / Vitest / Mocha 自動検出
# Python
pytest -q
# Rust
cargo test
# Go
go test ./...
# .NET
dotnet test
# Ruby
bundle exec rspec
```

`--bail` 相当を**使わない**。全 failing を集めて feedback に記録する。

## 静的解析 (型 + lint)

```bash
# 型
npx tsc --noEmit                # TypeScript
mypy .                          # Python
cargo check                     # Rust
go vet ./...                    # Go
# Lint
npm run lint                    # project-defined
ruff check .                    # Python
cargo clippy -- -D warnings     # Rust
golangci-lint run               # Go
```

- 型エラーは即 NEEDS_FIX
- Lint warning は契約の品質基準が `warning 0 件` なら NEEDS_FIX、それ以外は advisory

## CLI の検証

バイナリを実際に実行する。

```bash
# ビルド
npm run build   # or: cargo build --release / go build / etc.

# 起動
./dist/cli --help                     # help 出力が空でないか
./dist/cli <契約の Test plan の引数>   # 期待される出力と比較
echo $?                                # exit code を確認 (成功 = 0)
```

契約の Test plan に `成功時 exit 0、失敗時 exit 1` のように書かれていれば、それを厳密に検証する。

### 標準出力の比較

```bash
./dist/cli foo > /tmp/actual.txt
diff /tmp/actual.txt docs/feedback/expected.txt
```

- 完全一致を要求する場合と、部分一致 (grep) を許容する場合は契約で指定されている
- 日付・UUID・一時ファイルパスは期待値から除外 (正規化)

### 敵対的入力 (CLI 固有)

| カテゴリ | 具体 |
|---|---|
| **フラグ組合せ** | `--flag-a --flag-b` が意図通り、矛盾する組合せはエラー |
| **欠落引数** | 必須引数を省略 → 明確なエラーメッセージ + exit コード |
| **未知フラグ** | `--unknown` → 無視ではなくエラー |
| **stdin パイプ** | `echo "..." \| ./cli` でパイプ入力が効くか |
| **SIGINT** | 実行中に Ctrl-C → クラッシュではなくクリーンな終了 |
| **大入力** | 1MB の stdin / 巨大ファイルを食わせてメモリリークしないか |

## ライブラリの検証

公開 API として意図された export が実際に使えるか。

### インポート確認

```bash
# Node library
node -e "const pkg = require('./dist'); console.log(Object.keys(pkg))"

# Python library
python -c "import mypkg; print(dir(mypkg))"

# Rust: dependents からインポートできるかを Cargo.toml で検証
```

契約で公開 API 一覧が宣言されていれば、各シンボルが存在することを確認。

### 型定義の export (TypeScript)

```bash
npx tsc --noEmit                    # 自ライブラリの型チェック
# dependents 目線の検証:
mkdir /tmp/consumer && cd /tmp/consumer
npm init -y && npm install /path/to/library
echo "import { foo } from 'library'; const x: ReturnType<typeof foo> = foo();" > test.ts
npx tsc --noEmit test.ts
```

### README の例を実行

README の `## Usage` セクションにあるコード例をコピペで動かす。動かなければドキュメント不一致として NEEDS_FIX。

## API サーバーの検証

### サーバー起動

```bash
./init.sh                  # or: npm run dev / uvicorn main:app / cargo run
# バックグラウンドで起動し、PID を控える
SERVER_PID=$!
# ヘルスチェック
curl -fsS http://localhost:3000/health
```

起動失敗 (port 衝突、DB 接続失敗、env var 欠落) はクリティカル、即 NEEDS_FIX。

### エンドポイント検証

契約の Test plan の各 API 呼び出しを `curl` で実行:

```bash
# GET
curl -i http://localhost:3000/api/users/123

# POST (JSON)
curl -i -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice"}'

# 認証付き
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/me
```

検証項目:
- HTTP status code (200 / 201 / 4xx / 5xx が契約通りか)
- Response body のスキーマ (jq でフィールド存在確認)
- Response headers (CORS, Content-Type, Cache-Control)
- エラーレスポンスの形式 (`{error: {message, code}}` など契約通りか)

### 敵対的入力 (API 固有)

| カテゴリ | 具体 |
|---|---|
| **認証バイパス** | トークン無し / 期限切れ / 他ユーザーのトークンで保護エンドポイントを叩く |
| **SQL injection** | `' OR 1=1--` を path / query / body に入れる |
| **rate limit** | 100 req/s を 10 秒送って throttling が効くか |
| **malformed JSON** | `{"name":}` のような壊れた body |
| **oversized body** | 10MB のリクエスト → 413 Payload Too Large か、サーバー落ちるか |
| **Unicode / 絵文字** | ユーザー名・検索クエリに `👨‍👩‍👧‍👦` |
| **path traversal** | `/api/files/../../etc/passwd` |
| **race condition** | 同じリソースを 2 並行で更新して矛盾しないか |

### 終了

```bash
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null   # port 解放確認
```

## バックエンド処理 (cron / worker) の検証

入力を投入して副作用を検証する:

```bash
# 1. 事前状態のスナップショット
db_before=$(psql -c "SELECT count(*) FROM queue_jobs")

# 2. 入力投入
curl -X POST http://localhost:3000/enqueue -d '{"job":"send_email","to":"..."}'

# 3. 処理待ち
sleep 5   # または polling で完了検知

# 4. 副作用確認
db_after=$(psql -c "SELECT count(*) FROM processed_jobs")
# ファイル生成、メール送信ログ、etc.
```

副作用が契約通りでなければ NEEDS_FIX。

## 回帰テスト

前 Sprint までに確立した API / CLI コマンドが壊れていないか:

1. 前の Issue の `docs/feedback/issue-<prev>.md` で PASSED した Test plan を再実行
2. 同じ入力で同じ出力 / 同じ status code が返るか
3. 型の後方互換性 (破壊的変更が無いか)

## エラー検知

### プロセスエラー
- 起動失敗 (exit code != 0): 即 NEEDS_FIX
- クラッシュ (unexpected exit during test): 即 NEEDS_FIX
- unhandled rejection / panic: 即 NEEDS_FIX

### ログ
- `stderr` への warning / error 出力を確認
- 契約の品質基準が `stderr 無出力` なら違反で NEEDS_FIX
- スタックトレースが出ていたら根本原因を feedback に記録

## 禁止事項

- テストランナーの実行をスキップ (baseline の欠落)
- `--bail` で最初の failing で止める (全件報告しないと Generator が修正計画を立てられない)
- サーバープロセスを残したまま終了 (次回の evaluator 起動で port conflict)
- `2>/dev/null` でエラーを隠す

## 参照

- `skills/skeptical-evaluation/` — 合否判定の 9 原則と 5 基準スコア
- `skills/test-integrity/` — generator のテスト改変検知
- `skills/initializer-protocol/` — アプリ起動プロトコル
