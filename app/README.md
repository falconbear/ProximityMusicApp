# Proximity Music App (Flutter, mock UI)

近接ベースの音楽交換 / 再生アプリの Flutter 実装 (現在はモック UI、近接通信は未実装)。

## クイックスタート

リポジトリルートで:

```bash
./init.sh
```

`./init.sh` は冪等で、Flutter SDK が PATH にあれば `flutter pub get` / `flutter analyze` / `flutter test` を `app/` 配下で実行します。SDK が見つからない場合は警告を出して `exit 0` で終了します (CI 環境では `./init.sh --strict` を使うと SDK 不在時に `exit 1`)。

## 起動方法

### Web (Tailscale 経由でスマホからアクセスする場合)

```bash
cd app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

別ターミナルで Tailscale URL を表示:

```bash
bash bin/show-test-url.sh 8080
```

`--web-hostname 0.0.0.0` を必ず付けて全インターフェースで listen させてください (Tailscale 越し / 同一 LAN の別端末から開けるようになります)。

### iOS / Android (実機検証)

```bash
flutter run -d ios       # iOS シミュレータ
flutter run -d android   # Android エミュレータ
```

実機テストは近接 API の検証で必須。

## テスト

```bash
cd app
flutter test
```

CI (`.github/workflows/flutter-ci.yml`) は subosito/flutter-action を使い、push と pull_request の両方で `flutter pub get` / `dart format --set-exit-if-changed` / `flutter analyze` / `flutter test` を実行します。

## ディレクトリ構成 (Issue #1 で導入した層分離)

```
app/lib/
├── main.dart                                    # 16 行: runApp のみ + ProximityMusicApp の re-export
├── app.dart                                     # ProximityMusicApp (MaterialApp.router + GoRouter)
├── domain/
│   └── entities/
│       └── track.dart                           # Track entity (純 Dart)
├── data/
│   └── services/
│       └── audio_service.dart                   # just_audio をラップ
└── presentation/
    ├── state/
    │   └── providers.dart                       # Riverpod providers
    ├── pages/
    │   ├── dashboard_page.dart                  # ホーム画面
    │   └── player_page.dart                     # 再生画面
    └── widgets/
        └── mini_player.dart                     # ボトムのミニプレイヤー
```

依存方向は `presentation → data → domain` の単方向。Domain は Flutter / Riverpod / just_audio / go_router を import しません。

## モックの使い方

- ホーム画面で「Discovery」スイッチを ON にし、FAB「Simulate Discovery」でキューに曲が追加されます。
- AppBar 右の `queue_music` アイコンで Player 画面に遷移できます。
- AppBar の `fingerprint` アイコンで Anonymous Session ('/session') 画面に遷移できます。

## Anonymous Session (Issue #4)

Sprint 04 で導入した匿名セッション管理画面 ('/session') では、現在の匿名 ID
を `XXXX-XXXX` 形式のフィンガープリントで表示し、'今すぐ更新' ボタンで即時
ID rotation を実行できます。Domain 層 (`IdRotationPolicy`) はアプリ起動毎と
15 分間隔のいずれか早い方でローテートし、ローテート後は旧 ID で開いた
セッションを自動切断します。

**Sprint 04 spike**: Native session transport (`MethodChannel
proximity_music_app/session` + `EventChannel
proximity_music_app/session/disconnects`) は Platform Channel の wire-up
のみで、iOS/Android のネイティブ側は意図的に `transport_unavailable` を返す
スタブです。`StubKeyExchange` も sha256 ベースの MVP placeholder で、実
ECDH (X25519) 鍵交換は Issue #5 以降で差し替えます。

**ブランチ並列の注記**: 本 sprint は main から分岐しており Issue #2
(SettingsPage) / Issue #3 (DiscoverPage / Peer entity) はマージ前です。
Discover ピアタップ→セッション開始の wiring と、Settings からの '匿名 ID
即時更新' UI 統合は両 Issue マージ後の follow-up commit で実施します。

## 次の実装ステップ

- 近接通信: Platform Channel 経由で MultipeerConnectivity (iOS) / Nearby Connections (Android) のスパイク。
- 再生: `just_audio` + `audio_service` でバックグラウンド再生を実装、モックキューと差し替え。
- ストレージ: Hive / Drift でお気に入り・ブロックリスト・キューを永続化。
- バックエンド: Cloud Run + Firestore / Cloud SQL で匿名 ID / ブロックリスト / メトリクス API を用意し、Feature Flag で段階導入。
