# Handoff: Issue #5 — P2P 楽曲転送 (チャンク受信 + 暗号化 + 整合性)

- branch: `sprint/05-p2p-transfer`
- RED commit: `6e8422c`
- GREEN commit: `0b33513`
- contract attempts: 2 (approved on attempt 2)
- impl attempts: 1/5

## 実装サマリ

受信機側 (receiver) の P2P 楽曲チャンク受信パイプラインを Domain / Data 層に純 Dart で新設した。送信機側・実 BLE/nearby・Riverpod wiring は契約 out_of_scope。

### Domain 層 (新規 4 ファイル)

| ファイル | 内容 |
|---|---|
| `app/lib/domain/entities/track_transfer.dart` | `TrackTransferManifest` (8 final fields), `TrackChunk` (sequence/payload/isLast), `TrackTransferStatus` (8 値 enum), `ReceiveProgress` (receivedBytes / totalBytes / status / optional error), `DecryptionFailure` 例外 |
| `app/lib/domain/services/integrity_verifier.dart` | `abstract IntegrityVerifier` + `Sha256IntegrityVerifier` (`package:crypto` の `sha256.convert`) |
| `app/lib/domain/services/payload_decryptor.dart` | `abstract PayloadDecryptor` + `AesGcmPayloadDecryptor` (`package:cryptography` の `AesGcm.with256bits`)。wire format = `cipherBody \|\| 16-byte mac` |
| `app/lib/domain/services/chunk_transport.dart` | `abstract ChunkTransport` + `FakeChunkTransport`。固定 `List<TrackChunk>` を `Stream` 化、optional `addError` で切断シナリオ |

### Data 層 (新規 2 ファイル)

| ファイル | 内容 |
|---|---|
| `app/lib/data/services/duplicate_track_detector.dart` | `abstract DuplicateTrackDetector` + `InMemoryDuplicateTrackDetector` (`Set<String>`) |
| `app/lib/data/services/track_receiver.dart` | `TrackReceiver.receive(): Stream<ReceiveProgress>`。重複ガード → in-order 組立て → SHA-256 検証 → preflight decrypt → `PersistEncrypted` callback。out-of-order / preflight 失敗 → `abortedIntegrity`、`addError` → `abortedDisconnected`、duplicate → `abortedDuplicate` (persist 不呼び出し) |

### pubspec.yaml

```yaml
crypto: ^3.0.3
cryptography: ^2.7.0
```

(他 dependency 変更なし)

### テスト (新規 4 ファイル, 計 16 ケース)

| ファイル | ケース数 | 主観点 |
|---|---|---|
| `app/test/domain/track_transfer_test.dart` | 3 | Manifest / Chunk / Status enum の値保持・8 値 enum 充足 |
| `app/test/domain/integrity_verifier_test.dart` | 3 | 一致 / 1byte 改竄 / sha256-of-empty 既知値 (`e3b0c44...`) |
| `app/test/domain/payload_decryptor_test.dart` | 3 | round-trip 'hello world' / 1bit tamper / 鍵不正 |
| `app/test/data/track_receiver_test.dart` | 7 | TP-12 の 7 観点 (completed / integrity / decrypt / disconnect / duplicate / progress / out-of-order) |

既存テスト (`app/test/widget_test.dart` 3 件 + `app/test/domain/track_test.dart` 4 件) は未改変 (test-integrity 遵守)。total = 7 既存 + 16 新規 = 23 件で SC[16] / TP-16 を満たす。

## Success criteria 対応マッピング

| SC# | 要件 | 対応箇所 |
|---|---|---|
| SC[1] | track_transfer.dart 存在 + Manifest/Chunk/Status grep | `app/lib/domain/entities/track_transfer.dart:13` (Manifest), `:39` (Chunk), `:54` (Status enum) |
| SC[2] | Manifest 8 final fields | `app/lib/domain/entities/track_transfer.dart:26-33` (8 行 grep ヒット確認済) |
| SC[3] | Status enum 8 値 | `app/lib/domain/entities/track_transfer.dart:54-65` |
| SC[4] | IntegrityVerifier abstract + Sha256 impl | `app/lib/domain/services/integrity_verifier.dart:5` (abstract), `:11` (impl) |
| SC[5] | PayloadDecryptor abstract + AesGcm impl | `app/lib/domain/services/payload_decryptor.dart:11` (abstract), `:21` (impl) |
| SC[6] | ChunkTransport abstract + FakeChunkTransport | `app/lib/domain/services/chunk_transport.dart:9` (abstract), `:18` (Fake) |
| SC[7] | TrackReceiver + `Stream<ReceiveProgress> receive()` | `app/lib/data/services/track_receiver.dart:30` (class), `:53` (receive 定義) |
| SC[8] | DuplicateTrackDetector abstract + InMemory impl | `app/lib/data/services/duplicate_track_detector.dart:3` (abstract), `:11` (impl) |
| SC[9] | pubspec deps | `app/pubspec.yaml` の `crypto: ^3.0.3` / `cryptography: ^2.7.0` |
| SC[10] | Domain 層に flutter/riverpod/just_audio/go_router import なし | 新規 4 ファイルとも `package:crypto` / `package:cryptography` のみ (chunk_transport は core 依存のみ) |
| SC[11] | Data 層に flutter/material・go_router import なし | 新規 2 ファイルとも `package:proximity_music_app/...` のみ |
| SC[12] | track_receiver_test ≥7 + 7 観点 | `app/test/data/track_receiver_test.dart` 7 ケース全観点カバー (下表) |
| SC[13] | track_transfer_test ≥3 | `app/test/domain/track_transfer_test.dart` 3 ケース |
| SC[14] | integrity_verifier_test ≥3 + sha256-of-empty | `app/test/domain/integrity_verifier_test.dart:46` で `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` 直接検証 |
| SC[15] | payload_decryptor_test ≥3 | `app/test/domain/payload_decryptor_test.dart` 3 ケース、`'hello world'` round-trip 含む |
| SC[16] | flutter test 23 件 green | SDK 不在 container のため CI (`.github/workflows/flutter-ci.yml`) で確認 (後述) |
| SC[17] | flutter analyze 通過 | CI で確認。新規コードに lint 抑止コメントなし |
| SC[18] | 既存テスト不変 | `git diff main -- app/test/widget_test.dart app/test/domain/track_test.dart` = 0 行 (確認済) |
| SC[19] | 既存実装 8 ファイル不変 | `git diff main -- <8 files>` = 0 行 (新規ファイル追加 + pubspec 追記のみ) |
| SC[20] | harness 系不変 | `git diff main -- init.sh .github/workflows/... docs/PIPELINE.md .harness/version bin/controller.py hooks/` = 0 行 |
| SC[21] | ReceiveProgress.totalBytes = manifest.totalBytes、receivedBytes 単調非減少、終端 status=completed | `track_receiver.dart` 全 yield で `totalBytes: manifest.totalBytes` 固定。`progress emit` テスト (`app/test/data/track_receiver_test.dart:292`) で `greaterThanOrEqualTo` ループ検証 |

### TP (test_plan) → 実装テストの対応 (RED 16 ケース)

| TP# | 観点 | 実装ケース (file:line) |
|---|---|---|
| TP-01,02,07,08,09,10,18,19,20 | 静的 grep | (CI / evaluator が直接実行する静的検査) |
| TP-03 | Manifest 8 final | `app/lib/domain/entities/track_transfer.dart:26-33` |
| TP-04 | Status enum 8 値 | `app/lib/domain/entities/track_transfer.dart:54-65` |
| TP-05 | abstract+具象 9 組 | 上表 SC[1]-[8] と同所 |
| TP-06 | `Stream<ReceiveProgress> receive(` | `app/lib/data/services/track_receiver.dart:53` |
| TP-11,12 (a) 正常系 | `'completed happy path'` | `track_receiver_test.dart:130` |
| TP-12 (b) 整合性 | `'integrity hash mismatch -> abortedIntegrity, persist not called'` | `track_receiver_test.dart:163` |
| TP-12 (c) 復号 | `'decrypt preflight failure (wrong cipher / key) -> abortedIntegrity'` | `track_receiver_test.dart:195` |
| TP-12 (d) 切断 | `'transport disconnect (addError) -> abortedDisconnected, ...'` | `track_receiver_test.dart:226` |
| TP-12 (e) 重複 | `'isDuplicate=true -> abortedDuplicate, persist callCount equals 0'` | `track_receiver_test.dart:263` |
| TP-12 (f) 進捗 | `'progress emit: receivedBytes is monotonically non-decreasing'` | `track_receiver_test.dart:292` |
| TP-12 (g) 順序 | `'out of order sequence -> abortedIntegrity'` | `track_receiver_test.dart:342` |
| TP-13 | track_transfer_test ≥3 | `track_transfer_test.dart:15,43,65` |
| TP-14 | integrity_verifier_test ≥3 + empty hex | `integrity_verifier_test.dart:15,26,39` (line 46 に既知 hex) |
| TP-15 | payload_decryptor_test ≥3 + 'hello world' | `payload_decryptor_test.dart:24,43,65` |
| TP-16,17 | flutter test / analyze | CI run |
| TP-21 | sha256 of empty 既知値 | `integrity_verifier_test.dart:46` |
| TP-22 | AES-GCM 'hello world' round-trip | `payload_decryptor_test.dart:24` (固定 32-byte key 0x00..0x1f, 12-byte nonce 0x00..0x0b) |
| TP-23 | FakeChunkTransport 使用 | `track_receiver_test.dart:130` ほか全 7 ケースで `FakeChunkTransport` 経由 |
| TP-24 | duplicate 時 persist 0 回 | `track_receiver_test.dart:263` (`persistCallCount, equals(0)`) |
| TP-25 | abortedDisconnected + addError + persist 0 | `track_receiver_test.dart:226` (`addError` + `abortedDisconnected` + `equals(0)`) |
| TP-26 | abortedIntegrity 時 persist 0 | `track_receiver_test.dart:163` (`abortedIntegrity` + `equals(0)`) |
| TP-27 | receivedBytes 単調非減少 (bytes ベース) | `track_receiver_test.dart:292` (`for` ループ + `greaterThanOrEqualTo`) |

## 起動方法 / 検証コマンド

このコンテナには Flutter SDK が無いため、ローカルで動かす手順と CI 検証の両方を示す。

### ローカル (Flutter SDK 必須)

```bash
./init.sh                 # Issue #1 で作成済の冪等セットアップ
cd app
flutter pub get           # crypto / cryptography を解決
flutter test              # 23 ケース全 green が期待値
flutter analyze           # 'No issues found.' が期待値
```

### evaluator 静的検査コマンド (SDK 不要)

```bash
# ファイル存在 (TP-01, TP-02, TP-10)
test -f app/lib/domain/entities/track_transfer.dart
test -f app/lib/domain/services/integrity_verifier.dart
test -f app/lib/domain/services/payload_decryptor.dart
test -f app/lib/domain/services/chunk_transport.dart
test -f app/lib/data/services/track_receiver.dart
test -f app/lib/data/services/duplicate_track_detector.dart
test -f app/test/data/track_receiver_test.dart
test -f app/test/domain/track_transfer_test.dart
test -f app/test/domain/integrity_verifier_test.dart
test -f app/test/domain/payload_decryptor_test.dart

# Manifest 8 final (TP-03)
grep -E 'final (int|String) (chunkCount|totalBytes|sha256Hex|encryptionAlgo|mimeType|suggestedFileName|title|artist)' app/lib/domain/entities/track_transfer.dart | wc -l   # 8

# Status enum 8 値 (TP-04)
grep -E '\b(idle|receiving|verifying|decrypting|completed|abortedIntegrity|abortedDisconnected|abortedDuplicate)\b' app/lib/domain/entities/track_transfer.dart | wc -l    # 8+

# 抽象/具象 9 組 (TP-05): contract.json TP-05 (a)-(i) を順に grep

# pubspec deps (TP-07)
grep -cE '^\s+(crypto|cryptography):' app/pubspec.yaml   # 2

# 層 import 制約 (TP-08, TP-09)
grep -REn "^import 'package:(flutter/|flutter_riverpod|just_audio|go_router)" app/lib/domain/ | wc -l   # 0
grep -REn "^import 'package:(flutter/material|go_router)" app/lib/data/ | wc -l                          # 0

# 既存ファイル不変 (TP-18, TP-19, TP-20)
git diff main -- app/test/widget_test.dart app/test/domain/track_test.dart | wc -l     # 0
git diff main -- app/lib/main.dart app/lib/app.dart app/lib/data/services/audio_service.dart \
  app/lib/domain/entities/track.dart app/lib/presentation/state/providers.dart \
  app/lib/presentation/pages/dashboard_page.dart app/lib/presentation/pages/player_page.dart \
  app/lib/presentation/widgets/mini_player.dart | wc -l   # 0
git diff main -- init.sh .github/workflows/flutter-ci.yml docs/PIPELINE.md .harness/version \
  bin/controller.py hooks/ | wc -l   # 0

# テストケース数
grep -cE "^\s*test\(" app/test/data/track_receiver_test.dart      # 7
grep -cE "^\s*test\(" app/test/domain/track_transfer_test.dart    # 3
grep -cE "^\s*test\(" app/test/domain/integrity_verifier_test.dart  # 3
grep -cE "^\s*test\(" app/test/domain/payload_decryptor_test.dart   # 3

# 既知ハッシュ / 既知 plaintext (TP-21, TP-22)
grep -F 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' app/test/domain/integrity_verifier_test.dart
grep -F 'hello world' app/test/domain/payload_decryptor_test.dart
```

### CI (TP-16, TP-17 の SDK 必須項目)

`.github/workflows/flutter-ci.yml` が PR push で `flutter pub get` → `flutter test` → `flutter analyze` を回す。最新 run の summary が緑であることが SC[16] / SC[17] の代替確認 (契約 SC[16] 後段で明文化済)。本ブランチの最新 commit `0b33513` の CI 結果を evaluator は確認すること。

## 既知の制約 / 後続 Issue への申し送り

1. **(Issue #6 即時再生)** `TrackReceiver` は受信した暗号文をそのまま `PersistEncrypted` に渡す。再生時の復号は Issue #6 (AudioService 拡張) で実装する。本 Issue の `payload_decryptor` 抽象/実装をそのまま再利用できる設計にしてある (鍵 / nonce は呼び出し側パラメータ)。
2. **(Issue #4 鍵交換)** 復号鍵 / nonce は `TrackReceiver` のコンストラクタ引数に直接渡す形 (テスト時はリテラルバイト列)。Issue #4 の SessionTransport / SessionId と結線する adapter は別 Issue で書く。`TrackReceiver` の API は変更不要。
3. **(Issue #9 storage / 重複)** `DuplicateTrackDetector` は `InMemoryDuplicateTrackDetector` のみ提供。永続化版 (sqflite or flutter_secure_storage backed) は Issue #9 で実装する想定。本 Issue の interface はそのまま継承可。`record(sha256Hex)` は `PersistEncrypted` 成功後に呼ぶ実装になっているため、後続で永続化に置換しても呼び出し順は変えなくてよい。
4. **(BLE/nearby)** `ChunkTransport` 抽象は `Stream<TrackChunk>` のみを公開。`FakeChunkTransport` がテスト用 in-memory 実装。`flutter_blue_plus` / `nearby_connections` ベースの実装は Issue #3 完了後の別 Issue で。
5. **(transit cipher hash)** 契約 out_of_scope[14] のとおり、`manifest.sha256Hex` は転送中暗号文の SHA-256 を指す。同一楽曲を異なる鍵で再受信した場合の重複検出漏れは仕様。後続 Issue で plain content hash 版に切替えても `IntegrityVerifier` interface は不変。
6. **(preflight decrypt の範囲)** 全暗号文を decrypt して整合性を担保している (1 ブロック preflight ではない)。理由: AES-GCM は最終 mac 検証のために全文必要なため、部分 preflight は不可能。契約 scope[5] の「preflight として呼び、失敗時は abortedIntegrity」要件は『失敗時の状態遷移』が本質と解釈し、復号成功時の plaintext は捨てる。コメントは `track_receiver.dart:7` に明記。

## 自己評価 (Guilty until proven innocent, 過小気味に)

| 観点 | 自己採点 | 根拠 |
|---|---|---|
| **契約 SC 充足** | △ (要 evaluator 検証) | 21 SC のうち静的 grep 系 (SC[1]-[15], SC[18]-[20]) は手元で確認済。SC[16]/[17] (flutter test/analyze) は SDK 不在のため CI 待ち。CI 結果次第で △ → ○ |
| **TDD 遵守** | ○ | RED commit `6e8422c` (test 4 ファイル + 16 ケースのみ、impl 0) → GREEN commit `0b33513` (impl 6 ファイル + pubspec、テスト変更なし)。順序明確 |
| **test-integrity** | ○ | 既存 7 ケース (`widget_test.dart` 3 + `track_test.dart` 4) を一切変更していない (`git diff main` 0 行) |
| **層分離** | ○ | Domain 4 ファイル: `package:flutter/...` `package:flutter_riverpod` `package:just_audio` `package:go_router` 一切なし。Data 2 ファイル: `package:flutter/material` `package:go_router` なし |
| **YAGNI / 契約外混入なし** | △ | preflight decrypt が「全暗号文 decrypt」になっている点は契約 scope[5] と厳密には差異あり。失敗時の状態遷移は契約通りなので機能要件は充足するが、evaluator が「最初の 1 ブロックだけ」を要件と解釈すれば指摘されうる。コメントに理由明記済 |

総合: 契約 SC を 18/21 で満たしていると確信。SC[16]/[17] は CI 結果待ち。SC[5] の preflight 解釈差異は evaluator 判断に委ねる (コードは契約の機能要件を満たすが文言と乖離あり)。

## 技術判断ログ

1. **`AesGcm.with256bits` (cryptography パッケージ) 採用**: Dart 標準には AES-GCM 実装がないため `package:cryptography ^2.7.0` を契約どおり追加。`SecretBox` の wire format は (nonce, cipherBody, mac=16byte) だが、契約は ciphertext + mac の連結を期待していると読み取り、`payload_decryptor.dart` 内で `cipherBody = ciphertext[:-16] / mac = ciphertext[-16:]` とパースする実装にした。テスト側で encrypt → decrypt round-trip するため整合性は保証される。
2. **preflight decrypt の範囲**: 上記「既知の制約 6.」のとおり、AES-GCM の特性上「最初の 1 ブロックだけ」という preflight は不可能。契約 scope[5] の意図は『復号失敗を `abortedIntegrity` で扱う』点と解釈。
3. **`record(sha256Hex)` 呼び出し位置**: `PersistEncrypted` 成功後に呼ぶ。失敗パス (integrity / decrypt / disconnect) では呼ばないことで、再試行時に重複扱いされない。契約に明文化なしだが合理的解釈。
4. **`ReceiveProgress` の発行タイミング**: 各 chunk 受信ごと + 各 status 遷移ごとに emit。`receiving` (初回 + chunk ごと) → `verifying` → `decrypting` → `completed` または abort 系。SC[21] の `totalBytes = manifest.totalBytes` 固定 + `receivedBytes` 単調非減少 + 最終 `completed` は `progress emit` テストで検証。
5. **`out-of-order` を `abortedIntegrity` に統一**: 契約 scope[5] の文言「out-of-order が来たら abortedIntegrity で終了」に従う。`abortedDisconnected` ではない。

## blocker

なし。READY_FOR_REVIEW に遷移する。
