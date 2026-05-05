// Riverpod providers for the anonymous session feature.
//
// Wires the pure-Dart Domain + Data classes into the widget tree. The
// providers expose the same shape as Sprint 01-03 conventions: services as
// `Provider<T>`, mutable view models as derived `Provider<List<T>>` /
// `Provider<T>` with a small _sessionTickProvider used to invalidate
// computed views after imperative mutations (rotateNow / openSession).

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/data/services/fake_session_transport.dart';
import 'package:proximity_music_app/data/services/stub_key_exchange.dart';
import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/services/id_rotation_policy.dart';
import 'package:proximity_music_app/domain/services/key_exchange.dart';
import 'package:proximity_music_app/domain/services/session_registry.dart';
import 'package:proximity_music_app/domain/services/session_transport.dart';
import 'package:proximity_music_app/presentation/state/session_controller.dart';

/// KeyExchange implementation. Defaults to StubKeyExchange (sha256 MVP).
final keyExchangeProvider = Provider<KeyExchange>((ref) => StubKeyExchange());

/// SessionTransport implementation. Defaults to FakeSessionTransport with
/// no outcomes (i.e., every sendHandshake fails until configured) — this is
/// intentional for Sprint 04 since the native side is a stub. Real transport
/// is swapped in via override in the production app entrypoint when Issue
/// #5+ ships.
final sessionTransportProvider = Provider<SessionTransport>(
  (ref) => FakeSessionTransport(outcomes: const {}),
);

/// IdRotationPolicy seeded at app start with a fresh SessionId. App-start
/// rotation is satisfied by the construction itself (spec.md feature 4).
final idRotationPolicyProvider = Provider<IdRotationPolicy>((ref) {
  final now = DateTime.now().toUtc();
  final id = SessionId.generate(Random.secure(), now);
  return IdRotationPolicy(initial: id, initializedAt: now);
});

/// In-memory SessionRegistry. Resets on app launch (no persistence by spec).
final sessionRegistryProvider = Provider<SessionRegistry>(
  (ref) => SessionRegistry(),
);

/// Tick used to invalidate sessionsProvider / currentSessionIdProvider after
/// an imperative mutation (upsert / rotate). Increment via
/// `ref.read(_sessionTickProvider.notifier).state++`.
final _sessionTickProvider = StateProvider<int>((ref) => 0);

/// Latest list of sessions known to the registry. Re-evaluates on every
/// _sessionTickProvider increment.
final sessionsProvider = Provider<List<Session>>((ref) {
  ref.watch(_sessionTickProvider);
  return ref.read(sessionRegistryProvider).sessions;
});

/// Current SessionId from the rotation policy. Re-evaluates on every
/// _sessionTickProvider increment so widgets see the new fingerprint after
/// rotateNow.
final currentSessionIdProvider = Provider<SessionId>((ref) {
  ref.watch(_sessionTickProvider);
  return ref.read(idRotationPolicyProvider).current;
});

/// SessionController bound to the ProviderScope. Reads transport / key
/// exchange / policy / registry from their providers and bumps
/// _sessionTickProvider on every upsert / rotation so derived views update.
final sessionControllerProvider = Provider<SessionController>((ref) {
  final registry = ref.read(sessionRegistryProvider);
  final controller = SessionController(
    transport: ref.read(sessionTransportProvider),
    keyExchange: ref.read(keyExchangeProvider),
    idRotationPolicy: ref.read(idRotationPolicyProvider),
    upsertSession: (session) {
      registry.upsert(session);
      ref.read(_sessionTickProvider.notifier).state++;
    },
    onIdRotated: (_) {
      ref.read(_sessionTickProvider.notifier).state++;
    },
    clock: () => DateTime.now().toUtc(),
    rng: () => Random.secure(),
  );
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});
