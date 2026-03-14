import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

/// 抽奖历史状态管理
class DrawHistoryProvider extends ChangeNotifier {
  static const int pageSize = 20;

  final StorageService _storageService = StorageService();

  List<DrawRecord> _records = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  bool _hasLoaded = false;
  String? _error;

  List<DrawRecord> get records => _records;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  DrawHistoryProvider();

  Future<void> ensureLoaded() async {
    if (_hasLoaded || _isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    final shouldNotifyLoading =
        _hasLoaded || _records.isNotEmpty || _error != null;
    _isLoading = true;
    _error = null;
    if (shouldNotifyLoading) {
      notifyListeners();
    }

    try {
      final records = await _storageService.queryDrawRecords(
        limit: pageSize,
        offset: 0,
      );
      _records = records;
      _page = 0;
      _hasMore = records.length == pageSize;
    } catch (error) {
      _error = '加载失败: $error';
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _page + 1;
      final records = await _storageService.queryDrawRecords(
        limit: pageSize,
        offset: nextPage * pageSize,
      );
      if (records.isEmpty) {
        _hasMore = false;
      } else {
        _records = [..._records, ...records];
        _page = nextPage;
        _hasMore = records.length == pageSize;
      }
    } catch (error) {
      _error = '加载更多失败: $error';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _reloadVisibleRecords() async {
    final limit = math.max((_page + 1) * pageSize, pageSize);
    final results = await Future.wait<Object>([
      _storageService.queryDrawRecords(limit: limit, offset: 0),
      _storageService.countDrawRecords(),
    ]);
    final records = results[0] as List<DrawRecord>;
    final total = results[1] as int;
    _records = records;
    _page = records.isEmpty ? 0 : ((records.length - 1) / pageSize).floor();
    _hasMore = records.length < total;
    notifyListeners();
  }

  /// 添加一条记录并刷新
  Future<void> addRecord(DrawRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _storageService.addDrawRecord(record);
      await _reloadVisibleRecords();
    } catch (error) {
      _error = '保存失败: $error';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空历史
  Future<void> clearAll() async {
    try {
      await _storageService.clearDrawHistory();
      _records = [];
      _page = 0;
      _hasMore = false;
      notifyListeners();
    } catch (error) {
      _error = '清空失败: $error';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
