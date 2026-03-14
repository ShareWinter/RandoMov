import 'package:flutter_test/flutter_test.dart';
import 'package:random_movie/models/models.dart';

void main() {
  group('MovieSubjectType', () {
    test('fromValue returns movie for null', () {
      expect(MovieSubjectType.fromValue(null), equals(MovieSubjectType.movie));
    });

    test('fromValue returns movie for "movie"', () {
      expect(
        MovieSubjectType.fromValue('movie'),
        equals(MovieSubjectType.movie),
      );
    });

    test('fromValue returns tvSeries for "tvSeries"', () {
      expect(
        MovieSubjectType.fromValue('tvSeries'),
        equals(MovieSubjectType.tvSeries),
      );
    });

    test('fromValue returns movie for unknown value', () {
      expect(
        MovieSubjectType.fromValue('unknown'),
        equals(MovieSubjectType.movie),
      );
    });

    test('value property returns correct string', () {
      expect(MovieSubjectType.movie.value, equals('movie'));
      expect(MovieSubjectType.tvSeries.value, equals('tvSeries'));
    });
  });

  group('MovieEpisode', () {
    test('constructor creates episode with default values', () {
      final episode = MovieEpisode(
        number: 1,
        label: 'Episode 1',
        doubanUrl: 'https://example.com',
      );

      expect(episode.number, equals(1));
      expect(episode.label, equals('Episode 1'));
      expect(episode.doubanUrl, equals('https://example.com'));
      expect(episode.watched, isFalse);
    });

    test('fromJson parses correctly with valid data', () {
      final json = {
        'number': 5,
        'label': '第5集',
        'doubanUrl': 'https://douban.com/episode/5',
        'watched': true,
      };

      final episode = MovieEpisode.fromJson(json);

      expect(episode.number, equals(5));
      expect(episode.label, equals('第5集'));
      expect(episode.doubanUrl, equals('https://douban.com/episode/5'));
      expect(episode.watched, isTrue);
    });

    test('fromJson handles missing fields with defaults', () {
      final episode = MovieEpisode.fromJson({});

      expect(episode.number, equals(0));
      expect(episode.label, equals(''));
      expect(episode.doubanUrl, equals(''));
      expect(episode.watched, isFalse);
    });

    test('fromJson handles watched as integer 1', () {
      final episode = MovieEpisode.fromJson({'watched': 1});
      expect(episode.watched, isTrue);
    });

    test('fromJson handles watched as string "1"', () {
      final episode = MovieEpisode.fromJson({'watched': '1'});
      expect(episode.watched, isTrue);
    });

    test('fromJson handles watched as string "true"', () {
      final episode = MovieEpisode.fromJson({'watched': 'true'});
      expect(episode.watched, isTrue);
    });

    test('fromJson handles watched as string "TRUE" (case insensitive)', () {
      final episode = MovieEpisode.fromJson({'watched': 'TRUE'});
      expect(episode.watched, isTrue);
    });

    test('fromJson handles watched as string "false"', () {
      final episode = MovieEpisode.fromJson({'watched': 'false'});
      expect(episode.watched, isFalse);
    });

    test('fromJson handles number as string', () {
      final episode = MovieEpisode.fromJson({'number': '10'});
      expect(episode.number, equals(10));
    });

    test('fromJson handles invalid number string', () {
      final episode = MovieEpisode.fromJson({'number': 'invalid'});
      expect(episode.number, equals(0));
    });

    test('toJson produces correct output', () {
      final episode = MovieEpisode(
        number: 3,
        label: 'Episode 3',
        doubanUrl: 'https://example.com/3',
        watched: true,
      );

      final json = episode.toJson();

      expect(json['number'], equals(3));
      expect(json['label'], equals('Episode 3'));
      expect(json['doubanUrl'], equals('https://example.com/3'));
      expect(json['watched'], isTrue);
    });

    test('copyWith creates a modified copy', () {
      final episode = MovieEpisode(
        number: 1,
        label: 'Episode 1',
        doubanUrl: 'https://example.com',
        watched: false,
      );

      final copy = episode.copyWith(watched: true, label: 'Updated');

      expect(copy.number, equals(1));
      expect(copy.label, equals('Updated'));
      expect(copy.doubanUrl, equals('https://example.com'));
      expect(copy.watched, isTrue);
      // Original unchanged
      expect(episode.watched, isFalse);
      expect(episode.label, equals('Episode 1'));
    });

    test('toJson and fromJson round trip', () {
      final original = MovieEpisode(
        number: 10,
        label: '第十集',
        doubanUrl: 'https://douban.com/ep10',
        watched: true,
      );

      final json = original.toJson();
      final restored = MovieEpisode.fromJson(json);

      expect(restored.number, equals(original.number));
      expect(restored.label, equals(original.label));
      expect(restored.doubanUrl, equals(original.doubanUrl));
      expect(restored.watched, equals(original.watched));
    });
  });

  group('Movie', () {
    test('constructor creates movie with required fields only', () {
      final movie = Movie(id: 'movie_1', title: 'Test Movie');

      expect(movie.id, equals('movie_1'));
      expect(movie.title, equals('Test Movie'));
      expect(movie.year, equals(''));
      expect(movie.director, equals(''));
      expect(movie.rating, equals(0));
      expect(movie.genre, isEmpty);
      expect(movie.watched, isFalse);
      expect(movie.subjectType, equals(MovieSubjectType.movie));
      expect(movie.episodes, isEmpty);
    });

    test('constructor creates movie with all fields', () {
      final watchedAt = DateTime(2024, 1, 15);
      final createdAt = DateTime(2024, 1, 1);

      final movie = Movie(
        id: 'movie_2',
        title: 'Complete Movie',
        year: '2024',
        director: 'Director Name',
        author: 'Writer Name',
        cast: 'Actor 1, Actor 2',
        rating: 8.5,
        genre: ['Drama', 'Thriller'],
        region: 'US',
        summary: 'A great movie summary.',
        publishedAt: '2024-01-01',
        durationText: '120分钟',
        poster: 'https://example.com/poster.jpg',
        doubanUrl: 'https://douban.com/123',
        subjectType: MovieSubjectType.tvSeries,
        episodes: [
          MovieEpisode(number: 1, label: 'Ep1', doubanUrl: 'url1'),
        ],
        watched: true,
        watchedAt: watchedAt,
        userRating: 9.0,
        userReview: 'Excellent!',
        createdAt: createdAt,
      );

      expect(movie.id, equals('movie_2'));
      expect(movie.title, equals('Complete Movie'));
      expect(movie.year, equals('2024'));
      expect(movie.director, equals('Director Name'));
      expect(movie.author, equals('Writer Name'));
      expect(movie.cast, equals('Actor 1, Actor 2'));
      expect(movie.rating, equals(8.5));
      expect(movie.genre, equals(['Drama', 'Thriller']));
      expect(movie.region, equals('US'));
      expect(movie.summary, equals('A great movie summary.'));
      expect(movie.publishedAt, equals('2024-01-01'));
      expect(movie.durationText, equals('120分钟'));
      expect(movie.poster, equals('https://example.com/poster.jpg'));
      expect(movie.doubanUrl, equals('https://douban.com/123'));
      expect(movie.subjectType, equals(MovieSubjectType.tvSeries));
      expect(movie.episodes.length, equals(1));
      expect(movie.watched, isTrue);
      expect(movie.watchedAt, equals(watchedAt));
      expect(movie.userRating, equals(9.0));
      expect(movie.userReview, equals('Excellent!'));
      expect(movie.createdAt, equals(createdAt));
    });

    test('proxiedPosterUrl returns empty string for empty poster', () {
      final movie = Movie(id: '1', title: 'Test', poster: '');
      expect(movie.proxiedPosterUrl, equals(''));
    });

    test('proxiedPosterUrl returns poster url for non-empty poster', () {
      final movie = Movie(
        id: '1',
        title: 'Test',
        poster: 'https://example.com/poster.jpg',
      );
      expect(movie.proxiedPosterUrl, equals('https://example.com/poster.jpg'));
    });

    test('fromJson parses correctly with all fields', () {
      final json = {
        'id': 'movie_3',
        'title': 'JSON Movie',
        'year': '2023',
        'director': 'Director',
        'author': 'Author',
        'cast': 'Cast',
        'rating': 7.5,
        'genre': ['Action', 'Adventure'],
        'region': 'CN',
        'summary': 'Summary text',
        'publishedAt': '2023-06-01',
        'durationText': '90分钟',
        'poster': 'poster_url',
        'doubanUrl': 'douban_url',
        'subjectType': 'tvSeries',
        'episodes': [
          {'number': 1, 'label': 'Ep1', 'doubanUrl': 'url1', 'watched': false}
        ],
        'watched': true,
        'watchedAt': '2024-01-15T10:30:00.000',
        'userRating': 8.0,
        'userReview': 'Good',
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final movie = Movie.fromJson(json);

      expect(movie.id, equals('movie_3'));
      expect(movie.title, equals('JSON Movie'));
      expect(movie.year, equals('2023'));
      expect(movie.director, equals('Director'));
      expect(movie.author, equals('Author'));
      expect(movie.cast, equals('Cast'));
      expect(movie.rating, equals(7.5));
      expect(movie.genre, equals(['Action', 'Adventure']));
      expect(movie.region, equals('CN'));
      expect(movie.summary, equals('Summary text'));
      expect(movie.publishedAt, equals('2023-06-01'));
      expect(movie.durationText, equals('90分钟'));
      expect(movie.poster, equals('poster_url'));
      expect(movie.doubanUrl, equals('douban_url'));
      expect(movie.subjectType, equals(MovieSubjectType.tvSeries));
      expect(movie.episodes.length, equals(1));
      expect(movie.watched, isTrue);
      expect(movie.watchedAt, equals(DateTime(2024, 1, 15, 10, 30)));
      expect(movie.userRating, equals(8.0));
      expect(movie.userReview, equals('Good'));
      expect(movie.createdAt, equals(DateTime(2024, 1, 1)));
    });

    test('fromJson handles _id field as fallback for id', () {
      final json = {'_id': 'mongo_id', 'title': 'Movie'};
      final movie = Movie.fromJson(json);
      expect(movie.id, equals('mongo_id'));
    });

    test('fromJson handles missing fields with defaults', () {
      final movie = Movie.fromJson({});

      expect(movie.id, equals(''));
      expect(movie.title, equals(''));
      expect(movie.year, equals(''));
      expect(movie.rating, equals(0));
      expect(movie.genre, isEmpty);
      expect(movie.subjectType, equals(MovieSubjectType.movie));
      expect(movie.episodes, isEmpty);
      expect(movie.watched, isFalse);
    });

    test('fromJson handles integer rating conversion', () {
      final movie = Movie.fromJson({'rating': 8});
      expect(movie.rating, equals(8.0));
    });

    test('toJson produces correct output', () {
      final movie = Movie(
        id: 'movie_4',
        title: 'ToJson Test',
        year: '2024',
        director: 'Director',
        author: 'Author',
        cast: 'Cast',
        rating: 9.0,
        genre: ['Sci-Fi'],
        region: 'US',
        summary: 'Summary',
        publishedAt: '2024-01-01',
        durationText: '150分钟',
        poster: 'poster',
        doubanUrl: 'douban',
        subjectType: MovieSubjectType.movie,
        episodes: [],
        watched: true,
        watchedAt: DateTime(2024, 1, 15),
        userRating: 8.5,
        userReview: 'Review',
        createdAt: DateTime(2024, 1, 1),
      );

      final json = movie.toJson();

      expect(json['id'], equals('movie_4'));
      expect(json['title'], equals('ToJson Test'));
      expect(json['year'], equals('2024'));
      expect(json['director'], equals('Director'));
      expect(json['author'], equals('Author'));
      expect(json['cast'], equals('Cast'));
      expect(json['rating'], equals(9.0));
      expect(json['genre'], equals(['Sci-Fi']));
      expect(json['region'], equals('US'));
      expect(json['summary'], equals('Summary'));
      expect(json['publishedAt'], equals('2024-01-01'));
      expect(json['durationText'], equals('150分钟'));
      expect(json['poster'], equals('poster'));
      expect(json['doubanUrl'], equals('douban'));
      expect(json['subjectType'], equals('movie'));
      expect(json['watched'], isTrue);
      expect(json['userRating'], equals(8.5));
      expect(json['userReview'], equals('Review'));
    });

    test('copyWith creates modified copy', () {
      final original = Movie(
        id: 'movie_5',
        title: 'Original',
        year: '2020',
        rating: 7.0,
        watched: false,
      );

      final copy = original.copyWith(
        title: 'Modified',
        rating: 8.5,
        watched: true,
      );

      expect(copy.id, equals('movie_5'));
      expect(copy.title, equals('Modified'));
      expect(copy.year, equals('2020')); // Unchanged
      expect(copy.rating, equals(8.5));
      expect(copy.watched, isTrue);
      // Original unchanged
      expect(original.title, equals('Original'));
      expect(original.rating, equals(7.0));
      expect(original.watched, isFalse);
    });

    test('copyWith clearWatchedAt clears watchedAt', () {
      final original = Movie(
        id: '1',
        title: 'Test',
        watchedAt: DateTime(2024, 1, 1),
      );

      final copy = original.copyWith(clearWatchedAt: true);

      expect(copy.watchedAt, isNull);
    });

    test('copyWith clearUserRating clears userRating', () {
      final original = Movie(id: '1', title: 'Test', userRating: 8.0);

      final copy = original.copyWith(clearUserRating: true);

      expect(copy.userRating, isNull);
    });

    test('copyWith clearUserReview clears userReview', () {
      final original = Movie(id: '1', title: 'Test', userReview: 'Review');

      final copy = original.copyWith(clearUserReview: true);

      expect(copy.userReview, isNull);
    });

    test('toJson and fromJson round trip', () {
      final original = Movie(
        id: 'movie_round_trip',
        title: 'Round Trip Test',
        year: '2024',
        director: 'Director',
        author: 'Author',
        cast: 'Actor1, Actor2',
        rating: 8.5,
        genre: ['Drama', 'Mystery'],
        region: 'KR',
        summary: 'A mysterious drama.',
        publishedAt: '2024-03-15',
        durationText: '110分钟',
        poster: 'https://example.com/poster.jpg',
        doubanUrl: 'https://douban.com/subject/123',
        subjectType: MovieSubjectType.tvSeries,
        episodes: [
          MovieEpisode(number: 1, label: 'Ep1', doubanUrl: 'url1', watched: true),
          MovieEpisode(number: 2, label: 'Ep2', doubanUrl: 'url2', watched: false),
        ],
        watched: true,
        watchedAt: DateTime(2024, 3, 20, 15, 30),
        userRating: 9.0,
        userReview: '非常好!',
        createdAt: DateTime(2024, 3, 1, 10, 0),
      );

      final json = original.toJson();
      final restored = Movie.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.year, equals(original.year));
      expect(restored.director, equals(original.director));
      expect(restored.author, equals(original.author));
      expect(restored.cast, equals(original.cast));
      expect(restored.rating, equals(original.rating));
      expect(restored.genre, equals(original.genre));
      expect(restored.region, equals(original.region));
      expect(restored.summary, equals(original.summary));
      expect(restored.publishedAt, equals(original.publishedAt));
      expect(restored.durationText, equals(original.durationText));
      expect(restored.poster, equals(original.poster));
      expect(restored.doubanUrl, equals(original.doubanUrl));
      expect(restored.subjectType, equals(original.subjectType));
      expect(restored.episodes.length, equals(original.episodes.length));
      expect(restored.watched, equals(original.watched));
      expect(restored.userRating, equals(original.userRating));
      expect(restored.userReview, equals(original.userReview));
    });

    test('toString returns formatted string', () {
      final movie = Movie(id: 'movie_123', title: 'Test Movie', year: '2024');
      expect(movie.toString(), equals('Movie(id: movie_123, title: Test Movie, year: 2024)'));
    });
  });
}
