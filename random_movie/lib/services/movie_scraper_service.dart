import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/models/movie.dart';

class DoulistScrapeProgress {
  final int total;
  final int completed;
  final String? currentTitle;
  final List<Movie> movies;

  const DoulistScrapeProgress({
    required this.total,
    required this.completed,
    this.currentTitle,
    this.movies = const [],
  });

  double? get progress {
    if (total <= 0) return null;
    final safeCompleted = completed < 0
        ? 0
        : (completed > total ? total : completed);
    return safeCompleted / total;
  }
}

/// 影片爬取服务
class MovieScraperService {
  final Dio _dio;
  final _CookieJarLite _doubanCookieJar = _CookieJarLite();

  MovieScraperService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ),
      );

  /// 爬取单个影片（直接解析豆瓣页面）
  Future<Movie> scrapeMovie(String doubanUrl) async {
    final normalizedUrl = _validateDoubanMovieUrl(doubanUrl);

    try {
      final page = await _fetchMoviePage(normalizedUrl);
      final ldJsonText = _extractLdJson(page.html);
      final ldJson = _parseLdJson(ldJsonText);
      return _buildMovieFromPage(
        requestUrl: normalizedUrl,
        finalUrl: page.finalUrl,
        html: page.html,
        ldJson: ldJson,
      );
    } on ScraperException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw ScraperException('请求超时，请稍后重试');
      }
      throw ScraperException('获取影片信息失败: ${error.message}');
    } catch (error) {
      throw ScraperException('爬取失败: $error');
    }
  }

  /// 爬取片单（解析片单页 -> 并发用单片抓取详情）
  Future<List<Movie>> scrapeDoulist(
    String doulistUrl, {
    void Function(DoulistScrapeProgress progress)? onProgress,
  }) async {
    try {
      if (!doulistUrl.contains('douban.com/doulist/')) {
        throw ScraperException('无效的豆瓣片单链接');
      }

      final response = await _getPlainHtml(
        doulistUrl,
        headers: ApiConfig.doubanHeaders,
        cookieJar: _doubanCookieJar,
      );

      final document = parse(response.data ?? '');
      final items = document.querySelectorAll('.doulist-item');

      final candidates = <({String subjectUrl, Movie fallback})>[];
      final seenIds = <String>{};

      for (final item in items) {
        try {
          final linkElem = item.querySelector('.post a');
          final rawUrl = linkElem?.attributes['href'] ?? '';
          final subjectId = _extractSubjectId(rawUrl);
          if (subjectId == null || subjectId.isEmpty) continue;

          final subjectUrl = _normalizeDoubanUrl('/subject/$subjectId/');
          final movieId = 'douban_$subjectId';
          if (!seenIds.add(movieId)) continue;

          final titleElem = item.querySelector('.title a');
          final title = titleElem?.text.trim() ?? '';
          if (title.isEmpty) continue;

          final imgElem = item.querySelector('.post img');
          var poster = imgElem?.attributes['src'] ?? '';
          poster = _convertToWebp(poster);

          final ratingElem = item.querySelector('.rating_nums');
          final rating = double.tryParse(ratingElem?.text.trim() ?? '0') ?? 0;

          final abstractElem = item.querySelector('.abstract');
          final abstractData = _parseAbstract(abstractElem?.text ?? '');

          candidates.add((
            subjectUrl: subjectUrl,
            fallback: Movie(
              id: movieId,
              title: title,
              year: abstractData['year'] ?? '',
              director: abstractData['director'] ?? '',
              cast: abstractData['cast'] ?? '',
              rating: rating,
              genre: _parseGenre(abstractData['genre'] ?? ''),
              region: abstractData['region'] ?? '',
              poster: poster,
              doubanUrl: subjectUrl,
            ),
          ));
        } catch (_) {
          continue;
        }
      }

      if (candidates.isEmpty) {
        throw ScraperException('未找到影片，片单可能为空或需要登录');
      }

      const batchSize = 4;
      final resultSlots = List<Movie?>.filled(candidates.length, null);
      var completedCount = 0;

      Future<Movie> scrapeOrFallback(
        ({String subjectUrl, Movie fallback}) candidate,
      ) async {
        try {
          return await scrapeMovie(candidate.subjectUrl);
        } catch (_) {
          return candidate.fallback;
        }
      }

      List<Movie> snapshotMovies() =>
          resultSlots.whereType<Movie>().toList(growable: false);

      void emitProgress({String? currentTitle}) {
        onProgress?.call(
          DoulistScrapeProgress(
            total: candidates.length,
            completed: completedCount,
            currentTitle: currentTitle,
            movies: snapshotMovies(),
          ),
        );
      }

      Future<void> scrapeAt(
        int index,
        ({String subjectUrl, Movie fallback}) candidate,
      ) async {
        final movie = await scrapeOrFallback(candidate);
        resultSlots[index] = movie;
        completedCount++;
        emitProgress(currentTitle: movie.title);
      }

      emitProgress();

      // 先抓第一条，用于“预热” Cookie，减少后续批量触发挑战页概率
      await scrapeAt(0, candidates.first);

      final remaining = candidates.asMap().entries.skip(1).toList();
      for (var start = 0; start < remaining.length; start += batchSize) {
        final end = math.min(start + batchSize, remaining.length);
        final batch = remaining.sublist(start, end);
        await Future.wait(
          batch.map((entry) => scrapeAt(entry.key, entry.value)),
        );
      }

      return snapshotMovies();
    } on ScraperException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw ScraperException('请求超时，请稍后重试');
      }
      throw ScraperException('获取片单失败: ${error.message}');
    } catch (error) {
      throw ScraperException(error.toString());
    }
  }

  Future<_FetchedMoviePage> _fetchMoviePage(String targetUrl) async {
    final cookieJar = _doubanCookieJar;
    final headers = _buildMovieHeaders(targetUrl);
    final firstResponse = await _getPlainHtml(
      targetUrl,
      headers: headers,
      cookieJar: cookieJar,
    );
    final firstHtml = firstResponse.data ?? '';

    if (firstHtml.isEmpty) {
      throw ScraperException('豆瓣页面内容为空');
    }

    if (!_looksLikeChallengePage(firstHtml)) {
      return _FetchedMoviePage(
        html: firstHtml,
        finalUrl: firstResponse.realUri.toString(),
      );
    }

    final token = _extractHiddenValue(firstHtml, 'tok');
    final challenge = _extractHiddenValue(firstHtml, 'cha');
    final redirectUrl = _extractHiddenValue(firstHtml, 'red');
    final solution = await _powNonce(challenge, difficulty: 4);

    final challengeHeaders = {
      'Referer':
          'https://sec.douban.com/c?r=${Uri.encodeComponent(redirectUrl)}'
          '&_s=${token.contains('@') ? token.split('@').last : ''}&a=1',
      'Origin': 'https://sec.douban.com',
      'User-Agent': headers['User-Agent']!,
      'Accept': headers['Accept']!,
      'Accept-Language': headers['Accept-Language']!,
      if (cookieJar.hasCookies) 'Cookie': cookieJar.buildHeader(),
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'same-origin',
    };

    final challengeResponse = await _dio.post<String>(
      'https://sec.douban.com/c',
      data: {
        'tok': token,
        'cha': challenge,
        'sol': solution.toString(),
        'red': redirectUrl,
      },
      options: Options(
        headers: challengeHeaders,
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    cookieJar.absorb(challengeResponse.headers);

    final statusCode = challengeResponse.statusCode ?? 0;
    if (statusCode >= 400) {
      throw ScraperException('挑战页验证失败: $statusCode');
    }

    if (_isRedirectStatus(statusCode)) {
      final location = challengeResponse.headers.value('location');
      if (location != null && location.isNotEmpty) {
        await _getPlainHtml(
          _normalizeDoubanUrl(location),
          headers: headers,
          cookieJar: cookieJar,
        );
      }
    }

    final finalResponse = await _getPlainHtml(
      _normalizeDoubanUrl(redirectUrl),
      headers: headers,
      cookieJar: cookieJar,
    );
    final finalHtml = finalResponse.data ?? '';

    if (finalHtml.isEmpty) {
      throw ScraperException('豆瓣页面内容为空');
    }

    if (_looksLikeChallengePage(finalHtml)) {
      throw ScraperException('提交验证后仍返回挑战页');
    }

    return _FetchedMoviePage(
      html: finalHtml,
      finalUrl: finalResponse.realUri.toString(),
    );
  }

  Future<Response<String>> _getPlainHtml(
    String url, {
    required Map<String, String> headers,
    _CookieJarLite? cookieJar,
  }) async {
    final requestHeaders = Map<String, String>.from(headers);
    if (cookieJar != null && cookieJar.hasCookies) {
      requestHeaders['Cookie'] = cookieJar.buildHeader();
    }

    final response = await _dio.get<String>(
      url,
      options: Options(
        headers: requestHeaders,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    cookieJar?.absorb(response.headers);

    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 400) {
      throw ScraperException('请求豆瓣页面失败: $statusCode');
    }
    return response;
  }

  Map<String, String> _buildMovieHeaders(String targetUrl) {
    return {
      'Referer': targetUrl,
      'Origin': 'https://movie.douban.com',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
          'image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
  }

  String _validateDoubanMovieUrl(String doubanUrl) {
    final normalized = doubanUrl.trim();
    final uri = Uri.tryParse(normalized);
    final host = uri?.host ?? '';
    final path = uri?.path ?? '';
    final isDoubanHost =
        host == 'movie.douban.com' ||
        host == 'www.douban.com' ||
        host == 'm.douban.com';
    final isMoviePath =
        path.contains('/subject/') ||
        path.contains('/doubanapp/dispatch/movie/');

    if (!isDoubanHost || !isMoviePath) {
      throw ScraperException('无效的豆瓣影片链接');
    }

    return normalized;
  }

  bool _looksLikeChallengePage(String html) {
    return html.contains('name="sec"') && html.contains('action="/c"');
  }

  bool _isRedirectStatus(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }

  String _extractHiddenValue(String html, String name) {
    final match = RegExp(
      '<input[^>]*name="${RegExp.escape(name)}"[^>]*value="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);

    if (match == null) {
      throw ScraperException('豆瓣挑战页缺少字段: $name');
    }
    return match.group(1) ?? '';
  }

  String _extractLdJson(String html) {
    final match = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (match == null) {
      throw ScraperException('页面缺少影片结构化数据');
    }

    return match.group(1)?.trim() ?? '';
  }

  Map<String, dynamic> _parseLdJson(String ldJsonText) {
    final cleaned = ldJsonText.trim().replaceFirst('\ufeff', '');

    try {
      return Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
    } on FormatException {
      final sanitized = _sanitizeJsonControlChars(cleaned);
      return Map<String, dynamic>.from(jsonDecode(sanitized) as Map);
    }
  }

  String _sanitizeJsonControlChars(String source) {
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;

    for (final rune in source.runes) {
      final character = String.fromCharCode(rune);

      if (!inString) {
        if (character == '"') {
          inString = true;
        }
        buffer.write(character);
        continue;
      }

      if (escaped) {
        buffer.write(character);
        escaped = false;
        continue;
      }

      if (character == r'\') {
        buffer.write(character);
        escaped = true;
        continue;
      }

      if (character == '"') {
        buffer.write(character);
        inString = false;
        continue;
      }

      if (rune < 0x20) {
        if (character == '\n') {
          buffer.write(r'\n');
        } else if (character == '\r') {
          buffer.write(r'\r');
        } else if (character == '\t') {
          buffer.write(r'\t');
        } else {
          buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
        }
        continue;
      }

      buffer.write(character);
    }

    return buffer.toString();
  }

  Future<int> _powNonce(String data, {int difficulty = 4}) async {
    final prefix = '0' * difficulty;
    var nonce = 0;

    while (true) {
      nonce++;
      if (_sha512Hex('$data$nonce').startsWith(prefix)) {
        return nonce;
      }
      if (nonce % 2048 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  String _sha512Hex(String value) {
    return sha512.convert(utf8.encode(value)).toString();
  }

  Movie _buildMovieFromPage({
    required String requestUrl,
    required String finalUrl,
    required String html,
    required Map<String, dynamic> ldJson,
  }) {
    final ldType = ldJson['@type']?.toString().trim();
    final subjectType = switch (ldType) {
      'TVSeries' => MovieSubjectType.tvSeries,
      'Movie' => MovieSubjectType.movie,
      _ => MovieSubjectType.movie,
    };

    final normalizedUrl = _normalizeDoubanUrl(
      (ldJson['url'] ?? finalUrl ?? requestUrl).toString(),
    );
    final subjectId =
        _extractSubjectId(normalizedUrl) ??
        _extractSubjectId(finalUrl) ??
        _extractSubjectId(requestUrl);

    if (subjectId == null || subjectId.isEmpty) {
      throw ScraperException('未能提取豆瓣条目 ID');
    }

    final title = (ldJson['name'] ?? '').toString().trim();
    if (title.isEmpty) {
      throw ScraperException('页面缺少影片标题');
    }

    final aggregateRating = ldJson['aggregateRating'];
    final posterUrl = (ldJson['image'] ?? '').toString().trim();
    final summary = (ldJson['description'] ?? '').toString().trim();
    final publishedAt = (ldJson['datePublished'] ?? '').toString().trim();
    final durationText = (ldJson['duration'] ?? '').toString().trim();

    return Movie(
      id: 'douban_$subjectId',
      subjectType: subjectType,
      title: title,
      year:
          _extractInfoValue(html, const ['年份']) ??
          _extractYearFromDate(ldJson['datePublished']),
      director: _extractPersonNames(ldJson['director']).join(' / '),
      author: _extractPersonNames(ldJson['author']).join(' / '),
      cast: _extractPersonNames(ldJson['actor']).join(' / '),
      rating: _toDouble(
        aggregateRating is Map ? aggregateRating['ratingValue'] : null,
      ),
      genre: _toStringList(ldJson['genre']),
      region: _extractInfoValue(html, const ['制片国家/地区', '国家/地区']) ?? '',
      summary: summary,
      publishedAt: publishedAt,
      durationText: durationText,
      poster: posterUrl.isEmpty ? '' : _normalizeDoubanUrl(posterUrl),
      doubanUrl: normalizedUrl,
      episodes: subjectType == MovieSubjectType.tvSeries
          ? _extractEpisodes(html)
          : const [],
    );
  }

  List<MovieEpisode> _extractEpisodes(String html) {
    final document = parse(html);
    final anchors = document.querySelectorAll('.episode_list a');

    final episodes = <MovieEpisode>[];
    for (final anchor in anchors) {
      final href = anchor.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;

      final label = anchor.text.trim();
      final numberMatch = RegExp(r'(\d+)').firstMatch(label);
      final number = numberMatch != null
          ? int.tryParse(numberMatch.group(1)!) ?? 0
          : 0;

      episodes.add(
        MovieEpisode(
          number: number,
          label: label,
          doubanUrl: _normalizeDoubanUrl(href),
        ),
      );
    }

    episodes.sort((a, b) => a.number.compareTo(b.number));
    return episodes;
  }

  String? _extractInfoValue(String html, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '<span[^>]*>\\s*${RegExp.escape(label)}\\s*:\\s*</span>\\s*([^<]+)',
        caseSensitive: false,
      ).firstMatch(html);

      final value = match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _extractSubjectId(String url) {
    final match = RegExp(r'(?:subject|movie)/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  String _extractYearFromDate(dynamic value) {
    if (value == null) return '';
    final match = RegExp(r'(\d{4})').firstMatch(value.toString());
    return match?.group(1) ?? '';
  }

  List<String> _extractPersonNames(dynamic value) {
    if (value is Map) {
      final name = (value['name'] ?? '').toString().trim();
      return name.isEmpty ? const [] : [name];
    }

    if (value is! List) {
      return const [];
    }

    final names = <String>[];
    for (final item in value) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    return names;
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(RegExp(r'[/,，]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }

  double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ========== 私有工具方法 ==========

  /// 解析类型字符串
  List<String> _parseGenre(String genreStr) {
    if (genreStr.isEmpty) return [];
    return genreStr
        .split('/')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// 解析 abstract 字段
  Map<String, String> _parseAbstract(String text) {
    final result = <String, String>{};
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in lines) {
      if (line.startsWith('导演:')) {
        result['director'] = line.replaceFirst('导演:', '').trim();
      } else if (line.startsWith('主演:')) {
        result['cast'] = line.replaceFirst('主演:', '').trim();
      } else if (line.startsWith('类型:')) {
        result['genre'] = line.replaceFirst('类型:', '').trim();
      } else if (line.startsWith('制片国家/地区:')) {
        result['region'] = line.replaceFirst('制片国家/地区:', '').trim();
      } else if (line.startsWith('年份:')) {
        result['year'] = line.replaceFirst('年份:', '').trim();
      }
    }

    return result;
  }

  /// 转换为 webp 格式
  String _convertToWebp(String url) {
    if (url.isEmpty) return '';
    if (url.endsWith('.webp')) return url;
    return url.replaceAll(
      RegExp(r'\.(jpg|jpeg|png|gif)$', caseSensitive: false),
      '.webp',
    );
  }

  String _normalizeDoubanUrl(String url) {
    final baseUri = Uri.parse('https://movie.douban.com');
    return baseUri.resolve(url).toString();
  }
}

class ScraperException implements Exception {
  final String message;
  ScraperException(this.message);

  @override
  String toString() => message;
}

class _CookieJarLite {
  final Map<String, String> _cookies = {};

  bool get hasCookies => _cookies.isNotEmpty;

  String buildHeader() {
    return _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  void absorb(Headers headers) {
    final values = headers.map['set-cookie'];
    if (values == null || values.isEmpty) return;

    for (final item in values) {
      final firstPart = item.split(';').first.trim();
      if (firstPart.isEmpty) continue;

      final equalsIndex = firstPart.indexOf('=');
      if (equalsIndex <= 0) continue;

      final name = firstPart.substring(0, equalsIndex).trim();
      final value = firstPart.substring(equalsIndex + 1).trim();
      if (name.isEmpty) continue;

      _cookies[name] = value;
    }
  }
}

class _FetchedMoviePage {
  final String html;
  final String finalUrl;

  const _FetchedMoviePage({required this.html, required this.finalUrl});
}
