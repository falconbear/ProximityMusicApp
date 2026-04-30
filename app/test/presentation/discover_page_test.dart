// Presentation widget tests for DiscoverPage (Issue #3 — RED phase).
//
// Drives the page with provider overrides so tests are deterministic:
//   - discoverySourceProvider → FakeDiscoverySource
//   - peerRegistryProvider / bluetoothStateProvider seeded as needed
//
// Asserts the spec-mandated UI:
//   - empty state copy
//   - Bluetooth-off error copy
//   - "N 台検知中" summary
//   - toggle Switch starts discovery
//   - one PeerListTile renders for one peer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/data/services/fake_discovery_source.dart';
import 'package:proximity_music_app/domain/entities/bluetooth_state.dart';
import 'package:proximity_music_app/domain/entities/discovery_status.dart';
import 'package:proximity_music_app/domain/entities/peer.dart';
import 'package:proximity_music_app/domain/services/discovery_source.dart';
import 'package:proximity_music_app/domain/services/peer_registry.dart';
import 'package:proximity_music_app/presentation/pages/discover_page.dart';
import 'package:proximity_music_app/presentation/state/discovery_providers.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

DiscoverySource _makeSource({
  BluetoothState bt = BluetoothState.on,
  List<Peer> peers = const [],
}) {
  return FakeDiscoverySource(
    initialBluetoothState: bt,
    peers: peers,
    interval: const Duration(seconds: 5),
  );
}

void main() {
  testWidgets(
    'shows "周囲に誰もいません" empty-state copy when Bluetooth.on and 0 peers',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DiscoverPage(),
          overrides: [
            discoverySourceProvider.overrideWithValue(_makeSource()),
            bluetoothStateProvider
                .overrideWith((ref) => BluetoothState.on),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.text('周囲に誰もいません。場所を変えてみてください'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows Bluetooth-off error copy when Bluetooth state is off',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DiscoverPage(),
          overrides: [
            discoverySourceProvider.overrideWithValue(
              _makeSource(bt: BluetoothState.off),
            ),
            bluetoothStateProvider
                .overrideWith((ref) => BluetoothState.off),
          ],
        ),
      );
      await tester.pump();

      expect(
        find.text('Bluetooth が無効です。設定を確認してください'),
        findsOneWidget,
      );
    },
  );

  testWidgets('summary shows "2 台検知中" when registry has 2 peers',
      (tester) async {
    final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
    final registry = PeerRegistry()
      ..upsert(Peer(id: 'a', lastSeenAt: t, avatarSeed: 1))
      ..upsert(Peer(id: 'b', lastSeenAt: t, avatarSeed: 2));

    await tester.pumpWidget(
      _wrap(
        const DiscoverPage(),
        overrides: [
          discoverySourceProvider.overrideWithValue(_makeSource()),
          bluetoothStateProvider.overrideWith((ref) => BluetoothState.on),
          peerRegistryProvider.overrideWith((ref) => registry),
          discoveryStatusProvider
              .overrideWith((ref) => DiscoveryStatus.scanning),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('2 台検知中'), findsOneWidget);
  });

  testWidgets(
    'tapping the Switch transitions DiscoveryStatus toward starting/scanning',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DiscoverPage(),
          overrides: [
            discoverySourceProvider.overrideWithValue(_makeSource()),
            bluetoothStateProvider
                .overrideWith((ref) => BluetoothState.on),
          ],
        ),
      );
      await tester.pump();

      final sw = find.byType(Switch);
      expect(sw, findsOneWidget);

      await tester.tap(sw);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Status must have advanced past idle.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiscoverPage)),
      );
      final status = container.read(discoveryStatusProvider);
      expect(
        status == DiscoveryStatus.starting ||
            status == DiscoveryStatus.scanning,
        isTrue,
        reason: 'expected starting or scanning, got $status',
      );
    },
  );

  testWidgets('renders one PeerListTile per peer in the registry',
      (tester) async {
    final t = DateTime.utc(2026, 5, 1, 12, 0, 0);
    final registry = PeerRegistry()
      ..upsert(Peer(id: 'peer-aaa00001', lastSeenAt: t, avatarSeed: 7));

    await tester.pumpWidget(
      _wrap(
        const DiscoverPage(),
        overrides: [
          discoverySourceProvider.overrideWithValue(_makeSource()),
          bluetoothStateProvider.overrideWith((ref) => BluetoothState.on),
          peerRegistryProvider.overrideWith((ref) => registry),
          discoveryStatusProvider
              .overrideWith((ref) => DiscoveryStatus.scanning),
        ],
      ),
    );
    await tester.pump();

    // Truncated id (first 8 chars) and a relative-time label are visible.
    expect(find.textContaining('peer-aaa'), findsOneWidget);
    expect(find.textContaining('たった今'), findsOneWidget);
  });
}
