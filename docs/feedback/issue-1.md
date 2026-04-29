# Issue #1 評価結果 (実装モード)

**判定:** NEEDS_FIX
**評価日:** 2026-04-29
**評価対象:** Issue #1 - プロジェクト基盤整備 (init.sh + CI + 層分離)
**Attempts:** 1/5
**Branch:** `sprint/01-bootstrap-and-layered-refactor`
**RED commit:** `56ba9ca` (`app/test/domain/track_test.dart` の 4 ケース)
**GREEN commit:** `e0f422a` (層分離 7 ファイル + init.sh + CI workflow + README 追記)

## スコア

| 基準 | スコア | 閾値 | 判定 |
|------|--------|------|------|
| 契約適合性 (contract_compliance) | 4/5 | 4 | PASS |
| 動作安定性 (operational_stability) | 4/5 | 4 | PASS |
| 品質 UX/可読性 (quality_ux) | 4/5 | 3 | PASS |
| エッジケース対応 (edge_cases) | 3/5 | 3 | PASS |
| 回帰なし (no_regressions) | 5/5 | 5 | PASS |

**閾値判定上は全項目クリア**だが、以下の CRITICAL なアーキテクチャ違反を `skeptical-evaluation` 原則 5 (「契約に厳密に従い、内側で可能な限り厳しく」) と原則 4 (「テストが通ってもバグが見つからなかっただけと考え、怪しい箇所を追加で掘る」) に基づき指摘し、NEEDS_FIX とする。Attempts 予算 (1/5) は十分に残っているため、この機会に Sprint 01 の基盤として正しい層分離を確立しておくべき。

## TDD 順序検証

- `state.tdd.red_commit_sha`: `56ba9ca` ✓
- RED commit に実装ファイル混入: **なし** (test ファイル 1 枚のみ追加 = 期待通り)
- `state.tdd.green_commit_sha`: `e0f422a` ✓
- RED → GREEN の時系列順序: 正 (RED 22:17:30 → GREEN 22:23:58)
- GREEN commit にテストファイル変更: **なし** (test-integrity 健全)
- RED 時点でのコンパイル失敗想定: 妥当 (`package:proximity_music_app/domain/entities/track.dart` は GREEN まで存在しない)

→ `qa.json.implementation_review.tdd_verified = true`

## 契約ベーステスト結果 (TP-01〜TP-16)

### 合格した項目

| TP | 検証内容 | 結果 / 観測 |
|---|---|---|
| TP-01 | init.sh 冪等性 | `./init.sh && ./init.sh && echo OK` を実機実行、両回 exit 0 で `OK` 出力を確認 |
| TP-02 | SDK 不在ガイド | 'Flutter SDK not found. See https://docs.flutter.dev/get-started/install' を含む 1 行を stderr に出力、exit 0 |
| TP-03 | --strict mode | `./init.sh --strict; echo $?` → `1` を実機確認 |
| TP-04 | 起動案内表示 | 'flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080' / 'bin/show-test-url.sh 8080' をそれぞれ 1 件以上出力 (trap EXIT で SDK 有無に関係なく表示) |
| TP-05 | 7 ファイル存在 | track.dart / audio_service.dart / providers.dart / dashboard_page.dart / player_page.dart / mini_player.dart / app.dart すべて存在 |
| TP-06 | main.dart 縮小 | `wc -l < app/lib/main.dart` = 16 (≤30) |
| TP-07 | Domain 層 import 制約 | grep 出力 0 件 (Track は pure Dart のみ) |
| TP-08 | Data 層 import 制約 (material/go_router) | grep 出力 0 件 |
| TP-09 | 既存 widget_test.dart 不変 | `git diff f7f582d -- app/test/widget_test.dart` 出力 0 byte (完全同一) |
| TP-10 | track_test.dart の構造 | `test(` 4 件 (≥3)、equality assertion (`isTrue/isFalse/equals/==`) 8 件 |
| TP-13 | CI 5 文字列 | subosito/flutter-action@v2 ×1, pub get ×2, dart format ×2, analyze ×2, test ×2 を含有 |
| TP-14 | README 3 文字列 | './init.sh' ×2, 'flutter run -d web-server --web-hostname 0.0.0.0' ×1, 'bin/show-test-url.sh' ×3 |
| TP-16 | Track equality 静的検査 | `@override` 3 件 / `bool operator ==` 1 件 / `int get hashCode` 1 件 / `String toString` 1 件 |

### CI 検証依存 (Flutter SDK 不在のため container 内実行不可、契約上既知)

| TP | 状態 | 備考 |
|---|---|---|
| TP-11 | 未検証 | `flutter test` の green は CI 実行に依存。既存 widget_test.dart 3 件が新文言 (`'Proximity Music'` / `'Discovery Active'` / `'Discovery Paused'` / `'Player'` / `'再生コントロール'`) で green になるかは Presentation 実装上はレンダリングされている (静的に grep で確認) ため強い green 確信あり。 |
| TP-12 | 未検証 | `flutter analyze` 0 error/warning は CI 依存。`prefer_const_constructors` 違反の有無は静的読了では断定不可。 |
| TP-15 | 未検証 | widget_test.dart の 3 ケースが新パスで green になるかは TP-11 と同じく CI 依存。実装側に必要文言・Icon は揃っている (静的確認済)。 |

CI workflow 自体はこのブランチが remote に push されていないため (`origin/sprint/01-bootstrap-and-layered-refactor` 未存在) run 履歴を取得できなかった。本評価は static + 実機 init.sh 動作のみで判定し、TP-11/12/15 は契約上「CI ログ確認に置き換える」既知制約として扱う。

### 不合格の項目

なし (SC 14 件すべて静的検査または実機検証で達成、CI 依存 2 件は契約上の既知制約)。

## Adversarial findings (契約外の能動的検査)

### CRITICAL — BUG-1: Data → Presentation の逆向き依存 / 循環依存

**観測:**

```
$ grep -n "^import" app/lib/data/services/audio_service.dart
8:import 'package:flutter/foundation.dart' show debugPrint;
9:import 'package:flutter_riverpod/flutter_riverpod.dart';
11:import 'package:proximity_music_app/domain/entities/track.dart';
12:import 'package:proximity_music_app/presentation/state/providers.dart';   ← ★ 違反

$ grep -n "^import" app/lib/presentation/state/providers.dart
6:import 'package:flutter_riverpod/flutter_riverpod.dart';
7:import 'package:just_audio/just_audio.dart';
9:import 'package:proximity_music_app/data/services/audio_service.dart';   ← Presentation→Data はOK
10:import 'package:proximity_music_app/domain/entities/track.dart';
```

**契約条文との突き合わせ:**

`contract.json` scope[3]:

> 新ファイル群はそれぞれ層を超えた**逆向き依存をしない** (Domain は他層を import しない / **Data は Domain のみ参照可** / Presentation は Domain と Data を参照可)。dart import 上のルールとして守る。

`audio_service.dart` (Data 層) は Presentation 層の `providers.dart` を import しており、scope[3] の「Data は Domain のみ参照可」に明確に違反する。さらに `providers.dart` (Presentation) は `audio_service.dart` (Data) を import するため、**Data ⇄ Presentation の循環依存**が発生している。これは Issue #1 の核心目的 (層分離による依存方向の整理) を内側で破綻させており、後続 Issue (#3 近接検知 / #5 P2P 転送 / #6 自動再生) で「Data 層から Presentation の Provider を直接読む」アンチパターンが固定化される技術的負債。

なぜ SC で検出されないか:

- SC #7 (Domain) と SC #8 (Data) の grep は `flutter/material` と `go_router` のみを禁止しており、**`package:proximity_music_app/presentation/...` の import は grep 対象外**。
- handoff.md 「既知の課題 #5」も flutter_riverpod の Ref 利用のみを言及し、Presentation 層 import の自覚が無い。

**期待される動作:**

`AudioService` クラスは Presentation の Provider 名を知らないべき。具体的には以下のいずれかの構造に直す:

- 案 A (推奨): `AudioService` のコンストラクタに必要な依存を引数注入し、`providers.dart` 側で組み立てる。例えば `AudioService(this.player, {required this.onPlayingChanged, required this.onPositionChanged, required this.onDurationChanged, required this.onNowPlayingChanged, required this.onQueueMutated})` のようにコールバックで状態反映を Presentation 側に委譲する。`audio_service.dart` の import から `presentation/state/providers.dart` を削除する。
- 案 B: AudioService 内部の状態 (現在再生中 Track / playing / position / duration / queue) を `domain/services/playback_state.dart` のような Domain インタフェースに切り出して、Presentation Provider は AudioService のストリーム / コールバックを購読する形にする。

`providers.dart` 側は引き続き `audio_service.dart` を import してよい (Presentation → Data は順方向)。

**検証 grep (修正後に通るべき):**

```
grep -RE "^import 'package:proximity_music_app/presentation/" app/lib/data/ | wc -l   # 期待: 0
```

**スコア影響:** contract_compliance を 5 から 4 に減点。SC レベルでは pass だが scope[3] 違反が NEEDS_FIX の根拠。

### MINOR — BUG-2: Data 層が `flutter/foundation` (debugPrint) を import

`audio_service.dart` line 8:

```dart
import 'package:flutter/foundation.dart' show debugPrint;
```

`flutter/foundation` は `flutter` パッケージの一部であり、Pure Dart ではない。SC #8 の grep は `'package:(flutter/material|go_router)'` のみを禁止しており、`flutter/foundation` は通過するが、scope[3] の「Data は Domain のみ参照可」の精神には微妙に反する。just_audio や flutter_riverpod は契約で明示的に Data 層で許可されているが、`flutter/foundation` は許可リストに無く、`debugPrint` の利用は `print` (dart:core) や `developer.log` (`dart:developer`) で代替可能。

**期待される動作:** `import 'package:flutter/foundation.dart' show debugPrint;` を削除し、`developer.log('Error playing audio: $e', name: 'AudioService')` などに置き換える。または BUG-1 の修正でコールバックを通じて Presentation に通知する形にする。

**スコア影響:** quality_ux を 5 から 4 に減点 (合否には影響しない)。BUG-1 を直す過程で同時に解消可能。

### 検査済みで問題なし (positive findings)

- `_EmptyQueue` の Icon を `Icons.queue_music` → `Icons.playlist_play` に変更した点 (handoff 技術判断 #2): widget_test.dart `find.byIcon(Icons.queue_music)` が `findsOneWidget` を要求するため、AppBar の player ボタン (line 30) と `_EmptyQueue` プレースホルダ (line 356) で重複する `queue_music` を 1 個に絞る正当な実装側調整。out_of_scope[3] (UI 文言) は文字列指定であり Icon シンボルは対象外。**問題なし**。
- main.dart の `flutter_riverpod` import は `ProviderScope` を使うため必要。Presentation 入口 (entrypoint) であり Data/Domain ではないため層制約の対象外。
- main.dart の `export 'package:proximity_music_app/app.dart' show ProximityMusicApp;` は scope[8] で明示的に許可された 2 案のうちの 1 案で、widget_test.dart の import を 1 byte も変えずに済ませた素晴らしい選択 (TP-09 が完全 0 byte diff で通る)。
- TDD 順序が完璧 (RED に test ファイル 1 枚のみ、GREEN に test ファイルなし、両 commit が時系列順)。
- track_test.dart の equality テストが 4 ケース構造化されており、SC #10 の 3 観点 (constructor / equality true / equality false) を全て押さえつつ toString も追加 (handoff 通り)。
- init.sh が `set -euo pipefail` + `trap print_banner EXIT` で SDK 有無に関わらず案内を出す設計が堅牢。`-h/--help` も実装。冪等性 (実機 2 回実行確認) も OK。

## バグ一覧

| # | 重要度 | 内容 | 修正方針 |
|---|--------|------|----------|
| BUG-1 | critical | `app/lib/data/services/audio_service.dart` が `presentation/state/providers.dart` を import (scope[3] 単方向依存違反 + Data⇄Presentation 循環依存) | AudioService からコールバックを引数注入し、Presentation Provider 名への直接依存を削除する。`providers.dart` 側で組み立てる。 |
| BUG-2 | minor | `audio_service.dart` が `flutter/foundation` (debugPrint) を import | `dart:developer` の `log()` に置き換える、または BUG-1 の修正で同時にコールバック先 (Presentation) に委譲。 |

## 改善提案 (契約外、合否には影響しない)

1. `audio_service.dart` の `play()` 内でストリーム listen を新規再生のたびに行っており、複数回 `play()` 呼ぶと listener が重複登録される。subscription の cancel 処理を入れる、または `init()` 等の一度きりのセットアップに分ける方が安全。Issue #6 (自動再生) で問題化する前に検討。
2. CI workflow を 1 ジョブにまとめても 5 文字列要件は満たせる (現在は 1 ジョブ構成)。format check を別 job に分けるなら名称を明示すると DX 向上。
3. `app.dart` の `MaterialApp.router` 内テーマブロックが GoRouter と同居しており、テーマだけ別 Helper に切り出すと可読性向上。Issue #1 の scope 外なので任意。

## Generator への指示 (Phase 4)

優先度順:

1. **(CRITICAL, 必須) BUG-1 修正**: `app/lib/data/services/audio_service.dart` の `import 'package:proximity_music_app/presentation/state/providers.dart';` を削除する。`AudioService` クラスのインタフェースを以下のいずれかに変える:
   - 推奨案: コールバック注入 (`AudioService(this.player, {required this.onPlayingChanged, required this.onPositionChanged, required this.onDurationChanged, required this.onNowPlayingChanged, required this.onQueueMutated})` 等)。`providers.dart` 側の `audioServiceProvider` で各コールバックを `(value) => ref.read(...notifier).state = value` のクロージャとして渡す。
   - 代替案: AudioService が Stream を expose し、Presentation Provider 側でそれを listen して Notifier を更新する (StreamProvider に置き換える)。
   どちらでも修正後に以下が成立すること:
   ```
   grep -RE "^import 'package:proximity_music_app/presentation/" app/lib/data/ | wc -l   →  0
   ```

2. **(MINOR, BUG-1 修正のついでに) BUG-2 修正**: `flutter/foundation` の import を削除し、`dart:developer` の `log()` に置き換える (または BUG-1 修正で Presentation 側に通知する設計にすれば自然に消える)。

3. **修正コミット粒度**: BUG-1 の修正は GREEN 後の追加 commit として `fix(issue-1): break data→presentation dep cycle in AudioService` 等で 1 commit、BUG-2 を含めて 1 commit でも 2 commit でも可。新規テストは不要 (既存 widget_test.dart で interaction 経路は担保済)。ただし AudioService をコールバック注入型に変える場合、`audio_service.dart` のロジックが変わるため `app/test/data/audio_service_test.dart` を追加して mock コールバックで状態反映が呼ばれることを確認する unit test を入れると将来の回帰防止に強い (任意、TDD でやるなら RED → GREEN を別 commit に分けてください)。

4. handoff.md の「既知の課題」セクションに BUG-1 の構造を明示し、後続 Issue (#5/#6) で同種ミスを再発させない注意書きを残してください。

5. その他 14 件の SC は本評価で全て pass しているため、修正対象は audio_service.dart のみで構いません。dashboard_page.dart / player_page.dart / mini_player.dart / providers.dart / track.dart / app.dart / main.dart / init.sh / flutter-ci.yml / README.md / track_test.dart は触らないでください (test-integrity / contract-immutability の遵守)。

修正完了後、`bin/controller.py submit-impl --issue-id 1 --actor generator` で再度 READY_FOR_REVIEW に遷移してください。

---

# Attempt 2 再評価 (2026-04-29)

**判定:** PASSED
**Attempts:** 2/5
**修正 commit:** `638c972` (`fix(issue-1): break data->presentation cycle, use dart:developer`)
**変更範囲:** `app/lib/data/services/audio_service.dart` + `app/lib/presentation/state/providers.dart` の 2 ファイルのみ (テストファイル変更なし、実装の他ファイル変更なし)

## スコア (再評価)

| 基準 | スコア | 閾値 | 判定 | 変動 |
|------|--------|------|------|------|
| 契約適合性 (contract_compliance) | 5/5 | 4 | PASS | +1 (BUG-1 解消) |
| 動作安定性 (operational_stability) | 5/5 | 4 | PASS | +1 |
| 品質 UX/可読性 (quality_ux) | 5/5 | 3 | PASS | +1 (BUG-2 解消、コメントで層分離意図が明示化) |
| エッジケース対応 (edge_cases) | 4/5 | 3 | PASS | +1 |
| 回帰なし (no_regressions) | 5/5 | 5 | PASS | 維持 |

**閾値判定: 全項目クリア → PASSED**

## 前回指摘 2 件の解消検証

### BUG-1 (CRITICAL): Data → Presentation 循環依存

**修正方針:** 推奨案 A (コールバック注入) を完全に採用。

検証 grep:

```
$ grep -REn "^import 'package:proximity_music_app/presentation/" app/lib/data/ | wc -l
0   ← 解消
```

`app/lib/data/services/audio_service.dart` の現在の import 群:

```
10:import 'dart:developer' as developer;
12:import 'package:just_audio/just_audio.dart';
14:import 'package:proximity_music_app/domain/entities/track.dart';
```

**Data 層が Domain と外部 just_audio 以外に何にも依存しない** という scope[3] の理想形に到達した。`flutter_riverpod` も完全に外れており (これは指摘以上の改善)、Data 層は Riverpod 非依存の純粋な Domain サービスとして再構築されている。

`AudioService` のコンストラクタ:

```dart
AudioService(
  this.player, {
  required this.onPlayingChanged,
  required this.onPositionChanged,
  required this.onDurationChanged,
  required this.onNowPlayingChanged,
  required this.readQueue,
  required this.writeQueue,
});
```

typedef は Domain 型 (`Track`) と組み込み型 (`Duration`, `bool`, `List`) のみで定義されており、Riverpod / Flutter への漏れなし。

`presentation/state/providers.dart` 側の組み立て:

```dart
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(
    ref.read(audioPlayerProvider),
    onPlayingChanged: (playing) =>
        ref.read(isPlayingProvider.notifier).state = playing,
    ...
    readQueue: () => ref.read(queueProvider),
    writeQueue: (queue) => ref.read(queueProvider.notifier).state = queue,
  );
});
```

Presentation → Data の単方向依存に整合。queueProvider の読み書きを 2 つのコールバックに分けたのは妥当 (skipNext は queue のスナップショット読み + 更新書きを必要とするため)。

**判定: 解消完了。**

### BUG-2 (MINOR): flutter/foundation import

検証 grep:

```
$ grep -REn "flutter/foundation" app/lib/data/ | wc -l
0   ← 解消
```

`debugPrint` は `dart:developer` の `developer.log('Error playing audio: $e', name: 'AudioService')` に置換 (audio_service.dart line 65)。`dart:developer` は Pure Dart のため Data 層の責務として清潔。

**判定: 解消完了。**

## 回帰チェック (Attempt 1 で PASS だった項目の再確認)

| 項目 | 状態 | 検証コマンド / 観測 |
|---|---|---|
| TP-09 widget_test.dart 不変 | 維持 | `git diff f7f582d HEAD -- app/test/widget_test.dart \| wc -c` = 0 |
| TP-06 main.dart ≤ 30 行 | 維持 | `wc -l app/lib/main.dart` = 16 |
| TP-05 7 ファイル存在 | 維持 | track / audio_service / providers / dashboard_page / player_page / mini_player / app すべて存在 |
| TP-07 Domain import 制約 | 維持 | Track は package import 0 件 (Pure Dart) |
| TP-08 Data import 制約 (flutter/material, go_router) | 維持 | 0 件 |
| TP-13 CI 5 文字列 | 維持 | subosito@v2 / pub get / dart format / analyze / test 全て含む |
| TP-14 README 3 文字列 | 維持 | `./init.sh` / `flutter run -d web-server --web-hostname 0.0.0.0` / `bin/show-test-url.sh` 全て含む |
| TP-16 Track equality static | 維持 | @override 3 件 / operator == / hashCode / toString 各 1 件 |
| TP-01 init.sh 冪等性 | 維持 | 実機で 2 回連続実行 → 両回 exit 0 |
| TP-02 SDK 不在ガイド | 維持 | "Flutter SDK not found. See https://docs.flutter.dev/get-started/install" を観測 |
| TP-03 --strict mode | 維持 | exit 1 を観測 |
| TP-04 起動案内 | 維持 | `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` と `bin/show-test-url.sh 8080` を末尾出力 |

## TDD 順序再検証

- `state.tdd.red_commit_sha`: `56ba9ca` (Track 4 失敗テスト追加のみ) ✓
- `state.tdd.green_commit_sha`: `e0f422a` (実装 7 ファイル追加、テストファイル変更なし) ✓
- 修正 commit `638c972` は GREEN 後の Phase 4 修正 commit。**テストファイルへの変更は 0 件**。

```
$ git show --stat 638c972
 app/lib/data/services/audio_service.dart  | 73 ++++++++++++++++++++-----------
 app/lib/presentation/state/providers.dart | 19 +++++++-
```

test-integrity 健全。新規テスト追加は不要 (公開シグネチャが不変なため既存 widget_test.dart で interaction 経路を担保) という generator の判断に同意。

## Adversarial 再検査 (新規問題の有無)

| 観点 | 結果 |
|---|---|
| 公開 interface の signature 変更 | 不変 (`play(Track)` / `pause()` / `resume()` / `stop()` / `skipNext()` 全て同じ)。dashboard_page.dart / player_page.dart / mini_player.dart の 5 箇所の呼び出しは引数なし or Track 1 つで一致しており回帰なし。|
| typedef の Domain 純度 | `PlayingChanged` / `PositionChanged` / `DurationChanged` / `NowPlayingChanged` は `bool` / `Duration` / `Track?` のみ参照。`QueueRead` / `QueueWrite` は `List<Track>` のみ。**Flutter / Riverpod への漏れなし**。 |
| Domain Track への汚染 | Track 自体は変更されておらず Pure Dart のまま (`@override` 3 件のみ、外部 import 0 件)。|
| null safety | `onNowPlayingChanged: NowPlayingChanged = void Function(Track? track)` で nullable を許容。`stop()` 内で `onPositionChanged(Duration.zero)` を呼ぶのは明示的リセットで妥当。|
| 副作用順序 | `play()` 内の listener セットアップは `play()` を複数回呼ぶと subscription が重複登録される問題 (前回 attempt 1 の改善提案 #1) が依然として残るが、これは BUG-1 修正範囲外であり Issue #6 (自動再生) で個別対応する論点。本 Issue の合否には影響しない。|
| Riverpod の `ref.read(queueProvider)` クロージャキャプチャ | `Provider<AudioService>` のスコープ内で `ref` をキャプチャしており、Provider 寿命と AudioService 寿命が一致するため安全。`ref.onDispose` で player は破棄される。AudioService 自体に dispose は無いがコールバック保持のみで GC 対象なので問題なし。|
| widget_test.dart 経路への影響 | smoke / Discovery toggle / Player navigation の 3 ケースは AudioService を呼ばない経路 (nowPlaying は null、Add Track ボタンは押されない)。AudioService コンストラクタ変更による副作用はなし。|
| BUG-2 修正の意味的等価性 | `debugPrint` (release ビルドで no-op、debug ビルドで stdout) → `developer.log` (常に Observatory / IDE に記録)。意味的にはむしろ **改善** (release でもエラーが Observatory に残る)。|

## handoff.md の「既知の課題 #5」更新

generator の attempt 2 修正ログで「`audio_service.dart` で flutter_riverpod を import」が解消されたと明示している。後続 Issue #5/#6 で同種の Data → Presentation 依存を作りそうになったら、Domain typedef + コールバック注入パターンで切り出すという原則も明文化されている。**良い知見の蓄積。**

## 残課題 (合否に影響しない改善提案、Issue #6 / #11 に持ち越し)

1. (繰越) AudioService の `play()` 内ストリーム listen は subscription cancel が無く、複数回 `play()` で listener が重複登録される。Issue #6 (自動再生・受信即時再生) で対応。
2. (新規, advisory) AudioService に `dispose()` メソッドを追加して subscription をまとめて cancel できる構造にすると、テスト時のリークも防ぎやすい。Issue #6 で着手推奨。
3. (繰越) CI workflow を 1 ジョブにまとめても 5 文字列要件は満たせる。format check を別 job に分けるなら名称を明示すると DX 向上。

これらは Issue #1 のスコープ外であり、本 Sprint では合否に影響させない。

## 結論

CRITICAL BUG-1 (循環依存) と MINOR BUG-2 (flutter/foundation) の両方が完全解消。修正範囲は最小限 (2 ファイル、73+19 行)、テストファイルは一切触られておらず、公開 interface の不変性により周辺コードへの回帰なし。Domain Track の純度も維持。Sprint 01 の目的 (層分離 + init.sh + CI 基盤) を高品質に達成した。

**判定: PASSED。** 後続 Issue でも Domain typedef + コールバック注入のパターンを継続する基盤が整った。

