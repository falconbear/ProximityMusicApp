# Initial Brief — ProximityMusicApp

## 概要

近接通信ですれ違った端末と楽曲を交換し、自動再生で偶発的な音楽体験を提供する Flutter アプリ (iOS/Android)。
本ハーネスは既存リポジトリ `falconbear/ProximityMusicApp` を引き継ぐ形で導入される。

## 既存の前提

詳細仕様は以下を参照:
- `docs/requirements.md` — 要件定義 (元プロジェクトで作成済み)
- `docs/architecture.md` — 技術選定とアーキテクチャ方針
- `docs/project-plan.md` — プロジェクト計画
- `docs/process-and-quality.md` — プロセスと品質方針
- `app/DEVELOPMENT_STATUS.md` — 直近の進捗メモ (2024-12-14 時点)

planner は `docs/spec.md` を起こす際に上記を入力として扱い、矛盾があれば `docs/spec.md` を Source of Truth として上書きする。

## 現状

### 実装済み (元プロジェクトより継承)

- 音楽再生 (`just_audio` + `audio_service`、バックグラウンド再生対応)
- Spotify風ダーク UI (Material 3)
- ミニプレイヤー
- Riverpod による状態管理
- GoRouter による宣言的ルーティング

ただし `lib/main.dart` 1 ファイルにすべて書かれており、層分離 (Presentation / Domain / Data) されていない。リファクタリングは MVP 機能追加と並行して順次行う。

### 未実装 (MVP の核)

1. **近接検知**: Platform Channels (Pigeon) + iOS CoreBluetooth/MultipeerConnectivity / Android Nearby Connections / BLE
2. **P2P 楽曲転送**: チャンク送受信、整合性チェック、暗号化
3. **セッション・ピア管理**: 匿名 ID ローテーション、エフェメラル鍵交換
4. **セキュリティ**: E2E 暗号化、ローカル保存暗号化、ブロックリスト
5. **受信楽曲管理**: 受信履歴、お気に入り、ストレージ上限とクリーンアップ

## コア機能 (MVP スコープ)

- 周囲端末の近接検知 + 匿名セッション確立
- 短尺サンプル楽曲の P2P 転送 + ローカル保存
- 受信即時再生 + 自動再生キュー (既存プレイヤー基盤を再利用)
- ブロック / スキップ / お気に入り
- バックグラウンドでの受信・再生
- 簡易ログ/メトリクス、電池消費の基本対策

## 言語 / プラットフォーム

- Flutter (Dart) — iOS / Android 両対応
- ネイティブ層: Kotlin (Android) / Swift (iOS) — 近接通信実装に使用
- バックエンド: なし (P2P のみ) — 必要になれば後続スプリントで GCP サーバレスを検討

## Out of scope (MVP)

- レコメンド / ランキング / ソーシャル機能
- DRM / 配信権管理 (権利クリア音源のみを扱う前提)
- サーバ運用 (バックエンド連携は MVP では行わない)
- アクセシビリティ最適化 (MVP 後)
- ストア要件最終調整 (法務チェック含む、ベータ後)

## 受け入れ基準 (MVP)

- 実機 2 種 (iOS/Android) で「すれ違い検知 → セッション確立 → サンプル楽曲受信 → 即時再生」が完走する
- バックグラウンドでの受信・再生が動作する
- ブロック / スキップ / お気に入りが正しく動作し、次回以降の挙動に反映される

## スプリント分割の見立て (planner が再分解する)

詳細は planner が `docs/project-plan.md` のロードマップ案を踏まえて `docs/spec.md` で正式定義する。ここでは粒度の目安のみ:

- 既存コードのリファクタリング (層分離、テスト整備) — 規模次第で MVP 機能と並行
- 近接検知 PoC (Platform Channels スパイク含む)
- セッション確立 + 匿名 ID ローテーション
- P2P 楽曲転送 + 暗号化
- 受信楽曲管理 (お気に入り、ブロック、ストレージ上限)
- 電池/安定性チューニング、ログ/メトリクス整備

## 環境セットアップに関する注記

元リポジトリは AI ハーネス前提ではなかったため、generator は最初のスプリントで:
- `init.sh` を `initializer-protocol` skill に従って整備 (Flutter SDK 依存、`flutter pub get`、テスト/lint コマンド)
- 既存テストの整備 (`app/test/widget_test.dart` 1 つのみ存在)
- CI ワークフロー整備 (format / analyze / test)

を行うことが想定される。詳細は planner / generator の判断に委ねる。
