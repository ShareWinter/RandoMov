import 'package:flutter/foundation.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

/// 抽奖历史状态管理
class DrawHistoryProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<DrawRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  List<DrawRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DrawHistoryProvider() {
    loadRecords();
  }

  /// 加载本地抽奖历史
  void loadRecords() {
    _records = _storageService.getDrawHistory();
    notifyListeners();
  }

  /// 添加一条记录并刷新
  Future<void> addRecord(DrawRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _storageService.addDrawRecord(record);
      loadRecords();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = '保存失败: $e';
      notifyListeners();
    }
  }

  /// 清空历史
  Future<void> clearAll() async {
    try {
      await _storageService.clearDrawHistory();
      loadRecords();
    } catch (e) {
      _error = '清空失败: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
