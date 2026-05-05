---
id: run_flutter_analyze_after_green_commit
role: generator
project_scope: ProximityMusicApp
confidence: 0.7
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [2]
---

# Run `flutter analyze` after GREEN commit before pushing

## Pattern

GREEN commit may introduce lint violations (e.g., `prefer_const_constructors`)
that CI catches after push, blocking downstream test execution. Run
`cd app && flutter analyze` locally after GREEN phase to catch warnings before
the PR.

## Why

Sprint 02 Issue #2 GREEN commit `7d11d63` introduced 3 `prefer_const_constructors`
warnings in `consent_page.dart` (lines 65-67) due to non-const `Expanded`
wrapping const children. CI workflow treats warnings as fatal
(`--no-fatal-infos` only, not `--no-fatal-warnings`), exit 1, and skips
`flutter test` downstream. Evaluator cannot verify implementation.

This is a **static quality issue**, not functional regression, but it gates
CI pipeline.

## How to apply

1. After GREEN commit completes and before `push -u origin`, run
   `cd app && flutter analyze` in the local container.
2. If warnings appear (even 1), edit the files to fix:
   - `prefer_const_constructors`: add `const` to widget constructors if children
     are fully const
   - `unnecessary_import`: remove unused imports
   - `missing_required_param`: add required params
3. Run `flutter analyze` again to confirm 0 error / 0 warning (info-only is OK).
4. Amend or add a follow-up commit (labeled `fix:` or `refactor:` per contract).
5. Push and let CI verify.

**Note**: If `flutter` command is unavailable in container, use the CI run
summary from `.github/workflows/flutter-ci.yml` to spot check; contact
evaluator early if lint violations surface during CI.

## Anti-pattern

```bash
# After GREEN commit
cd app && git push -u origin sprint/02-onboarding-and-consent
# (NO flutter analyze check)
# → CI fails with warning 3 / exit 1
# → flutter test not executed
# → evaluator must wait for attempt 2 fix
```

## Corrected pattern

```bash
# After GREEN commit
cd app && flutter analyze
# Check output for warnings
# If any: fix + commit / amend
# Then push
git push -u origin sprint/02-onboarding-and-consent
```
