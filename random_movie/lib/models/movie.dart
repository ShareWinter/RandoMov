/// 影片模型
class Movie {
  final String id;
  final String title;
  final String year;
  final String director;
  final String cast;
  final double rating;
  final List<String> genre;
  final String region;
  final String poster;
  final String doubanUrl;
  final bool watched;
  final DateTime? watchedAt;
  final double? userRating;
  final String? userReview;
  final DateTime createdAt;

  Movie({
    required this.id,
    required this.title,
    this.year = '',
    this.director = '',
    this.cast = '',
    this.rating = 0,
    this.genre = const [],
    this.region = '',
    this.poster = '',
    this.doubanUrl = '',
    this.watched = false,
    this.watchedAt,
    this.userRating,
    this.userReview,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 获取代理后的海报URL
  String get proxiedPosterUrl {
    if (poster.isEmpty) return '';
    return poster;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'year': year,
    'director': director,
    'cast': cast,
    'rating': rating,
    'genre': genre,
    'region': region,
    'poster': poster,
    'doubanUrl': doubanUrl,
    'watched': watched,
    'watchedAt': watchedAt?.toIso8601String(),
    'userRating': userRating,
    'userReview': userReview,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
    id: json['id'] ?? json['_id'] ?? '',
    title: json['title'] ?? '',
    year: json['year'] ?? '',
    director: json['director'] ?? '',
    cast: json['cast'] ?? '',
    rating: (json['rating'] ?? 0).toDouble(),
    genre: List<String>.from(json['genre'] ?? []),
    region: json['region'] ?? '',
    poster: json['poster'] ?? '',
    doubanUrl: json['doubanUrl'] ?? '',
    watched: json['watched'] ?? false,
    watchedAt: json['watchedAt'] != null
        ? DateTime.parse(json['watchedAt'])
        : null,
    userRating: json['userRating']?.toDouble(),
    userReview: json['userReview'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );

  Movie copyWith({
    String? id,
    String? title,
    String? year,
    String? director,
    String? cast,
    double? rating,
    List<String>? genre,
    String? region,
    String? poster,
    String? doubanUrl,
    bool? watched,
    DateTime? watchedAt,
    bool clearWatchedAt = false,
    double? userRating,
    bool clearUserRating = false,
    String? userReview,
    bool clearUserReview = false,
    DateTime? createdAt,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      director: director ?? this.director,
      cast: cast ?? this.cast,
      rating: rating ?? this.rating,
      genre: genre ?? this.genre,
      region: region ?? this.region,
      poster: poster ?? this.poster,
      doubanUrl: doubanUrl ?? this.doubanUrl,
      watched: watched ?? this.watched,
      watchedAt: clearWatchedAt ? null : (watchedAt ?? this.watchedAt),
      userRating: clearUserRating ? null : (userRating ?? this.userRating),
      userReview: clearUserReview ? null : (userReview ?? this.userReview),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Movie(id: $id, title: $title, year: $year)';
}
