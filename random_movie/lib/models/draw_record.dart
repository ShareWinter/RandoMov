/// Draw participant in a lottery session
class DrawParticipant {
  final String userId;
  final String name;
  final int? luckyNumber;

  DrawParticipant({
    required this.userId,
    required this.name,
    this.luckyNumber,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'luckyNumber': luckyNumber,
  };

  factory DrawParticipant.fromJson(Map<String, dynamic> json) =>
      DrawParticipant(
        userId: json['userId'] ?? '',
        name: json['name'] ?? '',
        luckyNumber: json['luckyNumber'],
      );
}

/// A single draw/lottery record, stored locally
class DrawRecord {
  final String id;
  final String mode; // 'solo' | 'room'
  final String? roomCode;
  final String movieId;
  final String movieTitle;
  final String moviePoster;
  final int seed;
  final List<DrawParticipant> participants;
  final int candidateCount;
  final DateTime drawnAt;

  DrawRecord({
    required this.id,
    required this.mode,
    this.roomCode,
    required this.movieId,
    required this.movieTitle,
    required this.moviePoster,
    required this.seed,
    required this.participants,
    required this.candidateCount,
    required this.drawnAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'roomCode': roomCode,
    'movieId': movieId,
    'movieTitle': movieTitle,
    'moviePoster': moviePoster,
    'seed': seed,
    'participants': participants.map((p) => p.toJson()).toList(),
    'candidateCount': candidateCount,
    'drawnAt': drawnAt.toIso8601String(),
  };

  factory DrawRecord.fromJson(Map<String, dynamic> json) => DrawRecord(
    id: json['id'] ?? '',
    mode: json['mode'] ?? 'solo',
    roomCode: json['roomCode'],
    movieId: json['movieId'] ?? '',
    movieTitle: json['movieTitle'] ?? '',
    moviePoster: json['moviePoster'] ?? '',
    seed: json['seed'] ?? 0,
    participants: (json['participants'] as List?)
        ?.map((p) => DrawParticipant.fromJson(p))
        .toList() ?? [],
    candidateCount: json['candidateCount'] ?? 0,
    drawnAt: json['drawnAt'] != null
        ? DateTime.parse(json['drawnAt'])
        : DateTime.now(),
  );
}
