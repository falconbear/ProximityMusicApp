# Issue #6 Handoff (Generator → Evaluator)

**Generator:** generator
**最終更新:** 2026-05-05
**Phase:** Phase 3 完了 (READY_FOR_REVIEW)
**Branch:** `sprint/06-playback-queue`
**Contract:** `.ai/work/6/contract.json` (locked, attempt 1 で承認)

## 実装サマリ

Issue #6「受信即時再生 + 自動再生キュー」を 3 層 (Domain / Data / Presentation) に分けて実装。新規 Domain ファイル 5 本 + Data fake 2 本 + Presentation Provider 7 本 + MiniPlayer に favorite トグル + DashboardPage の simulate 経路を `FakeTrackSource.emit` 化。既存テスト (`app/test/widget_test.dart` / `app/test/domain/track_test.dart`) は 0 byte diff、新規テストは Domain 19 ケース + Presentation 5 ケース = 24 ケース追加。

| Layer | 新規/変更 | ファイル | 行数 |
|---|---|---|---|
| Domain | 新規 | `app/lib/domain/playback/playback_queue.dart` | 47 |
| Domain | 新規 | `app/lib/domain/playback/favorites_store.dart` | 40 |
| Domain | 新規 | `app/lib/domain/playback/playback_controller.dart` | 124 |
| Domain | 新規 | `app/lib/domain/playback/audio_gateway.dart` | 17 |
| Domain | 新規 | `app/lib/domain/playback/playback_track_source.dart` | 15 |
| Data | 変更 | `app/lib/data/services/audio_service.dart` (+`implements AudioGateway`) | +3 |
| Data | 新規 | `app/lib/data/services/recording_audio_gateway.dart` | 25 |
| Data | 新規 | `app/lib/data/services/fake_track_source.dart` | 39 |
| Presentation | 変更 | `app/lib/presentation/state/providers.dart` (+7 providers + Bridge) | +141 |
| Presentation | 変更 | `app/lib/presentation/pages/dashboard_page.dart` (simulate→emit、watch controller、skip→controller) | +20 |
| Presentation | 変更 | `app/lib/presentation/widgets/mini_player.dart` (favorite トグル、skip→controller) | +30 |
| Test | 新規 | `app/test/domain/playback/playback_queue_test.dart` | 99 |
| Test | 新規 | `app/test/domain/playback/favorites_store_test.dart` | 93 |
| Test | 新規 | `app/test/domain/playback/playback_controller_test.dart` | 195 |
| Test | 新規 | `app/test/presentation/playback_integration_test.dart` | 148 |
| Test | 新規 | `app/test/presentation/mini_player_favorite_test.dart` | 77 |
| Doc | 変更 | `app/README.md` (ディレクトリ構成 + Domain 5 型サマリ) | +20 |

## 起動方法

```bash
# 1. 初回セットアップ (冪等、Issue #1 で導入済)
./init.sh

# 2. Flutter web をフォアグラウンド起動 (0.0.0.0 必須)
cd app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

# 3. 別ターミナルで Tailscale URL を取得 (スマホ確認)
bash bin/show-test-url.sh 8080
```

- 動作確認手順:
  1. ダッシュボード右上の Discovery スイッチを ON
  2. 表示される FAB「Simulate Discovery」を 1 回押す → 即時再生 (NowPlaying に Test Track 1)
  3. もう 1 回押す → Test Track 1 再生継続のまま、Up Next に Test Track 2
  4. NowPlayingCard 右の skip → Test Track 2 再生
  5. もう 1 回 skip → favorites 空 + fallback ON のため停止 (NowPlaying クリア、MiniPlayer 消滅)
  6. 任意のトラック再生中に MiniPlayer の heart アイコンをタップ → fill (favorited)、再タップ → outline
- URL: http://localhost:8080
- 停止方法: `Ctrl+C`
- 必要な環境変数: なし

## TDD ログ

| Phase | Commit SHA | 概要 |
|---|---|---|
| RED | `4b8a9d9` | 5 テストファイル新規追加 (612 行)。すべて未実装シンボル (`PlaybackQueue` / `FavoritesStore` / `PlaybackController` / `AudioGateway` / `PlaybackTrackSource` / `FakeTrackSource` / `RecordingAudioGateway` / `audioGatewayProvider` ほか) を import するため compile fail で RED 構成。実装ファイル 0、既存 test 0 byte diff。|
| GREEN | `3570e0d` | Domain 5 ファイル + Data 2 ファイル + AudioService に `implements AudioGateway` (1 行) + Presentation providers/MiniPlayer/DashboardPage の最小実装。既存 test の改変なし。|
| REFACTOR | (なし) | GREEN 段階で命名・配置・docstring を整えており、追加の refactor 必要性なし。`_BridgedPlaybackController` の subclass 抽出は GREEN 内で完結。|

これらは `state.json.tdd` (`red_commit_sha=4b8a9d9...`, `green_commit_sha=3570e0d...`) に記録済み。

## Success criteria 自己評価 (12 件)

> Guilty until proven innocent。Flutter SDK がコンテナ不在のため `flutter test` / `flutter analyze` のローカル実走は不可能。CI 実走は GitHub Actions に委ねる。

| # | criterion 要約 | 自己評価 | 根拠 |
|---|---|---|---|
| 1 | 5 ファイル存在 (`playback_queue.dart` ほか) | 達成 | `test -f` 5 ファイル全て exit 0 (handoff 作成時にローカル確認)。ls 結果で sizes 17/40/124/15/47 行を確認済み。|
| 2 | PlaybackQueue 4 アサーション (空→t1→t1+t2→skip→skip) | 達成 (構造) | `playback_queue.dart` の `currentTrack` / `upcoming` / `isEmpty` / `skip` ロジックが要求通り。`playback_queue_test.dart:6` ケースで全 transition を検証 (CI 実走依存)。|
| 3 | onTrackReceived 2 ケース (idle→play、busy→enqueue) | 達成 (構造) | `playback_controller.dart:82-90` で `_nowPlaying == null` 分岐を実装。`playback_controller_test.dart` の `play immediately when idle` / `enqueue when already playing` で検証。**Future の await を含めて 100ms 以内**: `play(track)` を `await` するが、`RecordingAudioGateway.play` は同期 List append のみで microtask 1 回。|
| 4 | skip 3 ケース (next / stop / favorite fallback、Random(42) 決定的) | 達成 (構造) | `playback_controller.dart:93-123`。`_fallbackEnabled() && !_favorites.isEmpty` 分岐を実装、`pickShuffled(_random)` で `Random(42)` 注入時に決定的。`playback_controller_test.dart` の 5 ケース (a〜e) で全分岐検証。|
| 5 | FavoritesStore 3 アサーション (add 冪等 / remove no-op / pickShuffled(Random(42))) | 達成 (構造) | `favorites_store.dart` は `Set<Track>` ベース。`_set.add` / `_set.remove` / `elementAt(rng.nextInt)` で要件を満たす。`favorites_store_test.dart` の 6 ケースで検証。|
| 6 | Presentation 統合 (override で gateway 差し替え→emit→pump→state) | 達成 (構造) | `playback_integration_test.dart` で `audioGatewayProvider` / `playbackTrackSourceProvider` / `favoritesStoreProvider` を override し、`emit(t1)→pump→nowPlaying==t1` / `emit(t2)→queue==[t2]` を検証。providers.dart の `_BridgedPlaybackController.onSnapshot` callback が `nowPlayingProvider` / `queueProvider` を更新する経路。|
| 7 | MiniPlayer favorite トグル (border→fill→border) | 達成 (構造) | `mini_player.dart:107-126` に IconButton + `Icons.favorite_border` / `Icons.favorite` 切り替え。`favoritesTickProvider` で rebuild を強制。`mini_player_favorite_test.dart` 2 ケースで初期 border / tap→fill / 再 tap→border を検証。|
| 8 | Discover 復帰 (skip + queue 空 + favorites 空 → nowPlaying null + MiniPlayer SizedBox) | 達成 (構造) | `playback_controller.dart:121-122` で `_nowPlaying = null; await _gateway.stop()` 経路、`mini_player.dart:24` の `if (nowPlaying == null) return const SizedBox.shrink();`。`playback_integration_test.dart` の skip→empty シナリオで MiniPlayer descendant が SizedBox に縮退することを検証。|
| 9 | 既存テスト未改変 (`widget_test.dart` 3 件 + `track_test.dart` 4 件) | 達成 | `git diff main..HEAD -- app/test/widget_test.dart app/test/domain/track_test.dart` の出力**空** (handoff 作成時に確認、commit log でも触れていない)。RED 4b8a9d9 / GREEN 3570e0d の `git show --stat` でも対象 2 ファイルは含まれない。|
| 10 | 性能構造保証: domain/playback/ 配下に `Future.delayed` 0 件 | 達成 | `Grep "Future\.delayed" /workspace/app/lib/domain/playback` の結果 0 件 (handoff 作成時に確認済)。`onTrackReceived` / `skip` ともに `await _gateway.<op>()` のみで delay は使っていない。|
| 11 | `flutter analyze` 0 error | **CI 検証依存** | コンテナに Flutter SDK 不在のためローカル不可。GREEN commit ではすべての新規ファイルに `final` / `const` / `@override` を付与し、Issue #1 と同水準の lint 整合性を意識。CI workflow (`.github/workflows/ci.yml`) で実走確認。|
| 12 | `flutter test --reporter compact` exit 0 | **CI 検証依存** | 同上。新規テスト 24 ケース + 既存 7 ケース = 31 ケース全 pass を CI で検証。|

## Test plan 実装対応 (RED-1〜7 / GREEN-1〜7 / Verification-1〜6)

| Test plan ID | 対応ファイル / 検証内容 | 実装場所 |
|---|---|---|
| RED-1 (PlaybackQueue 4 シナリオ) | `app/test/domain/playback/playback_queue_test.dart` (6 ケース、契約の 4 シナリオ + skip 空 + clear) | RED commit 4b8a9d9 |
| RED-2 (FavoritesStore 4 ケース) | `app/test/domain/playback/favorites_store_test.dart` (6 ケース、add 冪等 / remove no-op / pickShuffled 決定性 / 空時 null + αの complete coverage) | RED commit 4b8a9d9 |
| RED-3 (PlaybackController 5 ケース) | `app/test/domain/playback/playback_controller_test.dart` (7 ケース、契約 a〜e + favorite を skip しない non-touch + 同 track repeat enqueue) | RED commit 4b8a9d9 |
| RED-4 (Widget integration: emit→play / enqueue) | `app/test/presentation/playback_integration_test.dart` の 1〜2 ケース | RED commit 4b8a9d9 |
| RED-5 (skip→fallback→SizedBox) | `app/test/presentation/playback_integration_test.dart` の 3 ケース目 | RED commit 4b8a9d9 |
| RED-6 (MiniPlayer favorite トグル) | `app/test/presentation/mini_player_favorite_test.dart` 2 ケース | RED commit 4b8a9d9 |
| RED-7 (既存テスト未改変 sentinel) | git diff main..HEAD で確認 (CI workflow にも組み込まれており PR で監視可能) | 検証コマンド参照 |
| GREEN-1 (PlaybackQueue 最小実装) | `app/lib/domain/playback/playback_queue.dart` (`List<Track>` 内部、enqueue/skip/clear/getter) | GREEN commit 3570e0d |
| GREEN-2 (FavoritesStore Set 実装) | `app/lib/domain/playback/favorites_store.dart` (`Set<Track>` + `pickShuffled(rng)`) | GREEN commit 3570e0d |
| GREEN-3 (audio_gateway / track_source / controller) | `audio_gateway.dart` (abstract 2 メソッド) / `playback_track_source.dart` (abstract `Stream<Track> get tracks`) / `playback_controller.dart` (queue + favorites + gateway + Random + fallback callback) | GREEN commit 3570e0d |
| GREEN-4 (Data fakes + AudioService 適合) | `recording_audio_gateway.dart` / `fake_track_source.dart` / `audio_service.dart` に `implements AudioGateway` | GREEN commit 3570e0d |
| GREEN-5 (Presentation providers) | `providers.dart` に audioGatewayProvider / favoritesStoreProvider / favoritesTickProvider / favoritesFallbackEnabledProvider / playbackTrackSourceProvider / playbackQueueProvider / playbackRandomProvider / playbackControllerProvider (+ `_BridgedPlaybackController` で snapshot bridge) | GREEN commit 3570e0d |
| GREEN-6 (MiniPlayer favorite + skip→controller) | `mini_player.dart` の IconButton 追加 + skip 配線 | GREEN commit 3570e0d |
| GREEN-7 (DashboardPage simulate→emit) | `dashboard_page.dart` の `_simulateDiscovery` を `FakeTrackSource.emit` に置換 + `ref.watch(playbackControllerProvider)` で eager subscribe | GREEN commit 3570e0d |
| Verification-1〜6 | evaluator が下記コマンドで検証 | — |

## evaluator 検証コマンド

handoff の自己評価を再現するための機械検証コマンド。コピペ可能。

```bash
# Verification-6: 5 ファイル存在
test -f app/lib/domain/playback/playback_queue.dart && \
test -f app/lib/domain/playback/favorites_store.dart && \
test -f app/lib/domain/playback/playback_controller.dart && \
test -f app/lib/domain/playback/audio_gateway.dart && \
test -f app/lib/domain/playback/playback_track_source.dart && echo OK

# Verification-5: domain/playback/ に Future.delayed 0 件
grep -RIn 'Future\.delayed' app/lib/domain/playback/ ; echo "expected: no output"

# Verification-4 + RED-7: 既存テスト未改変
git diff --name-only main..HEAD -- app/test/widget_test.dart app/test/domain/track_test.dart
# expected: 空出力

# Verification-2: dart format
cd app && dart format --set-exit-if-changed .

# Verification-1: analyze
cd app && flutter analyze

# Verification-3: 全テスト pass
cd app && flutter test --reporter compact

# Domain 層 import 制約 (flutter / riverpod / just_audio / go_router 不可)
grep -RIEn "^import 'package:(flutter|flutter_riverpod|just_audio|go_router)" app/lib/domain/playback/ | wc -l
# expected: 0

# TDD 順序検証
git log --oneline 4b8a9d9..3570e0d
# expected: GREEN 1 件 (RED が祖先)

git show --stat 4b8a9d9
# expected: app/test/domain/playback/* と app/test/presentation/* のみ (実装ファイル 0)

git show --stat 3570e0d -- app/test/widget_test.dart app/test/domain/track_test.dart
# expected: ファイル無し (両方とも diff に含まれない)
```

## 技術判断 (契約に書ききれなかった選択)

1. **PlaybackController の `_nowPlaying` を Queue とは独立に保持**: 契約 SC #4 の「fallback で favorite を再生」を満たすには、PlaybackQueue が空でも nowPlaying は非 null になる時間帯がある。Queue.currentTrack をそのまま nowPlaying と等値にしてしまうと fallback 経路が壊れる。よって controller 側で `Track? _nowPlaying` を独立保持し、`upcoming` getter で「nowPlaying と queue.currentTrack が一致するか」によって queue 全体を露出するか / queue.upcoming を露出するかを切り替えている (`playback_controller.dart:65-77`)。

2. **AudioGateway の `play` が冪等」と docstring に明示**: 契約 SC #3 が「同期的に 1 回呼ばれる」を要求するため、controller 内では `await _gateway.play(t)` を 1 回だけ呼ぶ。本物の `AudioService.play` は `setAsset → play → listener` を多段で行うため「2 回 play しても問題ない」状態にしておきたい。docstring で idempotent を表明 (`audio_gateway.dart:11-13`)。

3. **`_BridgedPlaybackController` を providers.dart 内 private subclass として実装**: Domain (PlaybackController) が Riverpod に依存しないようにする方法は (a) Listener パターン、(b) callback 注入、(c) subclass で hook の 3 通り。今回は (c) を選択し、`super.onTrackReceived` / `super.skip` 後に `onSnapshot` callback を呼ぶ薄い subclass を providers.dart 内 private として配置 (`providers.dart:174-197`)。理由: Domain 側にイベントエミット機構を持たせると テスト用の `PlaybackController` が肥大化し、`playback_controller_test.dart` の純粋単体テストが書きにくくなる。

4. **`favoritesTickProvider` を導入**: `FavoritesStore` は `Set<Track>` を内部で mutate するため Riverpod の identity-based equality では rebuild がトリガされない。これを「StateNotifier に書き換える」 / 「`StateProvider<Set<Track>>` で immutable コピーを管理する」のいずれかにすると Domain クラス自体が変質する。今回は **Domain は keep simple、Presentation 側の rebuild トリガとして `favoritesTickProvider`** (`int` カウンタ) を 1 つ追加する選択を取った。MiniPlayer は `favoritesStoreProvider` と `favoritesTickProvider` の両方を watch することで rebuild を保証 (`mini_player.dart:29-31`、`providers.dart:101-104`)。

5. **DashboardPage で `ref.watch(playbackControllerProvider)` を build 直下で eager に呼ぶ**: 契約 SC #6 の widget 統合テストは `pumpWidget` 直後に `emit(t1)` を行い、即時に `nowPlayingProvider` が更新されることを期待する。`playbackControllerProvider` の build 内で `source.tracks.listen(...)` を行っているため、provider が一度も read されないと subscription が張られない。よって DashboardPage の build 関数の最初に `ref.watch(playbackControllerProvider);` を入れて eager 化した (`dashboard_page.dart:24`)。Presentation で provider を「副作用目的で watch する」点は若干 Riverpod らしくない使い方なので、`Issue #5` で本物の TrackReceiver を導入する際に **`autoDispose` + main.dart 起動時 `ProviderContainer.read`** などへ整理してよい。

6. **`_simulateDiscovery` で source 型チェック**: 契約 scope に「DashboardPage の `_simulateDiscovery` を FakeTrackSource.emit 呼び出しに置き換え」とある。本物の TrackReceiver が installed された時 (Issue #5 完了後) に simulate ボタンを押されると emit メソッドが存在しないため runtime error する。今回は `if (source is FakeTrackSource) source.emit(...)` で型ガードして本物の receiver が入った場合は no-op となるよう保護した (`dashboard_page.dart:233-235`)。Issue #5 では simulate ボタン自体を削除する案もあり (debug-only にする)、その判断は #5 generator に委ねる。

7. **既存 `AudioService.skipNext()` を残置 (削除しない)**: PlaybackController.skip() に置き換わったため `AudioService.skipNext()` は dead code 寄りだが、`out_of_scope` には削除許可がなく、既存テストが間接呼び出ししている可能性もゼロではないため温存。次 Sprint で safe に削除可能 (call site が widget tree から消えていることを確認した上で)。

## 後続 Issue への申し送り

| Issue | 申し送り |
|---|---|
| **#5 P2P 受信統合** | `PlaybackTrackSource` (abstract、`Stream<Track> get tracks`) に**本物の TrackReceiver-backed source** を `implements` させて `playbackTrackSourceProvider` を override すれば、本 Sprint の Controller がそのまま受信→再生をハンドルする。decryption / integrity check 完了後に `_controller.add(track)` するだけで pipeline 完成。`FakeTrackSource` (data/services/) は debug-only として残してもよい。`DashboardPage._simulateDiscovery` の `if (source is FakeTrackSource)` ガードは Issue #5 で受信が動いた後は no-op になる (本物の receiver は FakeTrackSource ではないため)。debug ボタン自体を非表示化する選択肢もあり。|
| **#7 バックグラウンド再生** | `AudioGateway.play / stop` の port が確立済。just_audio_background や notification 連携は `AudioService` の内部 (Data 層) に閉じて追加可能で、Domain (PlaybackController) は変更不要のはず。`onTrackReceived` を Stream 経由で受け取る機構も background isolate からの emit に耐える (StreamController.broadcast)。|
| **#8 楽曲スキップ履歴 / ピアブロック / お気に入りフィルタ** | 本 Sprint の `FavoritesStore` は in-memory Set。永続化は `FavoritesStore` を `implements` する `PersistedFavoritesStore` (data 層) を作って provider override する方針で対応可能。スキップ履歴も `PlaybackController.skip()` の前後に hook を入れる (callback or Stream) で記録可能。|
| **#9 ストレージ・ライブラリ画面** | Track 重複判定は本 Sprint では実装していない (Track に内容ハッシュは無い)。受信ライブラリ画面では `favoritesStoreProvider` を表示の起点にできる。|
| **#10 設定画面** | `favoritesFallbackEnabledProvider` (StateProvider<bool>, default true) は in-memory のまま。設定 OFF 永続化と UI は #10 で `SharedPreferences` 連携 + 設定スイッチを追加する想定。`PlaybackController` の `FallbackEnabledGetter` callback はそのまま使える。|

## 既知の課題 / 制約

1. **Flutter SDK がコンテナ不在**: SC #11 / #12 の `flutter analyze` / `flutter test` のローカル green 検証ができないため、CI workflow に依存する。`.github/workflows/ci.yml` の最新 run summary を確認願う。

2. **`audio_service.dart` の listener leak**: 既存実装の `AudioService.play()` は `positionStream.listen` などを毎回 subscribe するが unsubscribe していない (Issue #1 時点からの構造)。本 Sprint の `implements AudioGateway` 追加では振る舞いを変えていないため新規 leak は発生しないが、後続 Sprint で要対処 (#7 バックグラウンド再生で顕在化する可能性あり)。

3. **`FavoritesStore` rebuild の hack**: 上記「技術判断 #4」の `favoritesTickProvider` は Riverpod らしくない。Domain を変えずに済む最小コストで選んだが、#10 で永続化を入れるタイミングで `StateNotifier<Set<Track>>` ベースの Presentation Provider に置き換えるのが綺麗。

4. **`upcoming` getter の fallback ケース表現**: `PlaybackController.upcoming` は nowPlaying が favorites fallback の時に「queue 全体 (`currentTrack` を含む)」を返す (`playback_controller.dart:65-77`)。これは「nowPlaying と queue.currentTrack が等しくない」レアケースで、現 UI (Up Next リスト) は queue を fallback 中もそのまま表示する設計。**この挙動は契約に明示されていない**ため、evaluator が「fallback 中は queue を空表示にすべき」と判断する場合は要修正 (該当箇所 1 メソッド差し替え)。

5. **`AudioService.skipNext()` が dead code 寄り**: 上記「技術判断 #7」のとおり残置。`out_of_scope` で削除許可が無いことと、widget_test.dart 改変禁止 (= 既存 ProximityMusicApp 経由の動作確認は維持) のため温存した。

6. **`_BridgedPlaybackController` の subclass 化**: providers.dart 内 private に置いたが、Domain 側 (PlaybackController) を `mixin` 化 / `Listenable` 化する設計の方が綺麗とも言える。今回は YAGNI (Issue #6 の test_plan を最短で通す) を優先した。

## 自己評価 (5 基準、過小気味)

| 基準 | 自己評価 | コメント |
|---|---|---|
| **契約遵守** | ★★★★☆ | scope 8 項目すべてに対応する実装あり、out_of_scope は侵食していない。ただし「fallback 中の upcoming」挙動は契約で明示されておらず、解釈の余地が残る (既知課題 #4)。|
| **TDD 順序** | ★★★★★ | RED commit (4b8a9d9) は test 612 行のみ、impl 0 行。GREEN commit (3570e0d) は impl + (handoff 作成時点では README 改変も含む)。RED → GREEN の祖先関係も維持。|
| **テスト網羅** | ★★★★☆ | 24 ケース新規追加で test_plan の RED-1〜RED-6 を全カバー。Random(42) で fallback 決定性も検証。Presentation integration 3 ケースは widget tree レベルで provider override → emit → state assertion を行い、契約 SC #6 と #8 を統合的に検証。改善余地: timer / Future.delayed なしの構造保証は grep だけで担保しており、テスト本体での「100ms 以内に play が呼ばれる」 timing 検証は入れていない (microtask で同期完了する設計のため過剰と判断)。|
| **アーキテクチャ整合** | ★★★★☆ | Domain (純 Dart) / Data (just_audio + Domain port 実装) / Presentation (Riverpod + UI) の三層分離を維持。Domain → 他層への逆依存なし (grep 確認済)。減点ポイント: providers.dart の `_BridgedPlaybackController` subclass 化は実用的だが「Riverpod 用の薄いブリッジを Domain サブクラスとして書く」やり方が広く受け入れられる慣用かは判断保留 (技術判断 #3)。|
| **保守性 / 後続接続性** | ★★★★☆ | 5 つの Domain abstraction (`PlaybackQueue` / `FavoritesStore` / `AudioGateway` / `PlaybackTrackSource` / `PlaybackController`) で Issue #5/#7/#8/#9/#10 の接続点が明示されている (申し送り表参照)。FakeTrackSource は debug 用としても production 用としても使える設計。減点ポイント: `favoritesTickProvider` は #10 で消すべき hack。|

総合 4.4/5 (過小気味)。CI で `flutter test` / `flutter analyze` が両方 green になることを前提とし、契約逸脱なし、後続 Issue への接続点も明確、と判断。**懸念は (a) Flutter SDK ローカル不在による未検証、(b) fallback 中の upcoming 挙動が契約未明示、(c) `favoritesTickProvider` の Riverpod 慣用性、の 3 点。**

## 修正ログ (Phase 4 のみ追記)

(なし — 初回 READY_FOR_REVIEW)
