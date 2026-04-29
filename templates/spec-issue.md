<!-- Spec Issue body template.
     タイトル形式: "Spec issue: <短い問題タイトル>"
     ラベル:      spec-issue,critical  (または spec-issue のみ)
     起票者: generator が docs/spec-issues.md を書いた直後、または
             evaluator が契約モードで 3/3 拒否して BLOCKED になった直後。 -->

## Problem

<!-- 仕様の何が問題か。1-3 文で -->

## Affected issues

<!-- 影響を受ける Issue 番号。複数あれば全て -->
- #<id>

## Detail

<!-- 問題の具体。以下のいずれかで分類:
     - Ambiguity: 仕様の解釈が複数成り立ってしまう
     - Contradiction: 仕様内の記述同士が矛盾する
     - Gap: 合理的な解釈のための情報が不足している
     - Out-of-reach: 契約を結べない (3/3 で拒否された)

     具体的な spec.md の引用と、なぜ困っているかを書く -->

## Impact

<!-- BLOCKED か advisory か -->
- [ ] BLOCKED: この Issue は spec 修正なしで進められない
- [ ] Advisory: 暫定解釈で進行中だが、人間確認を希望

## Proposed resolutions

<!-- 1-3 個の解決案。意思決定を押し付けず、トレードオフを並べる -->

1. <案 A> — pros / cons
2. <案 B> — pros / cons
3. <案 C> — pros / cons

## References

- Spec: `docs/spec.md`
- Spec issues log: `docs/spec-issues.md`
- (契約審査で上限到達した場合) Feedback: `docs/feedback/issue-<id>-contract.md`

---

🤖 Generator / Evaluator により自動起票。人間の判断を待つ。
