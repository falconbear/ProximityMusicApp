---
id: avoid_strict_grep_forbidden_in_comments
role: generator
project_scope: ProximityMusicApp
confidence: 0.6
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [2]
---

# When scope says grep X=0, exclude X from comments too

## Pattern

Scope / success_criteria with strict grep (e.g., `grep -F 'permission_handler'
app/lib/ | wc -l == 0`) requires the search string to be absent **entirely**,
including comments. Forward-looking notes like "The real X arrives in Issue #N"
will cause the grep to hit and fail the contract even if the actual package
is not imported.

## Why

Sprint 02 Issue #2 success_criteria SC-25 (scope[19]) requires:
```
`grep -F 'permission_handler' app/lib/` = 0 (permission_handler not added)
```

Generator added placeholder comment in `onboarding_providers.dart:68`:
```
/// The real `permission_handler` integration arrives in Issue #3.
```

This caused `grep -RF 'permission_handler' app/lib/ | wc -l` = **1** (the
comment), failing the strict grep despite zero actual imports. BUG-2 during
attempt 1 evaluation, requiring a Phase 4 fix.

## How to apply

1. When scope requires `grep -F '<word>' app/lib/ | wc -l == 0`, interpret
   it as **zero occurrences anywhere**, including comments.
2. To document forward intent without failing the grep, use alternative
   phrasing:
   - "OS permission API integration"
   - "Native permission flow" (generic, not package-specific)
   - "Real device permission handling" (descriptive, avoids package name)
3. For planned dependencies, document in out_of_scope or README instead of
   leaving a dartdoc comment in app/lib/. Comments in scope artifacts are
   vulnerable to grep filters.
4. If the comment is essential, propose contract wording change to evaluator
   before drafting (e.g., relax grep to "`grep -F 'permission_handler[^_]`" or
   specify imports only via `grep -E '^import'`).

## Anti-pattern

```dart
// Violates scope[19] strict grep = 0
/// The real `permission_handler` integration arrives in Issue #3.
final requestOsPermissionProvider = ...
```

## Corrected pattern

```dart
// Complies with scope[19]
/// The real OS permission API integration arrives in Issue #3.
final requestOsPermissionProvider = ...
```

or

```dart
// No comment, put intent in README or out_of_scope instead
final requestOsPermissionProvider = ...
```
