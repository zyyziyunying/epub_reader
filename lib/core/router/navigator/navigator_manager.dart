import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// 基于 GoRouter 的统一导航管理器
// ! 禁止在此处添加 Navigator 路由方法

/// 优先使用命名路由，命名路由会自动处理Path与Query参数
class NavigatorManager {
  NavigatorManager._();

  // GoRouter 实例
  static GoRouter? _router;

  // ! 初始化，必须在 App 启动时调用
  static void init(GoRouter router) {
    _router = router;
  }

  /// 获取 GoRouter 实例
  static GoRouter get router {
    assert(_router != null, 'NavigatorManager.init() must be called first');
    return _router!;
  }

  /// 全局 BuildContext
  /// 全局 BuildContext
  static BuildContext get context {
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) {
      throw Exception(
        'NavigatorManager.context is null. Ensure that NavigatorManager.init() has been called and the navigatorKey is set up correctly.',
      );
    }
    return ctx;
  }

  /// —— 基础导航 —— ///

  /// Push route（新路由）
  static Future<T?> push<T extends Object?>(String route, {Object? extra}) {
    return router.push<T>(route, extra: extra);
  }

  /// Push route（新路由）（命名路由）
  static Future<T?> pushNamed<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    return router.pushNamed<T>(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  /// PushReplacement route（替换当前路由）
  static Future<T?> pushReplacement<T extends Object?>(
    String route, {
    Object? extra,
  }) {
    return router.pushReplacement<T>(route, extra: extra);
  }

  /// PushReplacement route（替换当前路由）（命名路由）
  static Future<T?> pushReplacementNamed<T extends Object?>(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    return router.pushReplacementNamed<T>(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  /// Go to route（替换整个导航栈）（普通路由）
  static void go(String route, {Object? extra}) {
    router.go(route, extra: extra);
  }

  /// Go to route（替换整个导航栈）（命名路由）
  static void goNamed(
    String name, {
    Map<String, String> pathParameters = const {},
    Map<String, dynamic> queryParameters = const {},
    Object? extra,
  }) {
    router.goNamed(
      name,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
      extra: extra,
    );
  }

  /// Pop 当前路由
  static void pop<T extends Object?>([T? result]) {
    router.pop<T>(result);
  }

  /// 是否可以 pop
  static bool canPop() => router.canPop();

  /// 通过 URL 进行路由跳转
  /// - awwpet://willtolearn/ 开头：提取路径传给 GoRouter
  /// - https://willtolearn.com：提取路径传给 GoRouter
  /// - 其他 https:// 链接：直接打开外部浏览器
  static Future<T?> routerWithUrl<T extends Object?>(String url) async {
    try {
      final uri = Uri.parse(url);

      if (uri.scheme == 'awwpet') {
        final host = uri.host;
        final path = uri.path.isEmpty ? '/' : uri.path;
        final query = uri.queryParameters.isNotEmpty ? '?${uri.query}' : '';
        try {
          return await push<T>('$path$query');
        } catch (e) {
          debugPrint(
            '[NavigatorManager] Failed to navigate to awwpet route:$host - $path - $e',
          );
          return null;
        }
      }

      // 处理 https://willtolearn.com
      if (uri.scheme == 'https' && uri.host == 'willtolearn.com') {
        final path = uri.path.isEmpty ? '/' : uri.path;
        final query = uri.queryParameters.isNotEmpty ? '?${uri.query}' : '';
        try {
          return await push<T>('$path$query');
        } catch (e) {
          debugPrint(
            '[NavigatorManager] Failed to navigate to willtolearn route: $path - $e',
          );
          return null;
        }
      }

      // 处理其他 https 链接，直接打开浏览器
      if (uri.scheme == 'https' || uri.scheme == 'http') {
        try {
          final urlToLaunch = Uri.parse(url);
          if (await canLaunchUrl(urlToLaunch)) {
            final launched = await launchUrl(
              urlToLaunch,
              mode: LaunchMode.externalApplication,
            );
            if (!launched) {
              debugPrint('[NavigatorManager] Failed to launch URL: $url');
            }
          } else {
            debugPrint('[NavigatorManager] Cannot launch URL: $url');
          }
        } catch (e) {
          debugPrint('[NavigatorManager] Error launching URL: $url - $e');
        }
        return null;
      }

      try {
        return await push<T>(url);
      } catch (e) {
        debugPrint('[NavigatorManager] Failed to navigate to route: $url - $e');
        return null;
      }
    } catch (e) {
      debugPrint('[NavigatorManager] Failed to parse URL: $url - $e');
      return null;
    }
  }

  /// —— Sheet（Cupertino 风格） —— ///
  @Deprecated('用官方方法：showCupertinoModalPopup 替代，没必要额外封装')
  static Future<T?> sheet<T>(
    BuildContext context,
    WidgetBuilder builder, {
    bool root = false,
    bool useSafeArea = true,
    Color? barrierColor,
    bool barrierDismissible = true,
  }) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: root,
      barrierColor:
          barrierColor ?? const Color(0xFF000000).withValues(alpha: 0.8),
      barrierDismissible: barrierDismissible,
      builder: (ctx) =>
          useSafeArea ? SafeArea(child: builder(ctx)) : builder(ctx),
    );
  }

  /// —— Dialog（Cupertino 风格） —— ///
  @Deprecated('用官方方法：showCupertinoDialog 替代，没必要额外封装')
  static Future<T?> cupertinoDialog<T>(
    BuildContext context,
    WidgetBuilder builder, {
    bool root = false,
    bool barrierDismissible = false,
  }) {
    return showCupertinoDialog<T>(
      context: context,
      useRootNavigator: root,
      barrierColor: const Color(0xFF000000).withValues(alpha: 0.8),
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// —— 小工具 —— ///
  /// await 完成后，若 context 已销毁则返回 null
  static Future<R?> safeAwait<R>(BuildContext context, Future<R> fut) async {
    final r = await fut;
    if (!context.mounted) return null;
    return r;
  }
}
