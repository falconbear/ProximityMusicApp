---
name: context-strategy
description: 長期 AI セッションでのコンテキスト管理戦略。compaction タイミング、MEMORY.md 再注入、subagent 間 context 受け渡しの最小化、プロンプトキャッシュ活用 (1M context 向け) を統合した、親 Claude 向けプロトコル。
---

# context-strategy — 長期セッションの context 管理

## 背景

AI 自律開発で長時間セッションを回すと context が必ず膨張する:

- `docs/feedback/*.md` の蓄積
- `.ai/work/*/handoff.md` の蓄積
- subagent 呼び出しの累積
- Bash 出力や Read したファイルの蓄積

対策を体系化しないと、200K / 1M どちらの context 長でも遅かれ早かれ劣化する。

`.ai/work/<id>/state.json` などの構造化データは小さいので問題にならない (per-Issue で 1KB 程度)。問題は散文 MD の累積。

## 原則

1. **予防 > 治療**: context が溢れてから compact するのではなく、閾値到達前に pre-empt
2. **記憶の分離**: 揮発 (session) / 永続 (MEMORY.md) / 本能 (Instinct) を使い分ける
3. **必要なものだけロード**: subagent には必要最小の引数だけ渡す。細部は subagent 自身が Read する
4. **キャッシュを壊さない**: 5 分キャッシュ TTL 内の連続作業を優先

## 戦略 1: 動的コンパクション (Proactive Compaction)

親 Claude は以下の指標を監視し、閾値を超えたら `/compact` を発動:

| 指標 | 閾値 | 対応 |
|---|---|---|
| 総 token 消費 | 200K context の 70% (= 140K) | 軽い `/compact` (最近 10 ターンのみ要約) |
| 総 token 消費 | 200K context の 85% (= 170K) | 強い `/compact` (全ターンを要約、コードは保持) |
| 総 token 消費 | 1M context の 50% (= 500K) | 軽い `/compact` |
| Issue 間境界 | 1 Issue 完了時 | 強制 compact (次 Issue に不要な詳細を捨てる) |
| Phase 間境界 | RED → GREEN 遷移時 | 軽い compact (任意) |

## 戦略 2: MEMORY.md の運用

各 subagent は frontmatter `memory: project` により `.claude/agent-memory/<agent-name>/MEMORY.md` が自動注入される (先頭 200 行または 25KB)。

**書き込みタイミング**: subagent 終了時に自分の学びを MEMORY.md に追記する。

**古い記憶の退避**: 10 Issue より古いものは `archived/YYYY-MM.md` に移し、MEMORY.md 本体は最新分だけ残す。

**Instinct 抽出**: Issue PASSED 直後に observer subagent を dispatch して MEMORY.md と feedback から Instinct (project-scoped `.harness/instincts/`) を抽出する。

## 戦略 3: Subagent 間の context 受け渡し

親 Claude が subagent を dispatch する際、**必要な情報だけを task 引数に含める**:

| Dispatched agent | 必要な入力 | 不要な入力 (含めない) |
|---|---|---|
| planner | user idea, CLAUDE.md, 既存 spec.md | 過去 Issue の詳細 |
| generator (Phase 3) | issue_id (controller で読む), 契約 (`.ai/work/<id>/contract.json`), spec.md 該当部分 | 他 Issue の詳細 |
| evaluator (契約モード) | issue_id, contract.json, spec.md | 実装コード |
| evaluator (実装モード) | issue_id, contract.json, handoff.md, 実行指示 | 前 Issue の feedback (ただし回帰テスト観点では最近分は渡す) |
| observer | 直近 PASSED の issue_id 一覧 + 各 progress.jsonl + qa.json + feedback/ | コード、契約本文 |

subagent は自分が必要な追加情報を自分で Read する (iterative-retrieval パターン)。**親が前もって全部渡すと token 負荷が倍増する**。

## 戦略 4: プロンプトキャッシュの活用 (1M context モデル向け)

Opus 4.7 (1M context) では prompt cache TTL が 5 分。効率的に使うには:

- **5 分以内の連続操作**はキャッシュヒット → token コスト激減
- **5 分以上の sleep** は可能な限り避ける (キャッシュミスで全 context 再計算)
- **意図的な compact** は例外的にキャッシュを捨てる (新たなキャッシュキーになる) ので、タイミングを選ぶ (境界部分でまとめて行う)
- Background task (Agent run_in_background) は並行時に個別キャッシュを持つ

## 実践ガイドライン (親 Claude 向け)

### Issue 開始時のチェック

```
1. bin/controller.py list で全 Issue 状態を 1 行ずつ取得 (軽量)
2. git log --oneline -n 30 で直近履歴を把握
3. 対象 Issue の contract.json と handoff.md だけを Read (他 Issue は触らない)
4. subagent を dispatch (必要最小の引数)
```

### Issue 完了時のクリーンアップ

```
1. subagent の MEMORY.md が更新されているか確認
2. 必要なら /compact (軽い)
3. observer を dispatch して Instinct 抽出 (.harness/instincts/ に書き込み)
4. 次 Issue へ
```

### 長時間セッションでの再開

```
1. git log, controller.py list, CLAUDE.md, MEMORY.md (主要 agent 分) を読む
2. session_start_hook が自動でスナップショットを context 注入してくれる
3. prompt cache が有効か意識 (270 秒ルール)
4. 作業開始
```

## 参照

- `docs/PIPELINE.md` §4 (状態機械), §8 (skill manifest)
- `skills/pipeline-protocol/`
- `skills/instinct-loop/` (Instinct 抽出プロトコル)
- `hooks/session_start_hook.py` (セッション開始時の自動 snapshot 注入)
