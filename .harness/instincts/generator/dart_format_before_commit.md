---
id: dart_format_before_commit
role: generator
project_scope: ProximityMusicApp
confidence: 0.95
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [1]
---

# Always run `dart format .` before committing Flutter / Dart code

## Pattern

GREEN / Refactor / Phase 4 fix で Dart コードを書いたら、commit 前に必ず
`cd app && dart format .` を実行する。formatter 差分があるまま push すると CI
の format check が落ちる (issue-1 PR #12 で 2 回連続で発生)。

## Why

- `.github/workflows/flutter-ci.yml` の format step は `dart format --set-exit-if-changed`
  を使い、空白 1 文字の差分でも fail する設計。Sprint 01 では暫定的に
  `continue-on-error: true` で warning 化したが、本来は green を保つべき。
- 既存テスト (`test/widget_test.dart`) も formatter 対象。test-integrity の
  「アサーション改変禁止」とは独立した形式ルールなので、format 適用は許容
  される (改行 / インデントのみ)。

## How to apply

1. RED / GREEN / Refactor / Phase 4 で Dart ファイルを編集したら、commit 直前に
   `cd app && dart format .` を実行。
2. format による diff が出たら、それを実装と同じ commit に含める (別 commit に
   切るとコメントが冗長になる)。
3. 親コンテナに dart が無い場合は手動でも 80 列折り返し / trailing comma を
   揃える。完全一致は不可なので最低限 import 並びと trailing comma を意識する。
4. CI の format step が warning を吐いたら、次の attempt で必ず修正する。

## Anti-pattern (issue-1 attempt #1 / #2 で観測)

- `dart format` を当てずに GREEN commit → CI で `Changed lib/.../...dart`
  が 3 ファイル出て exit 1。
- format diff は内容変更ではないので生成時に気付きにくい。
- `widget_test.dart` も対象に入るが、これは「test 改変ではなく formatting」
  であることを evaluator にも周知 (PR コメントで根拠を明示するとよい)。
