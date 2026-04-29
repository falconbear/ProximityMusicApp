---
name: heuristic_callback_injection_remedy
description: Data → Presentation 循環依存の修正は Domain typedef + コールバック注入が clean。riverpod を Data 層から完全排除できる
type: feedback
---

Data 層が Presentation の Riverpod Provider を直接 read/write してしまう典型的な循環依存に対し、**Domain 型のみで定義した typedef + コールバック注入**で remediation すると、修正範囲を Data 層 + Provider 組み立て層の 2 ファイルに限定でき、公開 interface (`play()` / `pause()` 等) を不変に保てる。これにより呼び出し側のページ・ウィジェットを 1 行も触らずに循環依存を解消できる。

**Why:** Data 層が `flutter_riverpod` を import していると「Riverpod の Ref 経由なら Presentation Provider を read してよい」という錯覚を生む。Domain typedef + コールバックなら Riverpod 自体が Data 層から消え、層境界が物理的に強制される。

**How to apply:**
- 評価時に Data 層の `flutter_riverpod` import を見たら、たとえ「Ref のみ参照」と generator が主張しても、**Provider 名 (`...Provider`) の文字列出現**を grep で確認する。出現していたら循環依存。
- 修正提案は Generator に「Domain typedef でコールバックを定義し Presentation 側で注入」を案 A として提示する (Issue #1 で実証済み)。Stream-based の案 B も代替として記載。
- 修正後の検証: `grep -RE "^import 'package:<project>/presentation/" app/lib/data/ | wc -l` が 0、かつ `grep -RE "flutter_riverpod" app/lib/data/ | wc -l` も 0 を期待 (riverpod も完全排除されるのが理想)。
- 公開 interface 不変なら Generator は新規テスト追加なしで済むので、attempt 2 が軽量に終わる。
