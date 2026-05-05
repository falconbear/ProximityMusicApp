# Issue #4 Handoff (Generator → Evaluator)

**Generator:** generator
**最終更新:** 2026-05-05
**Phase:** Phase 3 完了 (READY_FOR_REVIEW)
**Branch:** `sprint/04-session-handshake` (main 直分岐 — Issue #2 / #3 マージ前)

## 実装サマリ

Layered architecture を Sprint 01 で確立した構造に追従し、3 層 + Native スパイクで実装した。

- **Domain (pure Dart, no flutter / framework imports)** — 8 ファイル
  - `entities/session_id.dart` `SessionId` + `factory generate(Random, DateTime)` + `fingerprint` getter (`XXXX-XXXX` 形式)
  - `entities/session_status.dart` `SessionStatus` enum 5 値 (idle / connecting / connected / failed / disconnected)
  - `entities/session.dart` `Session` + `copyWith` + `(peerId, myIdAtOpen.value, status)` の 3-field equality
  - `entities/key_pair.dart` `EphemeralKeyPair` + `HandshakeMessage`
  - `services/key_exchange.dart` `abstract class KeyExchange { generate / deriveSharedSecret }`
  - `services/session_transport.dart` `abstract class SessionTransport { sendHandshake / closeSession / disconnectStream }` + `SessionTransportException`
  - `services/id_rotation_policy.dart` 15 分間隔ローテーション policy (`current` / `rotate` / `isDueForRotation` / `lastRotatedAt`)
  - `services/session_registry.dart` peerId → Session の in-memory map (`upsert` / `sessionFor` / `sessions` / `disconnectAllExcept` / `remove`)

- **Data** — 3 ファイル
  - `services/stub_key_exchange.dart` `StubKeyExchange implements KeyExchange` (sha256 ベース MVP placeholder。実 ECDH は #5 で差替予定のコメント付き)
  - `services/fake_session_transport.dart` `FakeSessionTransport implements SessionTransport` (test 用、`emitDisconnect` public)
  - `services/native_session_transport.dart` `NativeSessionTransport implements SessionTransport` (`MethodChannel('proximity_music_app/session')` + `EventChannel('proximity_music_app/session/disconnects')` の wire-up のみ)

- **Presentation** — 4 ファイル
  - `state/session_controller.dart` `SessionController` (純粋 Dart、callback 注入で `flutter` / `flutter_riverpod` 非依存。Sprint 01 の callback_injection_remedy 規約継承)
  - `state/session_providers.dart` 7 Riverpod providers (`keyExchangeProvider` / `sessionTransportProvider` / `idRotationPolicyProvider` / `sessionRegistryProvider` / `sessionsProvider` / `currentSessionIdProvider` / `sessionControllerProvider`) + 内部 `_sessionTickProvider`
  - `widgets/session_status_chip.dart` 5 status を chip 化 (日本語ラベル: アイドル / 接続中 / 接続済み / 失敗 / 切断)
  - `pages/session_page.dart` `/session` ページ (フィンガープリントカード + アクティブセッション一覧 + 空状態文言 + `今すぐ更新` button + Snackbar)

- **Routing + Dashboard 連携** — 既存テスト互換を最優先
  - `app.dart` に `'/session'` → `SessionPage` を追加。`'/'` / `'/player'` は不変。`'/discover'` / `'/settings'` は **追加していない** (Issue #2 / #3 マージ前のため衝突を回避)
  - `dashboard_page.dart` の `AppBar.actions` の **先頭** に `Icons.fingerprint` IconButton を追加。既存 `Icons.queue_music` は 1 個のまま、Hero の Switch も 1 個のまま

- **Native スパイク** — Sprint 04 範囲は wire-up のみ
  - `app/ios/Runner/AppDelegate.swift` MethodChannel + EventChannel 登録、`sendHandshake` は `FlutterError(code: 'transport_unavailable')` を返す
  - `app/android/app/src/main/kotlin/com/example/proximity_music_app/MainActivity.kt` `configureFlutterEngine` を override し同等のスタブを登録

- **依存関係** — `pubspec.yaml` に `crypto: ^3.0.3` を明示追加 (元は `flutter_test` 経由の transitive)。`pigeon` は意図的に追加していない

- **README** — `app/README.md` に Anonymous Session セクション (Sprint 04 spike note + ID rotation 挙動 + Issue #2/#3 follow-up note) を追記

## 起動方法

```bash
# 1. 初回セットアップ (冪等)
./init.sh

# 2. Web 開発サーバ起動 (Tailscale 確認用)
cd app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
# 別ターミナル: bash bin/show-test-url.sh 8080

# 3. 単体テスト
cd app && flutter test

# 4. 静的検査
cd app && flutter analyze
cd app && dart format --set-exit-if-changed .

# 5. Native ビルド (環境依存、スパイクのみ)
cd app && flutter build apk --debug          # Android
cd app && flutter build ios --no-codesign --simulator  # iOS (macOS のみ)
```

- Session 画面: `http://localhost:8080/#/session` または Dashboard AppBar の `fingerprint` アイコン
- 停止: `Ctrl+C`

## TDD ログ

| Phase | Commit SHA | 概要 |
|---|---|---|
| RED | `3d02297` | 9 テストファイル / 計 42 ケース (Domain 20 + Data 7 + Presentation 15)。`app/lib/...` 未存在のため import エラーで RED。`widget_test.dart` / `track_test.dart` は不変。|
| GREEN | `e02737b` | Domain 8 ファイル + Data 3 ファイル + Presentation 4 ファイル + app.dart routing + dashboard_page.dart の Icons.fingerprint 追加 + iOS/Android Native スパイク + crypto 依存追加 + README 追記。新規 RED 9 テスト全 green、既存 widget_test 3 ケース + track_test 4 ケース継続 green を想定。|
| REFACTOR | (なし) | GREEN commit が層分離・命名統一を含むため追加 refactor は不要と判断。|

`state.json.tdd` にも記録済み (`red_commit_sha=3d02297...`, `green_commit_sha=e02737b...`)。

## Success criteria 自己評価

> Guilty until proven innocent。CI 実走できないため Flutter 検証は CI 依存と明記。

| # | Success criterion (要約) | 自己評価 | 根拠 |
|---|---|---|---|
| 1 | Domain entities 4 ファイル + class/enum 存在 | 達成 | `test -f` 4 ファイル成功。`grep` で `class SessionId` / `enum SessionStatus` / `class Session` / `class EphemeralKeyPair` / `class HandshakeMessage` 各 1 件以上。|
| 2 | `SessionId.generate(` factory + `fingerprint` getter | 達成 | `grep -F 'SessionId.generate('` ヒット、`grep -F 'fingerprint'` も `session_id.dart` に存在。|
| 3 | `KeyExchange` abstract + 2 メソッド | 達成 | `app/lib/domain/services/key_exchange.dart` に `abstract class KeyExchange` / `generate` / `deriveSharedSecret` を定義。|
| 4 | `SessionTransport` abstract + 3 シンボル + Exception | 達成 | `sendHandshake` / `closeSession` / `disconnectStream` / `SessionTransportException` がすべて同ファイル内。|
| 5 | `IdRotationPolicy` 4 シンボル | 達成 | `current` / `rotate` / `isDueForRotation` / `lastRotatedAt` の 4 シンボルが宣言済。|
| 6 | `SessionRegistry` 5 シンボル | 達成 | `upsert` / `sessionFor` / `sessions` / `disconnectAllExcept` / `remove` の 5 シンボル宣言済。|
| 7 | Domain 層 import 制約 (flutter / riverpod / just_audio / go_router / pigeon / flutter/services 不可) | 達成 | `grep -REn "^import 'package:(flutter\|flutter_riverpod\|just_audio\|go_router\|shared_preferences\|pigeon)" app/lib/domain/ \| wc -l` = 0、`flutter/services` 同様に 0。|
| 8 | `StubKeyExchange implements KeyExchange` | 達成 | `grep -F 'implements KeyExchange'` ヒット。|
| 9 | `FakeSessionTransport implements SessionTransport` + `emitDisconnect` | 達成 | 両 grep ヒット。|
| 10 | `NativeSessionTransport implements SessionTransport` + flutter/services + channel 名 | 達成 | `package:flutter/services.dart` import + `proximity_music_app/session` 文字列 ともに同ファイル内。|
| 11 | Data 層 import 制約 | 達成 | `grep -REn "^import 'package:(flutter/material\|go_router\|pigeon)" app/lib/data/ \| wc -l` = 0。`fake_session_transport` / `stub_key_exchange` は flutter/services も import していない。`native_session_transport` のみ flutter/services を許容範囲で import。|
| 12 | iOS Native スパイク (`proximity_music_app/session` 出現) | 達成 | `AppDelegate.swift` に MethodChannel + EventChannel 登録。CI で iOS build 検証はベストエフォート。|
| 13 | Android Native スパイク (`proximity_music_app/session` 出現) | 達成 | `MainActivity.kt` で `configureFlutterEngine` override + 両 channel スタブ登録。|
| 14 | `SessionController` 4 メソッド + flutter/riverpod 非依存 | 達成 | `openSession` / `retrySession` / `rotateNow` / `checkRotation` の 4 メソッド宣言、import に flutter / flutter_riverpod 無し。|
| 15 | 7 Provider すべて定義 | 達成 | `keyExchangeProvider` / `sessionTransportProvider` / `idRotationPolicyProvider` / `sessionRegistryProvider` / `sessionsProvider` / `currentSessionIdProvider` / `sessionControllerProvider` の 7 シンボル。|
| 16 | SessionPage 必須文字列 (`今すぐ更新` / 空状態文言 / `ID: `) | 達成 | 3 文字列 grep ヒット。|
| 17 | SessionStatusChip 5 ラベル | 達成 | アイドル / 接続中 / 接続済み / 失敗 / 切断 すべて grep ヒット。|
| 18 | app.dart `/session` 追加 + 既存 `/`, `/player` 残 + `/discover`, `/settings` 不在 | 達成 | 4 grep 条件すべて満たす (`/session` 追加、`/discover` / `/settings` は 0 件)。|
| 19 | dashboard_page.dart `Icons.fingerprint` + `Icons.queue_music` 1 件維持 | 達成 | `Icons.fingerprint` 1 件、`Icons.queue_music` 1 件 (= 既存)。|
| 20 | 既存テスト互換: `widget_test.dart` 0 byte 不変 + 3 ケース green + Switch 1 個 + 5 文字列残存 | **CI 検証依存** | `git diff main -- app/test/widget_test.dart` 0 byte。Switch 1 個 (`grep -cE 'Switch[\.\(]'` = 1)。Flutter SDK 不在のため green は CI 依存。|
| 21-29 | 各新規テストファイル test() / testWidgets() 件数 (5/4/5/6/3/4/6/5/4) | 達成 | per-file grep counts: session_id=5, session=4, id_rotation_policy=5, session_registry=6, stub_key_exchange=3, fake_session_transport=4, session_controller=6, session_page=5 (testWidgets), session_status_chip=4 (testWidgets)。`isDueForRotation` 含むケース 3 件以上、`disconnectAllExcept` 含むケース 2 件以上、`rotateNow` / `retrySession` 各 1 件以上。|
| 30 | `flutter test` 全 green | **CI 検証依存** | コンテナに Flutter SDK が無いため `flutter test` をローカル実行できない。CI workflow で確認。|
| 31 | `flutter analyze` 0 error / 0 warning | **CI 検証依存** | 同上。実装中に Sprint 02/03 instinct (`avoid_relative_lib_imports` / `unused_import` 系) を意識して書いたが run できないため CI 待ち。|
| 32 | README に 'Anonymous Session' / 'Sprint 04 spike' / 'ID rotation' (or 'ローテーション') | 達成 | 3 語すべて grep ヒット。|
| 33 | crypto 追加 / pigeon 不在 | 達成 | `pubspec.yaml` に `  crypto: ^3.0.3`、pigeon は 0 件。|
| 34 | 位置情報 / 個人識別 API 不在 | 達成 | `grep -REn "^import 'package:(geolocator\|location\|device_info_plus)" app/lib/ \| wc -l` = 0。|

## Test plan 実行可否 (RED 1-10 / GREEN 1-6 / Verification / Manual)

| TP | 状況 | 根拠 |
|---|---|---|
| RED 1-9 (各 _test.dart) | 静的構造済 | RED commit `3d02297` で 9 ファイル / 42 ケースを追加。Flutter SDK 不在のため `flutter test` 単体での失敗確認は CI に委譲。import 先 (`app/lib/...`) が当該 commit 時点では未存在のため compile error で必ず RED となる。|
| RED 10 (widget_test.dart 不変) | ローカル確認済 | `git diff main -- app/test/widget_test.dart` 0 byte。RED commit 時点でも 0 byte 差分。|
| GREEN 1 (Domain 実装) | 静的構造済 / 動的 CI 依存 | 8 ファイル全存在 + grep 条件全合格。`flutter test test/domain/` の green は CI で確認。|
| GREEN 2 (Data 実装 + crypto) | 静的構造済 / 動的 CI 依存 | 3 ファイル + `crypto: ^3.0.3` を `pubspec.yaml` に追加。`flutter test test/data/` の green は CI 依存。|
| GREEN 3 (Presentation 実装) | 静的構造済 / 動的 CI 依存 | 4 ファイル + 必須文字列含む。green は CI 依存。|
| GREEN 4 (routing + dashboard) | 静的構造済 / 動的 CI 依存 | `'/session'` 追加 + `Icons.fingerprint` 追加 + Switch / queue_music 1 個維持。`flutter test test/widget_test.dart` の既存 3 ケース回帰確認は CI 依存。|
| GREEN 5 (Native スパイク) | 静的構造済 / Native build CI 依存 | iOS / Android 両ファイルに channel 名出現を確認。`flutter build apk --debug` / `flutter build ios --no-codesign --simulator` は CI / 実機環境で確認。|
| GREEN 6 (README + 静的検査) | 静的構造済 / format & analyze CI 依存 | README 追記済。`dart format` をコンテナ内で当てられないため、手動で 80 列 / trailing comma / import alphabetic sort に揃えた (Sprint 01-03 同様)。|
| Verification (`flutter test` 一括) | CI 依存 | 既存 widget_test (3) + track_test (4) + 新規 9 ファイル (42) = 計 49 ケース想定。|
| Manual / spike check | 実機 / シミュレータ依存 | (i) AppBar `fingerprint` → `/session` 遷移、(ii) `今すぐ更新` で fingerprint 即時変化 + Snackbar、(iii) アプリ再起動で fingerprint 変化 (アプリ起動毎ローテーション)、(iv) Native session transport は意図的に `transport_unavailable` を返すスタブのため、実機で SessionPage は 'active session 0 件' empty state のまま — これが本 sprint の正常完成状態。実 P2P は #5 以降。|
| Anti-AI-slop | ローカル確認済 | `grep -REn 'Image\.(asset\|network)\|NetworkImage\|unsplash' app/lib/presentation/widgets/ \| wc -l` = 0。|

## 技術判断 (契約に書ききれなかった選択)

1. **Random 注入の方針**: `SessionId.generate` は `Random rng` を引数で受ける形にし、`SessionController` も `Random Function() randomFactory` を callback として受ける構造にした。理由は、Sprint 01 で確立した Pure Dart Domain ルール (時計・乱数を境界で注入) と Sprint 02/03 の callback_injection_remedy instinct を継承するため。本 Sprint のテストは fixed-seed `Random(seed)` を流し込んで決定的に検証している (例: `session_id_test.dart` の "100 回 distinct" は `Random.secure()` を直接使うが、controller テストは fixed `Random(42)`)。

2. **`SessionController` の callback 注入**: `SessionController` は `flutter` / `flutter_riverpod` を import しないため、`session_providers.dart` で `Provider<SessionController>` を組み立てる際に「registry を更新したら tick provider を bump する」「IdRotationPolicy が変わったら tick を bump する」の 2 つを callback として注入している。これは Sprint 01 の `audio_service.dart` で確立した callback_injection_remedy 規約 (Data 層が Presentation Provider 名を知らない) を Presentation 層内部にも展開した形。SessionController が flutter_riverpod を直接 import しない構造は契約 SC #14 を満たすために必要。

3. **`sessionsProvider` の derive 戦略**: `sessionRegistryProvider` は単なる `Provider<SessionRegistry>` (非 Stateful) のため、`upsert` 後に View が rebuild されない。Sprint 02/03 の Discover 等で使われた `_tickProvider` パターンを継承し、`_sessionTickProvider` (StateProvider<int>) を 1 個用意して `sessionsProvider` / `currentSessionIdProvider` がこれを `watch` する構造にした。SessionController が tick を bump する責務を持つ。これにより `Provider` のシンプルさを保ったまま rebuild トリガを供給できる。

4. **`session_status.disconnected` の Chip 表示**: 契約は「灰色 + 取り消し線無し (テキストのみ disabled 表現)」を要求。実装では `Theme.of(context).disabledColor` 系の代わりに、`Color(0xFF9E9E9E)` (Material grey 500 相当) をベタ指定し、テキストは `TextStyle(color: Color(0xFF757575))` で disabled っぽく描いた。理由は spec.md AI-Slop アンチディレクティブの「Material default に頼らず Spotify 配色トークンに揃える」を継承するため。SessionStatusChip テストの (c) では Container/Chip type の存在のみを assert し、色そのものの float 値検証は行っていない。

5. **`Session.equality` を 3-field (peerId + myIdAtOpen.value + status) ベースにした理由**: 契約 scope は「(peerId, myIdAtOpen.value, status) ベース」を明示。`updatedAt` / `sharedSecretHex` / `failureReason` を equality に入れるとテストでの fixed-time 検証が壊れる + registry の `upsert` で「同 peerId + 同 myIdAtOpen + 同 status」のときに no-op にできる。`hashCode` も同じ 3 フィールドで合算。

6. **`StubKeyExchange.deriveSharedSecret` の決定性**: 契約 scope は「同入力 → 同 output」を要求。実装は `sha256(myPriv ++ theirsPub ++ theirsNonce)` の hex とした。`myPriv` を含めるため、片側だけが決定的でなく両者依存の値になる (E2E では当然 my と theirs の組み合わせが両端で対称にならないが、本 sprint MVP placeholder では handshake.fromIdValue を破棄して単に `myPriv ++ theirsPub ++ theirsNonce` の hash としている)。**実 ECDH では非対称鍵から両端で同じ shared secret が生成される必要がある — 本 stub はそこを満たさない (テストで決定性のみ確認)**。コメントに `Real ECDH (X25519) is Issue #5 以降` と明記。

7. **Native iOS / Android スタブの `transport_unavailable` 返却**: 契約 scope は「常に `SessionTransportException` を throw する PoC スタブ」を要求。MethodChannel 経由での例外は Flutter 側で `PlatformException` として伝播するため、`NativeSessionTransport.sendHandshake` 内で catch して `SessionTransportException` に再 throw している。EventChannel の `disconnects` は本 sprint では `onListen` で何もせず、`Stream<String>.empty()` 相当 (controller を保持するが emit しない)。これにより SessionPage で active session が 0 件のまま empty state が出るのが本 sprint の正常完成状態 (test plan Manual check (iv) と一致)。

8. **`pubspec.yaml` の crypto 追加位置**: 既存 dependencies は `flutter` / `flutter_riverpod` / `just_audio` / `go_router` の 4 個。`crypto: ^3.0.3` を 5 個目として alphabetical 順位置 (`crypto` は `flutter` の前) に追加。`flutter pub get` をコンテナ内で走らせて lock を更新する手段が無いため、`pubspec.lock` の更新は CI 側 (subosito/flutter-action) に委譲。**evaluator が CI run 後の lock diff を確認すると `crypto: 3.0.3` 行が新規追加される**。

9. **Snackbar の duration**: `今すぐ更新` 押下時の Snackbar は `Duration(seconds: 2)` で表示。契約は duration を指定していないが、widget test (e) で `pumpAndSettle` 経由の検証ができるよう短めにした。

## 既知の課題 / 制約

1. **Flutter SDK がコンテナ内に無い** (Sprint 01-03 と同様): `flutter test` / `flutter analyze` / `dart format` のローカル実行不可。SC #20 / #30 / #31 と Test plan Verification は CI ログ依存。`.github/workflows/flutter-ci.yml` の最新 run summary で確認願いたい。

2. **Native ビルド検証**: iOS は macOS 必須、Android も SDK / NDK 必須。本コンテナでは両方とも build 検証不可。CI に `flutter build apk --debug` / iOS shadow build を追加する余地はあるが、本 sprint の契約 SC #12 / #13 は **grep で channel 名の存在を見るのみ**で十分としている (実 P2P は #5 以降)。

3. **`SessionController.openSession` の peerId 直接受け** (契約 OoS で明示): Issue #3 (Peer entity / DiscoveryController) が main にマージされていないため、Discover ピアタップ → `openSession` の wiring は本 sprint では行わない。`openSession(String peerId)` API として独立提供。Issue #3 マージ後の follow-up commit で `discover_page.dart` 側に `peer.id` を渡す呼び出しを追加する想定。

4. **SettingsPage 統合の延期** (契約 OoS): Issue #2 (SettingsPage) が main 未マージのため、'匿名 ID 即時更新' UI は本 sprint では SessionPage に直接配置。Issue #2 マージ後の follow-up commit で SettingsPage の検知セクションに集約する想定。

5. **`StubKeyExchange` の暗号学的弱点 (本 sprint MVP の意図的制約)**: 上記「技術判断 #6」のとおり、本 stub は ECDH ではなく sha256 ベースで両端で対称な shared secret を生成しない。これは spec.md でも「実 ECDH は #5 以降」と分離されており、契約 scope[3] にも MVP placeholder と明記されている。**本 stub を本番 P2P 楽曲転送 (#5) に流用しないこと**。

6. **Refactor commit を作っていない**: tdd-enforcement skill では REFACTOR は任意。GREEN commit 自体が層分離を含み、追加 refactor の必要性なしと判断。

7. **作業ツリーに無関係な変更が滞留**: `git status --short` で `bin/controller.py` / `hooks/*` / `.github/workflows/ci.yml` / `.harness/version` / `docs/PIPELINE.md` / `.claude/commands/newproject.md` / `.ai/work/3/*` 等が modified / untracked として表示されているが、これらは harness の v2026-05-03 refresh および Issue #3 完了処理に伴う変更で、本 sprint (Issue #4) の実装範囲外。Issue #4 の handoff commit には `.ai/work/4/handoff.md` のみを stage する。

## evaluator への申し送り (3-5 行)

- `git log --oneline e02737b...3d02297^` で RED → GREEN の TDD 順序が確認できる (RED commit `3d02297` は test ファイルのみ追加、GREEN commit `e02737b` は impl + crypto + README 追記、test ファイル改変なし)。
- 既存 `widget_test.dart` / `track_test.dart` は `git diff main -- app/test/widget_test.dart app/test/domain/track_test.dart` が 0 byte (test-integrity 健全)。Switch 出現回数 1、Icons.queue_music 出現回数 1。
- Flutter SDK 必須項目 (SC #20 既存テスト green / SC #30 全テスト green / SC #31 analyze) はローカル不能、`.github/workflows/flutter-ci.yml` の CI run summary で確認願う。
- Native スパイクは「常に `transport_unavailable` を返すスタブ」が仕様 (契約 scope[6][7])。SessionPage で active session が 0 件のまま empty state が出るのが本 sprint の正常完成状態。実 P2P 接続は Issue #5 以降。
- 唯一の懸念点は `StubKeyExchange.deriveSharedSecret` の対称性欠如 (技術判断 #6)。spec / 契約は MVP placeholder と分離しており違反ではないが、コメントの明示性で問題があれば指摘を。

## 修正ログ (Phase 4 で追記する場合のみ)

(現時点では Phase 3 の初回提出。Phase 4 が発生したら本セクションに `### Attempt N` 単位で追記する。)
