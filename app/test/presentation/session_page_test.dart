// RED phase widget tests for SessionPage.
//
// Imports not-yet-existing widgets/providers; will fail to compile until GREEN.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/fake_session_transport.dart';
import 'package:proximity_music_app/data/services/stub_key_exchange.dart';
import 'package:proximity_music_app/domain/entities/key_pair.dart';
import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';
import 'package:proximity_music_app/domain/services/id_rotation_policy.dart';
import 'package:proximity_music_app/domain/services/session_registry.dart';
import 'package:proximity_music_app/presentation/pages/session_page.dart';
import 'package:proximity_music_app/presentation/state/session_providers.dart';

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

HandshakeMessage replyFor(String peerId) => HandshakeMessage(
      fromIdValue: peerId,
      publicKeyHex: 'c' * 64,
      nonceHex: 'd' * 32,
    );

void main() {
  final t0 = DateTime.utc(2026, 5, 5, 12);

  SessionId seedId() => SessionId.generate(Random(99), t0);

  IdRotationPolicy seedPolicy() =>
      IdRotationPolicy(initial: seedId(), initializedAt: t0);

  testWidgets('initial state shows ID and a XXXX-XXXX fingerprint',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionPage(),
        [
          idRotationPolicyProvider.overrideWithValue(seedPolicy()),
          sessionTransportProvider.overrideWithValue(
            FakeSessionTransport(outcomes: const {}),
          ),
          keyExchangeProvider.overrideWithValue(StubKeyExchange()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ID: '), findsWidgets);
    final fingerprintFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data != null &&
          RegExp(r'[0-9a-fA-F]{4}-[0-9a-fA-F]{4}').hasMatch(w.data!),
    );
    expect(fingerprintFinder, findsWidgets);
  });

  testWidgets('empty state shows the unconnected guidance text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionPage(),
        [
          idRotationPolicyProvider.overrideWithValue(seedPolicy()),
          sessionTransportProvider.overrideWithValue(
            FakeSessionTransport(outcomes: const {}),
          ),
          keyExchangeProvider.overrideWithValue(StubKeyExchange()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('近くのピアと未接続です。Discover 画面からピアを選んで接続してください'),
      findsOneWidget,
    );
  });

  testWidgets('seeded connected Session is rendered', (tester) async {
    final policy = seedPolicy();
    final registry = SessionRegistry();
    registry.upsert(
      Session(
        peerId: 'peer-AAAA-BBBB',
        myIdAtOpen: policy.current,
        status: SessionStatus.connected,
        updatedAt: t0,
      ),
    );

    await tester.pumpWidget(
      _wrap(
        const SessionPage(),
        [
          idRotationPolicyProvider.overrideWithValue(policy),
          sessionRegistryProvider.overrideWithValue(registry),
          sessionTransportProvider.overrideWithValue(
            FakeSessionTransport(outcomes: const {}),
          ),
          keyExchangeProvider.overrideWithValue(StubKeyExchange()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // peerId short form should be visible somewhere on the page.
    expect(find.textContaining('peer-AAAA'), findsWidgets);
    // The connected status label from the chip.
    expect(find.text('接続済み'), findsWidgets);
  });

  testWidgets('failed session shows retry button and tap returns to connected',
      (tester) async {
    final policy = seedPolicy();
    final registry = SessionRegistry();
    registry.upsert(
      Session(
        peerId: 'peer-FAIL',
        myIdAtOpen: policy.current,
        status: SessionStatus.failed,
        updatedAt: t0,
        failureReason: 'transport_unavailable',
      ),
    );

    final transport = FakeSessionTransport(
      outcomes: {'peer-FAIL': FakeHandshakeOutcome.success(replyFor('peer-FAIL'))},
    );

    await tester.pumpWidget(
      _wrap(
        const SessionPage(),
        [
          idRotationPolicyProvider.overrideWithValue(policy),
          sessionRegistryProvider.overrideWithValue(registry),
          sessionTransportProvider.overrideWithValue(transport),
          keyExchangeProvider.overrideWithValue(StubKeyExchange()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final retry = find.text('再試行');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(
      registry.sessionFor('peer-FAIL')?.status,
      SessionStatus.connected,
    );
  });

  testWidgets('tapping 今すぐ更新 changes the displayed fingerprint',
      (tester) async {
    final policy = seedPolicy();

    await tester.pumpWidget(
      _wrap(
        const SessionPage(),
        [
          idRotationPolicyProvider.overrideWithValue(policy),
          sessionTransportProvider.overrideWithValue(
            FakeSessionTransport(outcomes: const {}),
          ),
          keyExchangeProvider.overrideWithValue(StubKeyExchange()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final fpRegex = RegExp(r'[0-9a-fA-F]{4}-[0-9a-fA-F]{4}');
    String? capture() {
      String? hit;
      for (final el in find
          .byWidgetPredicate((w) => w is Text && w.data != null)
          .evaluate()) {
        final t = el.widget as Text;
        final match = fpRegex.firstMatch(t.data!);
        if (match != null) {
          hit = match.group(0);
          break;
        }
      }
      return hit;
    }

    final before = capture();
    expect(before, isNotNull);

    await tester.tap(find.text('今すぐ更新'));
    await tester.pumpAndSettle();

    final after = capture();
    expect(after, isNotNull);
    expect(after, isNot(before));
  });
}
