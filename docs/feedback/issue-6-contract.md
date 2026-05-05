# Issue #6 契約レビュー結果

**判定:** ✅ 承認 (CONTRACT_APPROVED)
**レビュー日:** 2026-05-05
**Contract attempts:** 1/3

## 7 観点チェック

| # | 観点 | 判定 | 根拠 |
|---|---|---|---|
| 1 | Scope の明確性 (scope_clarity) | PASS | 9 項目、Domain/Data/Presentation 層別に責務分離。`PlaybackQueue` / `PlaybackController` / `FavoritesStore` / `AudioGateway` / `PlaybackTrackSource` のクラス境界・公開 API・依存方向 (Domain は Riverpod/just_audio 非依存) が明文化されている。曖昧語なし。 |
| 2 | Out of scope の明示性 (out_of_scope_explicit) | PASS | 10 項目。Issue #4/#5/#7/#8/#9/#10 のいずれが何を担当するかを 1:1 で割り当て、本 Issue の境界を機能名・データ persistence・UI 範囲の 3 軸で明示。クロスフェード等の越権機能も列挙。 |
| 3 | Success criteria の測定可能性 (success_measurable) | PASS | 12 項目すべてが binary 判定可能。例: SC-2 は `currentTrack == t1` / `upcoming == [t2]` の equality 比較、SC-3 は `FakeAudioGateway.callLog == ['play(t1)']` の配列一致、SC-10 は `grep -RIn 'Future\.delayed' app/lib/domain/playback/` の 0 件、SC-1 は `test -f` で 5 ファイル存在。「使いやすい」「自然な」のような主観語を排除している。 |
| 4 | Test plan の実行可能性 (test_plan_executable) | PASS | 21 項目 (RED-1〜7 / GREEN-1〜7 / REFACTOR / Verification-1〜6)。各 RED にはファイルパス + シナリオ数 + 期待失敗理由 (compile error / 未配線) が明記。`FakeAudioGateway.callLog` / `Random(42)` シード固定など決定性が担保されている。Verification は実行可能なシェルコマンドで記述。 |
| 5 | Coverage (criteria が test plan に全網羅) | PASS | 12 SC → test plan の対応関係: SC-1↔Verification-6/GREEN-1〜3、SC-2↔RED-1/GREEN-1、SC-3↔RED-3 (a)(b)、SC-4↔RED-3 (c)(d)(e)、SC-5↔RED-2/GREEN-2、SC-6↔RED-4/GREEN-5,7、SC-7↔RED-6/GREEN-6、SC-8↔RED-5/GREEN-6、SC-9↔RED-7/Verification-3,4、SC-10↔Verification-5、SC-11↔Verification-1,2、SC-12↔Verification-3。漏れなし。 |
| 6 | spec.md との整合性 (spec_aligned) | PASS | spec §6 の受け入れ基準 5 項目と全て整合。「受信完了 → 再生開始 2 秒以内」は SC-3 の「100ms 以内」でより厳しく担保。「キュー空かつお気に入り 0 件で MiniPlayer が消える」は SC-8 で `find.byType(MiniPlayer)` の SizedBox 縮退で検証。お気に入りシャッフル fallback (spec の「設定で OFF 可能」) は `favoritesFallbackEnabledProvider` (StateProvider<bool> default true) で表現、永続化は #10 へ delegate と明記し spec 整合。「バックグラウンド継続」は #7 へ delegate (spec が「機能 7 と連動」と書いている前提と一致)。 |
| 7 | 他 Issue との整合性 (prior_sprint_aligned) | PASS | #1 (PASSED) の Track entity / AudioService / providers 構造を尊重。AudioService に `implements AudioGateway` を付与し既存メソッド `play(Track)` / `stop()` と整合させる方針で、#1 の既存 widget_test (3) + track_test (4) を未改変で通すこと (SC-9, RED-7, Verification-4) を契約化。#5 の TrackReceiver は未存在ゆえ `PlaybackTrackSource` 抽象 + `FakeTrackSource` で代替し、out_of_scope に明示。#8 の永続的 favorites との重複は `FavoritesStore` を in-memory 限定にし、persistence を #8/#9 に delegate と明記、矛盾なし。 |

これらは `.ai/work/6/qa.json` の `contract_review.seven_point` にも記録した。

## 備考 (承認時)

良い点:

- **テスト計画の決定性**: `Random(42)` 固定、`FakeAudioGateway.callLog` 配列比較、`grep` 0 件チェックなど、評価時のフレーキネスが構造的に排除されている。
- **層境界の遵守**: Domain (`app/lib/domain/playback/`) は Riverpod / Flutter / just_audio に非依存と明記。`AudioGateway` 抽象を挟むことで `just_audio` 詳細の逆依存を防いでいる。
- **test-integrity 内蔵**: RED-7 + Verification-4 で既存テスト未改変を契約レベルで担保している。`test-integrity` skill の自動チェックと二重防衛になる。
- **構造的性能保証 (SC-10)**: 「2 秒以内」を実時間計測ではなく「`Future.delayed` 不在」という静的検査で代替している。flutter test 環境の不安定さを回避する妥当な工夫。

次フェーズへの軽い注意 (合否には影響しない、generator が念頭に置けばよい程度):

- **既存 `audioServiceProvider` のクロージャ駆動アーキテクチャ** (`onPlayingChanged` / `readQueue` / `writeQueue` を Presentation から注入) と、新規 `PlaybackController` の関係を Bridge する箇所 (GREEN-5) でループや二重更新が起きないか手元検証推奨。例えば `nowPlayingProvider` を `PlaybackController` 経由でしか書かないようにする・既存 `AudioService.skipNext` を `PlaybackController.skip` に委譲するなどの整理が必要になる可能性がある。これは **契約の Scope 内** (scope item 5/6) なので追加交渉不要。
- **`PlaybackTrackSource` の API 形** (Stream か callback か) を契約は両方併記しているが、generator は GREEN-3 で 1 つに decidable にし、handoff.md でその判断根拠を残すことを推奨。
- **`pickShuffled(Random(42))` の決定性 (SC-5)** は `Set` の iteration order が Dart で挿入順保証されるとはいえ、`HashSet` を使うと壊れる。`LinkedHashSet` (Dart `Set` のデフォルト) を維持する前提でテスト設計されているか、generator が確認すること。

これらはすべて scope 内の実装判断であり、契約自体の妥当性には影響しない。

## Generator への次の指示

次フェーズ (Phase 3.1: RED commit) で:

1. `bin/controller.py record-tdd --issue-id 6 --actor generator --phase red --commit-sha <sha>` の前に、test plan RED-1〜7 のうちまず **Domain unit test (RED-1〜3)** を 1 commit で投入し、確実に compile fail することを確認。
2. その後 RED-4〜6 (Widget test) を別 commit でも 1 commit でもよいが、いずれも実装ファイル (`app/lib/domain/playback/*.dart` 等) を**含めない**こと。`tdd-enforcement` skill により、RED commit に impl が混入すると即 NEEDS_FIX となる。
3. RED-7 (sentinel) は実テストではないため、この検証は CI 経由か手動での `git diff` 確認で OK。`docs/spec-issues.md` 等に記録は不要。
