// Domain: PlaybackTrackSource (abstract)
//
// One-way pipe: discovery / receive pipeline → PlaybackController. The Domain
// only needs a Stream<Track>; concrete implementations (FakeTrackSource for
// tests / DashboardPage simulation, real TrackReceiver in Issue #5) live
// outside this layer.

import 'package:proximity_music_app/domain/entities/track.dart';

abstract class PlaybackTrackSource {
  /// Stream of tracks ready for playback. Each event represents a fully
  /// received Track (decryption / integrity checks already passed by the
  /// upstream pipeline).
  Stream<Track> get tracks;
}
