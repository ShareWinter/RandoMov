import 'package:flutter_test/flutter_test.dart';
import 'package:random_movie/models/models.dart';

void main() {
  group('Participant', () {
    test('constructor creates participant with required fields', () {
      final participant = Participant(
        userId: 'user_1',
        name: 'Test User',
      );

      expect(participant.userId, equals('user_1'));
      expect(participant.name, equals('Test User'));
      expect(participant.isHost, isFalse);
      expect(participant.luckyNumber, isNull);
    });

    test('constructor creates participant with all fields', () {
      final joinedAt = DateTime(2024, 1, 15, 10, 30);

      final participant = Participant(
        userId: 'user_2',
        name: 'Host User',
        isHost: true,
        joinedAt: joinedAt,
        luckyNumber: 42,
      );

      expect(participant.userId, equals('user_2'));
      expect(participant.name, equals('Host User'));
      expect(participant.isHost, isTrue);
      expect(participant.joinedAt, equals(joinedAt));
      expect(participant.luckyNumber, equals(42));
    });

    test('fromJson parses correctly', () {
      final json = {
        'userId': 'user_3',
        'name': 'JSON User',
        'isHost': true,
        'joinedAt': '2024-02-20T14:00:00.000',
        'luckyNumber': 99,
      };

      final participant = Participant.fromJson(json);

      expect(participant.userId, equals('user_3'));
      expect(participant.name, equals('JSON User'));
      expect(participant.isHost, isTrue);
      expect(participant.joinedAt, equals(DateTime(2024, 2, 20, 14, 0)));
      expect(participant.luckyNumber, equals(99));
    });

    test('fromJson handles missing fields with defaults', () {
      final participant = Participant.fromJson({});

      expect(participant.userId, equals(''));
      expect(participant.name, equals(''));
      expect(participant.isHost, isFalse);
      expect(participant.luckyNumber, isNull);
    });

    test('toJson produces correct output', () {
      final participant = Participant(
        userId: 'user_4',
        name: 'ToJson User',
        isHost: true,
        joinedAt: DateTime(2024, 3, 1, 12, 0),
        luckyNumber: 7,
      );

      final json = participant.toJson();

      expect(json['userId'], equals('user_4'));
      expect(json['name'], equals('ToJson User'));
      expect(json['isHost'], isTrue);
      expect(json['luckyNumber'], equals(7));
    });

    test('copyWith creates modified copy', () {
      final original = Participant(
        userId: 'user_5',
        name: 'Original',
        isHost: false,
        luckyNumber: 10,
      );

      final copy = original.copyWith(
        name: 'Modified',
        isHost: true,
        luckyNumber: 20,
      );

      expect(copy.userId, equals('user_5'));
      expect(copy.name, equals('Modified'));
      expect(copy.isHost, isTrue);
      expect(copy.luckyNumber, equals(20));
      // Original unchanged
      expect(original.name, equals('Original'));
      expect(original.isHost, isFalse);
    });

    test('toJson and fromJson round trip', () {
      final original = Participant(
        userId: 'user_round_trip',
        name: 'Round Trip User',
        isHost: true,
        joinedAt: DateTime(2024, 5, 10, 8, 30),
        luckyNumber: 88,
      );

      final json = original.toJson();
      final restored = Participant.fromJson(json);

      expect(restored.userId, equals(original.userId));
      expect(restored.name, equals(original.name));
      expect(restored.isHost, equals(original.isHost));
      expect(restored.joinedAt, equals(original.joinedAt));
      expect(restored.luckyNumber, equals(original.luckyNumber));
    });
  });

  group('DrawResult', () {
    test('constructor creates draw result', () {
      final drawnAt = DateTime(2024, 1, 15, 10, 30);

      final result = DrawResult(
        movieId: 'movie_1',
        movieTitle: 'Selected Movie',
        drawnAt: drawnAt,
        seed: 12345,
      );

      expect(result.movieId, equals('movie_1'));
      expect(result.movieTitle, equals('Selected Movie'));
      expect(result.drawnAt, equals(drawnAt));
      expect(result.seed, equals(12345));
    });

    test('fromJson parses correctly', () {
      final json = {
        'movieId': 'movie_2',
        'movieTitle': 'JSON Movie',
        'drawnAt': '2024-02-20T14:00:00.000',
        'seed': 67890,
      };

      final result = DrawResult.fromJson(json);

      expect(result.movieId, equals('movie_2'));
      expect(result.movieTitle, equals('JSON Movie'));
      expect(result.drawnAt, equals(DateTime(2024, 2, 20, 14, 0)));
      expect(result.seed, equals(67890));
    });

    test('fromJson handles missing fields with defaults', () {
      final result = DrawResult.fromJson({});

      expect(result.movieId, equals(''));
      expect(result.movieTitle, equals(''));
      expect(result.seed, equals(0));
    });

    test('toJson produces correct output', () {
      final result = DrawResult(
        movieId: 'movie_3',
        movieTitle: 'ToJson Movie',
        drawnAt: DateTime(2024, 3, 1, 12, 0),
        seed: 11111,
      );

      final json = result.toJson();

      expect(json['movieId'], equals('movie_3'));
      expect(json['movieTitle'], equals('ToJson Movie'));
      expect(json['seed'], equals(11111));
    });

    test('toJson and fromJson round trip', () {
      final original = DrawResult(
        movieId: 'movie_round_trip',
        movieTitle: 'Round Trip Movie',
        drawnAt: DateTime(2024, 5, 10, 8, 30),
        seed: 99999,
      );

      final json = original.toJson();
      final restored = DrawResult.fromJson(json);

      expect(restored.movieId, equals(original.movieId));
      expect(restored.movieTitle, equals(original.movieTitle));
      expect(restored.drawnAt, equals(original.drawnAt));
      expect(restored.seed, equals(original.seed));
    });
  });

  group('Room', () {
    test('constructor creates room with required fields', () {
      final room = Room(
        code: 'ROOM01',
        hostId: 'host_1',
      );

      expect(room.code, equals('ROOM01'));
      expect(room.hostId, equals('host_1'));
      expect(room.participants, isEmpty);
      expect(room.selectedMovieIds, isEmpty);
      expect(room.status, equals('waiting'));
      expect(room.drawResult, isNull);
      expect(room.moviesById, isNull);
    });

    test('constructor creates room with all fields', () {
      final participants = [
        Participant(userId: 'user_1', name: 'User 1', isHost: true),
        Participant(userId: 'user_2', name: 'User 2'),
      ];
      final drawResult = DrawResult(
        movieId: 'movie_1',
        movieTitle: 'Winner',
        drawnAt: DateTime.now(),
        seed: 123,
      );
      final moviesById = {
        'movie_1': {'title': 'Movie 1'},
        'movie_2': {'title': 'Movie 2'},
      };

      final room = Room(
        code: 'ROOM02',
        hostId: 'host_1',
        participants: participants,
        selectedMovieIds: ['movie_1', 'movie_2', 'movie_3'],
        status: 'completed',
        drawResult: drawResult,
        moviesById: moviesById,
      );

      expect(room.code, equals('ROOM02'));
      expect(room.hostId, equals('host_1'));
      expect(room.participants.length, equals(2));
      expect(room.selectedMovieIds.length, equals(3));
      expect(room.status, equals('completed'));
      expect(room.drawResult, isNotNull);
      expect(room.moviesById, isNotNull);
    });

    test('status getters work correctly', () {
      expect(Room(code: 'R1', hostId: 'h1', status: 'waiting').isWaiting, isTrue);
      expect(Room(code: 'R2', hostId: 'h1', status: 'waiting').isCollecting, isFalse);

      expect(Room(code: 'R3', hostId: 'h1', status: 'collecting').isCollecting, isTrue);
      expect(Room(code: 'R4', hostId: 'h1', status: 'collecting').isWaiting, isFalse);

      expect(Room(code: 'R5', hostId: 'h1', status: 'drawing').isDrawing, isTrue);
      expect(Room(code: 'R6', hostId: 'h1', status: 'drawing').isWaiting, isFalse);

      expect(Room(code: 'R7', hostId: 'h1', status: 'completed').isCompleted, isTrue);
      expect(Room(code: 'R8', hostId: 'h1', status: 'completed').isWaiting, isFalse);
    });

    test('isUserHost returns correct value', () {
      final room = Room(code: 'ROOM', hostId: 'host_123');

      expect(room.isUserHost('host_123'), isTrue);
      expect(room.isUserHost('other_user'), isFalse);
    });

    test('getParticipant returns correct participant', () {
      final participants = [
        Participant(userId: 'user_1', name: 'User 1'),
        Participant(userId: 'user_2', name: 'User 2'),
      ];

      final room = Room(
        code: 'ROOM',
        hostId: 'host_1',
        participants: participants,
      );

      final found = room.getParticipant('user_1');
      expect(found, isNotNull);
      expect(found!.name, equals('User 1'));

      final notFound = room.getParticipant('user_999');
      expect(notFound, isNull);
    });

    test('fromJson parses correctly', () {
      final json = {
        'code': 'JSON01',
        'hostId': 'host_json',
        'participants': [
          {'userId': 'user_1', 'name': 'User 1', 'isHost': true},
          {'userId': 'user_2', 'name': 'User 2', 'isHost': false},
        ],
        'selectedMovieIds': ['m1', 'm2'],
        'status': 'drawing',
        'drawResult': {
          'movieId': 'm1',
          'movieTitle': 'Winner Movie',
          'drawnAt': '2024-03-15T10:00:00.000',
          'seed': 555,
        },
        'moviesById': {'m1': {'title': 'Movie 1'}},
      };

      final room = Room.fromJson(json);

      expect(room.code, equals('JSON01'));
      expect(room.hostId, equals('host_json'));
      expect(room.participants.length, equals(2));
      expect(room.selectedMovieIds, equals(['m1', 'm2']));
      expect(room.status, equals('drawing'));
      expect(room.drawResult, isNotNull);
      expect(room.drawResult!.movieId, equals('m1'));
      expect(room.moviesById, isNotNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final room = Room.fromJson({});

      expect(room.code, equals(''));
      expect(room.hostId, equals(''));
      expect(room.participants, isEmpty);
      expect(room.selectedMovieIds, isEmpty);
      expect(room.status, equals('waiting'));
      expect(room.drawResult, isNull);
      expect(room.moviesById, isNull);
    });

    test('fromJson handles null participants list', () {
      final room = Room.fromJson({'participants': null});
      expect(room.participants, isEmpty);
    });

    test('toJson produces correct output', () {
      final room = Room(
        code: 'TOJSON',
        hostId: 'host_to',
        participants: [
          Participant(userId: 'u1', name: 'U1', isHost: true),
        ],
        selectedMovieIds: ['m1', 'm2'],
        status: 'collecting',
      );

      final json = room.toJson();

      expect(json['code'], equals('TOJSON'));
      expect(json['hostId'], equals('host_to'));
      expect(json['participants'], isA<List>());
      expect((json['participants'] as List).length, equals(1));
      expect(json['selectedMovieIds'], equals(['m1', 'm2']));
      expect(json['status'], equals('collecting'));
      expect(json['drawResult'], isNull);
    });

    test('copyWith creates modified copy', () {
      final original = Room(
        code: 'ORIGINAL',
        hostId: 'host_1',
        status: 'waiting',
        selectedMovieIds: ['m1'],
      );

      final copy = original.copyWith(
        status: 'collecting',
        selectedMovieIds: ['m1', 'm2', 'm3'],
      );

      expect(copy.code, equals('ORIGINAL'));
      expect(copy.hostId, equals('host_1'));
      expect(copy.status, equals('collecting'));
      expect(copy.selectedMovieIds.length, equals(3));
      // Original unchanged
      expect(original.status, equals('waiting'));
      expect(original.selectedMovieIds.length, equals(1));
    });

    test('toJson and fromJson round trip', () {
      final original = Room(
        code: 'ROUND_TRIP',
        hostId: 'host_rt',
        participants: [
          Participant(userId: 'u1', name: 'User 1', isHost: true, luckyNumber: 42),
          Participant(userId: 'u2', name: 'User 2', luckyNumber: 88),
        ],
        selectedMovieIds: ['movie_a', 'movie_b', 'movie_c'],
        status: 'completed',
        drawResult: DrawResult(
          movieId: 'movie_b',
          movieTitle: 'Winner Movie',
          drawnAt: DateTime(2024, 6, 15, 14, 30),
          seed: 77777,
        ),
        moviesById: {'movie_a': {'title': 'A'}, 'movie_b': {'title': 'B'}},
      );

      final json = original.toJson();
      final restored = Room.fromJson(json);

      expect(restored.code, equals(original.code));
      expect(restored.hostId, equals(original.hostId));
      expect(restored.participants.length, equals(original.participants.length));
      expect(restored.selectedMovieIds, equals(original.selectedMovieIds));
      expect(restored.status, equals(original.status));
      expect(restored.drawResult?.movieId, equals(original.drawResult?.movieId));
    });
  });

  group('DrawStartData', () {
    test('constructor creates draw start data', () {
      final data = DrawStartData(
        seed: 12345,
        movies: [
          {'id': 'm1', 'title': 'Movie 1'},
          {'id': 'm2', 'title': 'Movie 2'},
        ],
      );

      expect(data.seed, equals(12345));
      expect(data.movies.length, equals(2));
    });

    test('fromJson parses correctly', () {
      final json = {
        'seed': 67890,
        'movies': [
          {'id': 'm3', 'title': 'Movie 3'},
        ],
      };

      final data = DrawStartData.fromJson(json);

      expect(data.seed, equals(67890));
      expect(data.movies.length, equals(1));
    });

    test('fromJson handles missing fields with defaults', () {
      final data = DrawStartData.fromJson({});

      expect(data.seed, equals(0));
      expect(data.movies, isEmpty);
    });
  });
}
