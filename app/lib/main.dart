// Application entry point.
//
// Re-exports `app.dart` so that existing imports of
// `package:proximity_music_app/main.dart` (e.g. widget_test.dart) still
// resolve `ProximityMusicApp`.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:proximity_music_app/app.dart';

export 'package:proximity_music_app/app.dart' show ProximityMusicApp;

void main() {
  runApp(const ProviderScope(child: ProximityMusicApp()));
}
