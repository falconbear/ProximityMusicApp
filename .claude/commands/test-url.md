---
description: 起動中の dev server のアクセス URL を表示。スマホから Tailscale 経由でテストするとき / 同じ Wi-Fi の別端末で確認するときに使う。
---

`bin/show-test-url.sh $ARGUMENTS` を実行し、結果をユーザーにそのまま表示してください。

## 入力

`$ARGUMENTS` に空白区切りで port 番号を 1 つ以上。

```
/test-url 3000
/test-url 3000 8000
```

`$ARGUMENTS` が空なら「port 番号を指定してください (例: `/test-url 3000`)」と返して停止。

## 出力に含まれる URL

- **PC local** (`http://localhost:<port>`) — PC 上のブラウザ用
- **Same Wi-Fi** (`http://<LAN-IP>:<port>`) — 同じ Wi-Fi 内の他端末用
- **Tailscale** (`http://<machine>.<tailnet>.ts.net:<port>`) — どこからでも (スマホでも) 接続可

## 前提

dev server が **0.0.0.0** で listen していること (localhost のみだと LAN / Tailscale URL では繋がらない)。

主要フレームワークの起動オプション:

| フレームワーク | コマンド例 |
|---|---|
| Vite | `vite --host` |
| Next.js | `next dev -H 0.0.0.0` |
| Express | `app.listen(port, '0.0.0.0')` |
| Python http.server | `python -m http.server --bind 0.0.0.0 <port>` |
| Flask | `app.run(host='0.0.0.0')` |
| FastAPI / uvicorn | `uvicorn main:app --host 0.0.0.0` |

## いつ叩くか

- ユーザーが「スマホで動作確認したい」と言ったとき
- AI が dev server を起動したとき (CLAUDE.md の Tailscale convention に従って自動で実行)
- 既に動いている server を別端末から見たいとき (port 番号は自分で覚えておく)

## 実行例

```
$ /test-url 3000
Port 3000:
  - PC local:    http://localhost:3000
  - Same Wi-Fi:  http://192.168.68.58:3000
  - Tailscale:   http://macbook-air.tailcf4c9f.ts.net:3000  ⭐ (スマホ・外出先でも開ける)
```

## 関連

- `bin/show-test-url.sh` — 実体のスクリプト
- CLAUDE.md「実機テスト / スマホからの確認」節 — AI 側の規約
