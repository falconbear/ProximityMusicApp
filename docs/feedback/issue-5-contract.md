# Issue #5 契約レビュー結果

**判定:** ✅ 承認 (→ CONTRACT_APPROVED)
**レビュー日:** 2026-05-05 (再審査)
**Contract attempts:** 2/3

## Revision history

| Attempt | Date | 判定 | 主要指摘 / 解消 |
|---|---|---|---|
| 1 | 2026-05-05 (初審) | REJECT | TP-12 OR 合算 grep / SC[6][19][20] 独立 TP 不在 / 既存テスト 6→7 / out_of_scope 2 項目不足 |
| 2 | 2026-05-05 (再審) | **APPROVE** | 上記 5 指摘すべて解消 (詳細は本文書) |

## 7 観点チェック (再審査)

| # | 観点 | 判定 | 根拠 |
|---|---|---|---|
| 1 | Scope の明確性 (scope_clarity) | PASS | scope 14 項目、Domain/Data 層責務分離・抽象/concrete 二段・preflight decrypt 意図など具体的。曖昧語なし。前回から不変、PASS 維持。 |
| 2 | Out of scope の明示性 (out_of_scope_explicit) | **PASS (改善)** | 前回 13 項目 → 14 項目。out_of_scope[12] に "Plain content hash ベース重複判定" を本 Issue 範囲外と明示、out_of_scope[13] に "受信中の楽曲名/アーティスト/進捗 UI 表示" を Issue #6 範囲と明示。問題 4 / 5 解消。 |
| 3 | Success criteria の測定可能性 (success_measurable) | PASS | 21 項目すべてに grep / wc -l / git diff / file existence の binary 検証コマンドあり。前回から不変、PASS 維持。 |
| 4 | Test plan の実行可能性 (test_plan_executable) | **PASS (改善)** | TP-12 が 7 観点別の独立 grep -cE に分解され、最終行に「7 つの grep 全てが独立に >= 1 を返した場合のみ合格 (合算 grep は不可)」と明記。問題 2 解消。 |
| 5 | Coverage (criteria が test plan に全網羅) | **PASS (改善)** | SC[6] (abortedIntegrity 時 PersistEncrypted 不呼び出し) → TP-26、SC[19] (abortedDisconnected の Stream 終了挙動) → TP-25、SC[20] (ReceiveProgress 単調非減少 bytes ベース) → TP-27 がそれぞれ独立 TP として追加。テスト名 grep だけでなく本文識別子 + アサーション + 機構 (addError/Stream.error) の 3 軸で意味的検証を要求しており、契約モードでの担保水準として十分。問題 1 解消。 |
| 6 | spec.md との整合性 (spec_aligned) | PASS | spec §5 受け入れ基準との整合維持。"内容ハッシュ" 不整合を out_of_scope[12] で明示することで、評価者と次 Issue 担当 generator が前提を共有可能になった。 |
| 7 | 他 Issue との整合性 (prior_sprint_aligned) | **PASS (改善)** | SC[16] / TP-16 が「既存 7 件 + 新規 16 以上 = 23 以上」に修正され、main ブランチの実数値 (`grep -cE '^\\s*test(Widgets)?\\(' app/test/widget_test.dart app/test/domain/track_test.dart` で 7 を実測確認: widget_test.dart=3 + track_test.dart=4) と一致。問題 3 解消。 |

これらは `.ai/work/5/qa.json` の `contract_review.seven_point` にも記録済み。

## 前回指摘の解消状況

| # | 前回指摘 (重要度) | 今回の対応 | 検証結果 |
|---|---|---|---|
| 1 | TP-25/26/27 不在 (CRITICAL, Coverage 隙間) | TP-25 (abortedDisconnected: 識別子 + PersistEncrypted 不呼び出し + addError/Stream.error の 3 条件すべて binary grep), TP-26 (abortedIntegrity 時 PersistEncrypted 不呼び出し: 識別子 + 不呼び出しアサーション), TP-27 (receivedBytes 単調非減少: receivedBytes 3+ 件 + orderedEquals/greaterThanOrEqualTo/isNonDecreasing 1+ 件) を新規追加 | 全 3 項目 binary 判定可能、意味的検証要件を test plan に書き込み済み |
| 2 | TP-12 OR 合算 grep (MAJOR) | 7 観点それぞれ独立した `grep -cE "test\\(.*'.*(...).*'"` に分解。各観点 OR は同一 grep の `-e` で表現、観点間は分離。「合算 grep は不可」と明記 | 完全準拠 |
| 3 | 既存テスト件数 6→7 (MINOR) | SC[16] / TP-16 を「既存 7 件 + 新規 16 以上 = 23 以上」に修正。実態 grep コマンド (`grep -cE '^\\s*test(Widgets)?\\('`) を併記 | 実測 7 と完全一致 |
| 4 | out_of_scope に plain hash 範囲外明示 (MINOR) | out_of_scope[12] に追加 (transit cipher hash で代用、interface 不変のまま implementation 後続差し替え) | 追加確認 |
| 5 | out_of_scope に UI 表示範囲外明示 (MINOR) | out_of_scope[13] に追加 (ReceiveProgress Stream 作成までが本 Issue、Widget/Provider wire up は Issue #6) | 追加確認 |

5 項目すべて解消。CRITICAL の Coverage 隙間が埋まり、契約モードでの機械検証性と意味的担保が両立した。

## 承認の根拠

- **scope の精緻さ**: 14 項目で Domain / Data 層責務分離、抽象クラス先・concrete クラス後の設計、preflight decrypt によるエンドツーエンド整合性検証、FakeChunkTransport による flutter_test 完結性、いずれも generator が実装で迷う余地が少ない。
- **success_criteria の binary 性**: 21 項目すべてが grep / wc -l / git diff / file existence で機械判定可能。
- **test_plan の網羅性**: 27 項目 (TP-01〜TP-27) で SC をフルカバー。特に TP-25/26/27 で「テスト名キーワード grep だけでは挙動を担保できない」という Issue #1 の reflection が活かされ、本文識別子 + アサーション + 機構の 3 軸で意味的検証を要求している。
- **out_of_scope の透明性**: 14 項目で UI / 送信側 / Bluetooth / 鍵交換 / Riverpod wire up / plain hash 重複判定 / UI 進捗表示まで明示。後続 Issue (#3 / #4 / #6 / #9) との境界が一意に定まる。
- **prior_sprint_aligned**: 既存テスト 7 件の実測と整合。Issue #4 (SessionTransport) との未マージ前提も out_of_scope[2] で明示し、sprint/05 が main からの fork である構造が反映されている。
- **暗号アルゴリズム選択**: AES-GCM-256 / SHA-256 / pubspec パッケージ (crypto, cryptography) の具体性。

## Generator への指示 (実装フェーズ)

承認に伴い `contract.json` は CONTRACT_APPROVED 遷移と同時に lock される (controller 経由)。実装フェーズで以下の TDD 手順を厳守:

1. **Phase 3.1 RED**: 契約の Test plan (TP-01〜TP-27) を満たす failing test を `app/test/data/track_receiver_test.dart` (7+ ケース)、`app/test/domain/track_transfer_test.dart` (3+ ケース)、`app/test/domain/integrity_verifier_test.dart` (3+ ケース)、`app/test/domain/payload_decryptor_test.dart` (3+ ケース) として書き、`flutter test` で失敗を確認した上で 1 commit (実装ファイル混入禁止)。`bin/controller.py record-tdd --phase red` で IN_PROGRESS_RED へ。
2. **Phase 3.2 GREEN**: Domain / Data 実装を最小限で書き、上記テストを green にする。`bin/controller.py record-tdd --phase green` で IN_PROGRESS_GREEN へ。
3. **Phase 3.4**: `handoff.md` 整備 → `submit-impl` で READY_FOR_REVIEW。
4. 既存テストファイル (`widget_test.dart`, `track_test.dart`) は test-integrity skill により改変禁止。`git diff main -- app/test/widget_test.dart app/test/domain/track_test.dart` が 0 行であること。
5. 既存実装ファイル 8 個も契約 SC[18] に列挙されており同様に 0 行差分必須。
6. harness 系 (init.sh / .github/workflows/flutter-ci.yml / docs/PIPELINE.md / .harness/version / bin/controller.py / hooks/) も 0 行差分必須。
7. AES-GCM の cryptography package API 利用時、key/nonce のバイト長を 32/12 で固定すること (TP-22 の 'hello world' round-trip テストでこの形を要求)。

## 備考

- contract_attempts は今回 2/3 で承認に至り、3/3 ギリギリの強行突破ではない健全な収束。
- 前回指摘の問題 1 (Coverage 隙間) は CRITICAL 扱いだったが、TP-25/26/27 の追加によりテスト名キーワード grep 単独依存から脱却し、契約モードでの担保水準が引き上がった。これは将来 Issue (#7 / #9 など Stream / 状態遷移を含む契約) でも踏襲すべき pattern。
- Sprint 04 (Issue #4: 匿名セッション + ID rotation) との並行進行に伴うブランチ fork 状況も out_of_scope[2] で明確に切り分けられており、後続 adapter Issue (#5 → #4 結線) の前提が共有可能。
