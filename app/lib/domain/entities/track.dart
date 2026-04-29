// Domain entity: Track
//
// Pure Dart only. Must NOT import flutter, flutter_riverpod, just_audio, or
// go_router (Domain layer is at the inner-most ring; presentation/data depend
// on it, not the other way around).

class Track {
  const Track({
    required this.title,
    required this.from,
    required this.filePath,
    this.duration,
  });

  final String title;
  final String from;
  final String filePath; // 音楽ファイルのパス
  final Duration? duration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Track &&
        other.title == title &&
        other.from == from &&
        other.filePath == filePath &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(title, from, filePath, duration);

  @override
  String toString() {
    return 'Track(title: $title, from: $from, filePath: $filePath, '
        'duration: $duration)';
  }
}
