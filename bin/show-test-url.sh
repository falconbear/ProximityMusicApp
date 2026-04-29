#!/usr/bin/env bash
# show-test-url.sh — 起動中の dev server のアクセス URL を一覧表示する。
#
# 用途: スマホから Tailscale 経由でテストしたい / 同じ Wi-Fi の別端末で確認したい
#       といった場合に、AI が dev server を起動した直後にこれを叩いてユーザーに
#       URL を見せる。
#
# 前提: dev server が 0.0.0.0 (全 interface) で listen していること。
#       localhost (127.0.0.1) のみだと LAN / Tailscale URL では接続できない。
#
# Usage:
#   bin/show-test-url.sh <port> [<port> ...]
#
# 例:
#   bin/show-test-url.sh 3000
#   bin/show-test-url.sh 3000 8000

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <port> [<port> ...]" >&2
  exit 2
fi

# ---------------- LAN IP 検出 (macOS) ----------------

LAN_IP=""
for iface in en0 en1 en2 en3; do
  candidate=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
  if [ -n "$candidate" ]; then
    LAN_IP="$candidate"
    break
  fi
done

# ---------------- Tailscale 検出 ----------------

TS_IP=""
TS_HOST=""
TS_RUNNING=0

if command -v tailscale >/dev/null 2>&1; then
  if tailscale status >/dev/null 2>&1; then
    TS_RUNNING=1
    TS_IP=$(tailscale ip -4 2>/dev/null | head -1 || true)
    # MagicDNS のホスト名を取得 (短縮形が使える)
    TS_HOST=$(tailscale status --json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    name = d.get('Self', {}).get('DNSName', '').rstrip('.')
    print(name)
except Exception:
    pass
" 2>/dev/null || true)
  fi
fi

# ---------------- 出力 ----------------

for PORT in "$@"; do
  echo "Port $PORT:"
  echo "  - PC local:    http://localhost:$PORT"
  if [ -n "$LAN_IP" ]; then
    echo "  - Same Wi-Fi:  http://$LAN_IP:$PORT"
  fi
  TS_URL=""
  if [ -n "$TS_HOST" ]; then
    TS_URL="http://$TS_HOST:$PORT"
    echo "  - Tailscale:   $TS_URL  ⭐ (スマホ・外出先でも開ける)"
  elif [ -n "$TS_IP" ]; then
    TS_URL="http://$TS_IP:$PORT"
    echo "  - Tailscale:   $TS_URL  ⭐ (スマホ・外出先でも開ける)"
  fi

  # Expo (Metro bundler) のヒント: ポート 8081 は Expo の慣例
  if [ "$PORT" = "8081" ]; then
    echo "  - Expo Go:     上記 URL を Expo Go アプリの \"Enter URL manually\" に入力"
  fi

  # QR code (--qr オプション、または qrencode が存在し Tailscale URL があれば)
  if [ -n "$TS_URL" ] && [ "${SHOW_QR:-0}" = "1" ]; then
    if command -v qrencode >/dev/null 2>&1; then
      echo "  QR code (Tailscale):"
      echo "$TS_URL" | qrencode -t ANSIUTF8 | sed 's/^/    /'
    else
      echo "  Note: \`brew install qrencode\` で QR コード表示を有効化できる" >&2
    fi
  fi
  echo
done

if [ "$TS_RUNNING" -eq 0 ]; then
  echo "Note: Tailscale が起動していません。スマホから外部アクセスする場合は" >&2
  echo "      \`tailscale up\` で起動してください (または既にログイン済みなら自動起動を確認)。" >&2
fi
