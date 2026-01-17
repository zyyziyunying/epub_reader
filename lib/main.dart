import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/database_factory.dart';
import 'core/router/factory/router_factory.dart' as router_factory;
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库工厂（桌面平台需要 FFI）
  DatabaseFactoryHelper.initialize();

  // 创建路由
  final router = router_factory.RouterFactory.create(
    router_factory.RouterConfig(
      initialLocation: AppRoutes.library,
      showRouteErrorPage: true,
      routes: appRoutes(),
    ),
  );

  runApp(
    ProviderScope(
      child: EpubReaderApp(router: router),
    ),
  );
}