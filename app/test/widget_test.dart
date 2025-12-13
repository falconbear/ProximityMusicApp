// Proximity Music App widget tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/main.dart';

void main() {
  testWidgets('App smoke test - loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ProximityMusicApp()));

    // Verify that the app title is displayed.
    expect(find.text('Proximity Music'), findsOneWidget);
    
    // Verify that discovery section is displayed.
    expect(find.text('Discovery Paused'), findsOneWidget);
    
    // Verify that the discovery switch exists.
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Discovery switch toggles state', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProximityMusicApp()));

    // Find the discovery switch
    final switchWidget = find.byType(Switch);
    expect(switchWidget, findsOneWidget);

    // Initially should show 'Discovery Paused'
    expect(find.text('Discovery Paused'), findsOneWidget);
    
    // Tap the switch to turn on discovery
    await tester.tap(switchWidget);
    await tester.pump();

    // Should now show 'Discovery Active'
    expect(find.text('Discovery Active'), findsOneWidget);
  });

  testWidgets('Navigation to player page works', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProximityMusicApp()));

    // Find the player button in app bar
    final playerButton = find.byIcon(Icons.queue_music);
    expect(playerButton, findsOneWidget);

    // Tap the player button
    await tester.tap(playerButton);
    await tester.pumpAndSettle();

    // Should navigate to player page
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('再生コントロール'), findsOneWidget);
  });
}
