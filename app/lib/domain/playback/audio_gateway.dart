// Domain: AudioGateway (abstract)
//
// Minimal port that PlaybackController uses to actually emit sound. Keeps
// just_audio (and any other concrete audio backend) out of the Domain layer
// so the Controller can be unit-tested with a Fake.

import 'package:proximity_music_app/domain/entities/track.dart';

abstract class AudioGateway {
  /// Begin playing [track]. Implementations should be idempotent enough that
  /// calling [play] while another track is already playing simply replaces the
  /// current source.
  Future<void> play(Track track);

  /// Stop playback. After this completes, no track should be audible.
  Future<void> stop();
}
