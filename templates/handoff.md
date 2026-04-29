# Issue #<id> Handoff (Generator → Evaluator)

**Generator:** generator
**最終更新:** YYYY-MM-DD
**Phase:** Phase 3 完了 (READY_FOR_REVIEW) / Phase 4 修正完了

## 実装サマリ

<契約の Scope に対して、何を実装したかを 3-5 行で>

## 起動方法

```bash
# 例
./init.sh              # 初回セットアップ (冪等)
npm run dev            # 開発サーバ起動
```

- URL / エンドポイント: `<URL>`
- 停止方法: `<PID 確認 + kill, または Ctrl+C>`
- 必要な環境変数: `<key=value, ある場合のみ>`

## TDD ログ

| Phase | Commit SHA | 概要 |
|---|---|---|
| RED | `<sha>` | 失敗テストを追加 |
| GREEN | `<sha>` | 最小実装でパス |
| REFACTOR | `<sha>` (任意) | 命名改善・重複排除 |

これらは `state.json.tdd` にも記録済み。

## 自己評価 (参考、evaluator は無視)

| 基準 | スコア | 一言 |
|------|--------|------|
| 契約適合性 | X/5 | <一言> |
| 動作安定性 | X/5 | <一言> |
| 品質 (UX/可読性) | X/5 | <一言> |
| エッジケース対応 | X/5 | <一言> |

## 技術判断 (契約に書ききれなかった選択)

- <選択 + 理由 1>
- <選択 + 理由 2>

## 既知の課題 / 制約

- <Out of scope に該当する未実装>
- <一時的な workaround>
- <次 Issue で扱うべき関連事項>

## 修正ログ (Phase 4 のみ追記)

### Attempt N
- <evaluator の指摘 X> に対する修正: <内容>
- <indicator>: <修正後の動作>
