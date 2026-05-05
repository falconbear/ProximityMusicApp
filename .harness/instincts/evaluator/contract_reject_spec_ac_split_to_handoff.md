---
name: Contract reject pattern - spec AC split silently via handoff only
description: Generator が「次 Sprint に延期」を handoff だけで主張し out_of_scope に書かない場合は CRITICAL reject
type: feedback
---

`[CONTRACT-REJECT]` Generator が prompt や handoff で「機能 X の Y 部分は別 Sprint に分割」と主張するが、契約の `out_of_scope` にも `scope` にもその旨を書いていない場合、spec_aligned (観点 6) と out_of_scope_explicit (観点 2) の同時 FAIL として CRITICAL reject する。

**Why:** Issue #2 contract attempt 1 で Generator が「機能 13 後段 (再同意拒否時の機能停止 UI) は近接検知/再生キュー実装後の Sprint に委譲」と handoff の確認事項 #4 で主張したが、契約 JSON 自体には scope にも out_of_scope にも一切書かれていなかった。これは「やるとも言ってないし、やらないとも言ってない」状態 = 契約の沈黙が後の評価フェーズで爆発する。契約は handoff ではなく契約 JSON 自身が完結している必要がある (handoff は実装後の引き継ぎ文書であって契約の一部ではない)。

**How to apply:**
1. Generator の handoff / prompt / コミットメッセージで「次 Sprint に延期」「out of scope」「後の Sprint で扱う」等の言及があれば、その対象 AC を spec.md で特定
2. 特定した AC について contract の scope と out_of_scope を grep で確認 (`grep -F "<AC キーワード>" .ai/work/<id>/contract.json`)
3. どちらにも書かれていなければ即 reject 「観点 2 (out_of_scope_explicit) と観点 6 (spec_aligned) の同時 FAIL」
4. 修正提案: 「(A) scope に取り込む、(B) out_of_scope に明示延期、のどちらか 1 つを契約 JSON に書け」と Generator に指示
5. 「(B) で延期する根拠が弱い」と判断したら推奨を (A) に倒す。例: ConsentPage に stuck redirect させる UI 制御は近接検知 / 再生キュー実装に依存しないので Presentation 完結の Sprint で完成可能
