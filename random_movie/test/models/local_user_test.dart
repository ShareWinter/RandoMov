import 'package:flutter_test/flutter_test.dart';
import 'package:random_movie/models/models.dart';

void main() {
  group('LocalUser', () {
    test('constructor creates user with required fields', () {
      final user = LocalUser(
        id: 'user_123',
        name: 'Test User',
      );

      expect(user.id, equals('user_123'));
      expect(user.name, equals('Test User'));
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'user_456',
        'name': 'JSON User',
      };

      final user = LocalUser.fromJson(json);

      expect(user.id, equals('user_456'));
      expect(user.name, equals('JSON User'));
    });

    test('fromJson handles missing fields with defaults', () {
      final user = LocalUser.fromJson({});

      expect(user.id, equals(''));
      expect(user.name, equals(''));
    });

    test('toJson produces correct output', () {
      final user = LocalUser(
        id: 'user_789',
        name: 'ToJson User',
      );

      final json = user.toJson();

      expect(json['id'], equals('user_789'));
      expect(json['name'], equals('ToJson User'));
    });

    test('copyWith creates modified copy', () {
      final original = LocalUser(
        id: 'user_original',
        name: 'Original Name',
      );

      final copy = original.copyWith(name: 'Modified Name');

      expect(copy.id, equals('user_original'));
      expect(copy.name, equals('Modified Name'));
      // Original unchanged
      expect(original.name, equals('Original Name'));
    });

    test('copyWith can modify both fields', () {
      final original = LocalUser(
        id: 'user_1',
        name: 'Name 1',
      );

      final copy = original.copyWith(
        id: 'user_2',
        name: 'Name 2',
      );

      expect(copy.id, equals('user_2'));
      expect(copy.name, equals('Name 2'));
    });

    test('toJson and fromJson round trip', () {
      final original = LocalUser(
        id: 'user_round_trip',
        name: 'Round Trip User',
      );

      final json = original.toJson();
      final restored = LocalUser.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
    });

    test('toString returns formatted string', () {
      final user = LocalUser(id: 'user_123', name: 'Test User');
      expect(user.toString(), equals('LocalUser(id: user_123, name: Test User)'));
    });

    test('handles empty string values', () {
      final user = LocalUser(id: '', name: '');

      expect(user.id, equals(''));
      expect(user.name, equals(''));
    });

    test('handles special characters in name', () {
      final user = LocalUser(
        id: 'user_special',
        name: '用户 🎉 Test',
      );

      expect(user.name, equals('用户 🎉 Test'));

      final json = user.toJson();
      final restored = LocalUser.fromJson(json);
      expect(restored.name, equals('用户 🎉 Test'));
    });
  });
}
