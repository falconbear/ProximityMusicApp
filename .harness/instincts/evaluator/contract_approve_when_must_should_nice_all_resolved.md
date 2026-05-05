---
name: Contract approve heuristic - all MUST/SHOULD/NICE items resolved
description: Attempt 2 で MUST 全件解消 + SHOULD/NICE も漏れなく反映されていれば承認に倒す
type: heuristic
---

`[HEURISTIC]` 契約再審査で前回 reject の MUST 項目が全て解消され、SHOULD / NICE 項目も契約 JSON に反映されていれば、残り attempts に余裕があっても**承認に倒す**。境界 attempt (3/3 直前など) のときに「もう 1 回差し戻し」を選ぶと無駄に sprint を消費する。

**Why:** Issue #2 contract attempt 2 で MUST 7 + SHOULD 2 + NICE 2 = 11 件すべて解消されていた。SHA タイポ、機能 13 後段の scope 取り込み、redirect 統一、テスト互換戦略 (ProviderScope.overrides 経路分離)、TDD 順序検証の state.json.tdd 参照、OnStateChanged 呼出契約、Banner 非干渉検証、設定画面再要求検証、PermissionStatus.notRequested 非表示明示、RequestOsPermission スタブ品質基準が網羅。残り 1 attempt しかなかったが、これ以上の差し戻し対象 (CRITICAL 級新規) は無く、軽微な観察 (TP ラベル 1 ズレ等) は合否に影響しないため承認。

**How to apply:**
1. attempt N の contract に対して、attempt N-1 の reject 理由 (MUST / SHOULD / NICE) を逐一マッピングする (機械的に keyword grep で網羅性を確認するのが推奨。例: `python3 -c "import json; c=json.load(open(...)); text=json.dumps(c, ensure_ascii=False); print('keyword' in text)"` 形式)
2. MUST がすべて解消されていることが必要条件。1 件でも未解消なら reject (残り attempts 関わらず)
3. SHOULD / NICE は理想的には全件解消だが、明白な代替対応や後続 Issue への split が contract に書かれていれば許容
4. 7 観点を再採点。前回 FAIL → 今回 PASS の観点について、**何が変わって PASS になったのか**を feedback で具体的に書き出す (前回との差分が読める feedback は次フェーズで効く)
5. baseline SHA など機械実行性に関わる箇所は `git rev-parse` で必ず実機検証。タイポ修正系の MUST は「修正後の SHA がちゃんと存在する」ことまで確認しないと判断ミス
6. 軽微な観察 (TP ラベルの番号ズレ、success_criteria の冗長表現等) は合否に影響させず、`## 軽微な観察` セクションで参考情報として記録するに留める
7. 最終判定は controller.py 経由の遷移後に `python3 bin/validate-state.py --strict` で error 0 を確認、`contract.json.locked = true` も `python3 -c` で照合
