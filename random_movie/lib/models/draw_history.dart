/// 抽奖历史模型
class DrawHistory {
  final String id;
  final String roomCode;
  final String userName;
  final String movieId;
  final String movieTitle;
  final String moviePoster;
  final String movieYear;
  final double movieRating;
  final int participants;
  final int seed;
  final DateTime drawnAt;

  DrawHistory({
    required this.id,
    required this.roomCode,
    required this.userName,
    required this.movieId,
    required this.movieTitle,
    required this.moviePoster,
    required this.movieYear,
    required this.movieRating,
    required this.participants,
    required this.seed,
    required this.drawnAt,
  });

  factory DrawHistory.fromJson(Map<String, dynamic> json) => DrawHistory(
    id: json['_id'] ?? json['id'] ?? '',
    roomCode: json['roomCode'] ?? '',
    userName: json['userName'] ?? '',
    movieId: json['movieId'] ?? '',
    movieTitle: json['movieTitle'] ?? '',
    moviePoster: json['moviePoster'] ?? '',
    movieYear: json['movieYear'] ?? '',
    movieRating: (json['movieRating'] ?? 0).toDouble(),
    participants: json['participants'] ?? 0,
    seed: json['seed'] ?? 0,
    drawnAt: json['drawnAt'] != null
        ? DateTime.parse(json['drawnAt'])
        : DateTime.now(),
  );

  @override
  String toString() => 'DrawHistory(roomCode: $roomCode, movieTitle: $movieTitle)';
}
