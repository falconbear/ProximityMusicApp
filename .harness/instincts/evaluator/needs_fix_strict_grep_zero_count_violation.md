---
name: needs_fix - strict grep "must be 0" violations from comments / docstrings
description: contract が `grep -F '<keyword>' <path> | wc -l == 0` を要求するとき、コメント / dartdoc 中の文字列もカウントされる
type: heuristic
---

`[HEURISTIC]` 契約 (success_criteria / scope / test_plan) が `grep -F '<keyword>' <path> | wc -l` の出力 = 0 を strict 要求している場合、`<keyword>` がコメント / dartdoc / docstring 中に含まれていても**契約違反**として扱う。Generator が「実 import / 機能本体は不在なので意図は満たす」と主張しても、契約条文が grep 出力 0 を明示している以上 strict に違反扱いとし NEEDS_FIX する。

**Why:** Issue #2 attempt 1 の評価で、scope[19] 末尾が `grep -F 'permission_handler' app/lib/ 配下のヒットが 0 (= permission_handler 未追加が確定)` を要求していたが、`onboarding_providers.dart:68` の dartdoc コメント `/// The real permission_handler integration arrives in Issue #3.` が grep にヒット (出力 1)。Generator handoff では「実 import / pubspec.yaml への追加は無し」と主張していたが、契約の grep 条文を文字通り読めば違反。Generator も「strict 違反扱いされるなら 1 行 revert で対応可能」と自認しており、修正コストは小さい。

**How to apply:**
1. 契約 scope / SC / TP に `grep -F '<keyword>' <path> | wc -l` の出力 = 0 が書かれていたら、評価時に**必ず**そのコマンドを実行する
2. ヒット数が 1 以上であれば、その行が機能コード/import か、コメント/dartdoc/文字列リテラルかを問わず**契約違反**として扱う
3. feedback では「契約の意図 (= 機能未実装) は別の手段 (pubspec.yaml の dep 不在 + 実 import 0) で達成されているが、契約条文は grep 出力 0 を明示要求しているため strict に違反扱い」と明記し、修正方法 (コメント書き換え or 削除) を提示
4. severity は **CRITICAL** (契約条文の直接違反) として扱う。修正コストは 1 行 edit で済むため、Generator の修正サイクルへの負担は小さい
5. 反対に、契約が「grep 出力 == 0」ではなく「実 import がない」「pubspec.yaml に追加されていない」のような機能ベース条件で書かれていれば、コメントヒットは合格。Generator 起草段階で grep ベースを書くのは契約モードで指摘し、機能ベース条件に書き換えさせる選択肢もある

**関連:**
- `contract-first` skill (契約条文は機械検証可能性を優先するため grep ベースが多用される)
- `skeptical-evaluation` skill 原則 5 (契約に厳密に従う) — strict 解釈を恐れない
- Sprint 02 attempt 1 BUG-2 (本 instinct の確立元)
