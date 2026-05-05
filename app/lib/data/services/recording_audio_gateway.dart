// Data: RecordingAudioGateway
//
// Test-only AudioGateway that records every call into a `callLog` so widget
// tests can assert what the PlaybackController asked the audio backend to do
// without spinning up just_audio. Lives in the Data layer alongside the real
// AudioService implementation.

import 'package:proximity_music_app/domain/entities/track.dart';
import 'package:proximity_music_app/domain/playback/audio_gateway.dart';

class RecordingAudioGateway implements AudioGateway {
  RecordingAudioGateway();

  final List<String> callLog = <String>[];

  @override
  Future<void> play(Track track) async {
    callLog.add('play(${track.title})');
  }

  @override
  Future<void> stop() async {
    callLog.add('stop()');
  }
}
