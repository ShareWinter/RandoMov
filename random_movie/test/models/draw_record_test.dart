import 'package:flutter_test/flutter_test.dart';
import 'package:random_movie/models/models.dart';

void main() {
  group('DrawParticipant', () {
    test('constructor creates participant with required fields', () {
      final participant = DrawParticipant(
        userId: 'user_1',
        name: 'Test User',
      );

      expect(participant.userId, equals('user_1'));
      expect(participant.name, equals('Test User'));
      expect(participant.luckyNumber, isNull);
    });

    test('constructor creates participant with lucky number', () {
      final participant = DrawParticipant(
        userId: 'user_2',
        name: 'Lucky User',
        luckyNumber: 42,
      );

      expect(participant.luckyNumber, equals(42));
    });

    test('fromJson parses correctly', () {
      final json = {
        'userId': 'user_3',
        'name': 'JSON User',
        'luckyNumber': 99,
      };

      final participant = DrawParticipant.fromJson(json);

      expect(participant.userId, equals('user_3'));
      expect(participant.name, equals('JSON User'));
      expect(participant.luckyNumber, equals(99));
    });

    test('fromJson handles missing fields with defaults', () {
      final participant = DrawParticipant.fromJson({});

      expect(participant.userId, equals(''));
      expect(participant.name, equals(''));
      expect(participant.luckyNumber, isNull);
    });

    test('toJson produces correct output', () {
      final participant = DrawParticipant(
        userId: 'user_4',
        name: 'ToJson User',
        luckyNumber: 7,
      );

      final json = participant.toJson();

      expect(json['userId'], equals('user_4'));
      expect(json['name'], equals('ToJson User'));
      expect(json['luckyNumber'], equals(7));
    });

    test('toJson handles null luckyNumber', () {
      final participant = DrawParticipant(
        userId: 'user_5',
        name: 'No Lucky Number',
      );

      final json = participant.toJson();

      expect(json['luckyNumber'], isNull);
    });

    test('toJson and fromJson round trip', () {
      final original = DrawParticipant(
        userId: 'user_round_trip',
        name: 'Round Trip User',
        luckyNumber: 88,
      );

      final json = original.toJson();
      final restored = DrawParticipant.fromJson(json);

      expect(restored.userId, equals(original.userId));
      expect(restored.name, equals(original.name));
      expect(restored.luckyNumber, equals(original.luckyNumber));
    });
  });

  group('DrawRecord', () {
    test('constructor creates draw record with all fields', () {
      final drawnAt = DateTime(2024, 1, 15, 10, 30);
      final participants = [
        DrawParticipant(userId: 'u1', name: 'User 1', luckyNumber: 42),
        DrawParticipant(userId: 'u2', name: 'User 2', luckyNumber: 88),
      ];

      final record = DrawRecord(
        id: 'draw_1',
        mode: 'solo',
        roomCode: null,
        movieId: 'movie_1',
        movieTitle: 'Test Movie',
        moviePoster: 'https://example.com/poster.jpg',
        seed: 12345,
        participants: participants,
        candidateCount: 10,
        drawnAt: drawnAt,
      );

      expect(record.id, equals('draw_1'));
      expect(record.mode, equals('solo'));
      expect(record.roomCode, isNull);
      expect(record.movieId, equals('movie_1'));
      expect(record.movieTitle, equals('Test Movie'));
      expect(record.moviePoster, equals('https://example.com/poster.jpg'));
      expect(record.seed, equals(12345));
      expect(record.participants.length, equals(2));
      expect(record.candidateCount, equals(10));
      expect(record.drawnAt, equals(drawnAt));
    });

    test('constructor creates room mode draw record', () {
      final record = DrawRecord(
        id: 'draw_2',
        mode: 'room',
        roomCode: 'ROOM01',
        movieId: 'movie_2',
        movieTitle: 'Room Movie',
        moviePoster: 'poster_url',
        seed: 67890,
        participants: [],
        candidateCount: 5,
        drawnAt: DateTime.now(),
      );

      expect(record.mode, equals('room'));
      expect(record.roomCode, equals('ROOM01'));
    });

    test('fromJson parses solo mode record correctly', () {
      final json = {
        'id': 'draw_3',
        'mode': 'solo',
        'roomCode': null,
        'movieId': 'movie_3',
        'movieTitle': 'JSON Movie',
        'moviePoster': 'poster_url',
        'seed': 11111,
        'participants': [
          {'userId': 'u1', 'name': 'User 1', 'luckyNumber': 7},
        ],
        'candidateCount': 15,
        'drawnAt': '2024-02-20T14:00:00.000',
      };

      final record = DrawRecord.fromJson(json);

      expect(record.id, equals('draw_3'));
      expect(record.mode, equals('solo'));
      expect(record.roomCode, isNull);
      expect(record.movieId, equals('movie_3'));
      expect(record.movieTitle, equals('JSON Movie'));
      expect(record.moviePoster, equals('poster_url'));
      expect(record.seed, equals(11111));
      expect(record.participants.length, equals(1));
      expect(record.participants[0].luckyNumber, equals(7));
      expect(record.candidateCount, equals(15));
      expect(record.drawnAt, equals(DateTime(2024, 2, 20, 14, 0)));
    });

    test('fromJson parses room mode record correctly', () {
      final json = {
        'id': 'draw_4',
        'mode': 'room',
        'roomCode': 'ROOM02',
        'movieId': 'movie_4',
        'movieTitle': 'Room JSON Movie',
        'moviePoster': 'room_poster',
        'seed': 22222,
        'participants': [
          {'userId': 'u1', 'name': 'User 1', 'luckyNumber': 42},
          {'userId': 'u2', 'name': 'User 2', 'luckyNumber': 88},
        ],
        'candidateCount': 8,
        'drawnAt': '2024-03-15T10:30:00.000',
      };

      final record = DrawRecord.fromJson(json);

      expect(record.mode, equals('room'));
      expect(record.roomCode, equals('ROOM02'));
      expect(record.participants.length, equals(2));
    });

    test('fromJson handles missing fields with defaults', () {
      final record = DrawRecord.fromJson({});

      expect(record.id, equals(''));
      expect(record.mode, equals('solo'));
      expect(record.roomCode, isNull);
      expect(record.movieId, equals(''));
      expect(record.movieTitle, equals(''));
      expect(record.moviePoster, equals(''));
      expect(record.seed, equals(0));
      expect(record.participants, isEmpty);
      expect(record.candidateCount, equals(0));
    });

    test('fromJson handles null participants list', () {
      final record = DrawRecord.fromJson({'participants': null});
      expect(record.participants, isEmpty);
    });

    test('toJson produces correct output for solo mode', () {
      final record = DrawRecord(
        id: 'draw_5',
        mode: 'solo',
        roomCode: null,
        movieId: 'movie_5',
        movieTitle: 'ToJson Movie',
        moviePoster: 'tojson_poster',
        seed: 33333,
        participants: [
          DrawParticipant(userId: 'u1', name: 'User 1'),
        ],
        candidateCount: 20,
        drawnAt: DateTime(2024, 4, 1, 12, 0),
      );

      final json = record.toJson();

      expect(json['id'], equals('draw_5'));
      expect(json['mode'], equals('solo'));
      expect(json['roomCode'], isNull);
      expect(json['movieId'], equals('movie_5'));
      expect(json['movieTitle'], equals('ToJson Movie'));
      expect(json['moviePoster'], equals('tojson_poster'));
      expect(json['seed'], equals(33333));
      expect(json['participants'], isA<List>());
      expect((json['participants'] as List).length, equals(1));
      expect(json['candidateCount'], equals(20));
    });

    test('toJson produces correct output for room mode', () {
      final record = DrawRecord(
        id: 'draw_6',
        mode: 'room',
        roomCode: 'ROOM03',
        movieId: 'movie_6',
        movieTitle: 'Room ToJson',
        moviePoster: 'room_poster',
        seed: 44444,
        participants: [
          DrawParticipant(userId: 'u1', name: 'User 1', luckyNumber: 11),
          DrawParticipant(userId: 'u2', name: 'User 2', luckyNumber: 22),
        ],
        candidateCount: 12,
        drawnAt: DateTime(2024, 5, 15, 16, 30),
      );

      final json = record.toJson();

      expect(json['mode'], equals('room'));
      expect(json['roomCode'], equals('ROOM03'));
      expect((json['participants'] as List).length, equals(2));
    });

    test('toJson and fromJson round trip', () {
      final original = DrawRecord(
        id: 'draw_round_trip',
        mode: 'room',
        roomCode: 'ROOM_RT',
        movieId: 'movie_rt',
        movieTitle: 'Round Trip Movie',
        moviePoster: 'rt_poster',
        seed: 99999,
        participants: [
          DrawParticipant(userId: 'u1', name: 'User 1', luckyNumber: 42),
          DrawParticipant(userId: 'u2', name: 'User 2', luckyNumber: 88),
          DrawParticipant(userId: 'u3', name: 'User 3', luckyNumber: 15),
        ],
        candidateCount: 25,
        drawnAt: DateTime(2024, 6, 20, 9, 45),
      );

      final json = original.toJson();
      final restored = DrawRecord.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.mode, equals(original.mode));
      expect(restored.roomCode, equals(original.roomCode));
      expect(restored.movieId, equals(original.movieId));
      expect(restored.movieTitle, equals(original.movieTitle));
      expect(restored.moviePoster, equals(original.moviePoster));
      expect(restored.seed, equals(original.seed));
      expect(restored.participants.length, equals(original.participants.length));
      expect(restored.candidateCount, equals(original.candidateCount));
      expect(restored.drawnAt, equals(original.drawnAt));

      // Verify participant details
      expect(restored.participants[0].luckyNumber, equals(42));
      expect(restored.participants[1].luckyNumber, equals(88));
      expect(restored.participants[2].luckyNumber, equals(15));
    });
  });

  group('DrawHistory', () {
    test('constructor creates draw history with all fields', () {
      final drawnAt = DateTime(2024, 1, 15, 10, 30);

      final history = DrawHistory(
        id: 'history_1',
        roomCode: 'ROOM01',
        userName: 'Test User',
        movieId: 'movie_1',
        movieTitle: 'Test Movie',
        moviePoster: 'https://example.com/poster.jpg',
        movieYear: '2024',
        movieRating: 8.5,
        participants: 5,
        seed: 12345,
        drawnAt: drawnAt,
      );

      expect(history.id, equals('history_1'));
      expect(history.roomCode, equals('ROOM01'));
      expect(history.userName, equals('Test User'));
      expect(history.movieId, equals('movie_1'));
      expect(history.movieTitle, equals('Test Movie'));
      expect(history.moviePoster, equals('https://example.com/poster.jpg'));
      expect(history.movieYear, equals('2024'));
      expect(history.movieRating, equals(8.5));
      expect(history.participants, equals(5));
      expect(history.seed, equals(12345));
      expect(history.drawnAt, equals(drawnAt));
    });

    test('fromJson parses correctly with _id field', () {
      final json = {
        '_id': 'history_2',
        'roomCode': 'ROOM02',
        'userName': 'JSON User',
        'movieId': 'movie_2',
        'movieTitle': 'JSON Movie',
        'moviePoster': 'json_poster',
        'movieYear': '2023',
        'movieRating': 7.5,
        'participants': 3,
        'seed': 67890,
        'drawnAt': '2024-02-20T14:00:00.000',
      };

      final history = DrawHistory.fromJson(json);

      expect(history.id, equals('history_2'));
      expect(history.roomCode, equals('ROOM02'));
      expect(history.userName, equals('JSON User'));
      expect(history.movieId, equals('movie_2'));
      expect(history.movieTitle, equals('JSON Movie'));
      expect(history.moviePoster, equals('json_poster'));
      expect(history.movieYear, equals('2023'));
      expect(history.movieRating, equals(7.5));
      expect(history.participants, equals(3));
      expect(history.seed, equals(67890));
      expect(history.drawnAt, equals(DateTime(2024, 2, 20, 14, 0)));
    });

    test('fromJson uses id field as fallback', () {
      final history = DrawHistory.fromJson({'id': 'history_id'});
      expect(history.id, equals('history_id'));
    });

    test('fromJson handles missing fields with defaults', () {
      final history = DrawHistory.fromJson({});

      expect(history.id, equals(''));
      expect(history.roomCode, equals(''));
      expect(history.userName, equals(''));
      expect(history.movieId, equals(''));
      expect(history.movieTitle, equals(''));
      expect(history.moviePoster, equals(''));
      expect(history.movieYear, equals(''));
      expect(history.movieRating, equals(0));
      expect(history.participants, equals(0));
      expect(history.seed, equals(0));
    });

    test('fromJson handles integer rating conversion', () {
      final history = DrawHistory.fromJson({'movieRating': 8});
      expect(history.movieRating, equals(8.0));
    });

    test('toString returns formatted string', () {
      final history = DrawHistory(
        id: 'h1',
        roomCode: 'ROOM',
        userName: 'User',
        movieId: 'm1',
        movieTitle: 'Movie Title',
        moviePoster: '',
        movieYear: '2024',
        movieRating: 8.0,
        participants: 5,
        seed: 100,
        drawnAt: DateTime.now(),
      );

      expect(history.toString(), equals('DrawHistory(roomCode: ROOM, movieTitle: Movie Title)'));
    });
  });
}
