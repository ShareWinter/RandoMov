import 'package:flutter/foundation.dart';
import 'package:random_movie/models/models.dart';
import 'package:random_movie/services/services.dart';

/// 用户状态管理
class UserProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  LocalUser? _user;
  bool _isLoading = false;
  bool _hasInitialized = false;
  String? _error;

  LocalUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isReady => _user != null;
  bool get hasInitialized => _hasInitialized;
  String? get error => _error;

  UserProvider();

  Future<void> ensureInitialized() async {
    if (_hasInitialized || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _storageService.getOrCreateUser();
    } catch (e) {
      _error = '初始化失败: $e';
    } finally {
      _hasInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserName(String newName) async {
    if (newName.trim().isEmpty) return;
    await ensureInitialized();
    if (_user == null) return;

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
