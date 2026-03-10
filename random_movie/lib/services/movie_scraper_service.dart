import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:random_movie/config/api_config.dart';
import 'package:random_movie/models/movie.dart';

/// 影片爬取服务（纯前端实现）
class MovieScraperService {
  final Dio _dio;

  MovieScraperService() : _dio = Dio(BaseOptions(
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
  ));

  /// 爬取单个影片（通过 WMDB API）
  ///
  /// [useProxy] 为 true 时走服务端代理（绕墙），false 时直连 WMDB API。
  Future<Movie> scrapeMovie(String doubanUrl, {bool useProxy = true}) async {
    try {
      // 提取 doubanId（兼容网页版和手机版链接）
      // 网页版: https://movie.douban.com/subject/1309069/
      // 手机版: https://www.douban.com/doubanapp/dispatch/movie/1309069
      final match = RegExp(r'(?:subject|movie)/(\d+)').firstMatch(doubanUrl);
      if (match == null) {
        throw ScraperException('无效的豆瓣影片链接');
      }
      final doubanId = match.group(1);

      // Call WMDB API: proxy via backend or direct
      final url = useProxy
          ? '${ApiConfig.baseUrl}/api/movie?id=$doubanId'
          : '${ApiConfig.wmdbApiBase}/movie/api?id=$doubanId';

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = response.data;
      if (data == null || data['data'] == null || (data['data'] as List).isEmpty) {
        throw ScraperException('未找到影片数据');
      }

      // 提取中文数据
      final movieData = _getChineseData(data['data'] as List);
      if (movieData == null) {
        throw ScraperException('未找到中文影片信息');
      }

      // 提取导演
      final directors = _extractNames(data['director']);
      // 提取演员
      final actors = _extractNames(data['actor']);
      // 解析类型
      final genre = _parseGenre(movieData['genre'] ?? '');
      // 解析评分
      final rating = double.tryParse(data['doubanRating']?.toString() ?? '0') ?? 0;

      return Movie(
        id: 'douban_$doubanId',
        title: movieData['name'] ?? '',
        year: data['year']?.toString() ?? '',
        director: directors,
        cast: actors,
        rating: rating,
        genre: genre,
        region: movieData['country'] ?? '',
        poster: movieData['poster'] ?? '',
        doubanUrl: doubanUrl,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw ScraperException('请求超时，请稍后重试');
      }
      throw ScraperException('获取影片信息失败: ${e.message}');
    } catch (e) {
      throw ScraperException(e.toString());
    }
  }

  /// 爬取片单（直接解析豆瓣 HTML）
  Future<List<Movie>> scrapeDoulist(String doulistUrl) async {
    try {
      // 验证链接格式
      if (!doulistUrl.contains('douban.com/doulist/')) {
        throw ScraperException('无效的豆瓣片单链接');
      }

      // 请求片单页面
      final response = await _dio.get(
        doulistUrl,
        options: Options(
          headers: ApiConfig.doubanHeaders,
          responseType: ResponseType.plain,
        ),
      );

      // 解析 HTML
      final document = parse(response.data);
      final items = document.querySelectorAll('.doulist-item');

      final movies = <Movie>[];
      for (final item in items) {
        try {
          // 获取豆瓣链接
          final linkElem = item.querySelector('.post a');
          final doubanUrl = linkElem?.attributes['href'] ?? '';

          // 从 URL 提取豆瓣 ID 作为唯一标识
          final idMatch = RegExp(r'subject/(\d+)').firstMatch(doubanUrl);
          final movieId = idMatch != null ? 'douban_${idMatch.group(1)}' : '';

          // 获取海报
          final imgElem = item.querySelector('.post img');
          var poster = imgElem?.attributes['src'] ?? '';
          poster = _convertToWebp(poster);

          // 获取标题
          final titleElem = item.querySelector('.title a');
          final title = titleElem?.text.trim() ?? '';

          if (title.isEmpty) continue;

          // 获取评分
          final ratingElem = item.querySelector('.rating_nums');
          final rating = double.tryParse(ratingElem?.text.trim() ?? '0') ?? 0;

          // 解析详细信息
          final abstractElem = item.querySelector('.abstract');
          final abstractData = _parseAbstract(abstractElem?.text ?? '');

          movies.add(Movie(
            id: movieId,
            title: title,
            year: abstractData['year'] ?? '',
            director: abstractData['director'] ?? '',
            cast: abstractData['cast'] ?? '',
            rating: rating,
            genre: _parseGenre(abstractData['genre'] ?? ''),
            region: abstractData['region'] ?? '',
            poster: poster,
            doubanUrl: doubanUrl,
          ));
        } catch (e) {
          // 单条解析失败继续下一条
          continue;
        }
      }

      if (movies.isEmpty) {
        throw ScraperException('未找到影片，片单可能为空或需要登录');
      }

      return movies;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw ScraperException('请求超时，请稍后重试');
      }
      throw ScraperException('获取片单失败: ${e.message}');
    } catch (e) {
      throw ScraperException(e.toString());
    }
  }

  // ========== 私有工具方法 ==========

  /// 获取中文数据
  Map<String, dynamic>? _getChineseData(List<dynamic> items) {
    if (items.isEmpty) return null;
    return items.firstWhere(
      (item) => item['lang'] == 'Cn',
      orElse: () => items.first,
    ) as Map<String, dynamic>?;
  }

  /// 提取人名列表
  String _extractNames(List<dynamic>? persons) {
    if (persons == null || persons.isEmpty) return '';
    final names = <String>[];
    for (final person in persons) {
      if (person is Map && person['data'] is List) {
        final data = person['data'] as List;
        final name = _getChineseData(data)?['name'];
        if (name != null) {
          names.add(name.toString());
        }
      }
    }
    return names.join(' / ');
  }

  /// 解析类型字符串
  List<String> _parseGenre(String genreStr) {
    if (genreStr.isEmpty) return [];
    return genreStr.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// 解析 abstract 字段
  Map<String, String> _parseAbstract(String text) {
    final result = <String, String>{};
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);

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
    return url.replaceAll(RegExp(r'\.(jpg|jpeg|png|gif)$', caseSensitive: false), '.webp');
  }
}

class ScraperException implements Exception {
  final String message;
  ScraperException(this.message);
  @override
  String toString() => message;
}
