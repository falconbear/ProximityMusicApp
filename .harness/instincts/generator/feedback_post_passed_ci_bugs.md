---
name: post-PASSED CI bug fix without state transition
description: When a CI-only regression is found after PASSED, fix via direct commit and keep state PASSED — do not invoke controller.py needs-fix
type: feedback
---

After Issue #1 reached PASSED, CI on PR #12 surfaced 3 RenderFlex
overflow failures that the local evaluator could not catch (no Flutter
SDK in container). The user instructed: fix the bug as a regular commit
on the sprint branch, do NOT call `bin/controller.py needs-fix`, and
leave `state.json` at PASSED.

**Why:** the harness state machine has no `PASSED -> NEEDS_FIX` edge.
Inventing one would require a controller.py change that is itself out
of scope for the immediate CI fix. The PR (still Draft) is the
authoritative artifact for CI-discovered regressions; the next push
re-runs CI and that is the verification loop, not the JSON state.

**How to apply:**
1. If a bug is discovered AFTER `state.json.current_state == "PASSED"`
   but BEFORE PR merge, treat it as a normal `fix(issue-N): ...` commit
   on the existing sprint branch.
2. Do not write to `state.json` and do not run `bin/controller.py
   pass | needs-fix | submit-impl`.
3. Skip `handoff.md` updates — evaluator already produced its qa.json
   for the PASSED submission, and the next CI run is the new evidence.
4. Mention in the commit body why state is intentionally unchanged so
   future readers do not think the harness was bypassed.
5. Limit blast radius: keep changes to the smallest set of files that
   resolves the regression; do not bundle scope-expansion work.

**Anti-pattern:** running `bin/controller.py needs-fix` after PASSED
returns `exit 2` (invalid transition) and clutters progress.jsonl with
a failed event. Don't try.
