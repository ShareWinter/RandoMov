/// 参与者模型
class Participant {
  final String userId;
  final String name;
  final bool isHost;
  final DateTime joinedAt;
  final int? luckyNumber;

  Participant({
    required this.userId,
    required this.name,
    this.isHost = false,
    DateTime? joinedAt,
    this.luckyNumber,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'isHost': isHost,
    'joinedAt': joinedAt.toIso8601String(),
    'luckyNumber': luckyNumber,
  };

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    userId: json['userId'] ?? '',
    name: json['name'] ?? '',
    isHost: json['isHost'] ?? false,
    joinedAt: json['joinedAt'] != null
        ? DateTime.parse(json['joinedAt'])
        : DateTime.now(),
    luckyNumber: json['luckyNumber'],
  );

  Participant copyWith({
    String? userId,
    String? name,
    bool? isHost,
    DateTime? joinedAt,
    int? luckyNumber,
  }) {
    return Participant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      joinedAt: joinedAt ?? this.joinedAt,
      luckyNumber: luckyNumber ?? this.luckyNumber,
    );
  }
}

/// 抽奖结果模型
class DrawResult {
  final String movieId;
  final String movieTitle;
  final DateTime drawnAt;
  final int seed;

  DrawResult({
    required this.movieId,
    required this.movieTitle,
    required this.drawnAt,
    required this.seed,
  });

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'movieTitle': movieTitle,
    'drawnAt': drawnAt.toIso8601String(),
    'seed': seed,
  };

  factory DrawResult.fromJson(Map<String, dynamic> json) => DrawResult(
    movieId: json['movieId'] ?? '',
    movieTitle: json['movieTitle'] ?? '',
    drawnAt: DateTime.parse(json['drawnAt']),
    seed: json['seed'] ?? 0,
  );
}

/// 房间模型
class Room {
  final String code;
  final String hostId;
  final List<Participant> participants;
  final List<String> selectedMovieIds;
  final String status; // 'waiting' | 'collecting' | 'drawing' | 'completed'
  final DrawResult? drawResult;
  final Map<String, dynamic>? moviesById;

  Room({
    required this.code,
    required this.hostId,
    this.participants = const [],
    this.selectedMovieIds = const [],
    this.status = 'waiting',
    this.drawResult,
    this.moviesById,
  });

  bool get isWaiting => status == 'waiting';
  bool get isCollecting => status == 'collecting';
  bool get isDrawing => status == 'drawing';
  bool get isCompleted => status == 'completed';

  bool isUserHost(String userId) => hostId == userId;

  Participant? getParticipant(String userId) {
    try {
      return participants.firstWhere((p) => p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'participants': participants.map((p) => p.toJson()).toList(),
    'selectedMovieIds': selectedMovieIds,
    'status': status,
    'drawResult': drawResult?.toJson(),
    'moviesById': moviesById,
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    code: json['code'] ?? '',
    hostId: json['hostId'] ?? '',
    participants: (json['participants'] as List?)
        ?.map((p) => Participant.fromJson(p))
        .toList() ?? [],
    selectedMovieIds: List<String>.from(json['selectedMovieIds'] ?? []),
    status: json['status'] ?? 'waiting',
    drawResult: json['drawResult'] != null
        ? DrawResult.fromJson(json['drawResult'])
        : null,
    moviesById: json['moviesById'] as Map<String, dynamic>?,
  );

  Room copyWith({
    String? code,
    String? hostId,
    List<Participant>? participants,
    List<String>? selectedMovieIds,
    String? status,
    DrawResult? drawResult,
    Map<String, dynamic>? moviesById,
  }) {
    return Room(
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      participants: participants ?? this.participants,
      selectedMovieIds: selectedMovieIds ?? this.selectedMovieIds,
      status: status ?? this.status,
      drawResult: drawResult ?? this.drawResult,
      moviesById: moviesById ?? this.moviesById,
    );
  }
}

/// 抽奖开始数据
class DrawStartData {
  final int seed;
  final List<dynamic> movies;

  DrawStartData({
    required this.seed,
    required this.movies,
  });

  factory DrawStartData.fromJson(Map<String, dynamic> json) => DrawStartData(
    seed: json['seed'] ?? 0,
    movies: json['movies'] ?? [],
  );
}
