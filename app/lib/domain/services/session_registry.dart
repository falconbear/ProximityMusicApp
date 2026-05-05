// SessionRegistry — in-memory map of peerId -> Session.
//
// Pure Dart (no flutter / framework imports). De-duplicates by peerId; an
// upsert with a different myIdAtOpen replaces the existing entry. Used by
// SessionController to track active sessions and by SessionPage to render
// them. No persistence by design (spec.md feature 4: 永続的な個人識別子は持たない).

import 'package:proximity_music_app/domain/entities/session.dart';
import 'package:proximity_music_app/domain/entities/session_id.dart';
import 'package:proximity_music_app/domain/entities/session_status.dart';

class SessionRegistry {
  final Map<String, Session> _byPeerId = {};

  /// Insert or update a session. If a session for [s.peerId] already exists,
  /// the new entry replaces it (covering both same-myIdAtOpen status updates
  /// and myIdAtOpen-rotation replacements with identical semantics).
  void upsert(Session s) {
    _byPeerId[s.peerId] = s;
  }

  Session? sessionFor(String peerId) => _byPeerId[peerId];

  List<Session> get sessions => List.unmodifiable(_byPeerId.values);

  /// Mark every session whose myIdAtOpen != [currentId] as disconnected at
  /// [now]. Sessions opened with [currentId] are left untouched.
  void disconnectAllExcept(SessionId currentId, DateTime now) {
    _byPeerId.updateAll((_, s) {
      if (s.myIdAtOpen.value == currentId.value) return s;
      if (s.status == SessionStatus.disconnected) return s;
      return s.copyWith(
        status: SessionStatus.disconnected,
        updatedAt: now,
      );
    });
  }

  void remove(String peerId) {
    _byPeerId.remove(peerId);
  }
}
