// Data layer unit tests for TrackReceiver.
//
// TDD RED phase for Issue #5 (sprint-05: P2P track transfer).
// Targets the future Data layer file
// `package:proximity_music_app/data/services/track_receiver.dart` plus the
// Domain abstractions that it depends on. Until the GREEN phase lands,
// every test in this file MUST fail (compile error counts as failure under
// flutter_test).
//
// Test plan reference: TP-11 (>=7 cases), TP-12 (test name keywords for
// 7 perspectives), TP-23 (FakeChunkTransport usage), TP-24 (PersistEncrypted
// not called on duplicate), TP-25 (abortedDisconnected: identifier +
// PersistEncrypted not called + Stream.addError), TP-26 (abortedIntegrity:
// identifier + PersistEncrypted not called), TP-27 (receivedBytes monotonic
// non-decreasing).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track_transfer.dart';
import 'package:proximity_music_app/domain/services/chunk_transport.dart';
import 'package:proximity_music_app/domain/services/integrity_verifier.dart';
import 'package:proximity_music_app/domain/services/payload_decryptor.dart';
import 'package:proximity_music_app/data/services/duplicate_track_detector.dart';
import 'package:proximity_music_app/data/services/track_receiver.dart';

/// Test double for IntegrityVerifier whose result is configurable per test.
class _StubIntegrityVerifier implements IntegrityVerifier {
  _StubIntegrityVerifier({required this.result});
  final bool result;
  int callCount = 0;
  @override
  bool verify(List<int> bytes, String expectedHex) {
    callCount++;
    return result;
  }
}

/// Test double for PayloadDecryptor whose decrypt result / failure is
/// configurable per test. encryptForTest is unused in receiver tests.
class _StubPayloadDecryptor implements PayloadDecryptor {
  _StubPayloadDecryptor({this.shouldThrow = false, this.plaintext});
  final bool shouldThrow;
  final List<int>? plaintext;
  int decryptCallCount = 0;

  @override
  Future<List<int>> decrypt({
    required List<int> ciphertext,
    required List<int> key,
    required List<int> nonce,
  }) async {
    decryptCallCount++;
    if (shouldThrow) {
      throw DecryptionFailure('stub: forced failure');
    }
    return plaintext ?? ciphertext;
  }

  @override
  Future<List<int>> encryptForTest({
    required List<int> plaintext,
    required List<int> key,
    required List<int> nonce,
  }) async {
    // Not used by TrackReceiver tests.
    return plaintext;
  }
}

/// In-memory PersistEncrypted callback that records invocations so we can
/// assert call counts (e.g. "never called" for aborted flows).
class _PersistRecorder {
  int callCount = 0;
  List<int>? lastCiphertext;
  TrackTransferManifest? lastManifest;

  Future<String> call(
    List<int> ciphertext,
    TrackTransferManifest manifest,
  ) async {
    callCount++;
    lastCiphertext = ciphertext;
    lastManifest = manifest;
    return '/tmp/${manifest.suggestedFileName}';
  }
}

/// Stub DuplicateTrackDetector with controllable isDuplicate result.
class _StubDuplicateDetector implements DuplicateTrackDetector {
  _StubDuplicateDetector({this.duplicate = false});
  bool duplicate;
  final Set<String> recorded = <String>{};

  @override
  bool isDuplicate(String sha256Hex) => duplicate;

  @override
  void record(String sha256Hex) {
    recorded.add(sha256Hex);
  }
}

TrackTransferManifest _manifest({
  int chunkCount = 2,
  int totalBytes = 8,
  String sha256Hex = 'deadbeef' * 8, // 64 hex chars (test-only fixture)
}) {
  return TrackTransferManifest(
    chunkCount: chunkCount,
    totalBytes: totalBytes,
    sha256Hex: sha256Hex,
    encryptionAlgo: 'AES-GCM-256',
    mimeType: 'audio/mpeg',
    suggestedFileName: 'song.mp3',
    title: 'Song A',
    artist: 'Alice',
  );
}

void main() {
  // Fixed dummy crypto material; TrackReceiver should pass these through to
  // PayloadDecryptor without interpretation.
  final key = List<int>.generate(32, (i) => i);
  final nonce = List<int>.generate(12, (i) => i);

  group('TrackReceiver', () {
    test('completed happy path: chunks assembled, verified, persisted', () async {
      final manifest = _manifest(chunkCount: 2, totalBytes: 8);
      final transport = FakeChunkTransport(chunks: [
        TrackChunk(
            sequence: 0, payload: const [1, 2, 3, 4], isLast: false),
        TrackChunk(
            sequence: 1, payload: const [5, 6, 7, 8], isLast: true),
      ]);
      final verifier = _StubIntegrityVerifier(result: true);
      final decryptor = _StubPayloadDecryptor();
      final detector = _StubDuplicateDetector(duplicate: false);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();

      expect(events, isNotEmpty);
      expect(events.last.status, TrackTransferStatus.completed);
      expect(persist.callCount, 1);
      expect(persist.lastCiphertext, [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(persist.lastManifest?.sha256Hex, manifest.sha256Hex);
    });

    test('integrity hash mismatch -> abortedIntegrity, persist not called',
        () async {
      final manifest = _manifest();
      final transport = FakeChunkTransport(chunks: [
        TrackChunk(
            sequence: 0, payload: const [1, 2, 3, 4], isLast: false),
        TrackChunk(
            sequence: 1, payload: const [5, 6, 7, 8], isLast: true),
      ]);
      final verifier = _StubIntegrityVerifier(result: false); // tamper detected
      final decryptor = _StubPayloadDecryptor();
      final detector = _StubDuplicateDetector(duplicate: false);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();

      // SC[6] / TP-26: abortedIntegrity identifier + PersistEncrypted never called.
      expect(events.last.status, TrackTransferStatus.abortedIntegrity);
      expect(persist.callCount, 0);
    });

    test('decrypt preflight failure (wrong cipher / key) -> abortedIntegrity',
        () async {
      final manifest = _manifest();
      final transport = FakeChunkTransport(chunks: [
        TrackChunk(
            sequence: 0, payload: const [1, 2, 3, 4], isLast: false),
        TrackChunk(
            sequence: 1, payload: const [5, 6, 7, 8], isLast: true),
      ]);
      final verifier = _StubIntegrityVerifier(result: true);
      final decryptor = _StubPayloadDecryptor(shouldThrow: true);
      final detector = _StubDuplicateDetector(duplicate: false);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();
      expect(events.last.status, TrackTransferStatus.abortedIntegrity);
      // Persistence MUST NOT happen if decrypt preflight fails.
      expect(persist.callCount, 0);
    });

    test('transport disconnect (addError) -> abortedDisconnected, '
        'persist not called', () async {
      final manifest = _manifest();
      // Build a transport that emits one chunk then errors mid-stream.
      final transport = FakeChunkTransport(
        chunks: [
          TrackChunk(
              sequence: 0, payload: const [1, 2, 3, 4], isLast: false),
        ],
        // Simulate network drop using Stream.addError on the underlying
        // controller (TP-25 (c) requires addError / Stream.error / throw).
        errorAfterChunks: StateError('peer disconnected'),
      );
      final verifier = _StubIntegrityVerifier(result: true);
      final decryptor = _StubPayloadDecryptor();
      final detector = _StubDuplicateDetector(duplicate: false);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();

      // SC[19] / TP-25: abortedDisconnected identifier + persist call count 0
      // + transport error mechanism (addError) used in this test body.
      expect(events.last.status, TrackTransferStatus.abortedDisconnected);
      expect(persist.callCount, 0);
    });

    test('isDuplicate=true -> abortedDuplicate, persist callCount equals 0',
        () async {
      final manifest = _manifest();
      final transport = FakeChunkTransport(chunks: [
        TrackChunk(
            sequence: 0, payload: const [1, 2, 3, 4], isLast: true),
      ]);
      final verifier = _StubIntegrityVerifier(result: true);
      final decryptor = _StubPayloadDecryptor();
      final detector = _StubDuplicateDetector(duplicate: true);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();
      expect(events.last.status, TrackTransferStatus.abortedDuplicate);
      // TP-24: PersistEncrypted callback must NOT be called when duplicate.
      expect(persist.callCount, equals(0));
    });

    test('progress emit: receivedBytes is monotonically non-decreasing',
        () async {
      final manifest = _manifest(chunkCount: 4, totalBytes: 16);
      final transport = FakeChunkTransport(chunks: [
        TrackChunk(
            sequence: 0, payload: const [1, 2, 3, 4], isLast: false),
        TrackChunk(
            sequence: 1, payload: const [5, 6, 7, 8], isLast: false),
        TrackChunk(
            sequence: 2, payload: const [9, 10, 11, 12], isLast: false),
        TrackChunk(
            sequence: 3, payload: const [13, 14, 15, 16], isLast: true),
      ]);
      final verifier = _StubIntegrityVerifier(result: true);
      final decryptor = _StubPayloadDecryptor();
      final detector = _StubDuplicateDetector(duplicate: false);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();
      final bytesTimeline =
          events.map((e) => e.receivedBytes).toList();

      // SC[20] / TP-27: bytes-based monotonic non-decreasing.
      // Use both an explicit pairwise check and greaterThanOrEqualTo to
      // satisfy TP-27's keyword requirement.
      for (var i = 1; i < bytesTimeline.length; i++) {
        expect(
          bytesTimeline[i],
          greaterThanOrEqualTo(bytesTimeline[i - 1]),
          reason: 'receivedBytes must be monotonic non-decreasing',
        );
      }
      // totalBytes consistency with manifest.
      expect(events.last.totalBytes, manifest.totalBytes);
      // Final receivedBytes reaches totalBytes on completed flow.
      expect(events.last.status, TrackTransferStatus.completed);
      expect(events.last.receivedBytes, greaterThanOrEqualTo(manifest.totalBytes));
    });

    test('out of order sequence -> abortedIntegrity', () async {
      final manifest = _manifest(chunkCount: 3, totalBytes: 12);
      // Sequence skips from 0 to 2 (missing 1).
      final transport = FakeChunkTransport(chunks: [
        TrackChunk(
            sequence: 0, payload: const [1, 2, 3, 4], isLast: false),
        TrackChunk(
            sequence: 2, payload: const [9, 10, 11, 12], isLast: true),
      ]);
      final verifier = _StubIntegrityVerifier(result: true);
      final decryptor = _StubPayloadDecryptor();
      final detector = _StubDuplicateDetector(duplicate: false);
      final persist = _PersistRecorder();

      final receiver = TrackReceiver(
        manifest: manifest,
        transport: transport,
        integrityVerifier: verifier,
        payloadDecryptor: decryptor,
        duplicateDetector: detector,
        persistEncrypted: persist.call,
        decryptionKey: key,
        decryptionNonce: nonce,
      );

      final events = await receiver.receive().toList();
      expect(events.last.status, TrackTransferStatus.abortedIntegrity);
      expect(persist.callCount, 0);
    });
  });
}

// Avoid analyzer warnings about unused import in the (unlikely) case that
// utf8 is not referenced inside other branches of this test file at a
// future revision. Keeping a no-op reference here is intentional.
// ignore: unused_element
void _utf8Ref() => utf8.encode('');

// Same defensive ignore for unused Completer import on dart:async — used
// implicitly by Stream APIs in the future GREEN.
// ignore: unused_element
Completer<void>? _completerRef;
