import 'package:flutter/material.dart';
import 'package:random_movie/app.dart';
import 'package:random_movie/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储服务
  await StorageService().init();

  runApp(const MyApp());
}
