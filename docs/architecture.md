# アーキテクチャと技術選定

## 技術選定
- クライアント: Flutter (Dart) / iOS & Android 両対応。
- 状態管理: Riverpod or Bloc（テスト容易性と依存注入を重視）。
- UI/UX（モダン志向）:
  - Material 3 + カスタムデザイントークン（カラー/タイポ/エレベーションを一元管理）、モーションは `Animated*`/`ImplicitlyAnimated`系 + 必要に応じて `rive`/`lottie`。
  - v0/Locofy/Figma AI等のAI補助で初期デザイン案を生成し、Flutterで実装（最終は手動調整）。
- オーディオ/再生基盤:
  - ライブラリ: `just_audio` + `audio_session`（フォア/バックグラウンドの音声セッション管理）、`audio_service`（バックグラウンド再生とメディア通知）。
  - エンコード/ファイル: `ffmpeg_kit_flutter` で将来的なトランスコード対応を検討（初期は不要）。
  - DRM/配信は想定しない（ローカル転送のみ）。権利クリアなサンプル音源を利用。
- ストレージ: `hive` or `drift`（暗号化は `flutter_secure_storage` + encrypted box）。
- 近接通信: Platform Channels/Pigeonで抽象化。
  - iOS: CoreBluetooth / MultipeerConnectivity / Nearby Interaction（要スパイク）。
  - Android: Nearby Connections API / Wi‑Fi Direct / BLE。
- バックエンド: サーバレスを優先。BaaS(Firebase/Supabase)またはGCPサーバレス構成で認証・ブロックリスト・匿名ID管理を軽量に。
- CI/CD: GitHub Actions/Bitrise/Codemagicで format/lint/test/build を自動化。Crashlytics/Sentry導入。

## アーキテクチャ方針
- クリーンアーキテクチャ or MVVM: Presentation(View+State) / Domain(UseCase, Entity) / Data(Repository, DataSource) の3層。
- 近接通信の抽象: `DiscoveryService`, `SessionService`, `TransferService` をインタフェース化し、iOS/Android実装を差し替え。
- ドメインモデル例: `Track`, `Peer`, `Session`, `ExchangeEvent`, `PlaybackQueue`, `UserPreference`.
- セキュリティ: 匿名IDの周期ローテーション、一時鍵交換(エフェメラル鍵)、転送データ暗号化、保存データ暗号化。
- バッテリ対策: スキャン間隔/送信サイズの制御、バックオフ、ユーザーによる開始/停止トグル、低電力時の挙動変更。

## データフロー概要
- 近接検知: OS API → Platform Channel → DiscoveryService → Domainイベント。
- セッション確立: セッション要求/レスポンス → 鍵交換 → `Session` 確立。
- 転送: `TransferService` がチャンク送受信、整合性チェック後に `Repository` 経由で保存。
- 再生: `PlaybackQueue` が `just_audio` に指示、バックグラウンドは `audio_service` で制御。
- 設定/フィルタ: `UserPreference` を永続化し、ブロック/お気に入り/ストレージ上限に反映。

## バックエンド/インフラ選択肢
- なし/サーバレス開始: 完全P2Pで開始し、後から必要に応じて認証・ブロックリスト・メトリクスをBaaSに載せる。
- GCPサーバレス（推奨デフォルト）:
  - API: Cloud Run（軽量REST/GraphQL。FastAPI/NestJS/Dart Frogなど）。
  - データ: Firestore(スキーマレスで速く動ける) or Cloud SQL(PostgreSQL) + Cloud Run。匿名ID/ブロックリスト/メトリクスを格納。
  - ストレージ: Cloud Storage（転送音源は扱わない想定だが、検証データやログ保管に利用可）。
  - セキュリティ: Cloud IAM + Secret Manager、必要に応じてIAP。
  - パイプライン: GitHub Actions → ビルド/テスト → `gcloud run deploy` でデプロイ。
- ローカル開発/学習用:
  - DB: DockerのPostgreSQLで起動し、Cloud SQL互換スキーマで開発。例: `docker run -p 5432:5432 -e POSTGRES_PASSWORD=pass -e POSTGRES_DB=proximity postgres:15`.
  - API: ローカルで`dart_frog`/`NestJS`/`FastAPI`などシンプルなRESTを立てて認証・ブロックリストを担保、後にCloud Runへ載せ替え。
  - エミュレーション: Firebaseなら Emulator Suite を活用。

## ローカル開発のサンプル手順（DBサーバ）
1. DockerでPostgreSQLを起動:  
   `docker run --name proxmusic-pg -p 5432:5432 -e POSTGRES_PASSWORD=pass -e POSTGRES_DB=proximity postgres:15`
2. マイグレーション: `sqflite_common_ffi`や`drift_dev`でスキーマを管理する場合はCLIで実行。サーバAPIを持つ場合はORM(Prisma/TypeORM/SQLAlchemy)でマイグレート。
3. アプリ接続: `.env`または`secrets`で接続文字列を管理し、リポジトリ層に注入。CIでも同じコンテナを立ててテストを走らせる。

## テスト戦略の観点
- Domain/UseCaseのユニットテストを最優先。
- Data層はインタフェースをモックし、転送/再生はフェイク実装でインテグレーションテスト。
- 近接通信はプラットフォームスタブでシミュレーション、実機E2Eで補完。
- パフォーマンス/バッテリ計測は実機で定点観測し、スプリントごとに回帰計測。
