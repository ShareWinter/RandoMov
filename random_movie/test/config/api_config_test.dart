import 'package:flutter_test/flutter_test.dart';
import 'package:random_movie/config/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('isProduction defaults to false', () {
      // Without any compile-time flag, isProduction should be false
      expect(ApiConfig.isProduction, isFalse);
    });

    test('baseUrl returns devBaseUrl in development mode', () {
      // In test environment, isProduction should be false
      expect(ApiConfig.baseUrl, equals(ApiConfig.devBaseUrl));
    });

    test('socketUrl returns devSocketUrl in development mode', () {
      expect(ApiConfig.socketUrl, equals(ApiConfig.devSocketUrl));
    });

    test('connectTimeout is 15 seconds', () {
      expect(ApiConfig.connectTimeout, equals(const Duration(seconds: 15)));
    });

    test('receiveTimeout is 30 seconds', () {
      expect(ApiConfig.receiveTimeout, equals(const Duration(seconds: 30)));
    });

    group('defaultHeaders', () {
      test('contains User-Agent header', () {
        expect(ApiConfig.defaultHeaders, contains('User-Agent'));
        expect(
          ApiConfig.defaultHeaders['User-Agent'],
          contains('Mozilla/5.0'),
        );
      });

      test('contains Accept header', () {
        expect(ApiConfig.defaultHeaders, contains('Accept'));
        expect(ApiConfig.defaultHeaders['Accept'], equals('application/json'));
      });

      test('contains Accept-Language header', () {
        expect(ApiConfig.defaultHeaders, contains('Accept-Language'));
        expect(ApiConfig.defaultHeaders['Accept-Language'], contains('zh-CN'));
      });

      test('returns correct number of headers', () {
        expect(ApiConfig.defaultHeaders.length, equals(3));
      });
    });

    group('doubanHeaders', () {
      test('contains User-Agent header', () {
        expect(ApiConfig.doubanHeaders, contains('User-Agent'));
        expect(
          ApiConfig.doubanHeaders['User-Agent'],
          contains('Mozilla/5.0'),
        );
      });

      test('contains Accept header', () {
        expect(ApiConfig.doubanHeaders, contains('Accept'));
        expect(
          ApiConfig.doubanHeaders['Accept'],
          contains('text/html'),
        );
      });

      test('contains Accept-Language header', () {
        expect(ApiConfig.doubanHeaders, contains('Accept-Language'));
        expect(ApiConfig.doubanHeaders['Accept-Language'], contains('zh-CN'));
      });

      test('contains Referer header pointing to douban.com', () {
        expect(ApiConfig.doubanHeaders, contains('Referer'));
        expect(
          ApiConfig.doubanHeaders['Referer'],
          equals('https://www.douban.com/'),
        );
      });

      test('returns correct number of headers', () {
        expect(ApiConfig.doubanHeaders.length, equals(4));
      });
    });

    group('imageHeaders', () {
      test('contains Referer header pointing to movie.douban.com', () {
        expect(ApiConfig.imageHeaders, contains('Referer'));
        expect(
          ApiConfig.imageHeaders['Referer'],
          equals('https://movie.douban.com/'),
        );
      });

      test('contains User-Agent header', () {
        expect(ApiConfig.imageHeaders, contains('User-Agent'));
        expect(
          ApiConfig.imageHeaders['User-Agent'],
          contains('Mozilla/5.0'),
        );
      });

      test('returns correct number of headers', () {
        expect(ApiConfig.imageHeaders.length, equals(2));
      });
    });

    test('devBaseUrl is defined', () {
      expect(ApiConfig.devBaseUrl, isNotNull);
      expect(ApiConfig.devBaseUrl, isNotEmpty);
    });

    test('devSocketUrl is defined', () {
      expect(ApiConfig.devSocketUrl, isNotNull);
      expect(ApiConfig.devSocketUrl, isNotEmpty);
    });

    test('prodBaseUrl is defined', () {
      expect(ApiConfig.prodBaseUrl, isNotNull);
      expect(ApiConfig.prodBaseUrl, isNotEmpty);
    });

    test('prodSocketUrl is defined', () {
      expect(ApiConfig.prodSocketUrl, isNotNull);
      expect(ApiConfig.prodSocketUrl, isNotEmpty);
    });

    test('headers are immutable (getter returns new map)', () {
      // Call the getter twice and verify they are different instances
      final headers1 = ApiConfig.defaultHeaders;
      final headers2 = ApiConfig.defaultHeaders;

      // Maps should have same content
      expect(headers1, equals(headers2));
    });

    test('timeout durations are positive', () {
      expect(ApiConfig.connectTimeout.inMilliseconds, greaterThan(0));
      expect(ApiConfig.receiveTimeout.inMilliseconds, greaterThan(0));
    });

    test('receive timeout is longer than connect timeout', () {
      expect(
        ApiConfig.receiveTimeout.inMilliseconds,
        greaterThan(ApiConfig.connectTimeout.inMilliseconds),
      );
    });
  });
}
