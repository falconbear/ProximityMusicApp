---
name: Flutter widget tests use 800x600 viewport — guard placeholder Columns against overflow
description: Placeholder/empty-state Columns under Expanded must tolerate small heights (~50px) or they cause RenderFlex overflow in flutter test
type: feedback
---

`flutter test` runs in a synthetic 800x600 viewport. Any Column placed
inside an `Expanded` whose siblings consume most of the parent height
will receive only a few dozen pixels of vertical space. If the Column
contents have a natural height (icons, fixed `SizedBox(height: 16)`,
multi-line Text), it overflows with the classic
`RenderFlex overflowed by N pixels on the bottom` error.

**Why:** the dev-time Flutter app on a real device or web window has
600+ logical pixels for the queue area, so the layout looks fine
locally and during manual UI testing. The overflow only surfaces in
CI / `flutter test` because of the smaller test viewport. We hit this
in Issue #1 after PASSED — both `_EmptyQueue` (dashboard_page.dart) and
the controls `Column` in PlayerPage tripped it on PR #12.

**How to apply:**
1. For empty-state / placeholder widgets that decorate an Expanded
   slot, wrap the inner Column in
   `SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
   ...))`. This keeps the visual layout identical when there is enough
   space and falls back to scroll when squeezed.
2. Prefer `mainAxisSize: MainAxisSize.min` on Columns inside
   scroll views — without it the Column still requests
   `double.infinity` and you get an unbounded-height assertion.
3. If the section is naturally bottom-aligned (e.g. `mainAxisAlignment:
   MainAxisAlignment.end`), pair `SingleChildScrollView(reverse: true)`
   with `MainAxisSize.min` so the bottom remains visible when content
   exceeds the available height.
4. Do NOT add fixed `height:` to the parent or shrink children to fit;
   that breaks the device-width design and is visible to humans.
5. Test plan tip: contract Test plan items that say "no functional
   regression" should be flagged as "CI-dependent" if Flutter SDK is
   absent locally — evaluator otherwise has no way to detect this class
   of bug before PR CI.
