/// API 配置
class ApiConfig {
  // 开发环境
  static const String devBaseUrl = 'xxx';
  static const String devSocketUrl = 'xxx';

  // 生产环境
  static const String prodBaseUrl = 'xxx';
  static const String prodSocketUrl = 'xxx';

  // 当前环境（通过编译时变量或运行时配置切换）
  static const bool isProduction = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  );

  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;
  static String get socketUrl => isProduction ? prodSocketUrl : devSocketUrl;

  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // 豆瓣爬取相关
  static const String wmdbApiBase = 'https://api.wmdb.tv';

  // 请求头
  static Map<String, String> get defaultHeaders => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  // 豆瓣请求头（用于片单爬取）
  static Map<String, String> get doubanHeaders => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Referer': 'https://www.douban.com/',
  };

  // 图片请求头（绕过防盗链）
  static Map<String, String> get imageHeaders => {
    'Referer': 'https://movie.douban.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };
}
