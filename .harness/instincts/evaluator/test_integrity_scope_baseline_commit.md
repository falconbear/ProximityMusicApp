---
id: test_integrity_scope_baseline_commit
role: evaluator
project_scope: ProximityMusicApp
confidence: 0.75
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [2]
---

# test-integrity: "existing" = sprint base commit, not all test files

## Pattern

test-integrity hook forbids modification of "existing" test files. Define
"existing" precisely as: **test files that existed at sprint branch point
(= merge-base with main)**, typically the sprint base commit like `f7f582d`
(Sprint 02 split point).

**New test files created during RED phase** (e.g., `onboarding_flow_test.dart`
added in RED commit `17722cf`) are **not** "existing" and can be edited
within the same Sprint for correctness fixes (e.g., finder assertion
tightening).

## Why

Sprint 02 Issue #2 Phase 3 RED commit `17722cf` added 5 new test files
(onboarding_state_test, consent_record_test, onboarding_service_test,
onboarding_flow_test, dashboard_with_banner_test). Later in attempt 3,
`onboarding_flow_test.dart:139` failed because `find.text('Welcome')`
matched 2 widgets (AppBar + body), not 1.

Generator corrected the assertion from `findsOneWidget` to
`findsAtLeastNWidgets(1)` + added comment. This is a **finder specificity
fix**, not a functional rewrite, and is **valid** because:

1. The test file was written by the same generator in the same Sprint's RED
   phase (not pre-existing).
2. The fix maintains the intent (WelcomePage reachability) via anchor on
   `'Next'` button strict match.
3. test-integrity aims to prevent **regression of pre-existing test
   assertions**, not to freeze intra-Sprint test corrections.

## How to apply

1. Identify the sprint base commit (merge-base or explicit `sprint/XX-...`
   branch point). For Sprint 02, baseline = `f7f582d`.
2. Pre-existing tests = files that `git diff f7f582d --name-only | grep
   test/` lists as unchanged before Sprint start.
   - Sprint 02: `widget_test.dart` (0 byte diff from `f7f582d`),
     `track_test.dart` (0 byte diff from `638c972`).
3. New tests = files added in RED commit or later, not present in baseline.
   - Sprint 02: onboarding_state_test, consent_record_test, onboarding_flow_test,
     dashboard_with_banner_test, settings_page_test (all new).
4. Evaluator allows:
   - **Pre-existing test fixes**: only assertion **value changes** that do
     not alter intent (e.g., `assertEquals(x, 5)` → `assertEquals(x, 6)`
     if spec changed), NOT assertion **removal** or **skip/only addition**.
   - **New test corrections**: finder specificity, expected value tightening,
     mock setup edits, comments (anything that maintains test file
     existence + logical intent).
5. Evaluator blocks:
   - Pre-existing test assertion removal / skip / only.
   - Deletion of pre-existing test files.

## Anti-pattern (overly strict)

```
Evaluator rejects generator's finder fix in onboarding_flow_test.dart
because "test file is 0 byte changed from RED, so it's existing."
→ Wrong. RED is the boundary. onboarding_flow_test is NEW in RED.
```

## Corrected interpretation

```
onboarding_flow_test.dart was added in RED (17722cf).
Its modification in attempt 3 is **intra-Sprint correction**,
not pre-existing test manipulation.

But widget_test.dart (pre-existing, baseline f7f582d) must remain
0 byte diff. Any edit blocks contract.
```
