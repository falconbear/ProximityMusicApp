---
name: Contract reject pattern - test environment default vs spec UX conflict
description: Generator が widget_test 互換のため永続化スタブの default を completed/granted/skipped にする提案は、spec の初回起動 UX と矛盾しやすく契約段階で reject すべき
type: feedback
---

`[CONTRACT-REJECT]` Generator が「テスト時の互換性のため、Domain の永続化スタブの初期値を `completed` (オンボーディング)、`granted` (permission)、`true` (consent) のような『すでに済んだ状態』にする」と提案してきたら、spec の初回起動 UX と直接矛盾しないか必ず確認する。

**Why:** Issue #2 contract attempt 1 で Generator が scope[15] に「永続化スタブの初期値 = completed (テスト互換のためのデフォルト)」と書いたが、spec.md 機能 2 受け入れ基準 1「初回起動時、ウェルカム / プライバシー説明 / 権限要求の 3 ステップ以上のスクリーンが順に表示される」と直接矛盾。実機初回起動で Dashboard に直行してしまう契約を承認すれば spec_aligned FAIL の状態で Phase 3 に進み、後で詰む。

**How to apply:**
1. contract.scope に「テスト互換のため Domain default を X にする」記述があれば、その X が「初回起動 UX」「初回オンボーディング」「初回同意」のどれかと衝突しないか spec.md を grep で照合
2. 衝突したら以下の正攻法を提案:
   - **ProviderScope.overrides**: テスト側で provider を override (widget_test.dart 自体は不変要件があれば、`onboardingProviders.dart` 側に override 用 hook を提供)
   - **kFlutterTesting / WidgetsBinding 検知**: Provider のデフォルト値生成時にテスト環境を検知し、test/prod で分岐
   - **runApp 経路と pumpWidget 経路の分離**: main.dart の runApp で ProviderScope.overrides を渡し、widget_test.dart はその override 無しの ProviderScope を経由するため別 default を持つ
3. 上記いずれかを契約に明文化させる
