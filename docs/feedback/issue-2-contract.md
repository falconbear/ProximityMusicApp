# Issue #2 契約レビュー結果

**判定:** ❌ 拒否 (→ PLANNED で revise)
**レビュー日:** 2026-04-30
**Contract attempts:** 1/3
**Branch:** sprint/02-onboarding-and-consent
**参照 instinct:** `.harness/instincts/evaluator/contract_lock_on_approve.md`

## 7 観点チェック (サマリ)

| # | 観点 | 判定 | 主要根拠 |
|---|---|---|---|
| 1 | Scope の明確性 (scope_clarity) | **FAIL** | 問題 6 (scope[8] redirect 条件と scope[15] redirect 条件の矛盾)、問題 9 (`OnStateChanged` の呼出契約欠落) |
| 2 | Out of scope の明示性 (out_of_scope_explicit) | **FAIL** | 問題 2 (機能 13 後段「再同意拒否時の機能停止 UI」の延期が out_of_scope に書かれていない) |
| 3 | Success criteria の測定可能性 (success_measurable) | **FAIL** | 問題 1 (TP-18 baseline SHA タイポ `f7f502d`)、問題 7 (再同意 redirect の検証コマンド欠落)、問題 8 (TDD 順序検証が state.json と非整合) |
| 4 | Test plan の実行可能性 (test_plan_executable) | **FAIL** | 問題 1 (TP-18 機械実行不能)、問題 8 (TP-23 が state.json.tdd を参照しない) |
| 5 | Coverage (criteria が test plan に網羅) | **FAIL** | 問題 3 (機能 2 の「設定画面から権限再要求」検証欠落)、問題 4 (機能 2 の「権限拒否状態で楽曲再生継続」検証欠落)、問題 7 (再同意 redirect 検証欠落)、問題 9 (OnStateChanged 検証欠落) |
| 6 | spec.md との整合性 (spec_aligned) | **FAIL** | 問題 2 (spec 機能 13 受け入れ基準 5「再同意拒否時に検知/受信/再生機能停止 + 利用規約画面と『同意する』『アプリを終了』のみ」の不在)、問題 5 (scope[15] のテスト互換デフォルト=completed が spec 機能 2 受け入れ基準 1「初回起動時に 3 ステップ以上のスクリーンが順に表示される」と矛盾) |
| 7 | 他 Issue との整合性 (prior_sprint_aligned) | PASS | Sprint 01 の Domain pure Dart / Data コールバック注入規約を継承、Track / 既存 widget_test.dart を不変扱い、Sprint 03+ 機能を out_of_scope で除外、branch が `sprint/02-...` で分離 |

これらは `.ai/work/2/qa.json` の `contract_review.seven_point` にも記録した。

**結論:** 7 観点中 6 個 FAIL。CRITICAL 級の不整合 (問題 1, 2, 5, 6) と MAJOR 級欠落 (問題 3, 4, 7, 8, 9) が複合しており、本契約のまま CONTRACT_APPROVED に進めると Phase 3 で必ず詰む。Contract attempts は 2/3 が残るので**拒否して再提出**を求める。

---

## 拒否理由と改善指示

### 問題 1 (CRITICAL): 観点 3, 4 — TP-18 の baseline SHA `f7f502d` がタイポ、機械実行不能

**何が問題か:**

TP-18 (既存テスト不変) の本文:

> `git diff f7f582d -- app/test/widget_test.dart | wc -l` の出力が 0 (=空 diff、Issue #1 完了時点と完全同一)。同様に `git diff **f7f502d** -- app/test/domain/track_test.dart | wc -l` (注: この base SHA は Issue #1 GREEN commit `e0f422a` で固定する) の出力が 0 もしくは 'no diff' であることを確認する。実際の base SHA は Issue #1 GREEN: `e0f422a`、Issue #1 fix: `638c972` のうち最新 = `638c972` を baseline とする ...

検証:

```
$ git rev-parse f7f502d
fatal: ambiguous argument 'f7f502d': unknown revision or path not in the working tree.
$ git rev-parse f7f582d
f7f582d96c7586347336904c796d956689dc2566   ← OK
$ git rev-parse 638c972
638c972ea6e617cddd8336c4684e93458cd7be0c   ← OK
```

つまり `f7f502d` は存在しない SHA。さらに同じ TP 文中で 3 つ異なる SHA (`f7f502d` / `e0f422a` / `638c972`) に言及し、「最新 = 638c972 を baseline とする」と結論している一方、コマンド本体は `f7f502d` を使うため**実行すれば即 fatal で失敗**する。

**なぜ問題か:**

- evaluator が TP-18 を実行しようとすると `git diff` がエラー終了し、合否判定そのものが下せない
- track_test.dart の不変性検証 (Sprint 01 で追加された 4 ケース、Issue #5 重複判定の前段階) は本 Sprint における重要な test-integrity 砦であり、ここの検証コマンドが破綻していると Generator が track_test.dart を改変しても契約上検出できない
- 同 TP に複数の baseline 候補が並列で書かれていて、どれを正とするか機械判定不能

**どう書き直すか:**

TP-18 を以下のように単一 SHA に固定し、widget_test.dart と track_test.dart で異なる baseline を許容する形に明示する:

```
TP-18 (既存テスト不変):
  (a) `git diff f7f582d -- app/test/widget_test.dart | wc -l` の出力が 0
      (widget_test.dart は Sprint 01 で 0 byte diff に保たれているため
       sprint 分岐元 f7f582d を baseline とする)
  (b) `git diff 638c972 -- app/test/domain/track_test.dart | wc -l` の出力が 0
      (track_test.dart は Sprint 01 fix commit 638c972 で確定しており、
       それ以降変更されていないことを baseline とする)
  Given: Sprint 02 commit 後 / When: git diff baseline / Then: 各 wc -l == 0
```

success_criteria #19 (「既存 app/test/widget_test.dart の差分が 0 byte である」) も同様に track_test.dart 用の項目を分けて 1 行追加する (現在は widget_test.dart 単独しか書かれていない)。

**参照すべき箇所:**

- `git log --oneline f7f582d..HEAD` で sprint ブランチ分岐元と Issue #1 fix commit の関係を確認
- Sprint 01 contract.json TP-09 の機械化方法 (`git diff f7f582d ... | grep -E '^[+-][^+-]' | grep -vE "^[+-]import " | wc -l == 0`) を参考に

---

### 問題 2 (CRITICAL): 観点 2, 6 — spec 機能 13 受け入れ基準 5「再同意拒否時の機能停止 UI」の不在と out_of_scope への明示欠落

**何が問題か:**

spec.md 機能 13 受け入れ基準 5:

> ユーザーが再同意を拒否した場合、アプリは検知 / 受信 / 再生機能を停止し、**利用規約画面と「同意する」「アプリを終了」のみ操作可能になる**。

これに対応する scope / success_criteria / test_plan が contract に**一切存在しない**。同時に out_of_scope にも「機能 13 受け入れ基準 5 の機能停止 UI は本 Sprint で扱わない」が**書かれていない**。

Generator は handoff の確認事項 #4 で「機能停止 UI は近接検知 / 再生キュー実装後の Sprint に委譲」と主張するが、契約は handoff ではなく契約自身が完結している必要がある。

**なぜ問題か:**

- spec 受け入れ基準が契約に欠落かつ out_of_scope にも書かれていない = 「やるとも言ってないし、やらないとも言ってない」状態。spec_aligned (観点 6) と out_of_scope_explicit (観点 2) が同時に FAIL
- 検知 / 受信 / 再生機能の停止は確かに Sprint 03+ の実装を要するが、「Consent 画面に stuck させて他画面遷移を不能にする」UI 制御は本 Sprint の範囲内でできる (DashboardPage や他ルートへの redirect を Consent 画面 stuck で阻害するロジックは本 Sprint の GoRouter redirect の延長線上にある)
- 「アプリを終了」ボタンも本 Sprint の ConsentPage 実装の延長線上にあるべき要素 (`SystemNavigator.pop()` を呼ぶ程度の最小実装)
- 「同意する」と「アプリを終了」の 2 ボタンが ConsentPage に揃うことは、Sprint 02 で完結できる純 Presentation 機能であり、後続 Sprint に分割する合理的理由がない

**どう書き直すか:**

以下のいずれかを契約に明文化する:

- **(A) scope に取り込む (推奨)**: scope に 1 行追加: 「ConsentPage は通常時 (初回オンボーディング時) は『同意して続行』のみだが、`needsReconsent == true` で開かれた再同意モードでは『同意する』『アプリを終了』の 2 ボタンを表示し、戻る / スキップを表示しない。アプリを終了ボタンは `SystemNavigator.pop()` を呼ぶ。再同意モードで GoRouter redirect が他ルート ('/' や '/onboarding/welcome') への遷移を阻害し、ConsentPage に stuck させる」。あわせて success_criteria に「ConsentPage の再同意モードで『アプリを終了』ボタンの存在 grep」「`SystemNavigator.pop` の grep」「Widget テストで再同意モードの遷移阻害を検証」を追加。test_plan にも該当 TP を追加。

- **(B) out_of_scope で延期を明示**: out_of_scope に「spec 機能 13 受け入れ基準 5 の『再同意拒否時に検知/受信/再生機能を停止し、利用規約画面と『同意する』『アプリを終了』のみ操作可能』の挙動は、近接検知 (Sprint 03)・受信 (Sprint 05)・再生キュー (Sprint 06) 実装後でないと『機能停止』を意味づけ可能なドメインが存在しないため、Sprint 06+ に分割延期する」と書く。**ただしこの根拠は弱い**: 機能停止 UI のうち少なくとも「ConsentPage に stuck させる redirect」と「『アプリを終了』ボタン」は本 Sprint 完結可能なため、Generator が (A) に倒すことを推奨。

最も率直なのは **(A)**。本 Sprint の主目的が「オンボーディング + 利用規約同意フロー」である以上、再同意フローの完成が成果物として整合する。

**参照すべき箇所:**

- spec.md 機能 13 受け入れ基準 (line 432-438)
- 現 contract scope[8] (GoRouter redirect 関数で `needsReconsent == true` のとき `/onboarding/consent` へ redirect する記述はあるが、stuck 化と 2 ボタン仕様の記述なし)
- 現 contract scope[5] (ConsentPage 4 ステップ目の記述はあるが、再同意モードの 2 ボタン分岐の記述なし)

---

### 問題 3 (CRITICAL): 観点 5 — spec 機能 2 受け入れ基準「設定画面から『権限を再要求』が押下できる」の検証欠落

**何が問題か:**

spec.md 機能 2 受け入れ基準 6:

> 設定画面から「権限を再要求」が押下できる

contract scope[10] にも記述あり:

> '/settings' は本 Sprint ではタイトル 'Settings' と '権限を再要求' ボタンのみ持つ最小実装で良い

しかし success_criteria と test_plan には「'/settings' に '権限を再要求' という文字列が表示される」「ボタンタップで `RequestOsPermission` コールバックが呼ばれる」を検証する項目がない。GoRouter ルート存在 (criterion #12 / TP-11) は検証されているが、SettingsPage の具体的な内容は何もチェックされない。

**なぜ問題か:**

- scope に書いてあるが measurable success criterion が無い = Coverage 違反
- Generator が空の Scaffold (`Scaffold(appBar: AppBar(title: Text('Settings')))`) だけ用意しても契約上は通ってしまう
- spec 受け入れ基準 6 が満たされない PR が READY_FOR_REVIEW に進む可能性

**どう書き直すか:**

success_criteria に 1 行追加: 「app/lib/presentation/pages/settings_page.dart (または '/settings' を担当する Scaffold) に '権限を再要求' という文字列が含まれる: `grep -F '権限を再要求' app/lib/presentation/pages/` 配下の '/settings' 担当ファイルで 1 件以上ヒット」。

test_plan に対応 TP 追加: 「TP-XX (設定画面再要求ボタン): `find /workspace/app/lib/presentation/pages -name '*settings*' -exec grep -lF '権限を再要求' {} \\;` の出力が 1 件以上、または app.dart 内で '/settings' route の builder が返す Widget が '権限を再要求' Text を含むこと」。

---

### 問題 4 (MAJOR): 観点 5 — spec 機能 2「権限拒否状態で楽曲再生は引き続き利用可能」の検証欠落

**何が問題か:**

spec.md 機能 2 受け入れ基準 5:

> 権限拒否状態で楽曲再生 (既存機能) は引き続き利用可能である

contract には:
- scope[9] で「permission status が denied の場合のみ Banner レンダリング」(表示)
- scope[10] で「DashboardPage に PermissionDeniedBanner 組込」(配置)

しかし「Banner が表示されている状態でも DashboardPage / PlayerPage の既存再生機能が動作する」ことを検証する項目がない。Banner が画面遷移を阻害したり、Switch (Discovery) や Player ナビゲーションに影響しないことの保証が空白。

**なぜ問題か:**

- 既存 widget_test.dart 3 ケース (smoke / Discovery toggle / Player navigation) は contract scope[15] により「permission status を granted デフォルト想定」で実行される (Banner 非表示)。つまり permission denied のシナリオで既存機能が動作することは新規テストでもカバーされない
- spec 受け入れ基準 5 が機械検証されない

**どに書き直すか:**

success_criteria に 1 行追加: 「PermissionDeniedBanner が表示されている状態で DashboardPage の Switch (Discovery toggle) と Player ボタン (find.byIcon(Icons.queue_music)) が引き続きインタラクト可能 (disable されない)」を Widget テストで検証する。test_plan の TP-17 (onboarding_flow_test) に 1 ケース追加するか、別途 dashboard_with_banner_test.dart を新設する。

または scope[10] に「Banner は AppBar 直下 (Scaffold body の最上段) に挿入し、Switch / Player ボタンの配置・操作可能性に影響しない」と明示し、success_criteria でその grep を入れる。

---

### 問題 5 (CRITICAL): 観点 6 — scope[15] のテスト互換デフォルト=completed が spec 機能 2 受け入れ基準 1 と矛盾

**何が問題か:**

scope[15] (ほぼ最後の長いパラグラフ):

> 「永続化スタブの初期値 = completed (テスト互換のためのデフォルト)」「実機ビルドで初回起動を検知する責務は別 Sprint で SharedPreferences 等を導入したときに切り替える」という方針で逃げる。

これに対し spec.md 機能 2 受け入れ基準 1:

> 初回起動時、ウェルカム / プライバシー説明 / 権限要求の **3 ステップ以上のスクリーン** が順に表示される

scope[15] のとおり「永続化スタブの初期値が completed」で実機ビルドにもこのデフォルトが適用されると、**実機初回起動時に Dashboard へ直行**し、オンボーディング画面が**1 度も表示されない**。spec の「3 ステップ以上のスクリーンが順に表示される」を満たさない。

**なぜ問題か:**

- 受け入れ基準 1 は機能 2 の中核要件であり、これが満たせない契約は spec_aligned (観点 6) FAIL
- Generator は「実機ビルドで初回起動を検知する責務は別 Sprint」と書いているが、別 Sprint の対象は spec.md「永続化バックエンド」(SharedPreferences) であって「初回起動 UX が機能する」事自体を遅延する根拠にはならない
- テスト互換 (widget_test.dart の expect が Dashboard 文言を要求) と実機初回起動 UX の両立は、Generator が安易に「persistence の初期値=completed」で逃げるのではなく、**ProviderScope の override で widget_test.dart 側のみ completed 注入する**正攻法で解くべき (Sprint 01 の `f7f582d -- widget_test.dart` 不変性は『widget_test.dart のテスト**ファイル**を変更しない』であって、ProviderScope の override 機構を `app.dart` 側に追加することは禁じられていない)

**どう書き直すか:**

scope[15] を以下のように書き直す:

> **テスト互換と実機 UX 両立の正攻法**: 永続化スタブの初期値は本 Sprint では **`OnboardingStatus.notStarted`** (実機初回起動時にオンボーディングを表示する spec 機能 2 受け入れ基準 1 を満たすため)。widget_test.dart との互換性は、`app/lib/presentation/state/onboarding_providers.dart` 内に `onboardingStateProvider` を定義し、widget_test.dart が `ProviderScope` の `overrides` で `onboardingStateProvider.overrideWith((ref) => StateController(OnboardingState(status: completed, ...)))` を渡せる API を提供することで解決する。**ただし widget_test.dart 自体は 0 byte 変更不可**のため、widget_test.dart が override 無しで pumpWidget しても Dashboard に到達できる仕組みが必要。これは:
>
> - **(I) ProximityMusicApp に `bool skipOnboardingForTest` (デフォルト false) を追加**: widget_test.dart は `pumpWidget(const ProviderScope(child: ProximityMusicApp()))` を呼ぶので skipOnboardingForTest デフォルトに依存できないが、**ProviderScope の上に親で overrides を渡せる setUp() を入れる方法がある**。ただし widget_test.dart の pumpWidget 行を変更しない要件を満たすには、ProximityMusicApp 自身が「`flutter_test` で動いている時は completed をデフォルトにする」検知ロジックを持つしかない。
>
> - **(II) `WidgetsBinding.instance.testsBindingType` または `kFlutterTesting`相当の検知**: Flutter SDK は `kIsTestEnvironment` / `Zone` で flutter_test 環境を識別できる。`onboardingStateProvider` のデフォルト値生成時にこれを判定し、test 環境では completed、実機 / プロファイルでは notStarted を返す。ただし test 環境検知の API 名は Flutter バージョン依存のため、明示的な定数を契約で定める必要がある。
>
> - **(III) `app/lib/main.dart` の runApp 経路と `widget_test.dart` の pumpWidget 経路で別ツリー**: main.dart に「`onboardingPersistenceProvider` を notStarted で wire-up する `ProviderScope` を作って runApp する」処理を入れ、widget_test.dart はその ProviderScope を経由しないので default ([] の Provider 定義) は completed のまま、という分離。これは ProviderScope の overrides を通じて行える。

上記 3 案のうち本契約で 1 案を選択し、success_criteria に「実機ビルドで初回起動時にオンボーディングが順次表示される」を機械検証可能な形で追加する (例: `flutter test` の widget_test.dart が green かつ、新規 widget テスト `app/test/presentation/onboarding_initial_route_test.dart` で「main.dart の runApp が呼ばれる経路 (= ProviderScope の overrides 無し) で初期画面が WelcomePage」を検証)。

**参照すべき箇所:**

- spec.md 機能 2 受け入れ基準 1, 3 (line 114-116)
- 現 widget_test.dart の `pumpWidget(const ProviderScope(child: ProximityMusicApp()))` 行 (テストファイル不変前提)
- Riverpod の ProviderScope.overrides API ドキュメント (関連)

---

### 問題 6 (MAJOR): 観点 1 — scope[8] と scope[15] の redirect 条件が矛盾、`inProgress` 状態の挙動が未定義

**何が問題か:**

scope[8]:

> 初回起動 (`onboardingState.status != completed`) の場合に `/onboarding/welcome` へ自動遷移する

scope[15]:

> 初回起動判定のリダイレクトは `onboardingStateProvider` の初期値が `notStarted` のときのみ発火する

`OnboardingStatus` enum は `{ notStarted, inProgress, completed }` の 3 値。

- scope[8] 条件: `status != completed` → `notStarted` も `inProgress` もどちらも redirect 対象
- scope[15] 条件: `status == notStarted` のときのみ redirect → `inProgress` のときは redirect しない

この 2 つは異なる条件であり、`inProgress` ユーザー (オンボーディングの途中で離脱) の挙動が**定義されない**。

**なぜ問題か:**

- Generator がどちらを実装すれば契約準拠か判定不能
- ユーザー視点でも「2 ステップ目までいって app をクローズ → 再起動」したときに最初から (welcome) に戻るのか、3 ステップ目から再開するのかが曖昧

**どう書き直すか:**

scope[8] と scope[15] の片方に統一する。spec の「2 回目以降の起動ではオンボーディングをスキップしてメイン画面に直行」(機能 2 受け入れ基準 3) は `completed` のみを対象とした記述であり、`inProgress` (途中離脱) は spec で明示されていない。実装としては:

- **Option (a)**: `status != completed` のとき常に `/onboarding/welcome` から再開 (シンプル、ユーザーは前進した画面が消えるが consent / permissions の二重操作はしないので副作用無し)
- **Option (b)**: `currentStep` フィールドを使って続きから再開 (UX 良いが状態空間複雑化)

本 Sprint の Domain は `currentStep` を保持する設計だが、**永続化が in-memory スタブのみ**なら再起動で `currentStep` も飛ぶため (b) は事実上無意味。**Option (a) を選択する旨を契約で明記**することを推奨。scope[15] の redirect 条件を scope[8] と一致させ、「`status != completed` (= `notStarted` または `inProgress`) のとき `/onboarding/welcome` へ redirect」とする。

---

### 問題 7 (MAJOR): 観点 3, 5 — 「規約バージョン更新時の再同意 redirect」の検証欠落

**何が問題か:**

spec.md 機能 13 受け入れ基準 4:

> 規約バージョンを更新したビルドを起動すると、再同意フローが表示される

contract scope[8] には:

> 完了済みかつ規約バージョン更新が必要 (`needsReconsent == true`) の場合は `/onboarding/consent` へ自動遷移する

しかし success_criteria には `needsReconsent` の Domain メソッドの単体テスト (criterion #17) しか機械検証がない。GoRouter redirect が `needsReconsent == true` のとき本当に `/onboarding/consent` に遷移する**統合的振る舞いの検証**がない (scope レベルの記述のみで grep もテストもない)。

**なぜ問題か:**

- Generator が `needsReconsent` メソッド単体実装は用意したが、redirect 関数で呼び出していない、というバグが発生しても契約上検出できない
- spec 受け入れ基準 4 が機械検証されない

**どう書き直すか:**

success_criteria に 1 行追加: 「app/lib/app.dart の GoRouter redirect コールバック内で `needsReconsent` メソッドが呼ばれている: `grep -F 'needsReconsent' app/lib/app.dart` が 1 件以上、かつ `grep -F '/onboarding/consent' app/lib/app.dart` が 1 件以上」。test_plan に対応 TP を追加。

さらに Widget テスト onboarding_flow_test.dart に 1 ケース追加するよう scope[14] と criterion #18 を修正: 「`needsReconsent == true` の状態で ProximityMusicApp を pumpWidget すると ConsentPage が直接表示される」を testWidgets で検証 (4 ケース目)。

---

### 問題 8 (MAJOR): 観点 3, 4 — TDD 順序検証 (TP-23) が state.json.tdd を参照しない

**何が問題か:**

TP-23:

> `git log --oneline --all | grep -i 'sprint-2'` の出力で、'RED' を含む commit が 'GREEN' を含む commit より時系列で先行することを確認する

Sprint 01 で確立されたパターン (PIPELINE.md §10 / tdd-enforcement skill / state.json.tdd フィールド) は **`state.json.tdd.{red_commit_sha, green_commit_sha}` を canonical source として使う**。`controller.py record-tdd` が記録した SHA を 1 次情報源とすべきであり、`git log | grep` は脆い (commit message にうっかり 'RED' が含まれた他のコミットを誤検出する、`grep -i` は大文字小文字無視のため "redirect" や "credential" にもヒットしうる、など)。

実例: scope[16] が `'redirect'` 関数の記述を含むため Phase 3 の commit message に "add redirect" 等が入ると `grep -i 'sprint-2'` の文脈で誤検出する余地が生じる。

**なぜ問題か:**

- Sprint 01 の TP-09 では state.json + git diff で機械検証する方式が確立されている。Sprint 02 で別方式を採用すると一貫性が崩れる
- `git log | grep -i` は false positive を作りやすく、契約遵守の判定が不安定
- evaluator が TDD 順序検証を `state.json.tdd` から実行するのは tdd-enforcement skill の標準手順であり、TP-23 がそれを再発明している

**どう書き直すか:**

TP-23 を以下のように書き直す:

```
TP-23 (TDD 順序検証): `.ai/work/2/state.json` の `tdd.red_commit_sha` と
`tdd.green_commit_sha` がいずれも non-null であり、
`git log --pretty=format:'%H %ct' <red_sha> <green_sha>` で red の
committer timestamp が green より小さい (= 時系列で red が先行)。
さらに `git show --stat <red_sha>` の変更ファイルが test/ 配下のみ
(implementation file が含まれない) であることを確認する。
Given: TDD commit 完了後 / When: state.json + git show /
Then: red_sha != null, green_sha != null, red.ct < green.ct,
      red の changed files が `app/test/` 配下のみ。
```

success_criteria #23 (TDD 順序) も同様に state.json を参照する形に修正。

---

### 問題 9 (MAJOR): 観点 1, 5 — `OnStateChanged` typedef の呼出契約と検証欠落

**何が問題か:**

scope[3] で `OnStateChanged` typedef を「必須コンストラクタ引数」と定義しているが、

- いつ呼ばれるか (advanceTo / recordConsent / requestPermission / complete のすべて? それとも一部?)
- 何が渡されるか (新しい OnboardingState 全体? それとも diff?)

の契約が scope にも success_criteria にも書かれていない。

scope[4] のメソッド仕様 (a)-(f) には全て「state を save」と書かれているが、`OnStateChanged` を呼ぶことは書かれていない。`SaveOnboardingState` と `OnStateChanged` の役割分担が曖昧。

success_criteria #18 (Data テスト 6 ケース) にも `OnStateChanged` 呼出の検証が含まれていない。

**なぜ問題か:**

- 必須コンストラクタ引数が一度も呼ばれない / 全く呼ばれないのに必須化されているのは Sprint 01 の `callback_injection_remedy` instinct (Data 層からコールバックで Presentation へ通知する原則) の精神に反する
- Generator が `OnStateChanged` 引数を取るが本体で使わない実装をしても契約上検出できない
- Riverpod 側 (`onboardingServiceProvider`) で `OnStateChanged` を `(state) => ref.read(onboardingStateProvider.notifier).state = state` のように wire-up する想定だが、これが scope[6] (provider 定義) にも明示されていない

**どう書き直すか:**

scope[3] または scope[4] に追記:

> `OnStateChanged` は `advanceTo` / `recordConsent` / `requestPermission` / `complete` の各メソッドが state を save した**直後**に、新しい `OnboardingState` 全体を引数として呼ばれる。これにより Presentation 層は OnboardingService 内部の永続化と独立に状態変化を観測できる (Sprint 01 callback_injection_remedy 規約継承)。

scope[6] に追記:

> `onboardingServiceProvider` 内で `OnStateChanged` コールバックを `(newState) => ref.read(onboardingStateProvider.notifier).state = newState` として wire-up し、Service の状態更新を `onboardingStateProvider` に伝播させる。

success_criteria に 1 行追加: 「Data テスト onboarding_service_test.dart で `OnStateChanged` コールバックが `advanceTo` / `recordConsent` / `requestPermission` / `complete` の各呼出で 1 回以上呼ばれることを検証するケースが含まれる: `grep -F 'OnStateChanged' app/test/data/onboarding_service_test.dart | wc -l` が 1 以上、または scope[14] のケース数を 6 → 7 以上に拡張」。

---

### 問題 10 (MINOR): 観点 1, 3 — Bluetooth permission の `notRequested` 状態の Banner 挙動が曖昧

**何が問題か:**

scope[10] / criterion #14 / TP-13:

> bluetooth permission が **denied** のときのみ表示される

`PermissionStatus` enum は `{ granted, denied, notRequested }` の 3 値。`notRequested` (まだ permission ダイアログを出していない初回オンボーディング前) の挙動が contract で明示されていない。

criterion #14 の grep (`PermissionStatus.denied|AppPermission.bluetooth`) は OR 条件なので、Generator が `if (status == PermissionStatus.notRequested) Banner()` を書いても「`AppPermission.bluetooth` の grep」だけで通ってしまう。

**なぜ問題か:**

- spec 機能 2 受け入れ基準 4 は「Bluetooth 権限を**拒否**した場合」に Banner 表示で、`notRequested` (permission ダイアログ未表示) は対象外と読める
- 契約で `notRequested = 非表示` を明示しないと Generator の判断ブレ余地が残る

**どう書き直すか:**

scope[10] と criterion #14 で「`PermissionStatus.denied` のとき**のみ**表示する。`granted` および `notRequested` のときは表示しない (= `if (status == PermissionStatus.denied) Banner()` 等の単純比較)」を明示。criterion #14 の grep を `grep -F 'PermissionStatus.denied' app/lib/presentation/pages/dashboard_page.dart | wc -l >= 1` の AND 条件に締める。

---

### 問題 11 (MINOR): 観点 1 — `permission_handler` パッケージ追加の延期は妥当だが、抽象を満たすスタブ実装の品質基準が空白

**何が問題か:**

out_of_scope[2] で `permission_handler` パッケージ追加を延期し、本 Sprint では「常に granted を返すスタブ」を Presentation 層から注入するとしているが、

- 「常に granted を返す」と「ユーザー操作で granted/denied を切替できる開発用スタブ」のどちらが期待実装か不明
- Banner 表示のテスト (scope[14] / criterion #18) のためには `denied` 状態を作れる必要があり、「常に granted」では Widget テストで Banner を検証できない

**なぜ問題か:**

- スタブ仕様が「granted を返す」固定だと、PermissionDeniedBanner の表示確認テスト (criterion #14) が成立しない
- かといって「テスト時のみ denied」を仕掛けるとテスト互換 (widget_test.dart 側で永続化スタブ=completed の前提) と整合させる仕組みが必要

**どう書き直すか:**

scope に 1 行追加: 「`RequestOsPermission` のスタブ実装は `app/lib/presentation/state/onboarding_providers.dart` 内で provider として提供し、Riverpod の override 機構を使って『granted を返す』『denied を返す』の両方をテストから注入できるようにする (デフォルトは granted)。テスト onboarding_flow_test.dart は denied 注入で Banner が表示されることを 1 ケース検証する」。

---

## Generator から提示された 5 つの確認事項への賛否

| # | Generator 主張 | 賛否 | 理由 |
|---|---|---|---|
| 1 | テスト時の onboarding completed default は妥当 | **NO** | 問題 5 で詳述。spec 機能 2 受け入れ基準 1 (実機初回起動で 3 ステップ表示) と矛盾する。ProviderScope.overrides または `kFlutterTesting` 検知で解くべき (本 Sprint 完結可能、過剰スコープではない) |
| 2 | 永続化バックエンド + permission_handler を out_of_scope へ split は妥当 | **YES (条件付き)** | 永続化バックエンドの導入延期は妥当 (機能 12 設定画面 Issue #10 で扱うのが自然)。`permission_handler` パッケージの本実装延期も Issue #3 (Platform Channels) と整合。ただし問題 11 のスタブ品質基準を契約で明示する必要 |
| 3 | TP-19 / TP-20 (flutter test / flutter analyze) の CI 依存は許容範囲 | **YES** | コンテナに Flutter SDK が無い前提は Sprint 01 と同じ運用。`.github/workflows/flutter-ci.yml` で run summary を確認する流れは確立済み。問題なし |
| 4 | spec 機能 13 後段 (再同意拒否時の機能停止 UI) の延期は妥当 | **NO** | 問題 2 で詳述。少なくとも「ConsentPage に stuck させる redirect」と「『アプリを終了』ボタン」は Presentation 層完結で本 Sprint 内実装可能。out_of_scope へ書き出すか scope に取り込むかの**明示**が必要 (Generator は handoff で言及しただけで契約には反映していない) |
| 5 | Sprint 01 派生 branch (`sprint/02-onboarding-and-consent`) は妥当 | **YES** | Sprint 01 が `sprint/01-bootstrap-and-layered-refactor` で main に PR 待ち、本 Sprint が同 branch から派生する流れは PIPELINE.md §0 と整合。state.json の branch field も一致確認済み |

---

## Generator への指示 (拒否時)

次のラウンド (Phase 2: 契約修正、contract_attempts は 2/3 になる) で以下を修正:

1. **【MUST】問題 1 (TP-18 タイポ) を解消**: `f7f502d` を `638c972` に修正、track_test.dart の baseline を独立 TP として明示
2. **【MUST】問題 2 (機能 13 後段) を解消**: scope に「再同意モードの 2 ボタン (同意する / アプリを終了)」と「Consent stuck redirect」を追加 (Option A) または out_of_scope に明示延期 (Option B、根拠弱)
3. **【MUST】問題 3 (機能 2 設定画面) を解消**: success_criteria + test_plan に「'/settings' に '権限を再要求' 文字列存在」「ボタン tap で再要求が発火」の検証追加
4. **【MUST】問題 5 (テスト互換と実機 UX 矛盾) を解消**: scope[15] を書き直し、`onboardingStateProvider` 初期値=`notStarted` を実機 default にし、widget_test.dart 側の互換は ProviderScope.overrides もしくは `kFlutterTesting` 検知 で解く
5. **【MUST】問題 6 (redirect 条件矛盾) を解消**: scope[8] と scope[15] を統一 (`status != completed` で `/onboarding/welcome` へ redirect、`inProgress` も対象)
6. **【MUST】問題 7 (再同意 redirect 検証) を解消**: success_criteria に GoRouter redirect 内の `needsReconsent` 呼出 grep を追加、testWidgets ケースに「needsReconsent==true で ConsentPage 直行」を追加
7. **【MUST】問題 8 (TDD 順序検証方式) を解消**: TP-23 を `state.json.tdd` 参照 + `git show --stat <red_sha>` 方式に書き換え
8. **【SHOULD】問題 4 (権限拒否時の楽曲再生継続) を解消**: Banner 表示時の Discovery toggle / Player navigation の動作を Widget テストで検証
9. **【SHOULD】問題 9 (OnStateChanged 契約) を解消**: scope に呼出タイミングと引数仕様を追記、success_criteria に検証追加
10. **【NICE TO HAVE】問題 10 (PermissionStatus.notRequested の Banner 挙動)、問題 11 (RequestOsPermission スタブ品質)** を解消
11. revision_history に `attempt: 2, status: "drafted"` を追加し、`bin/controller.py submit-contract --issue-id 2 --actor generator` で再提出

**注**: 元契約の構造 (23 scope / 23 criteria / 23 TP) は十分丁寧で、追加・修正のみの差分対応で済む。ゼロから書き直す必要はない。Sprint 01 の attempt 2 と同様の精度で 2nd revision を期待する。

**参照すべき instinct:**
- `.harness/instincts/evaluator/contract_lock_on_approve.md` (CONTRACT_APPROVED 後の locked=true 検証は次フェーズの evaluator 側責務)

`bin/controller.py reject-contract --issue-id 2 --actor evaluator --feedback-ref docs/feedback/issue-2-contract.md` で `PLANNED` に差し戻す。

---

# Issue #2 契約レビュー結果 (Attempt 2 / 2nd revision)

**判定:** ✅ 承認 (→ CONTRACT_APPROVED)
**レビュー日:** 2026-04-30
**Contract attempts:** 2/3 (残り 1)
**Branch:** sprint/02-onboarding-and-consent
**参照 instinct:** `contract_lock_on_approve.md`, `contract_reject_sha_typo.md`, `contract_reject_spec_ac_split_to_handoff.md`, `contract_reject_test_env_default_conflict.md`

## 7 観点チェック (attempt 1 → attempt 2 差分)

| # | 観点 | attempt 1 | **attempt 2** | 主要根拠 (差分) |
|---|---|---|---|---|
| 1 | Scope の明確性 | FAIL | **PASS** | scope[8] redirect 条件を `status != OnboardingStatus.completed` で単一化 (notStarted / inProgress 両方を redirect、`completed` のみを除外、scope[15] と一致)、scope[2] に OnStateChanged の呼出契約 (advanceTo / recordConsent / requestPermission / complete の各 save 直後に new OnboardingState を 1 回呼ぶ、load() / needsReconsent では呼ばない) を明記 |
| 2 | Out of scope の明示性 | FAIL | **PASS** | out_of_scope[10] に「機能 13 受け入れ基準 5 のドメイン側機能停止 (検知 = Sprint 03、受信 = Sprint 05、再生キュー = Sprint 06)」の延期を明記し、本 Sprint で実装する UI 制約 (stuck redirect + 2 ボタンのみ) との分担を明示。Option A 方式 (scope に取り込み) で UI 完結部分を本 Sprint で実装することも scope[5] / scope[8] / success_criteria #25-#27 に書き下し |
| 3 | Success criteria の測定可能性 | FAIL | **PASS** | TP-18 baseline = `f7f582d` (widget_test.dart 用) と TP-18b baseline = `638c972` (track_test.dart 用) に分離。`f7f502d` タイポは消失。再同意 redirect は success_criteria #22 と #28 で grep + testWidgets 検証可、設定画面再要求は #25 で grep + testWidgets 検証可、TDD 順序は #31 + TP-23 で `state.json.tdd` 参照に修正 |
| 4 | Test plan の実行可能性 | FAIL | **PASS** | TP-18 / TP-18b 両 baseline SHA を `git rev-parse` で実在検証済 (後述)。両 git diff コマンドの実行結果も 0 を確認 (現状 widget_test.dart / track_test.dart は baseline と完全同一)。TP-23 は state.json.tdd を 1 次情報源、`git show --stat <red_sha>` で test/ 配下のみ変更を検証する形式に書き換え済み |
| 5 | Coverage | FAIL | **PASS** | 機能 2 受け入れ基準 5 (権限拒否時の再生継続) → success_criteria #21 + TP-25 / dashboard_with_banner_test.dart 新設、受け入れ基準 6 (設定画面再要求) → #25 + TP-27 / settings_page.dart 新設、機能 13 受け入れ基準 4 (再同意 redirect) → #22 + TP-26 / onboarding_flow_test 4 件目、受け入れ基準 5 (再同意モード 2 ボタン) → #25 + TP-28 / 5 件目、OnStateChanged 検証 → #27 + TP-29 |
| 6 | spec.md との整合性 | FAIL | **PASS** | scope[15] のテスト互換戦略を「main.dart の runApp で `ProviderScope(overrides: [onboardingStateProvider.overrideWith((ref) => OnboardingState(status: notStarted, ...))])` を渡し、widget_test.dart は override 無しの `ProviderScope` を経由するため Provider default の `completed` を取得して Dashboard 直行」という両立戦略に書き換え。実機初回起動 = Welcome 直行 (受け入れ基準 1 を満たす) と widget_test.dart 0 byte 不変が両立する |
| 7 | 他 Issue との整合性 | PASS | **PASS** | Sprint 01 PR #12 で確立した Domain pure Dart / Data コールバック注入 / `f7f582d` baseline / `638c972` track_test baseline を継承。`sprint/02-onboarding-and-consent` branch 上で完結 |

これらは `.ai/work/2/qa.json` の `contract_review.seven_point` にも記録した (mode=contract、verdict=contract_approved)。

**結論:** 7 観点すべて PASS。前回 reject の 11 項目 (MUST 7 / SHOULD 2 / NICE 2) はいずれも解消済み (詳細は次節)。Phase 3 (RED → GREEN → READY_FOR_REVIEW) に進むことを承認。

---

## 前回 reject 11 項目への対応確認

| # | 旧問題 | 強度 | attempt 2 での対応 | 判定 |
|---|---|---|---|---|
| 1 | TP-18 SHA タイポ `f7f502d` | MUST | TP-18 baseline = `f7f582d` (widget_test.dart 用)、TP-18b baseline = `638c972` (track_test.dart 用) に分離。タイポ消失、`git rev-parse` で両者実在確認、`git diff` 実行結果も 0 で機械実行可能 | ✅ |
| 2 | 機能 13 後段 (再同意 2 ボタン / stuck redirect) の出処不明 | MUST | scope[5] (ConsentPage 再同意モードで 2 ボタン)、scope[8] (stuck redirect)、success_criteria #25-#27、TP-27 / TP-28 で完全に scope に取り込み (Option A)。out_of_scope[10] にはドメインロジック側機能停止の延期理由を明記 | ✅ |
| 3 | 設定画面「権限を再要求」検証欠落 | MUST | scope[10] で SettingsPage 新設、success_criteria #25 で grep 検証 (`grep -F '権限を再要求' app/lib/presentation/pages/settings_page.dart` >= 1)、TP-27 で settings_page.dart 存在 + `app.dart` で SettingsPage builder 確認 | ✅ |
| 4 | 機能 2 受け入れ基準 5 (権限拒否時の再生継続) 検証欠落 | SHOULD | scope[14] に dashboard_with_banner_test.dart 新設、success_criteria #21 で testWidgets 1 件 + Switch tap → 'Discovery Active' / Player ボタン tap → /player を要求、TP-25 で flutter test 実行 | ✅ |
| 5 | scope[15] テスト互換 default=completed が spec 受け入れ基準 1 と矛盾 | MUST | scope[15] を全面書き換え。「main.dart の runApp で `ProviderScope.overrides` で `onboardingStateProvider` を `notStarted` で上書き」「widget_test.dart は override 無しの `ProviderScope` を経由するため Provider default = `completed` で Dashboard 直行」という両立戦略を明記。実機初回起動の Welcome 直行と widget_test.dart 0 byte 不変が両立する設計 | ✅ |
| 6 | scope[8] と scope[15] redirect 条件矛盾 | MUST | scope[8] を `status != OnboardingStatus.completed` に統一 (notStarted / inProgress 両方を redirect 対象、`completed` のみ除外)、Option (a) 採用根拠も明記 (in-memory スタブで再起動時 `currentStep` も飛ぶため `welcome` 再開で十分) | ✅ |
| 7 | 規約バージョン更新時の再同意 redirect 検証欠落 | MUST | scope[8] 末尾に `grep -F 'needsReconsent' app/lib/app.dart >= 1` + `grep -F '/onboarding/consent' app/lib/app.dart >= 1`、success_criteria #22 + TP-26 で onboarding_flow_test.dart に testWidgets 4 件目 (`acceptedVersion='v0'` で pumpWidget → ConsentPage 直行) を追加 | ✅ |
| 8 | TP-23 が state.json.tdd を参照しない | MUST | TP-23 を `state.json` の `tdd.red_commit_sha` / `tdd.green_commit_sha` non-null + `git log --pretty=format:'%H %ct'` で時系列検証 + `git show --stat <red_sha>` で `app/test/` 配下のみ変更を検証する形式に書き換え。`grep -i 'sprint-2'` 方式の脆さ (false positive) を排除 | ✅ |
| 9 | OnStateChanged 呼出契約・検証欠落 | SHOULD | scope[2] に呼出タイミング (advanceTo / recordConsent / requestPermission / complete の save 直後 1 回ずつ、load() / needsReconsent では呼ばない) と引数 (新 state 全体スナップショット) を明記、scope[4] に Riverpod での wire-up (`onboardingServiceProvider` 内で `(newState) => ref.read(onboardingStateProvider.notifier).state = newState`) を明記、success_criteria #27 で onboarding_service_test に 2 ケース追加 (advanceTo で 1 回 + 引数検証、load では呼ばれない)、TP-29 で mock callback 注入の検証手順を提示 | ✅ |
| 10 | PermissionStatus.notRequested の Banner 挙動曖昧 | NICE | scope[7] / scope[9] で「`PermissionStatus.denied` のとき**のみ**表示。`granted` および `notRequested` のときは非表示」を明示、success_criteria #14 を AND 条件 (`grep -F 'PermissionStatus.denied' >= 1`) に締めた | ✅ |
| 11 | RequestOsPermission スタブ品質基準 | NICE | scope[18] を新設し、`requestOsPermissionProvider` (`Provider<RequestOsPermission>`) として wire-up、デフォルト = 常に granted を返す純粋関数、テスト側は `requestOsPermissionProvider.overrideWithValue((perm) async => denied)` で denied 注入。`grep -F 'permission_handler' app/lib/ \| wc -l == 0` (パッケージ未追加確定) を含める | ✅ |

---

## 重要な独立検証 (evaluator 側で実機検証)

### A. baseline SHA 実在検証 (TP-18 / TP-18b)

```
$ git rev-parse f7f582d
f7f582d96c7586347336904c796d956689dc2566   ← OK (sprint 分岐元、widget_test.dart 不変 baseline)
$ git rev-parse 638c972
638c972ea6e617cddd8336c4684e93458cd7be0c   ← OK (Sprint 01 fix、track_test.dart 不変 baseline)
$ git diff f7f582d -- app/test/widget_test.dart | wc -l
0   ← OK (現状 widget_test.dart は baseline と完全同一)
$ git diff 638c972 -- app/test/domain/track_test.dart | wc -l
0   ← OK (現状 track_test.dart は baseline と完全同一)
```

両 SHA は実在し、両 git diff コマンドが期待通り 0 を返す。TP-18 / TP-18b は機械実行可能。`contract_reject_sha_typo.md` instinct の検証手順を適用済み。

### B. テスト互換戦略 (scope[15]) の妥当性検証

**読み取った設計**:
- Provider default: `onboardingStateProvider` のデフォルト値 = `OnboardingState(status: completed, consent: ConsentRecord('v1', ...), permissions: {bluetooth: granted, ...}, currentStep: welcome)`
- main.dart 経路: `runApp(ProviderScope(overrides: [onboardingStateProvider.overrideWith((ref) => OnboardingState(status: notStarted, ...))], child: const ProximityMusicApp()))` で `notStarted` を実機ビルドに注入
- widget_test.dart 経路: `pumpWidget(const ProviderScope(child: ProximityMusicApp()))` を呼ぶため main() を経由せず、Provider default = `completed` を取得して Dashboard 直行

**現状確認**:
- `app/lib/main.dart` (line 14-16): `runApp(const ProviderScope(child: ProximityMusicApp()))` — 現状は const 修飾で overrides 無し。Sprint 02 実装時には const を外して overrides 引数を追加する必要があるが、それは main.dart の編集で widget_test.dart には触れない。export 定義 (`export 'package:proximity_music_app/app.dart' show ProximityMusicApp`) も維持される
- `app/test/widget_test.dart` (line 12, 25, 43): `pumpWidget(const ProviderScope(child: ProximityMusicApp()))` を 3 回呼んでおり、main() を経由しない。`const ProviderScope(child: ProximityMusicApp())` が新しい ProviderScope 木を作るため、main.dart 側の overrides は伝播しない。Provider default が評価されて Dashboard 直行

**判定**: 戦略は技術的に成立する。Riverpod の ProviderScope は親子で別ツリーを作るので、widget_test.dart の独立した ProviderScope は main.dart の overrides に影響を受けない。`contract_reject_test_env_default_conflict.md` instinct の正攻法 (3) (runApp 経路と pumpWidget 経路の分離) に該当。**PASS**

### C. spec.md と契約の機能網羅マッピング

| spec 受け入れ基準 | 機能 | contract 反映 |
|---|---|---|
| 機能 2 受け入れ基準 1 (3 ステップ以上) | scope[5] / [8] / [15], TP-11 / TP-17 / TP-18 | ✅ |
| 機能 2 受け入れ基準 2 (Back/Next/Skip) | scope[6] (onboarding_navigation), success_criteria #2 | ✅ |
| 機能 2 受け入れ基準 3 (2 回目以降直行) | scope[8] (i) (`completed` のとき redirect 無し → '/' で Dashboard) | ✅ |
| 機能 2 受け入れ基準 4 (Banner 恒常表示) | scope[7] / [9], success_criteria #13 / #14, TP-12 / TP-13 | ✅ |
| 機能 2 受け入れ基準 5 (権限拒否で再生継続) | scope[14] (dashboard_with_banner_test), #21, TP-25 | ✅ |
| 機能 2 受け入れ基準 6 (設定画面で再要求) | scope[10] (SettingsPage placeholder), #25, TP-27 | ✅ |
| 機能 13 受け入れ基準 1 (同意必須) | scope[5] / [14], #9 / #18, TP-17 (a)(b) | ✅ |
| 機能 13 受け入れ基準 2 (アプリ内全文閲覧) | scope[5], #10, TP-10 | ✅ |
| 機能 13 受け入れ基準 3 (バージョン永続化) | scope[3] (recordConsent), #4 / #5 (acceptedVersion フィールド) | ✅ |
| 機能 13 受け入れ基準 4 (再同意フロー表示) | scope[8] (ii), #22, TP-26, onboarding_flow_test 4 件目 | ✅ |
| 機能 13 受け入れ基準 5 (機能停止 UI) | scope[5] (再同意モード 2 ボタン) + scope[8] (stuck redirect), #25-#27, TP-27 / TP-28; out_of_scope[10] でドメイン側停止の延期を明示 | ✅ |

すべての該当受け入れ基準が contract に網羅されている。

---

## 軽微な観察 (合否に影響しない、参考情報)

- `test_plan` の TP-25 ~ TP-29 は本文の先頭に「TP-24 (...)」「TP-25 (...)」のように内部ラベルが 1 つズレているが、配列 index 基準で 25-29 番目として参照すれば問題なし。実害なし
- success_criteria #18 は testWidgets 5 件以上 + (a)-(e) で 5 ケースを明示しており、#22 の「testWidgets 件数 3 → 4 に拡張」表現は古い記述の名残だが #18 で 5 件カバー済みのため矛盾なし。Phase 3 では #18 の 5 件を満たす実装で OK

---

## Generator への指示 (承認時の Phase 3 着手手順)

1. `bin/controller.py record-tdd --issue-id 2 --actor generator --phase red --commit-sha <sha>` の前に **failing test commit を先に作成**:
   - `app/test/domain/onboarding_state_test.dart` (5 ケース以上)
   - `app/test/domain/consent_record_test.dart` (3 ケース以上、`currentTermsVersion` アサーション含)
   - `app/test/data/onboarding_service_test.dart` (8 ケース以上、OnStateChanged mock 検証 2 ケース含)
   - `app/test/presentation/onboarding_flow_test.dart` (5 ケース、disabled / enabled / WelcomePage / 再同意 redirect / 再同意モード 2 ボタン)
   - `app/test/presentation/dashboard_with_banner_test.dart` (1 ケース、Banner 表示時の Switch / Player ボタン操作可能性)
2. RED commit メッセージは `test(issue-2): RED - failing tests for onboarding + consent flow` のような形式 (Sprint 01 instinct 継承)。`git show --stat <red_sha>` で変更ファイルが `app/test/` 配下のみであることを後の TP-23 検証で確認できるよう、impl ファイルを mix しないこと
3. RED commit 後に `python3 bin/controller.py record-tdd --issue-id 2 --actor generator --phase red --commit-sha $(git rev-parse HEAD)` で `IN_PROGRESS_RED` に遷移
4. GREEN 実装は scope[0] - scope[18] を順に消化:
   - Domain (純粋 Dart 4 entity + OnboardingState)
   - Data (OnboardingService + 4 typedef、flutter / flutter_riverpod / go_router 不 import)
   - Presentation (Riverpod providers / 4 onboarding pages / SettingsPage / PermissionDeniedBanner / GoRouter redirect / Dashboard 改修 / main.dart の `ProviderScope(overrides: [...])` 化)
   - 既存 widget_test.dart / track_test.dart は 0 byte 不変
5. GREEN 後 `record-tdd --phase green --commit-sha $(git rev-parse HEAD)` → `submit-impl --issue-id 2 --actor generator`
6. `cd app && flutter test` が 29 ケース以上 + `flutter analyze` が 'No issues found' (CI で検証)

## Evaluator が承認後にやること (備忘)

1. `bin/controller.py approve-contract --issue-id 2 --actor evaluator --feedback-ref docs/feedback/issue-2-contract.md` で遷移
2. controller.py が自動で `contract.json.locked = true` を立てる (`contract_lock_on_approve.md` instinct 適用済み、harness 修正済み)
3. `python3 bin/validate-state.py --strict` で error 0 を確認
4. 次フェーズは generator が Phase 3 (RED → GREEN → READY_FOR_REVIEW) を実行

**参照すべき instinct (本 attempt 2 で適用):**
- `.harness/instincts/evaluator/contract_lock_on_approve.md` (locked=true 検証)
- `.harness/instincts/evaluator/contract_reject_sha_typo.md` (TP-18 / TP-18b の `git rev-parse` 検証手順)
- `.harness/instincts/evaluator/contract_reject_spec_ac_split_to_handoff.md` (機能 13 後段の scope/out_of_scope 明文化検証)
- `.harness/instincts/evaluator/contract_reject_test_env_default_conflict.md` (scope[15] のテスト互換戦略の正攻法該当性検証)

`bin/controller.py approve-contract --issue-id 2 --actor evaluator --feedback-ref docs/feedback/issue-2-contract.md` で `CONTRACT_APPROVED` に遷移する。

