---
id: avoid_findsOneWidget_when_appbar_and_body_share_text
role: generator
project_scope: ProximityMusicApp
confidence: 0.65
created_at: 2026-04-30
last_observed: 2026-04-30
source_issues: [2]
---

# Use findsAtLeastNWidgets(1) when text shared by AppBar title and body content

## Pattern

`find.text(X)` will match X in multiple locations if scope places identical
text in both AppBar title and body content area. Using `findsOneWidget`
(= exactly 1 match) will fail. Use `findsAtLeastNWidgets(1)` instead when
the intent is to verify page content presence, then anchor to a unique widget
(e.g., `findsOneWidget` on a button) as the strict proof of navigation.

## Why

Sprint 02 Issue #2 WelcomePage test: `find.text('Welcome')` appeared in both
AppBar (line 65, via OnboardingPage mixin) and body heading (line 140, as
h1). Test wrote `findsOneWidget` expecting 1 exact match, causing
`Found 2 widgets with text "Welcome"... is too many` failure.

This is **not a test-integrity violation** (= not an asertion rewrite of
existing tests) but a finder over-specificity in the **new test file
written during RED phase**. AppBar title + body content duplication is
legitimate scope design.

## How to apply

1. When writing Widget tests for navigation pages (Welcome, Privacy, etc.),
   check scope: if page title appears in both AppBar and body, use
   `findsAtLeastNWidgets(1)` for the redundant element.
2. Anchor the strict check to a unique child element instead:
   - e.g., `expect(find.text('Next'), findsOneWidget)` (body-only button)
   - OR `find.descendant(of: find.byType(AppBar), matching: find.text('Title'))`
     if AppBar title uniqueness is critical.
3. Add a comment explaining the 2-location match is intentional design.

## Anti-pattern (Issue #2 attempt 3 failure)

```dart
// FAIL: finds 2 widgets (AppBar + body)
expect(find.text('Welcome'), findsOneWidget);
```

## Corrected pattern

```dart
// PASS: allow 1+ because AppBar + body both have 'Welcome'
expect(find.text('Welcome'), findsAtLeastNWidgets(1));
// STRICT check via unique button
expect(find.text('Next'), findsOneWidget);
```
