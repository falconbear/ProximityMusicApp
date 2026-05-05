---
name: Contract reject pattern - SHA typo in test_plan baseline
description: test_plan で baseline SHA を使う TP は `git rev-parse` で実在性を検証してから承認する
type: heuristic
---

`[HEURISTIC]` test_plan の TP に固定 SHA (`f7f582d` のような short hash) が含まれる場合、`git rev-parse <sha>` で実在性を検証してから approve する。タイポ 1 文字で TP 全体が機械実行不能になる。

**Why:** Issue #2 contract attempt 1 で TP-18 が `git diff f7f502d -- app/test/domain/track_test.dart` と書かれていたが、`f7f502d` は git rev-parse で `fatal: ambiguous argument` を返す存在しない SHA。同 TP 文中で `f7f582d` (sprint 分岐元) と `638c972` (Sprint 01 fix) と `e0f422a` (Sprint 01 GREEN) と `f7f502d` (タイポ) の 4 つが混在していた。文中の散文では「baseline = 638c972」と結論しているのにコマンド本体は `f7f502d`。実行すれば即 fatal で TP-18 の合否判定が下せない。

**How to apply:**
1. test_plan の各 TP を読みながら short SHA (`[0-9a-f]{7,40}`) パターンを抽出
2. それぞれに `git rev-parse <sha>` を実行 (parallel ok)
3. fatal が返るものは即 FAIL with "観点 4 (test_plan_executable) — TP-XX baseline SHA `<sha>` が存在しない"
4. 同 TP 文中で 2 つ以上の SHA に言及があるなら、コマンド本体が使う SHA と散文での baseline 結論が一致しているかも確認
5. 修正提案: 「単一の baseline SHA に固定し、複数候補を散文で並べないこと」
