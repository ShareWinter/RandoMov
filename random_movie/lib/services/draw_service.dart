import 'package:random_movie/models/models.dart';

/// Result of a draw computation
class DrawResultData {
  final Movie selectedMovie;
  final int seed;
  final int index;

  DrawResultData({
    required this.selectedMovie,
    required this.seed,
    required this.index,
  });
}

/// Draw logic — pure static methods, no state
class DrawService {
  /// Solo mode: pick a random movie from candidates
  static DrawResultData soloRandom(List<Movie> candidates) {
    if (candidates.isEmpty) {
      throw ArgumentError('候选影片列表不能为空');
    }
    final seed = DateTime.now().microsecondsSinceEpoch;
    final index = seed % candidates.length;
    return DrawResultData(
      selectedMovie: candidates[index],
      seed: seed,
      index: index,
    );
  }

  /// Build a DrawRecord for solo mode
  static DrawRecord buildSoloRecord({
    required DrawResultData result,
    required int candidateCount,
    required String userId,
    required String userName,
  }) {
    return DrawRecord(
      id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
      mode: 'solo',
      roomCode: null,
      movieId: result.selectedMovie.id,
      movieTitle: result.selectedMovie.title,
      moviePoster: result.selectedMovie.poster,
      seed: result.seed,
      participants: [
        DrawParticipant(userId: userId, name: userName),
      ],
      candidateCount: candidateCount,
      drawnAt: DateTime.now(),
    );
  }

  // ==================== Room mode ====================

  /// Java-style string hashCode, consistent with server.js
  static int stringHashCode(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.codeUnitAt(i);
      hash &= 0xFFFFFFFF;
      if (hash > 0x7FFFFFFF) hash -= 0x100000000;
    }
    return hash;
  }

  /// Auto-generate a lucky number (1-99), matching server logic
  static int autoLuckyNumber(String userId, String roomCode) {
    return (stringHashCode(userId + roomCode) & 0x7FFFFFFF) % 99 + 1;
  }

  /// Room mode: reconstruct result from server-provided seed + candidates
  static DrawResultData roomRandom(List<Movie> candidates, int seed) {
    if (candidates.isEmpty) {
      throw ArgumentError('候选影片列表不能为空');
    }
    final index = seed % candidates.length;
    return DrawResultData(
      selectedMovie: candidates[index],
      seed: seed,
      index: index,
    );
  }

  /// Build a DrawRecord for room mode (saved to local history)
  static DrawRecord buildRoomRecord({
    required String roomCode,
    required DrawResult drawResult,
    required List<Participant> participants,
    required int candidateCount,
    String? moviePoster,
  }) {
    return DrawRecord(
      id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
      mode: 'room',
      roomCode: roomCode,
      movieId: drawResult.movieId,
      movieTitle: drawResult.movieTitle,
      moviePoster: moviePoster ?? '',
      seed: drawResult.seed,
      participants: participants
          .map((p) => DrawParticipant(
                userId: p.userId,
                name: p.name,
                luckyNumber: p.luckyNumber,
              ))
          .toList(),
      candidateCount: candidateCount,
      drawnAt: drawResult.drawnAt,
    );
  }
}
