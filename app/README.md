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

## ディレクトリ構成 (Issue #1 で導入した層分離 + Issue #6 で拡張)

```
app/lib/
├── main.dart                                    # runApp + ProximityMusicApp の re-export
├── app.dart                                     # ProximityMusicApp (MaterialApp.router + GoRouter)
├── domain/
│   ├── entities/
│   │   └── track.dart                           # Track entity (純 Dart)
│   └── playback/                                # Issue #6: 純 Dart 再生ドメイン
│       ├── playback_queue.dart                  # FIFO キュー
│       ├── favorites_store.dart                 # in-memory お気に入り Set
│       ├── audio_gateway.dart                   # 抽象: play(Track)/stop()
│       ├── playback_track_source.dart           # 抽象: Stream<Track>
│       └── playback_controller.dart             # キュー + favorites + ゲートウェイ
├── data/
│   └── services/
│       ├── audio_service.dart                   # just_audio をラップ (AudioGateway 実装)
│       ├── fake_track_source.dart               # テスト / 模擬 Discovery 用
│       └── recording_audio_gateway.dart         # widgetTest 用 Recording fake
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

### Issue #6 再生ドメイン (`domain/playback/`)

- **PlaybackQueue**: 受信完了 Track の FIFO。`enqueue` / `skip` / `clear`。
- **FavoritesStore**: `Set<Track>` ベースの in-memory お気に入り。`pickShuffled(Random)` でフォールバック曲を選ぶ (Issue #9 で永続化、#10 で設定 UI)。
- **AudioGateway** (抽象): `play(Track)` / `stop()` のみ。`AudioService` が本実装、`RecordingAudioGateway` がテスト fake。
- **PlaybackTrackSource** (抽象): `Stream<Track>`。Issue #5 の本物の `TrackReceiver` がここに繋がる予定。本 Sprint では `FakeTrackSource` のみ提供。
- **PlaybackController**: 受信→自動再生 / 再生中→キュー追加 / スキップ→次曲 / 空キュー→お気に入りフォールバック (ON 時) or 停止。Riverpod 側 (`playbackControllerProvider`) が `nowPlayingProvider` / `queueProvider` への投影をブリッジする。

## モックの使い方

- ホーム画面で「Discovery」スイッチを ON にし、FAB「Simulate Discovery」でキューに曲が追加されます。
- AppBar 右の `queue_music` アイコンで Player 画面に遷移できます。

## オンボーディング / 利用規約 (Issue #2)

初回起動時は **Welcome → Privacy & Battery → Permissions → Consent → Dashboard**
の 4 ステップ Onboarding を経由します。Consent 画面では利用規約 / プライバシー
ポリシーを `SingleChildScrollView` でアプリ内全文表示し、「同意する」チェックを
入れた後にのみ「同意して続行」が押下可能になります。

利用規約バージョン (`currentTermsVersion`) を上げると、起動時に再同意フローへ
強制遷移し、規約画面と「同意する」「アプリを終了」の 2 ボタンしか操作できま
せん (spec 機能 13 受け入れ基準 5)。

Bluetooth 権限が `denied` の場合は Dashboard 上部に
`近接機能は無効です。設定から有効化できます` の Banner が常時表示されます。
Banner は表示中も Discovery スイッチや Player 画面遷移など他機能を阻害しま
せん。設定画面 (`/settings`) には「権限を再要求」ボタンの placeholder のみ
配置しています (本実装は別 Issue)。

なお `onboardingStateProvider` の **テスト用デフォルト** は `completed` で、
`widget_test.dart` のような override 無し pumpWidget は Dashboard に直接
着地します。実機ビルドでは `main.dart` 側で `notStarted` を override して
注入することで Welcome から起動します。

## 次の実装ステップ

- 近接通信: Platform Channel 経由で MultipeerConnectivity (iOS) / Nearby Connections (Android) のスパイク。
- 再生: `just_audio` + `audio_service` でバックグラウンド再生を実装、モックキューと差し替え。
- ストレージ: Hive / Drift でお気に入り・ブロックリスト・キューを永続化。
- バックエンド: Cloud Run + Firestore / Cloud SQL で匿名 ID / ブロックリスト / メトリクス API を用意し、Feature Flag で段階導入。
