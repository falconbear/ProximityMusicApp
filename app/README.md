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
│   ├── entities/
│   │   ├── track.dart                           # Track entity (純 Dart)
│   │   ├── peer.dart                            # Peer entity (Issue #3)
│   │   ├── bluetooth_state.dart                 # BluetoothState enum (Issue #3)
│   │   └── discovery_status.dart                # DiscoveryStatus enum (Issue #3)
│   └── services/
│       ├── discovery_source.dart                # DiscoverySource interface (Issue #3)
│       └── peer_registry.dart                   # PeerRegistry (重複なし + ttl prune)
├── data/
│   └── services/
│       ├── audio_service.dart                   # just_audio をラップ
│       ├── fake_discovery_source.dart           # テスト/dev 用 (Issue #3)
│       └── native_discovery_source.dart        # Platform Channel 経由 (Issue #3 spike)
└── presentation/
    ├── state/
    │   ├── providers.dart                       # 既存の audio / queue providers
    │   ├── discovery_providers.dart             # Discover 用 Riverpod (Issue #3)
    │   └── discovery_controller.dart            # Pure Dart コントローラ (Issue #3)
    ├── pages/
    │   ├── dashboard_page.dart                  # ホーム画面
    │   ├── player_page.dart                     # 再生画面
    │   └── discover_page.dart                   # Discover ページ (Issue #3)
    └── widgets/
        ├── mini_player.dart                     # ボトムのミニプレイヤー
        ├── ripple_radar.dart                    # 波紋アニメ (Issue #3)
        ├── peer_avatar.dart                     # 36 通り幾何学アイコン (Issue #3)
        └── peer_list_tile.dart                  # ピア一覧タイル + 相対時刻 (Issue #3)
```

依存方向は `presentation → data → domain` の単方向。Domain は Flutter / Riverpod / just_audio / go_router を import しません。

## モックの使い方

- ホーム画面で「Discovery」スイッチを ON にし、FAB「Simulate Discovery」でキューに曲が追加されます。
- AppBar 右の `queue_music` アイコンで Player 画面に遷移できます。
- AppBar 右の `radar` アイコンで `/discover` (Discover ページ) に遷移できます。

## Discover ページ (Issue #3)

Discover タブは近接ピアの検出 UI です。

- **検知トグル Switch**: 上部の Switch を ON にすると `DiscoveryController` が `DiscoverySource.start()` を呼び、波紋アニメーションと共にピア一覧が更新されます。OFF で停止します。
- **波紋レーダー** (`RippleRadarView`): スキャン中は 3 重の同心円が外側に拡大していくアニメーション。停止中は静的な中心アイコンのみ。
- **ピア一覧**: `PeerListTile` (匿名 ID 8 桁 + 相対時刻) が `lastSeenAt` 降順で並びます。`PeerAvatar` は `avatarSeed` から決まる 36 通り (色 6 × 形 6) の幾何学アイコン。
- **空状態**: 「周囲に誰もいません。場所を変えてみてください」を表示。
- **Bluetooth OFF / 未許可**: 「Bluetooth が無効です。設定を確認してください」のフルスクリーンエラー UI を表示しスキャンは開始しません。
- **下部サマリ**: 「N 台検知中」 (`peers.length`) を常時表示。`PeerRegistry.prune` により 60 秒間再検知されないピアは自動消去されます。

**Native discovery is a Sprint 03 spike** — only the Platform Channel scaffolding (`proximity_music_app/discovery` MethodChannel + 2 EventChannels) is in place. Real BLE/Nearby スキャンは Issue #4 以降で実装します。本 Sprint のデフォルト Provider は `FakeDiscoverySource` で、デモ用ピア 3 件が 5 秒間隔で出現します。

### iOS シミュレータ / Android エミュレータでのビルド確認

```bash
cd app
flutter build ios --no-codesign --simulator   # iOS シミュレータ向けビルド
flutter build apk --debug                     # Android エミュレータ向けビルド
flutter run -d ios                            # 実機/シミュレータで起動
flutter run -d android                        # 実機/エミュレータで起動
```

Android 12 以降では BLE スキャンに `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (12+) と `ACCESS_FINE_LOCATION` (12 未満) を `AndroidManifest.xml` で宣言済み。実 OS パーミッションのダイアログ呼び出しは Issue #4 でハンドリングします。

## 次の実装ステップ

- 近接通信 (Issue #4 以降): Platform Channel 経由で CoreBluetooth (iOS) / Nearby Connections (Android) の実装本体を `NativeDiscoverySource` の channel 先に組み込みます。
- 再生: `just_audio` + `audio_service` でバックグラウンド再生を実装、モックキューと差し替え。
- ストレージ: Hive / Drift でお気に入り・ブロックリスト・キューを永続化。
- バックエンド: Cloud Run + Firestore / Cloud SQL で匿名 ID / ブロックリスト / メトリクス API を用意し、Feature Flag で段階導入。
