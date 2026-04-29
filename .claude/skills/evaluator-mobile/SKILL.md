---
name: evaluator-mobile
description: モバイルアプリ (React Native / Expo / iOS / Android / Flutter) を対象とする evaluator の実装技術。スタック判定、ビルド起動、シミュレータ / 実機での検証、単体 + 統合 + E2E テストの使い分けを定義する。skeptical-evaluation の 3 層テストをモバイル固有の制約下で実行するためのプロトコル。
---

# evaluator-mobile — モバイルアプリ検証

iOS / Android / クロスプラットフォーム (RN, Expo, Flutter) の実装モード evaluator が使う。ブラウザではなくシミュレータ / 実機 / エミュレータ上で契約 Test plan を実行する。

## スタック判定 (起動時)

以下を順に確認してスタックを特定する:

```bash
test -f app.json -o -f app.config.{js,ts} && echo "expo"
test -f package.json && grep -q "react-native" package.json && echo "react-native (bare)"
test -f pubspec.yaml && grep -q "flutter:" pubspec.yaml && echo "flutter"
test -f ios/Podfile && echo "ios native"
test -f android/build.gradle && echo "android native"
```

複数該当する場合 (Expo + iOS/Android フォルダあり) は**プロジェクトの CLAUDE.md が指定するターゲット**を優先する。

## 評価モードの選択

スタックと契約の Scope から以下のいずれかを選ぶ:

| 条件 | 評価モード |
|---|---|
| Expo Web が有効 / 契約が Web 対応と指定 | `evaluator-web` skill に委譲 (Playwright で Expo Web を検証) |
| iOS simulator / Android emulator が利用可能 | シミュレータ検証 (後述) |
| 実機接続が前提の機能 (Camera, Biometric, Push) | 実機検証 (手順を feedback に明記、CI でない環境で人間補助) |
| E2E (Detox / Maestro) セットアップ済み | E2E スクリプト実行 |
| 上記いずれも不可 | 単体 + 統合テスト + ビルド成功 + Metro 起動確認で代替 |

## ビルド起動 (スタック別)

### Expo

**自動テスト (evaluator が叩く) の場合:**

```bash
npx expo install --check           # 依存整合
npx expo start --ios                # iOS simulator で起動 (--android / --web も選択可)
```

- Metro bundler が起動 → バンドルを simulator へ配信
- 初回は 30-60s かかる。`wait-for-log` 的な監視で "Bundling complete" を待つ

**人間が実機 (iPhone / Android) で目視確認したい場合 (Tailscale 経由):**

```bash
npx expo start --host lan          # 0.0.0.0 bind (Metro bundler は 8081)
bash bin/show-test-url.sh 8081     # Tailscale URL を表示
```

- 出力された Tailscale URL (例: `http://macbook-air.<tailnet>.ts.net:8081`) を**1 行ハイライトでユーザーに伝える**
- ユーザーは:
  - **Expo Go アプリ** (App Store / Google Play) を起動
  - 「Enter URL manually」で上記 Tailscale URL を入力 (または同じターミナルに出る QR コードをスキャン)
  - アプリがホットリロードで配信される
- 評価は localhost (シミュレータ) でやり、人間目視確認だけ Tailscale URL を共有する分業 (CLAUDE.md「実機テスト」節)
- `--tunnel` (Expo 内蔵 ngrok) は外部サービス依存なので**使わない**。Tailscale を一本化する

### React Native (bare)

```bash
cd ios && pod install && cd ..
npx react-native run-ios            # simulator
# または
npx react-native run-android        # emulator
```

### Flutter

```bash
flutter pub get
flutter run -d "iPhone 15"          # simulator を名前で指定
flutter test                         # widget + unit
flutter test integration_test/      # integration
```

### iOS native

```bash
xcodebuild -scheme <scheme> -destination 'platform=iOS Simulator,name=iPhone 15' build
xcrun simctl boot "iPhone 15"
xcrun simctl install booted /path/to/App.app
xcrun simctl launch booted com.example.app
```

### Android native

```bash
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.app/.MainActivity
```

## 契約 Test plan の実行

契約の Test plan の各手順について:

1. シミュレータ / エミュレータ上で手順を再現
2. 可能なら自動化 (Detox / Maestro / xcuitest / Espresso) で記述
3. 自動化が無い場合は `xcrun simctl io booted screenshot` や `adb exec-out screencap -p` で証拠キャプチャ
4. 期待結果と実際を比較

### Detox がある場合

```bash
npx detox build --configuration ios.sim.debug
npx detox test --configuration ios.sim.debug
```

### Maestro がある場合

```bash
maestro test flows/
```

### 自動化が無い場合 (多くの RN / iOS / Android プロジェクトの現実)

1. ビルド成功と起動成功を baseline とする
2. 単体 + 統合テスト (Jest / XCTest / JUnit) を全通し
3. 主要画面遷移を手動手順として feedback に列挙し、各ステップのスクリーンショット取得
4. `init.sh` が冪等にビルドを再現できることを確認

## テストの 3 層 (モバイル固有)

### A. 契約ベーステスト
- 契約の Test plan を上記いずれかの方法で実行
- 自動化テストがあればそちらを正とする

### B. 回帰テスト
- 既存の PASSED Sprint で確立した画面・フローが壊れていないか
- 既存の Jest / XCTest / JUnit / widget test を全通し (failing が 1 件でも NEEDS_FIX)

### C. 敵対的テスト (モバイル固有)

| カテゴリ | 具体 |
|---|---|
| **キーボード** | フォーカス中にキーボードが UI を隠さないか、Done 押下で閉じるか |
| **画面回転** | ポートレート ↔ ランドスケープで state が消えないか (サポートする場合) |
| **オフライン** | ネットワーク切断中のエラー表示、再接続で復帰するか |
| **バックグラウンド復帰** | アプリを backgrounded → 戻したときに state が保たれるか |
| **権限拒否** | Camera / Location / Notification 権限を拒否したときのエラー処理 |
| **キャンセル** | 非同期操作中に画面 pop / 戻るボタン → クラッシュしないか |
| **低メモリ** | 長時間利用でメモリリークしないか (プロファイラで確認、契約にあれば) |

## エラー検知

### ログ
```bash
# iOS simulator
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem contains "<bundle-id>"'

# Android emulator
adb logcat -s ReactNativeJS:V

# Expo
# Metro 出力を監視
```

- `red box` (RN) / クラッシュログ (native) が出たら即 NEEDS_FIX
- `yellow box` (RN warning) は契約で許容されていなければ NEEDS_FIX

### クラッシュ
- iOS: `~/Library/Logs/DiagnosticReports/` のクラッシュレポート
- Android: `adb logcat` で `FATAL EXCEPTION`

## Expo Web へのフォールバック

契約が UI 観点のみで、モバイル固有機能 (Camera / Push / BLE) を使わない場合:

1. `npx expo start --web` で Web 版を起動
2. `evaluator-web` skill に切り替えて Playwright で検証
3. feedback に「Expo Web で検証、native 固有動作は未検証」と明記

これは契約が native 固有を要求していない場合に限る。契約が iOS / Android 指定なら Web で代替しない。

## 禁止事項

- シミュレータプロセスを残して終了 (次回起動の port conflict 原因)
- Expo Go の warning を無視 (dev build と prod build で挙動が違う可能性)
- 「シミュレータで動けば OK」と実機検証を省略する (契約で実機指定されている場合)
- クラッシュレポートを読まずに NEEDS_FIX を出す (根拠が弱くなる)

## 参照

- `skills/skeptical-evaluation/` — 合否判定の 9 原則と 5 基準スコア
- `skills/test-integrity/` — generator のテスト改変検知
- `skills/initializer-protocol/` — アプリ起動プロトコル
- `skills/evaluator-web/` — Expo Web へフォールバックする際の Playwright 検証手法
- `skills/ui-design-quality/` — デザイン品質の advisory 評価
