---
name: needs_fix - CI flutter analyze warnings block flutter test execution
description: CI で analyze warning が exit 1 を出すと flutter test ステップが skip され、動的 SC が全面未確証になる
type: heuristic
---

`[HEURISTIC]` Flutter プロジェクトの CI workflow で `flutter analyze --no-fatal-infos` のみ指定 (warning は依然 fatal) かつ analyze ステップで warning が出ると、後続の `flutter test` ステップが実行されず、契約の動的 success_criteria (テスト件数 / Banner 動作 / redirect testWidgets / OnStateChanged) がすべて未確証になる。これを発見したら **NEEDS_FIX** で確実に差し戻す。

**Why:** Issue #2 attempt 1 の評価で、CI run #25133793477 が `prefer_const_constructors` warning 3 件 (consent_page.dart:65-67) で exit 1。後続の `flutter test` ステップが実行されず、TP-19 / TP-24 / TP-25 / TP-27 / TP-28 / SC-21 / SC-27 のすべてが「未確証」になった。Generator handoff の自己評価では「CI 検証依存」と書かれているが、実際は CI が test に到達していなかった = handoff の自己申告は鵜呑みにしてはいけないという原則 (Trust nothing self-reported) の典型例。

**How to apply:**
1. evaluator は `gh run list --branch <sprint-branch> --limit 5` で最新 run 状態を必ず確認する。失敗時は `gh run view <run-id> --log-failed` で具体的な失敗ステップを特定する
2. 失敗ステップが `flutter analyze` であれば、**`flutter test` は実行されていない可能性が高い** (`gh run view <id>` の job 出力で `- flutter test` のように "not executed" マーカー `-` を確認)
3. analyze で warning ゼロ要求 (例: SC-28 「0 error / 0 warning」) があれば warning 自体が契約違反 + 動的検証ブロックの二重違反となる
4. evaluator は scoring で:
   - **operational_stability**: CI が test に到達していないなら最大 2 (動作確証ゼロ)
   - **no_regressions**: 既存テストが 0 byte 不変でも flutter test 動的確証なしなら最大 3 (閾値 5 必須に対し常に FAIL)
   - これにより 5 基準のうち 2 つが必ず閾値未達 → 確実に NEEDS_FIX
5. feedback で `prefer_const_constructors` のような lint warning は **実装側で const を付けて消す** ことを最初の MUST に置く。CI workflow 側で warning を許容する (`--no-fatal-warnings` 追加) のは契約 SC と矛盾するので**実装側を直す方針を提示**する
6. 修正後の再評価では再度 `gh run list` で CI が green になっていることを最初に確認する

**関連:**
- `tdd-enforcement` skill (TDD 順序検証は CI 失敗の影響を受けない、別軸で検証可能)
- `test-integrity` skill (既存テストは 0 byte 不変だが動的 green 確証は別途必要)
- Sprint 01 instinct `feedback_post_passed_ci_bugs` (CI 修正は別 commit で対応する方針) — ただし READY_FOR_REVIEW 時点で CI red のまま PASSED は出さない
