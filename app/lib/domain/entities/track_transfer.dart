// Domain entities for P2P track transfer.
//
// Pure Dart only. Must NOT import flutter / flutter_riverpod / just_audio /
// go_router. The Domain layer is the inner-most ring (data and presentation
// depend on it, not the other way around).
//
// Defined here:
//   - TrackTransferManifest: immutable header describing the track.
//   - TrackChunk: one byte-range slice of the encrypted payload.
//   - TrackTransferStatus: 8-state enum tracking the receive lifecycle.
//   - ReceiveProgress: stream event emitted by TrackReceiver.
//   - DecryptionFailure: thrown by PayloadDecryptor on cipher / key error.

class TrackTransferManifest {
  const TrackTransferManifest({
    required this.chunkCount,
    required this.totalBytes,
    required this.sha256Hex,
    required this.encryptionAlgo,
    required this.mimeType,
    required this.suggestedFileName,
    required this.title,
    required this.artist,
  });

  final int chunkCount;
  final int totalBytes;
  final String sha256Hex;
  final String encryptionAlgo;
  final String mimeType;
  final String suggestedFileName;
  final String title;
  final String artist;
}

class TrackChunk {
  const TrackChunk({
    required this.sequence,
    required this.payload,
    required this.isLast,
  });

  final int sequence;
  final List<int> payload;
  final bool isLast;
}

enum TrackTransferStatus {
  idle,
  receiving,
  verifying,
  decrypting,
  completed,
  abortedIntegrity,
  abortedDisconnected,
  abortedDuplicate,
}

/// Stream event emitted by TrackReceiver.receive(). bytes-based progress per
/// contract scope[8] / SC[20].
class ReceiveProgress {
  const ReceiveProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.status,
    this.error,
  });

  final int receivedBytes;
  final int totalBytes;
  final TrackTransferStatus status;
  final Object? error;
}

/// Exception thrown by PayloadDecryptor on cipher / key / nonce errors.
class DecryptionFailure implements Exception {
  const DecryptionFailure(this.message);
  final String message;

  @override
  String toString() => 'DecryptionFailure: $message';
}
