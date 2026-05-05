// Data service: TrackReceiver. Orchestrates the receive-side P2P pipeline:
//   1. Duplicate guard (DuplicateTrackDetector.isDuplicate).
//   2. Subscribe to ChunkTransport.stream and assemble bytes in sequence.
//      - Out-of-order sequence -> abortedIntegrity.
//      - Stream onError -> abortedDisconnected.
//   3. Verify SHA-256 of assembled ciphertext (IntegrityVerifier.verify).
//   4. Preflight decrypt (PayloadDecryptor.decrypt) — only the validity of the
//      cipher / key combination is checked here; the plaintext is discarded.
//      A failure is treated as abortedIntegrity (per contract scope[5]).
//   5. Persist the *encrypted* payload via the [PersistEncrypted] callback;
//      decryption at playback time is the next Issue's responsibility
//      (contract out_of_scope[6]).
//
// Pure Dart only. No flutter / go_router imports (Data layer rule).

import 'package:proximity_music_app/data/services/duplicate_track_detector.dart';
import 'package:proximity_music_app/domain/entities/track_transfer.dart';
import 'package:proximity_music_app/domain/services/chunk_transport.dart';
import 'package:proximity_music_app/domain/services/integrity_verifier.dart';
import 'package:proximity_music_app/domain/services/payload_decryptor.dart';

/// Callback signature for persisting the received (still-encrypted) payload.
/// Returns the path the file was written to; the caller decides storage policy
/// (see contract scope[5] / out_of_scope[5]).
typedef PersistEncrypted = Future<String> Function(
  List<int> ciphertext,
  TrackTransferManifest manifest,
);

class TrackReceiver {
  TrackReceiver({
    required this.manifest,
    required this.transport,
    required this.integrityVerifier,
    required this.payloadDecryptor,
    required this.duplicateDetector,
    required this.persistEncrypted,
    required this.decryptionKey,
    required this.decryptionNonce,
  });

  final TrackTransferManifest manifest;
  final ChunkTransport transport;
  final IntegrityVerifier integrityVerifier;
  final PayloadDecryptor payloadDecryptor;
  final DuplicateTrackDetector duplicateDetector;
  final PersistEncrypted persistEncrypted;
  final List<int> decryptionKey;
  final List<int> decryptionNonce;

  /// Drives the receive pipeline and emits a [ReceiveProgress] event for every
  /// observable state change (per contract scope[8]).
  Stream<ReceiveProgress> receive() async* {
    // Step 1: duplicate guard (before subscribing to the transport).
    if (duplicateDetector.isDuplicate(manifest.sha256Hex)) {
      yield ReceiveProgress(
        receivedBytes: 0,
        totalBytes: manifest.totalBytes,
        status: TrackTransferStatus.abortedDuplicate,
      );
      return;
    }

    // Step 2: subscribe to the transport and assemble in sequence order.
    final assembled = <int>[];
    var receivedBytes = 0;
    var nextSequence = 0;
    var transportFailed = false;
    Object? transportError;

    yield ReceiveProgress(
      receivedBytes: 0,
      totalBytes: manifest.totalBytes,
      status: TrackTransferStatus.receiving,
    );

    try {
      await for (final chunk in transport.stream) {
        if (chunk.sequence != nextSequence) {
          // Out-of-order -> abortedIntegrity.
          yield ReceiveProgress(
            receivedBytes: receivedBytes,
            totalBytes: manifest.totalBytes,
            status: TrackTransferStatus.abortedIntegrity,
            error: StateError(
              'unexpected sequence ${chunk.sequence}, expected $nextSequence',
            ),
          );
          return;
        }
        assembled.addAll(chunk.payload);
        receivedBytes += chunk.payload.length;
        nextSequence++;
        yield ReceiveProgress(
          receivedBytes: receivedBytes,
          totalBytes: manifest.totalBytes,
          status: TrackTransferStatus.receiving,
        );
      }
    } catch (e) {
      transportFailed = true;
      transportError = e;
    }

    if (transportFailed) {
      yield ReceiveProgress(
        receivedBytes: receivedBytes,
        totalBytes: manifest.totalBytes,
        status: TrackTransferStatus.abortedDisconnected,
        error: transportError,
      );
      return;
    }

    // Step 3: integrity verification on the assembled ciphertext.
    yield ReceiveProgress(
      receivedBytes: receivedBytes,
      totalBytes: manifest.totalBytes,
      status: TrackTransferStatus.verifying,
    );
    final verified =
        integrityVerifier.verify(assembled, manifest.sha256Hex);
    if (!verified) {
      yield ReceiveProgress(
        receivedBytes: receivedBytes,
        totalBytes: manifest.totalBytes,
        status: TrackTransferStatus.abortedIntegrity,
      );
      return;
    }

    // Step 4: preflight decrypt. We discard the plaintext; only failure matters.
    yield ReceiveProgress(
      receivedBytes: receivedBytes,
      totalBytes: manifest.totalBytes,
      status: TrackTransferStatus.decrypting,
    );
    try {
      await payloadDecryptor.decrypt(
        ciphertext: assembled,
        key: decryptionKey,
        nonce: decryptionNonce,
      );
    } catch (_) {
      // Preflight failure is reported as abortedIntegrity per contract scope[5].
      yield ReceiveProgress(
        receivedBytes: receivedBytes,
        totalBytes: manifest.totalBytes,
        status: TrackTransferStatus.abortedIntegrity,
      );
      return;
    }

    // Step 5: persist the encrypted payload, then mark completed.
    await persistEncrypted(assembled, manifest);
    duplicateDetector.record(manifest.sha256Hex);

    yield ReceiveProgress(
      receivedBytes: receivedBytes,
      totalBytes: manifest.totalBytes,
      status: TrackTransferStatus.completed,
    );
  }
}
