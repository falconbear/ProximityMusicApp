---
name: Heuristic - validating ProviderScope.overrides strategy for test/prod default split
description: widget_test 0 byte 不変 + 実機初回起動 UX を両立する Riverpod 戦略の妥当性検証手順
type: heuristic
---

`[HEURISTIC]` Generator が「main.dart の runApp 経路で ProviderScope.overrides を渡し、widget_test.dart の経路では override 無しの ProviderScope を経由するため別 default を取得する」という戦略を提示してきた場合、以下 3 点を実機ファイル参照で検証してから承認する。

**Why:** Issue #2 contract attempt 2 で Generator が scope[15] にこの戦略を書き、`onboardingStateProvider` の Provider default = `completed` で widget_test.dart の Dashboard 直行を維持しつつ、main.dart の runApp で `ProviderScope(overrides: [onboardingStateProvider.overrideWith((ref) => OnboardingState(status: notStarted, ...))], child: const ProximityMusicApp())` を渡して実機初回起動を Welcome 直行にする提案。これは Riverpod の ProviderScope が親子で別ツリーを作る性質を利用した正攻法で技術的に成立するが、契約段階で **widget_test.dart が実際に main() を経由しないこと** を実機ファイルで確認しないと「想像の戦略」に終わる。

**How to apply:**
1. **widget_test.dart が main() を経由しないことの確認**: `app/test/widget_test.dart` を読み、`pumpWidget(<ここ>)` の中身が `const ProviderScope(child: ProximityMusicApp())` のような独立した ProviderScope であって `main()` の呼出ではないことを確認。`main()` 経由なら main.dart の overrides が widget_test.dart にも適用されてしまい戦略破綻
2. **main.dart の export 構造の確認**: `app/lib/main.dart` で `export 'package:proximity_music_app/app.dart' show ProximityMusicApp` のような export 文が現在あるか。これがあれば widget_test.dart は `import 'package:proximity_music_app/main.dart'` 経由で `ProximityMusicApp` シンボルを取得できる (Sprint 01 で確立されたパターン継承)。export が無いと widget_test.dart のビルドが失敗する可能性
3. **Provider default の評価タイミング**: `onboardingStateProvider` のデフォルト値を生成するクロージャが `flutter_test` と `runApp` のどちらの経路でも純粋関数 (副作用無し) として評価できることを確認。`DateTime.now()` のような実行時値を default で使うとテストが脆くなる (Sprint 02 では `acceptedAt: <ビルド時刻>` のような書き方が scope[4] にあるが、この場合はテスト側でも override すればよいので運用可)
4. 上記 3 点が確認できれば PASS。1 つでも怪しければ feedback で具体的に指摘して reject

**関連:**
- `contract_reject_test_env_default_conflict.md` の正攻法 (3) (runApp 経路と pumpWidget 経路の分離) の実装パターン
- Sprint 01 の `f7f582d -- app/lib/main.dart` で確立した「main.dart は薄い entry + export」構造 (再利用可能)
