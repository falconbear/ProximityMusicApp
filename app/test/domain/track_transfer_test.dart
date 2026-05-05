// Domain unit tests for TrackTransferManifest / TrackChunk / TrackTransferStatus.
//
// TDD RED phase for Issue #5 (sprint-05: P2P track transfer).
// Targets the future Domain layer file
// `package:proximity_music_app/domain/entities/track_transfer.dart` which does
// not exist yet. Until the GREEN phase introduces these types, every test in
// this file MUST fail (compile error counts as failure under flutter_test).

import 'package:flutter_test/flutter_test.dart';

import 'package:proximity_music_app/domain/entities/track_transfer.dart';

void main() {
  group('TrackTransferManifest', () {
    test('constructor preserves all field values', () {
      const manifest = TrackTransferManifest(
        chunkCount: 4,
        totalBytes: 4096,
        sha256Hex:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        encryptionAlgo: 'AES-GCM-256',
        mimeType: 'audio/mpeg',
        suggestedFileName: 'song.mp3',
        title: 'Song A',
        artist: 'Alice',
      );

      expect(manifest.chunkCount, 4);
      expect(manifest.totalBytes, 4096);
      expect(
        manifest.sha256Hex,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(manifest.encryptionAlgo, 'AES-GCM-256');
      expect(manifest.mimeType, 'audio/mpeg');
      expect(manifest.suggestedFileName, 'song.mp3');
      expect(manifest.title, 'Song A');
      expect(manifest.artist, 'Alice');
    });
  });

  group('TrackChunk', () {
    test('preserves sequence, payload, and isLast', () {
      final chunk = TrackChunk(
        sequence: 0,
        payload: const [1, 2, 3, 4],
        isLast: false,
      );

      expect(chunk.sequence, 0);
      expect(chunk.payload, [1, 2, 3, 4]);
      expect(chunk.isLast, isFalse);

      final last = TrackChunk(
        sequence: 7,
        payload: const [9, 9],
        isLast: true,
      );
      expect(last.sequence, 7);
      expect(last.isLast, isTrue);
    });
  });

  group('TrackTransferStatus', () {
    test('enum contains all 8 states required by the contract', () {
      // The 8 status values defined in contract scope[2] / SC[3]:
      // idle, receiving, verifying, decrypting, completed,
      // abortedIntegrity, abortedDisconnected, abortedDuplicate
      const expected = <TrackTransferStatus>{
        TrackTransferStatus.idle,
        TrackTransferStatus.receiving,
        TrackTransferStatus.verifying,
        TrackTransferStatus.decrypting,
        TrackTransferStatus.completed,
        TrackTransferStatus.abortedIntegrity,
        TrackTransferStatus.abortedDisconnected,
        TrackTransferStatus.abortedDuplicate,
      };

      // All 8 unique status values must exist on the enum.
      expect(expected.length, 8);
      // Sanity: TrackTransferStatus.values must contain at least these 8.
      for (final s in expected) {
        expect(TrackTransferStatus.values, contains(s));
      }
    });
  });
}
