// Widget test for the SettingsPage placeholder shipped in Sprint 02
// (Issue #2, TP-26).
//
// Sprint 02 only requires that the Settings screen surfaces a
// 「権限を再要求」 button. The full Settings UI lands in a later issue.
// This test pins the button text so future refactors can't silently drop
// it without a contract revision.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/presentation/pages/settings_page.dart';

void main() {
  testWidgets(
    'SettingsPage shows the 権限を再要求 button text (TP-26)',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('権限を再要求'), findsOneWidget);
    },
  );
}
