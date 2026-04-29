---
id: analyze_info_only_outside_strict_warning_count
role: evaluator
project_scope: ProximityMusicApp
confidence: 0.8
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [1, 2]
---

# `flutter analyze` info-level issues do not count as warnings for SC

## Pattern

When success_criteria requires `flutter analyze` "0 error / 0 warning",
interpret this as **warning count only**. Info-level issues
(deprecated_member_use, etc.) are advisory and do not fail the criterion.
This is distinct from the contract's `--no-fatal-infos` flag (which treats
info as non-fatal in CI workflow) — the criterion itself excludes info from
the "warning count."

## Why

Sprint 01 `dashboard_page.dart` used `withOpacity` (now deprecated),
generating `deprecated_member_use` info issues. Sprint 02 added more
`withOpacity` uses in new PermissionDeniedBanner (3 more info). Total:
33 info-level issues at end of Sprint 02 attempt 2.

CI `flutter analyze --no-fatal-infos` exit 0 with output:
```
33 issues:
  32 infos (deprecated_member_use + activeColor from Sprint 01 / 02)
  0 warnings
  0 errors
```

Evaluator evaluated as **SC-28 PASS** ("0 error / 0 warning") despite
33 info, recognizing that info ≠ warning. The alternative (failing SC-28
due to info count) would be overly strict and would block all code touching
deprecated APIs.

## How to apply

1. When evaluating success_criteria `flutter analyze` requirement:
   - Count **warnings + errors only**. Ignore info-level items.
   - CI exit code is secondary signal; the criterion specifies the level
     granularity.
2. If CI output shows "X issues: [Y info / Z warning / W error]":
   - Pass: if Z==0 AND W==0 (warnings and errors both zero).
   - Fail: if Z>0 OR W>0 (any warning or error present).
3. If issue is info-only, note it in feedback for future sprints
   (e.g., "Sprint 03+ should address deprecated API migration"), but do
   not block current Sprint's SC.
4. Establish a separate Issue for bulk deprecated API cleanup if
   accumulation becomes significant (baseline: ≤ 33 info is acceptable
   for Sprint 02 size).

## Anti-pattern

```
Evaluator: "flutter analyze produced 33 issues, so SC-28 fails."
→ Wrong. Info ≠ warning. Only count warnings + errors.
```

## Corrected pattern

```
Evaluator: "flutter analyze output: 33 info, 0 warning, 0 error.
SC-28 'flutter analyze 0 error / 0 warning' → PASS.
Note: Future Sprint should migrate deprecated APIs (separate Issue)."
```
