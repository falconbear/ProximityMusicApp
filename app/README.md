# Proximity Music App (Flutter, mock UI)

## 状態
- Flutter/Dart が未インストールの環境想定。まず Flutter SDK を導入してください。
- 現在はモックUIで、近接検知やオーディオ再生は未実装です。

## セットアップ（macOS）
1) Flutterをインストール:  
   - `brew install --cask flutter` もしくは公式手順でSDKを配置。  
   - `flutter doctor` で依存を解消（Xcode / Android SDK / CocoaPods）。
2) プロジェクト初期化:  
   ```
   cd proximity-music-app/app
   flutter pub get
   ```
3) 実行:  
   - iOSシミュレータ: `flutter run -d ios`  
   - Androidエミュレータ: `flutter run -d android`
   - 実機テストは近接API検証で必須。

## モックの使い方
- ホーム画面で「Discovery」スイッチをONにし、FABの「受信をシミュレート」でキューに曲が追加されます。
- Queue/Player画面でスキップやブロック(モック)の挙動を確認できます。

## 次の実装ステップ（例）
- 近接通信: Platform Channel経由で MultipeerConnectivity(iOS) / Nearby Connections(Android) のスパイク。
- 再生: `just_audio` + `audio_service` でバックグラウンド再生を実装、モックキューと差し替え。
- ストレージ: Hive/Driftでお気に入り・ブロックリスト・キューを永続化。
- バックエンド: Cloud Run + Firestore/Cloud SQL で匿名ID/ブロックリスト/メトリクスAPIを用意し、Feature Flagで段階導入。
