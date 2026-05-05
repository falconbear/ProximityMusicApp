// Domain service: ChunkTransport (abstract) + FakeChunkTransport.
//
// Pure Dart only. ChunkTransport is the transport-agnostic abstraction over
// the underlying P2P channel (Bluetooth / nearby / Platform Channels). The
// concrete implementations live outside this Issue's scope; here we provide
// FakeChunkTransport which emits a pre-baked List<TrackChunk> as a Stream so
// receiver-side logic can be tested without any platform plumbing.

import 'dart:async';

import 'package:proximity_music_app/domain/entities/track_transfer.dart';

abstract class ChunkTransport {
  /// Emits chunks in the order produced by the sender. The stream MAY emit an
  /// error before completion to model network failures (the receiver is
  /// expected to convert this into [TrackTransferStatus.abortedDisconnected]).
  Stream<TrackChunk> get stream;
}

class FakeChunkTransport implements ChunkTransport {
  FakeChunkTransport({
    required List<TrackChunk> chunks,
    Object? errorAfterChunks,
  }) : _chunks = List<TrackChunk>.unmodifiable(chunks),
       _errorAfterChunks = errorAfterChunks;

  final List<TrackChunk> _chunks;
  final Object? _errorAfterChunks;

  @override
  Stream<TrackChunk> get stream {
    final controller = StreamController<TrackChunk>();
    () async {
      try {
        for (final chunk in _chunks) {
          controller.add(chunk);
          // Yield to the event loop so listeners can observe each chunk.
          await Future<void>.delayed(Duration.zero);
        }
        if (_errorAfterChunks != null) {
          controller.addError(_errorAfterChunks);
        }
      } finally {
        await controller.close();
      }
    }();
    return controller.stream;
  }
}
