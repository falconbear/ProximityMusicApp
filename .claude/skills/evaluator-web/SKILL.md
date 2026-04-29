---
name: evaluator-web
description: Web / SPA / Expo Web を対象とする evaluator の実装技術。Playwright MCP を使った DOM 操作・セレクタ選択・非同期待機・エラー再現手順を定義する。skeptical-evaluation の 3 層テスト (契約ベース / 回帰 / 敵対的) を Web 固有の手法で実行するためのプロトコル。
---

# evaluator-web — Playwright ベース Web 検証

Web / SPA / Expo Web の実装モード evaluator が使う。ブラウザを起動して DOM 上で契約 Test plan を実行する。

## 起動と停止

```
評価開始:
  1. `./init.sh` でアプリを起動 (initializer-protocol)
  2. Playwright MCP で対象 URL へ `browser_navigate`
  3. 契約 Test plan を 1 手順ずつ実行
評価終了:
  1. `browser_console_messages` で unresolved error を確認
  2. `browser_close` で browser 解放
  3. アプリ側の PID を kill
```

起動プロセスを残したまま終了しないこと。残留プロセスは次の evaluator / generator 起動を壊す。

## セレクタ選択の優先順位

1. **role**: `getByRole('button', { name: 'Submit' })` — a11y 前提のセマンティック選択
2. **label / placeholder**: `getByLabel('Email')` — フォーム要素
3. **text**: `getByText('サインイン')` — 可視テキスト
4. **testid**: `getByTestId('user-menu')` — 明示的な test hook (推奨: プロダクション DOM に `data-testid`)
5. **CSS**: 最後の手段。DOM 構造変更で壊れやすい

XPath は使わない。生成 AI が書いた XPath は高確率で壊れる。

## 操作パターン

### クリック
```
browser_click(element="ログインボタン", ref="...")
```
- クリック前後に期待される DOM 変化を必ず検証 (text 変化、URL 変化、element 出現)

### フォーム入力
```
browser_fill_form(fields=[
  { name: "Email", type: "textbox", ref: "...", value: "test@example.com" },
  { name: "Password", type: "textbox", ref: "...", value: "password123" }
])
```
- 空入力・長文・特殊文字・Unicode の境界値検証は契約に含まれる場合のみ (契約外は advisory)

### 待機
- `browser_wait_for({ text: "..." })` — 特定テキスト出現まで待機
- 固定 `sleep` は禁止 (flaky の原因)
- API レスポンス待ちは `browser_network_requests` で確認

### ページ遷移
```
browser_navigate(url="http://localhost:3000/login")
```
- 遷移後は `browser_snapshot` で state を取得し、期待される要素の存在を検証

## 契約 Test plan の実行手順

契約の `**Test plan (for evaluator):**` に書かれた各手順について:

1. 手順を 1 つ読む
2. 対応する Playwright 操作を実行
3. 期待結果と実際の結果を比較
4. 不一致なら `browser_take_screenshot` で証拠を残し NEEDS_FIX の根拠とする
5. 次の手順へ

途中で 1 つでも失敗したら、残りの手順は実行せずに NEEDS_FIX として feedback に記録する。ただし、別系統の手順 (例: ログイン系とダッシュボード系) は独立して実行する。

## 敵対的テスト (Web 固有)

契約の内側で能動的に試す:

| カテゴリ | 具体操作 |
|---|---|
| **二重送信** | Submit ボタンを 100ms 以内に 2 回クリック。重複リクエストが送信されないか |
| **XSS 入力** | `<script>alert(1)</script>` をフォームに入れる。エスケープされているか |
| **SQL 風入力** | `' OR 1=1--` を入れる。サーバーエラーを引き起こさないか |
| **path traversal** | URL パラメータや filename 入力に `../../../etc/passwd` を入れる |
| **巨大入力** | 10,000 文字の string を入れる。UI が崩れないか、サーバーが timeout しないか |
| **Unicode / 絵文字** | ユーザー名に `👨‍👩‍👧‍👦` や `𝕏` を入れる |
| **ブラウザ戻る** | 画面遷移後にブラウザバック → 前の画面の state が stale でないか |
| **タブ並行** | 同じセッションで 2 タブ開いて並行操作 |

全部試す必要はない。契約の Scope に応じて関連するものを選ぶ。

## エラー検知

### コンソールエラー
```
browser_console_messages()
```
- `error` / `warning` レベルの出力を確認
- React の "Each child in a list should have a unique key" のような警告は軽微だが、契約の品質基準で `warning 0 件` が要求されていれば NEEDS_FIX

### ネットワーク異常
```
browser_network_requests()
```
- 4xx / 5xx の HTTP レスポンスを確認
- 期待されていない 404 (壊れたリンク) は NEEDS_FIX
- サーバー側 500 はクリティカル、再現手順を feedback に記録

### スクリーンショット証拠
```
browser_take_screenshot(filename="issue-<id>-bug-login-fail.png")
```
- NEEDS_FIX のとき、バグの視覚的証拠を撮って `docs/feedback/issue-<id>.md` に相対パスで埋め込む
- PASSED のときはスクリーンショットは不要 (ノイズになる)

## 回帰テストの実施

前 Sprint までに PASSED した機能が壊れていないか。特に以下を再確認:

1. ログイン / 認証フロー
2. 主要 CRUD 操作
3. ナビゲーション (サイドバー、ヘッダー、フッターのリンク)
4. フォームのバリデーション

前の Issue の `docs/feedback/issue-<prev>.md` の PASSED 項目を読み、同じ手順を今回のコードで実行する。

## 禁止事項

- `browser_evaluate` で DOM を書き換えて状態を作る (評価は natural flow で行う)
- 手動 CSS セレクタで XPath を書く
- `sleep` や固定 timeout で flaky を誤魔化す
- `browser_close` せずに終了する

## 参照

- `skills/skeptical-evaluation/` — 合否判定の 9 原則と 5 基準スコア
- `skills/test-integrity/` — generator のテスト改変検知
- `skills/initializer-protocol/` — アプリ起動プロトコル
- `skills/ui-design-quality/` — デザイン品質の advisory 評価 (プロジェクトが opt-in していれば併用)
