import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../navigator/navigator_manager.dart';
import '../pages/route_error_page.dart';

/// 路由工厂配置
///
/// 用于配置 GoRouter 的创建参数，包括错误处理、调试日志等。
class RouterConfig {
  /// 初始路由路径
  final String initialLocation;

  /// 是否显示路由错误页面
  ///
  /// - `true`: 显示统一的错误页面（RouteErrorPage）
  /// - `false`: 仅在控制台打印错误日志
  final bool showRouteErrorPage;

  /// 是否启用调试日志
  ///
  /// 默认在 Debug 模式下启用
  final bool debugLogDiagnostics;

  /// 路由列表
  final List<RouteBase> routes;

  /// 自定义错误页面构建器（可选）
  ///
  /// 如果提供，将覆盖默认的 RouteErrorPage
  final Page<void> Function(BuildContext, GoRouterState)?
  customErrorPageBuilder;

  /// 自定义异常处理器（可选）
  ///
  /// 当 showRouteErrorPage 为 false 时使用
  final void Function(BuildContext, GoRouterState, GoRouter)? customOnException;

  const RouterConfig({
    this.initialLocation = '/',
    this.showRouteErrorPage = true,
    this.debugLogDiagnostics = kDebugMode,
    required this.routes,
    this.customErrorPageBuilder,
    this.customOnException,
  });
}

/// 路由工厂
///
/// 提供统一的 GoRouter 创建方法，封装了错误处理、调试日志等通用配置。
///
/// ## 使用示例
///
/// ```dart
/// final router = RouterFactory.create(
///   RouterConfig(
///     showRouteErrorPage: AppConfig.instance.showRouteErrorPage,
///     routes: [
///       ...homeRoutes(),
///       ...settingRoutes(),
///     ],
///   ),
/// );
/// ```
abstract class RouterFactory {
  /// 创建 GoRouter 实例
  ///
  /// 执行以下步骤：
  /// 1. 根据配置设置错误处理方式（错误页面或日志输出）
  /// 2. 创建 GoRouter 实例
  /// 3. 初始化 NavigatorManager
  ///
  /// 注意：
  /// - onException 与 errorPageBuilder 不能同时使用
  /// - 创建后会自动调用 NavigatorManager.init()
  static GoRouter create(RouterConfig config) {
    final router = GoRouter(
      initialLocation: config.initialLocation,
      debugLogDiagnostics: config.debugLogDiagnostics,

      // 路由异常处理，防止静默失败
      onException: config.showRouteErrorPage
          ? null
          : config.customOnException ?? _defaultOnException,

      // 统一错误页面处理
      errorPageBuilder: config.showRouteErrorPage
          ? config.customErrorPageBuilder ?? _defaultErrorPageBuilder
          : null,

      routes: config.routes,
    );

    NavigatorManager.init(router);
    return router;
  }

  /// 默认的异常处理器
  static void _defaultOnException(
    BuildContext context,
    GoRouterState state,
    GoRouter router,
  ) {
    debugPrint('===e：===[GoRouter] Exception: ${state.error}');
    debugPrint('===e：===[GoRouter] Location: ${state.matchedLocation}');
  }

  /// 默认的错误页面构建器
  static Page<void> _defaultErrorPageBuilder(
    BuildContext context,
    GoRouterState state,
  ) {
    return CupertinoPage<void>(
      key: state.pageKey,
      child: RouteErrorPage(state: state),
    );
  }
}
