import 'package:flutter/foundation.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

/// 用户状态管理
class UserProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  LocalUser? _user;
  bool _isLoading = true;
  String? _error;

  LocalUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isReady => _user != null;
  String? get error => _error;

  UserProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      _user = await _storageService.getOrCreateUser();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '初始化失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserName(String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      await _storageService.updateUserName(newName.trim());
      _user = _user?.copyWith(name: newName.trim());
      notifyListeners();
    } catch (e) {
      _error = '更新失败: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
