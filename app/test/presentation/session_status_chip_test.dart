// RED phase widget tests for SessionStatusChip.
//
// Imports not-yet-existing widget; will fail to compile until GREEN.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/session_status.dart';
import 'package:proximity_music_app/presentation/widgets/session_status_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('idle status renders アイドル label', (tester) async {
    await tester
        .pumpWidget(_wrap(const SessionStatusChip(SessionStatus.idle)));

    expect(find.text('アイドル'), findsOneWidget);
  });

  testWidgets('connecting status renders 接続中 label and a CircularProgressIndicator',
      (tester) async {
    await tester
        .pumpWidget(_wrap(const SessionStatusChip(SessionStatus.connecting)));

    expect(find.text('接続中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('connected status renders 接続済み label', (tester) async {
    await tester
        .pumpWidget(_wrap(const SessionStatusChip(SessionStatus.connected)));

    expect(find.text('接続済み'), findsOneWidget);
  });

  testWidgets('failed status renders 失敗 label', (tester) async {
    await tester
        .pumpWidget(_wrap(const SessionStatusChip(SessionStatus.failed)));

    expect(find.text('失敗'), findsOneWidget);
  });
}
