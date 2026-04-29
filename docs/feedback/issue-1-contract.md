# Issue #1 契約レビュー結果

**判定:** ❌ 拒否 (→ PLANNED で revise)
**レビュー日:** 2026-04-29
**Contract attempts:** 1/3

## 7 観点チェック

| # | 観点 | 判定 | 根拠 |
|---|---|---|---|
| 1 | Scope の明確性 (scope_clarity) | PASS | 8 項目すべて具体ファイル名・コマンド付き、曖昧語なし、「最小分割に留める」で過剰設計を抑制 |
| 2 | Out of scope の明示性 (out_of_scope_explicit) | PASS | 8 項目で新機能/Native ビルド/UseCase/UI 文言/テスト緩和/Platform Channels/Riverpod 差替/ローカルストレージ等を明示 |
| 3 | Success criteria の測定可能性 (success_measurable) | PASS | 14 項目すべて binary 判定可能 (exit code / 行数 / grep / ファイル存在 / 文字列含有) |
| 4 | Test plan の実行可能性 (test_plan_executable) | **FAIL** | TP-15 と criterion #11 が「既存 widget_test.dart の 3 ケースが green」を要求するが、現コード (main.dart) はテスト期待文字列を出力していないため、import 更新だけでは green にならない (詳細: 問題 1) |
| 5 | Coverage (criteria が test plan に全網羅) | PASS | C1→TP-01, C2→TP-02, C3→TP-11/12, C4→TP-04, C5→TP-06, C6→TP-05, C7→TP-07, C8→TP-08, C9→TP-09, C10→TP-10, C11→TP-11, C12→TP-12, C13→TP-13, C14→TP-14 で 100% カバー |
| 6 | spec.md との整合性 (spec_aligned) | PASS | spec の Issue #1 受け入れ基準 (init.sh / SDK チェック / pub get / analyze / test / 層分離 / GitHub Actions / README) すべて契約に反映 |
| 7 | 他 Issue との整合性 (prior_sprint_aligned) | PASS | Issue #1 は最初。後続 Issue 用の前提を整える内容で整合。Platform Channels (#3) / ストレージ (#9) を out_of_scope で明示除外 |

これらは `.ai/work/1/qa.json` の `contract_review.seven_point` にも記録した。

---

## 拒否理由と改善指示

### 問題 1 (CRITICAL): 観点 4 — 既存 widget_test.dart は現コードに対して既に broken の疑い、TP-15 が実行不能

**何が問題か:**
契約の criterion #9 は「既存 app/test/widget_test.dart のアサーションを一切変更しない (`git diff` 上、import 文以外に変更が無い)」を要求し、TP-15 は「widget_test.dart の 3 ケース ('App smoke test', 'Discovery switch toggles state', 'Navigation to player page works') が新パスでも green になる」を要求している。さらに criterion #11 で「全テスト (既存 3 + 新規 2 以上 = 5 以上) が green」を必須化。

しかし現状 (sprint 着手前) のリポジトリでは、`app/test/widget_test.dart` の既存アサーションが指す文字列のうち以下が `app/lib/main.dart` の rendered widget text として**存在しない**:

| widget_test.dart の expect | 現 main.dart のレンダー | 検出 |
|---|---|---|
| `find.text('Proximity Music')` (line 15) | `MaterialApp.title: 'Proximity Music'` (main.dart:29) は **AppBar の title (line 189) ではなく** widget tree に Text として登場しない。AppBar は `Text('🎵 Proximity')` を表示 | `grep -rn "'Proximity Music'" app/lib/` → main.dart:29 のみ (MaterialApp.title 属性、find.text の対象外) |
| `find.text('Discovery Paused')` (line 18, 32) | main.dart:253 で `discoveryOn ? 'Discovery Active' : 'Discovery Mode'` と表示 (`'Discovery Paused'` は出力されない) | `grep -rn "Discovery Paused" app/lib/` → 0 件 |
| `find.text('再生コントロール')` (widget_test.dart line 55) | main.dart 全体で 0 件 | `grep -rn "再生コントロール" app/lib/` → 0 件 |

つまり、**契約の Phase 3.1 で generator が widget_test.dart を「import パスのみ更新」して `flutter test` を回しても、既存 3 ケースはおそらく FAIL する** (今までも green だった保証がない)。

**なぜ問題か:**
- TP-15 と criterion #11 が green を要求する一方、criterion #9 (アサーション不変) と out_of_scope[3]「テーマ / カラー / UI 文言の変更」が、generator にこの不整合を解消する手段を残さない。
- 取りうる選択肢:
  1. widget_test.dart を変更 → **criterion #9 違反 + test-integrity skill 違反**
  2. main.dart の表示文字列を `'Discovery Paused'` 等に修正 → **out_of_scope #4「UI 文言の変更」と衝突**
  3. 既存テストが現時点で broken であることを確認し、契約上で「既存テストの取扱い」を明示する → **本契約には書かれていない**
- どれを選んでも契約違反になり、generator が CONTRACT_APPROVED 後に詰む。これは「契約段階で曖昧なものを通すと実装フェーズで火を噴く」典型例。

**どう書き直すか:**
以下のいずれか 1 つを契約に明示する:

- **(A) UI 文言修正を明示的に scope に含める**: scope に「既存 widget_test.dart の expect (`'Proximity Music'` / `'Discovery Paused'` / `'再生コントロール'`) を満たすため、Presentation 層リファクタの一環として `app/lib/presentation/pages/dashboard_page.dart` の表示文字列を更新する (現 `'Discovery Mode'` → `'Discovery Paused'`、AppBar title を `'Proximity Music'` を含む形に、player page に `'再生コントロール'` 見出しを追加)」を追加し、out_of_scope[3] の「UI 文言の変更」から本リファクタに伴う **テスト整合用の文言追加** を**除外**する。
- **(B) 既存テストの import 以外の変更を明示的に許可する**: criterion #9 を「既存 widget_test.dart のテストロジックは変更しない (期待文字列の更新のみ可)」に緩和し、out_of_scope[5]「既存テストのアサーション緩和、削除、.skip 追加」と区別する。**ただし test-integrity skill との衝突を避けるため、契約内で明文化された例外として扱う旨を明記**。
- **(C) 既存テストの broken を spec-issues として切り分ける**: 現 baseline で `flutter test` がそもそも red であった事実を `docs/spec-issues.md` に記録する Issue #1 サブタスクを追加し、本 Sprint の TP-15 を「現 baseline で green だった既存テストのみが新パスでも green」に書き換える (broken だった既存テストは適宜更新を許容)。

最も率直なのは **(A)**。スプリント目的が「層分離」である以上、Presentation 層のテキスト調整は本来の作業の延長線にある。**(B)** は test-integrity と衝突しやすく注意が必要。**(C)** は事実関係を歪めない正攻法だが、generator 側で baseline 検証ステップが増える。

**参照すべき箇所:**
- `app/test/widget_test.dart` (現状の expect)
- `app/lib/main.dart:29, 189, 253` (現状の rendered text)
- `docs/spec.md` Issue #1「**ユーザーから見える振る舞い:** 既存の楽曲再生 / ミニプレイヤー / ダーク UI は **回帰せず動作する**」(spec は表示文字列の固定化までは要求していない)
- `skills/test-integrity/` (新パス更新は許容、ロジック変更は不可)

---

### 問題 2 (MINOR): 観点 4/3 — TP-09 baseline-sha プレースホルダ

**何が問題か:**
TP-09 が `git diff <baseline-sha> -- app/test/widget_test.dart` と書いているが、`<baseline-sha>` がプレースホルダのまま残り、evaluator がどの SHA を baseline として使うべきか機械的に決定できない。

**なぜ問題か:**
test_plan は generator/evaluator が**そのまま実行可能**であることを期待される。プレースホルダは実行時に解釈の余地を残し、TP-09 の合否判定がぶれる。

**どう書き直すか:**
具体的に決定可能な式に置換する。例:
- `git diff origin/main -- app/test/widget_test.dart` (sprint ブランチの分岐元を baseline とする)
- または `git log --diff-filter=M --pretty=format:'%H' app/test/widget_test.dart | tail -1` で改変前 commit を機械的に取得し diff 比較

scope[8] の export 互換性決定 (`export 'app.dart'` か import 更新か) を generator に委ねている以上、baseline は契約で固定すべき。

**参照すべき箇所:**
- 現リポジトリ HEAD: `f7f582d harness: integrate claude-harness-dev scaffold` (sprint ブランチ作成前の最新 commit)
- ブランチ: `sprint/01-bootstrap-and-layered-refactor` (state.json:branch)

---

### 問題 3 (MINOR): 観点 3/5 — `dart format` 検証ステップが scope と criteria でズレている

**何が問題か:**
scope[4] で「(b) dart format --set-exit-if-changed --output=none」を CI ワークフローに含めることが明示されているが、success_criteria #13 と TP-13 では `subosito/flutter-action@v2 / flutter pub get / flutter analyze / flutter test` の 4 文字列のみを検証対象とし、`dart format --set-exit-if-changed` の存在チェックがない。

**なぜ問題か:**
- scope に書いた成果物が success_criteria/test plan で検証されないと、generator が format ステップを忘れても契約上は通ってしまい、spec の「format / analyze / test を自動実行する」(docs/spec.md Issue #1) を満たさない PR が READY_FOR_REVIEW に進む可能性。
- coverage 観点で「scope に書いてあるが measurable success criteria が無い」状態。

**どう書き直すか:**
- success_criteria #13 を更新: 「ファイル内に subosito/flutter-action@v2、`flutter pub get`、`dart format --set-exit-if-changed`、`flutter analyze`、`flutter test` の 5 文字列がすべて含まれる」
- TP-13 を更新: `grep -c` 検査対象に `dart format --set-exit-if-changed` を追加

---

### 問題 4 (MINOR): 観点 3 — Domain ユニットテストの「2 ケース」要件が浅い

**何が問題か:**
criterion #10 が「少なくとも 2 ケース以上 (constructor で値が正しく保持される / equality または toString 等の値ベース挙動)」とし、TP-10 が `grep -c "^\s*test(" >= 2` で機械検証する。しかし現状 `Track` は `==` / `hashCode` / `toString` を override していないため、generator は **「コンストラクタで値が保持される」を 2 個書いて閾値を満たす** 抜け道がある (例: `final t = Track(title:'a',...); expect(t.title, 'a')` を 2 ケース並べる)。これは TDD 観点でほぼ無価値。

**なぜ問題か:**
- 「Domain 層のユニットテスト土台」を後続 Issue に引き渡す本 Sprint の意義 (spec.md「テスト土台」) が、空回りの 2 ケースで形骸化する。
- 後続 Issue で Domain クラス追加時にテストパターンが薄いまま流される懸念。

**どう書き直すか:**
- criterion #10 を「2 ケース以上、ただし**少なくとも 1 ケースは equality または toString または copyWith または props (== 値ベース挙動) を検証する**」に強化、もしくは
- scope に「Track クラスに `==` / `hashCode` / `toString` の override を追加し、後続の楽曲重複判定 (spec Issue #5「同一楽曲を異なるピアから受信した場合、重複保存しない (内容ハッシュで判定)」) の前段階を整える」を 1 行追加して値ベース挙動の根拠を作る。

これは BLOCKING ではないが、契約の Done 強度を上げるための提案として 2nd attempt で取り込むことを推奨。

---

## Generator への指示 (拒否時)

次のラウンド (Phase 2: 契約修正、contract_attempts は 2/3 になる) で以下を修正:

1. **【MUST】問題 1 を解消**: 既存 widget_test.dart が現コードに対して green でない事実を反映し、上記 (A)/(B)/(C) のいずれかを契約に明文化する。最も推奨は **(A)** (scope に Presentation 層の文言調整を追加し out_of_scope の例外として明示)。
2. **【MUST】問題 2 を解消**: TP-09 の `<baseline-sha>` を具体的な SHA か実行可能な git コマンドに置換する。
3. **【SHOULD】問題 3 を解消**: success_criteria #13 と TP-13 に `dart format --set-exit-if-changed` 文字列の存在チェックを追加する。
4. **【NICE TO HAVE】問題 4 を解消**: Domain テスト要件を強化する (scope に Track の equality/toString 追加を含めるか、criterion #10 を強化)。
5. revision_history に `attempt: 2, status: "drafted"` を追加し、`bin/controller.py submit-contract --issue-id 1 --actor generator` で再提出する。

**注**: 修正は契約全体の書き直しではなく、上記指摘点のみの差分修正で十分。元契約の 8 scope / 14 criteria / 15 TP の構造は良好。

---

# Issue #1 契約レビュー結果 — 2nd attempt

**判定:** ✅ 承認 (→ CONTRACT_APPROVED)
**レビュー日:** 2026-04-29
**Contract attempts:** 2/3

## 7 観点チェック (再点検)

| # | 観点 | 判定 | 根拠 |
|---|---|---|---|
| 1 | Scope の明確性 (scope_clarity) | PASS | 9 項目すべて具体ファイル名・コマンド・文字列付き、新 scope[9] が widget_test.dart 整合のための Presentation 層文言調整 (i)(ii)(iii) を明示、scope[10] が Track equality override を明示 |
| 2 | Out of scope の明示性 (out_of_scope_explicit) | PASS | 10 項目に拡張。out_of_scope[3] に括弧書きで scope[9] による 5 文字列の例外明記、out_of_scope[4]/[5] で test-integrity との両立を明示、out_of_scope[8]/[9] が scope[10] と整合 |
| 3 | Success criteria の測定可能性 (success_measurable) | PASS | 14 項目すべて binary。criterion #9 で baseline-sha 固定 (`f7f582d`)、criterion #10 が 3 ケース (a/b/c) で equality override 検証を含む、criterion #13 が 5 文字列に拡張、criterion #14 で `@override` × 3 を機械検証 |
| 4 | Test plan の実行可能性 (test_plan_executable) | **PASS (改善済)** | TP-09 が `git diff f7f582d ... \| grep -vE '^[+-]import ' \| wc -l == 0` に機械化、TP-13 が 5 文字列の `grep -F -c` 化、TP-15 が文言調整適用後の表示要件を明文化、TP-16 が Track equality override を検証 |
| 5 | Coverage | PASS | C1→TP-01, C2→TP-02, C3→TP-11/12, C4→TP-04, C5→TP-06, C6→TP-05, C7→TP-07, C8→TP-08, C9→TP-09, C10→TP-10, C11→TP-11, C12→TP-12, C13→TP-13, C14→TP-16 で 100% カバー、新 scope[9] が TP-15 / 新 scope[10] が TP-16 で検証 |
| 6 | spec.md との整合性 (spec_aligned) | PASS | spec Issue #1 受け入れ基準すべて契約に反映。scope[9] の文言調整は spec の「機能回帰なし」を破壊せず、widget smoke test を green で通すための必要最小調整。spec の「(このスプリントで UI は変わらない)」は画面構成・機能の不変を意味し、文言の最小調整は test-integrity 維持目的なので逸脱しない。scope[10] の Track equality override は spec Issue #5「同一楽曲を異なるピアから受信した場合、重複保存しない (内容ハッシュで判定)」の前段階整備として整合 |
| 7 | 他 Issue との整合性 (prior_sprint_aligned) | PASS | Issue #1 は最初。Platform Channels (#3) / ローカルストレージ (#9) を out_of_scope で明示除外、Track equality override が #5 への伏線として整合 |

## 前回指摘の解消状況

| 指摘 | 解消方針 | 確認 |
|---|---|---|
| 問題 1 (CRITICAL) widget_test.dart 整合 | (A) 案採用: scope[9] に Presentation 層 5 文字列 ('Proximity Music' / 'Discovery Paused' / 'Discovery Active' / 'Player' / '再生コントロール') の調整を明示、out_of_scope[3] に例外明記、out_of_scope[5] で test-integrity との両立明示 | ✅ 解消。`app/lib/main.dart:29` (MaterialApp.title 'Proximity Music' は属性のみ) / `:189` (`'🎵 Proximity'`) / `:253` (`'Discovery Mode'`) は scope[9](i)(ii) で Presentation 層へ移行・調整、PlayerPage への 'Player' と '再生コントロール' Text 追加は scope[9](iii) で明文化。`app/test/widget_test.dart` の 5 expect 文字列とすべてマッピング可能 |
| 問題 2 (MINOR) baseline-sha プレースホルダ | TP-09 で `f7f582d` (`harness: integrate claude-harness-dev scaffold`) に固定、`git diff f7f582d -- app/test/widget_test.dart \| grep -E '^[+-][^+-]' \| grep -vE "^[+-]import " \| wc -l == 0` で機械化、criterion #9 でも同 SHA を採用 | ✅ 解消。`git log --oneline` で `f7f582d` が sprint ブランチ分岐元の最新 commit であることを確認済み |
| 問題 3 (MINOR) dart format 検証ステップ欠落 | criterion #13 を 5 文字列 (subosito/flutter-action@v2 + flutter pub get + dart format --set-exit-if-changed + flutter analyze + flutter test) に拡張、TP-13 で各 `grep -F -c` を要求 | ✅ 解消。scope[5] CI ワークフロー記述と criterion / TP の対応が完全一致 |
| 問題 4 (MINOR) Domain テスト要件浅さ | criterion #10 を 3 ケース (a) constructor (b) 同フィールド `==` true (c) 異フィールド `==` false に強化、scope[10] と out_of_scope[8]/[9] で Track の `==` / `hashCode` / `toString` override を明示、criterion #14 + TP-16 で `@override` × 3 と `bool operator ==` / `int get hashCode` / `String toString` の各 grep を機械検証 | ✅ 解消。抜け道 (constructor 検証 × 2 で閾値達成) が equality 必須化で塞がれた |

## 残懸念 (MINOR、承認の妨げにはしない)

### 懸念 A (MINOR): widget_test.dart line 46 `find.byIcon(Icons.queue_music)` のアイコン整合

`app/test/widget_test.dart:46` は `find.byIcon(Icons.queue_music)` を 1 個ヒットさせ、tap して PlayerPage に遷移することを要求している。一方、現 main.dart:194 では AppBar の Player ボタンに `Icons.music_note_rounded` を使用している。`Icons.queue_music` は main.dart:468 (queue empty placeholder) にも存在するため、AppBar 上 1 個に絞るには Player ボタンの icon を `Icons.queue_music` に揃えるか、queue empty placeholder の icon を別に変更する判断が必要。

scope[9] は「**5 文字列**」を明示するが icon 名は明示していない。ただし scope[9] 冒頭で「既存 widget_test.dart は ... の存在を要求する」「Presentation 層リファクタの一環として ... 表示文字列を新ファイルで揃える」とあり、TP-15 が「Player ページ遷移後に 'Player' と '再生コントロール' が両方 Text として表示」を要求していることから、generator が Player ボタン (現 `Icons.music_note_rounded`) を `Icons.queue_music` に揃える implicit な要求は scope[9] の「Presentation 層リファクタの一環」として読み取れる範囲。

**この懸念は契約段階で BLOCKED に追い込むべきものではない**。CRITICAL 指摘 1 の解決を契約で確実にしたうえで、icon 整合は実装段階で generator が判断 (scope[9] の延長線上の最小調整) できる。実装フェーズで evaluator が `find.byIcon(Icons.queue_music)` の `findsOneWidget` 失敗を検出した場合は NEEDS_FIX で差し戻せばよい。

### 懸念 B (情報): scope[9](i) の文字列「'Proximity Music'」の重複表示

scope[9](i) で「AppBar(title: const Text('Proximity Music'))」と書いており、widget_test.dart の `find.text('Proximity Music')` が `findsOneWidget` (1 個ぴったり) を要求する。MaterialApp.title 属性の `'Proximity Music'` (現 main.dart:29) は Text widget として render されないため、AppBar に Text 1 個を置けば `findsOneWidget` は満たされる。これは generator が注意して実装すれば問題ない範囲。**実装段階の自検査ポイント**として記録するに留める。

## 承認の理由

- 前回 CRITICAL 1 (test_plan_executable FAIL) が確実に解消され、generator が CONTRACT_APPROVED 後に詰む経路が消えた
- MINOR 3 件はすべて `grep` / 文字列固定で機械検証可能な形に修正された
- scope[9] の文言調整は spec の「機能回帰なし」「(UI は変わらない = 画面構成不変)」の意図を破壊せず、test-integrity スキルの「expect 文字列を変更しない (実装側を直す)」原則を守る正攻法
- scope[10] / criterion #14 / TP-16 / out_of_scope[8][9] により Track equality override の Done 強度が確保され、後続 Issue #5 への伏線にもなっている
- 残懸念 A (queue_music icon) は契約の implicit な延長線で実装側が解決可能な範囲。3/3 attempts で BLOCKED に追い込むほどの blocker ではない

`bin/controller.py approve-contract --issue-id 1 --actor evaluator --feedback-ref docs/feedback/issue-1-contract.md` で `CONTRACT_APPROVED` に遷移する。Generator は Phase 3.1 (RED commit) から開始可能。

## Generator への次フェーズ留意事項 (advisory、非合否)

- Phase 3.1 (RED): widget_test.dart の現 expect (5 文字列 + `Icons.queue_music` byIcon) **すべて** が新 Presentation 層に対して green になるテスト先行を組む。`flutter test` で widget_test.dart 3 ケースが先に red、その後 GREEN commit で green に転じる流れを担保する
- AppBar の Player ボタン icon を `Icons.queue_music` に揃える必要性 (widget_test.dart:46) を見落とさないこと。queue empty placeholder (main.dart:468) の icon は別途 `Icons.queue_music` を引き続き使うと `findsOneWidget` が壊れるので、placeholder 側を `Icons.music_note_outlined` 等に切替する判断を要する
- TP-09 の baseline 比較で `import` 行以外の差分が 0 になるよう、widget_test.dart の修正は import 文のみに留める (scope[9] は実装側を直す方針)

