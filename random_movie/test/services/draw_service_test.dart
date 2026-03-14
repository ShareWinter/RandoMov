import 'package:flutter_test/flutter_test.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/draw_service.dart';

void main() {
  group('DrawResultData', () {
    test('constructor creates draw result data', () {
      final movie = Movie(id: 'm1', title: 'Test Movie');
      final result = DrawResultData(
        selectedMovie: movie,
        seed: 12345,
        index: 2,
      );

      expect(result.selectedMovie, equals(movie));
      expect(result.seed, equals(12345));
      expect(result.index, equals(2));
    });
  });

  group('DrawService.soloRandom', () {
    test('throws ArgumentError for empty candidates', () {
      expect(
        () => DrawService.soloRandom([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns a movie from candidates', () {
      final candidates = [
        Movie(id: 'm1', title: 'Movie 1'),
        Movie(id: 'm2', title: 'Movie 2'),
        Movie(id: 'm3', title: 'Movie 3'),
      ];

      final result = DrawService.soloRandom(candidates);

      expect(candidates.contains(result.selectedMovie), isTrue);
      expect(result.seed, greaterThan(0));
      expect(result.index, inRange(0, candidates.length - 1));
    });

    test('returns correct index for single candidate', () {
      final candidates = [Movie(id: 'm1', title: 'Single Movie')];

      final result = DrawService.soloRandom(candidates);

      expect(result.selectedMovie.id, equals('m1'));
      expect(result.index, equals(0));
    });

    test('index is always within valid range', () {
      final candidates = List.generate(
        100,
        (i) => Movie(id: 'm$i', title: 'Movie $i'),
      );

      for (int i = 0; i < 100; i++) {
        final result = DrawService.soloRandom(candidates);
        expect(result.index, inRange(0, candidates.length - 1));
        expect(result.selectedMovie, isNotNull);
      }
    });

    test('seed is based on current time', () {
      final candidates = [
        Movie(id: 'm1', title: 'Movie 1'),
        Movie(id: 'm2', title: 'Movie 2'),
      ];

      final before = DateTime.now().microsecondsSinceEpoch;
      final result = DrawService.soloRandom(candidates);
      final after = DateTime.now().microsecondsSinceEpoch;

      expect(result.seed, greaterThanOrEqualTo(before));
      expect(result.seed, lessThanOrEqualTo(after));
    });
  });

  group('DrawService.buildSoloRecord', () {
    test('creates correct record for solo mode', () {
      final movie = Movie(
        id: 'movie_1',
        title: 'Test Movie',
        poster: 'https://example.com/poster.jpg',
      );
      final result = DrawResultData(
        selectedMovie: movie,
        seed: 12345,
        index: 0,
      );

      final record = DrawService.buildSoloRecord(
        result: result,
        candidateCount: 10,
        userId: 'user_1',
        userName: 'Test User',
      );

      expect(record.mode, equals('solo'));
      expect(record.roomCode, isNull);
      expect(record.movieId, equals('movie_1'));
      expect(record.movieTitle, equals('Test Movie'));
      expect(record.moviePoster, equals('https://example.com/poster.jpg'));
      expect(record.seed, equals(12345));
      expect(record.participants.length, equals(1));
      expect(record.participants[0].userId, equals('user_1'));
      expect(record.participants[0].name, equals('Test User'));
      expect(record.participants[0].luckyNumber, isNull);
      expect(record.candidateCount, equals(10));
    });

    test('generates unique id for each record', () {
      final movie = Movie(id: 'm1', title: 'Movie');
      final result = DrawResultData(
        selectedMovie: movie,
        seed: 100,
        index: 0,
      );

      final record1 = DrawService.buildSoloRecord(
        result: result,
        candidateCount: 5,
        userId: 'u1',
        userName: 'User 1',
      );

      // Small delay to ensure different timestamps
      Future.delayed(const Duration(milliseconds: 10));

      final record2 = DrawService.buildSoloRecord(
        result: result,
        candidateCount: 5,
        userId: 'u1',
        userName: 'User 1',
      );

      expect(record1.id, isNot(equals(record2.id)));
    });

    test('id starts with draw_ prefix', () {
      final movie = Movie(id: 'm1', title: 'Movie');
      final result = DrawResultData(
        selectedMovie: movie,
        seed: 100,
        index: 0,
      );

      final record = DrawService.buildSoloRecord(
        result: result,
        candidateCount: 5,
        userId: 'u1',
        userName: 'User 1',
      );

      expect(record.id.startsWith('draw_'), isTrue);
    });
  });

  group('DrawService.stringHashCode', () {
    test('returns 0 for empty string', () {
      expect(DrawService.stringHashCode(''), equals(0));
    });

    test('returns consistent hash for same input', () {
      final hash1 = DrawService.stringHashCode('test_string');
      final hash2 = DrawService.stringHashCode('test_string');

      expect(hash1, equals(hash2));
    });

    test('returns different hash for different inputs', () {
      final hash1 = DrawService.stringHashCode('user_1');
      final hash2 = DrawService.stringHashCode('user_2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('handles unicode characters', () {
      // Should not throw for unicode
      expect(() => DrawService.stringHashCode('中文测试'), returnsNormally);
      expect(() => DrawService.stringHashCode('🎉🎊'), returnsNormally);
    });

    test('matches Java-style hashCode behavior', () {
      // Test known values that match Java's String.hashCode()
      // Java: "abc".hashCode() = 96354
      expect(DrawService.stringHashCode('abc'), equals(96354));

      // Java: "hello".hashCode() = 99162322
      expect(DrawService.stringHashCode('hello'), equals(99162322));
    });

    test('handles long strings without overflow issues', () {
      final longString = 'a' * 10000;
      expect(() => DrawService.stringHashCode(longString), returnsNormally);
    });
  });

  group('DrawService.autoLuckyNumber', () {
    test('returns number between 1 and 99 inclusive', () {
      for (int i = 0; i < 100; i++) {
        final lucky = DrawService.autoLuckyNumber('user_$i', 'ROOM$i');
        expect(lucky, inInclusiveRange(1, 99));
      }
    });

    test('returns consistent lucky number for same inputs', () {
      final lucky1 = DrawService.autoLuckyNumber('user_123', 'ROOM456');
      final lucky2 = DrawService.autoLuckyNumber('user_123', 'ROOM456');

      expect(lucky1, equals(lucky2));
    });

    test('returns different lucky number for different users in same room', () {
      final lucky1 = DrawService.autoLuckyNumber('user_1', 'ROOM');
      final lucky2 = DrawService.autoLuckyNumber('user_2', 'ROOM');

      // Different users might have same lucky number by chance,
      // but we test multiple pairs to ensure variation
      var differentCount = 0;
      for (int i = 0; i < 20; i++) {
        final l1 = DrawService.autoLuckyNumber('user_$i', 'ROOM');
        final l2 = DrawService.autoLuckyNumber('user_${i + 100}', 'ROOM');
        if (l1 != l2) differentCount++;
      }
      expect(differentCount, greaterThan(0));
    });

    test('returns different lucky number for same user in different rooms', () {
      final lucky1 = DrawService.autoLuckyNumber('user_1', 'ROOM1');
      final lucky2 = DrawService.autoLuckyNumber('user_1', 'ROOM2');

      // Test multiple pairs to ensure variation
      var differentCount = 0;
      for (int i = 0; i < 20; i++) {
        final l1 = DrawService.autoLuckyNumber('user_1', 'ROOM_$i');
        final l2 = DrawService.autoLuckyNumber('user_1', 'ROOM_${i + 100}');
        if (l1 != l2) differentCount++;
      }
      expect(differentCount, greaterThan(0));
    });
  });

  group('DrawService.roomRandom', () {
    test('throws ArgumentError for empty candidates', () {
      expect(
        () => DrawService.roomRandom([], 12345),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns movie at correct index based on seed', () {
      final candidates = [
        Movie(id: 'm0', title: 'Movie 0'),
        Movie(id: 'm1', title: 'Movie 1'),
        Movie(id: 'm2', title: 'Movie 2'),
        Movie(id: 'm3', title: 'Movie 3'),
        Movie(id: 'm4', title: 'Movie 4'),
      ];

      // Test deterministic behavior
      final result0 = DrawService.roomRandom(candidates, 0);
      expect(result0.selectedMovie.id, equals('m0'));
      expect(result0.index, equals(0));

      final result1 = DrawService.roomRandom(candidates, 1);
      expect(result1.selectedMovie.id, equals('m1'));
      expect(result1.index, equals(1));

      final result5 = DrawService.roomRandom(candidates, 5);
      expect(result5.selectedMovie.id, equals('m0')); // 5 % 5 = 0
      expect(result5.index, equals(0));

      final result7 = DrawService.roomRandom(candidates, 7);
      expect(result7.selectedMovie.id, equals('m2')); // 7 % 5 = 2
      expect(result7.index, equals(2));
    });

    test('returns consistent result for same seed and candidates', () {
      final candidates = [
        Movie(id: 'm1', title: 'Movie 1'),
        Movie(id: 'm2', title: 'Movie 2'),
        Movie(id: 'm3', title: 'Movie 3'),
      ];

      final result1 = DrawService.roomRandom(candidates, 12345);
      final result2 = DrawService.roomRandom(candidates, 12345);

      expect(result1.selectedMovie.id, equals(result2.selectedMovie.id));
      expect(result1.seed, equals(result2.seed));
      expect(result1.index, equals(result2.index));
    });

    test('handles large seed values', () {
      final candidates = [
        Movie(id: 'm0', title: 'Movie 0'),
        Movie(id: 'm1', title: 'Movie 1'),
      ];

      final result = DrawService.roomRandom(candidates, 999999999);

      expect(result.index, inRange(0, 1));
      expect(result.selectedMovie, isNotNull);
    });

    test('handles single candidate', () {
      final candidates = [Movie(id: 'm1', title: 'Single Movie')];

      final result = DrawService.roomRandom(candidates, 12345);

      expect(result.selectedMovie.id, equals('m1'));
      expect(result.index, equals(0));
    });
  });

  group('DrawService.buildRoomRecord', () {
    test('creates correct record for room mode', () {
      final drawResult = DrawResult(
        movieId: 'movie_1',
        movieTitle: 'Test Movie',
        drawnAt: DateTime(2024, 1, 15, 10, 30),
        seed: 12345,
      );
      final participants = [
        Participant(userId: 'u1', name: 'User 1', luckyNumber: 42),
        Participant(userId: 'u2', name: 'User 2', luckyNumber: 88),
      ];

      final record = DrawService.buildRoomRecord(
        roomCode: 'ROOM01',
        drawResult: drawResult,
        participants: participants,
        candidateCount: 10,
        moviePoster: 'https://example.com/poster.jpg',
      );

      expect(record.mode, equals('room'));
      expect(record.roomCode, equals('ROOM01'));
      expect(record.movieId, equals('movie_1'));
      expect(record.movieTitle, equals('Test Movie'));
      expect(record.moviePoster, equals('https://example.com/poster.jpg'));
      expect(record.seed, equals(12345));
      expect(record.participants.length, equals(2));
      expect(record.participants[0].luckyNumber, equals(42));
      expect(record.participants[1].luckyNumber, equals(88));
      expect(record.candidateCount, equals(10));
      expect(record.drawnAt, equals(DateTime(2024, 1, 15, 10, 30)));
    });

    test('handles empty poster with default empty string', () {
      final drawResult = DrawResult(
        movieId: 'm1',
        movieTitle: 'Movie',
        drawnAt: DateTime.now(),
        seed: 100,
      );

      final record = DrawService.buildRoomRecord(
        roomCode: 'ROOM',
        drawResult: drawResult,
        participants: [],
        candidateCount: 5,
      );

      expect(record.moviePoster, equals(''));
    });

    test('copies participant data correctly', () {
      final drawResult = DrawResult(
        movieId: 'm1',
        movieTitle: 'Movie',
        drawnAt: DateTime.now(),
        seed: 1,
      );
      final participants = [
        Participant(
          userId: 'user_1',
          name: 'Host User',
          isHost: true,
          luckyNumber: 7,
        ),
        Participant(
          userId: 'user_2',
          name: 'Guest User',
          isHost: false,
          luckyNumber: 99,
        ),
      ];

      final record = DrawService.buildRoomRecord(
        roomCode: 'ROOM',
        drawResult: drawResult,
        participants: participants,
        candidateCount: 15,
      );

      // DrawParticipant should have userId, name, and luckyNumber
      expect(record.participants[0].userId, equals('user_1'));
      expect(record.participants[0].name, equals('Host User'));
      expect(record.participants[0].luckyNumber, equals(7));

      expect(record.participants[1].userId, equals('user_2'));
      expect(record.participants[1].name, equals('Guest User'));
      expect(record.participants[1].luckyNumber, equals(99));
    });

    test('handles empty participants list', () {
      final drawResult = DrawResult(
        movieId: 'm1',
        movieTitle: 'Movie',
        drawnAt: DateTime.now(),
        seed: 1,
      );

      final record = DrawService.buildRoomRecord(
        roomCode: 'ROOM',
        drawResult: drawResult,
        participants: [],
        candidateCount: 0,
      );

      expect(record.participants, isEmpty);
    });

    test('id starts with draw_ prefix', () {
      final drawResult = DrawResult(
        movieId: 'm1',
        movieTitle: 'Movie',
        drawnAt: DateTime.now(),
        seed: 1,
      );

      final record = DrawService.buildRoomRecord(
        roomCode: 'ROOM',
        drawResult: drawResult,
        participants: [],
        candidateCount: 5,
      );

      expect(record.id.startsWith('draw_'), isTrue);
    });
  });
}
