import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/database_factory.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库工厂（桌面平台需要 FFI）
  DatabaseFactoryHelper.initialize();

  runApp(
    const ProviderScope(
      child: EpubReaderApp(),
    ),
  );
}