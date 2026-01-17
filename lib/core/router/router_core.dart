library;

/// # Router Core - GoRouter 封装层
///
/// 这是一个基于 GoRouter 的路由管理封装，提供统一的路由配置、导航管理和错误处理。
///
/// ## 核心组件
///
/// ### 1. RouterFactory - 路由工厂
/// 用于创建和配置 GoRouter 实例，支持自定义错误处理、调试日志等。
///
/// ### 2. NavigatorManager - 导航管理器
/// 提供统一的导航方法封装，支持命名路由、参数传递、URL 跳转等。
///
/// ### 3. RouteErrorPage - 错误页面
/// 统一的路由错误处理页面，在路由异常时显示友好的错误信息。
///
/// ### 4. RouteResult - 导航结果（已废弃）
/// 用于定义导航返回结果的类型，目前不推荐使用。
///
/// ---
///
/// ## 快速开始
///
/// ### 步骤 1：定义路由
///
/// ```dart
/// // lib/routes/home_routes.dart
/// import 'package:epub_reader/core/router/router_core.dart';
///
/// List<RouteBase> homeRoutes() => [
///   GoRoute(
///     path: '/',
///     name: 'home',
///     builder: (context, state) => const HomeScreen(),
///   ),
///   GoRoute(
///     path: '/library',
///     name: 'library',
///     builder: (context, state) => const LibraryScreen(),
///   ),
/// ];
/// ```
///
/// ### 步骤 2：创建 Router
///
/// ```dart
/// // lib/main.dart
/// import 'package:epub_reader/core/router/router_core.dart';
/// import 'package:epub_reader/routes/home_routes.dart';
///
/// void main() {
///   final router = RouterFactory.create(
///     RouterConfig(
///       initialLocation: '/',
///       showRouteErrorPage: true,  // 显示错误页面
///       debugLogDiagnostics: true, // 开启调试日志
///       routes: [
///         ...homeRoutes(),
///       ],
///     ),
///   );
///
///   runApp(MyApp(router: router));
/// }
/// ```
///
/// ### 步骤 3：使用 MaterialApp.router
///
/// ```dart
/// class MyApp extends StatelessWidget {
///   final GoRouter router;
///
///   const MyApp({super.key, required this.router});
///
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp.router(
///       routerConfig: router,
///       title: 'EPUB Reader',
///     );
///   }
/// }
/// ```
///
/// ---
///
/// ## 导航方法
///
/// ### 基础导航
///
/// ```dart
/// // Push - 新增路由到栈顶
/// NavigatorManager.push('/reader');
/// NavigatorManager.pushNamed('reader', pathParameters: {'id': '123'});
///
/// // PushReplacement - 替换当前路由
/// NavigatorManager.pushReplacement('/login');
/// NavigatorManager.pushReplacementNamed('login');
///
/// // Go - 替换整个导航栈
/// NavigatorManager.go('/home');
/// NavigatorManager.goNamed('home');
///
/// // Pop - 返回上一页
/// NavigatorManager.pop();
/// NavigatorManager.pop('result'); // 带返回值
///
/// // 检查是否可以返回
/// if (NavigatorManager.canPop()) {
///   NavigatorManager.pop();
/// }
/// ```
///
/// ### 命名路由与参数
///
/// ```dart
/// // 定义带参数的路由
/// GoRoute(
///   path: '/reader/:bookId',
///   name: 'reader',
///   builder: (context, state) {
///     final bookId = state.pathParameters['bookId']!;
///     final chapter = state.uri.queryParameters['chapter'];
///     return ReaderScreen(bookId: bookId, chapter: chapter);
///   },
/// ),
///
/// // 使用命名路由跳转
/// NavigatorManager.pushNamed(
///   'reader',
///   pathParameters: {'bookId': '123'},
///   queryParameters: {'chapter': '5'},
/// );
/// // 实际路径：/reader/123?chapter=5
/// ```
///
/// ### 传递复杂对象（extra）
///
/// ```dart
/// // 定义路由
/// GoRoute(
///   path: '/reader',
///   builder: (context, state) {
///     final book = state.extra as Book;
///     return ReaderScreen(book: book);
///   },
/// ),
///
/// // 跳转时传递对象
/// final book = Book(id: '123', title: 'Flutter Guide');
/// NavigatorManager.push('/reader', extra: book);
/// ```
///
/// ### URL 跳转（支持 Deep Link）
///
/// ```dart
/// // 自定义 scheme（需要在 routerWithUrl 中配置）
/// NavigatorManager.routerWithUrl('awwpet://willtolearn/reader/123');
///
/// // 域名路由（需要在 routerWithUrl 中配置）
/// NavigatorManager.routerWithUrl('https://willtolearn.com/reader/123');
///
/// // 外部链接（自动打开浏览器）
/// NavigatorManager.routerWithUrl('https://flutter.dev');
/// ```
///
/// ### 获取返回值
///
/// ```dart
/// // 页面 A：跳转并等待返回值
/// final result = await NavigatorManager.pushNamed('settings');
/// if (result != null) {
///   print('Settings changed: $result');
/// }
///
/// // 页面 B：返回时传递数据
/// NavigatorManager.pop({'theme': 'dark', 'fontSize': 16});
/// ```
///
/// ---
///
/// ## 路由配置
///
/// ### RouterConfig 参数说明
///
/// ```dart
/// RouterConfig(
///   // 初始路由路径
///   initialLocation: '/',
///
///   // 是否显示错误页面（true）或仅打印日志（false）
///   showRouteErrorPage: true,
///
///   // 是否启用调试日志（默认 Debug 模式启用）
///   debugLogDiagnostics: kDebugMode,
///
///   // 路由列表
///   routes: [...],
///
///   // 自定义错误页面（可选）
///   customErrorPageBuilder: (context, state) {
///     return CupertinoPage(child: MyErrorPage(state: state));
///   },
///
///   // 自定义异常处理器（可选，仅在 showRouteErrorPage=false 时生效）
///   customOnException: (context, state, router) {
///     print('Route error: ${state.error}');
///   },
/// )
/// ```
///
/// ---
///
/// ## 嵌套路由
///
/// ```dart
/// GoRoute(
///   path: '/home',
///   name: 'home',
///   builder: (context, state) => const HomeScreen(),
///   routes: [
///     // 子路由：/home/profile
///     GoRoute(
///       path: 'profile',
///       name: 'profile',
///       builder: (context, state) => const ProfileScreen(),
///     ),
///     // 子路由：/home/settings
///     GoRoute(
///       path: 'settings',
///       name: 'settings',
///       builder: (context, state) => const SettingsScreen(),
///     ),
///   ],
/// ),
///
/// // 跳转到子路由
/// NavigatorManager.pushNamed('profile'); // 使用命名路由
/// NavigatorManager.push('/home/profile'); // 使用路径
/// ```
///
/// ---
///
/// ## Shell 路由（底部导航栏）
///
/// ```dart
/// final shellRoute = ShellRoute(
///   builder: (context, state, child) {
///     return MainScaffold(child: child); // 包含底部导航栏的 Scaffold
///   },
///   routes: [
///     GoRoute(
///       path: '/home',
///       builder: (context, state) => const HomeScreen(),
///     ),
///     GoRoute(
///       path: '/library',
///       builder: (context, state) => const LibraryScreen(),
///     ),
///     GoRoute(
///       path: '/settings',
///       builder: (context, state) => const SettingsScreen(),
///     ),
///   ],
/// );
/// ```
///
/// ---
///
/// ## 路由守卫（重定向）
///
/// ```dart
/// final router = RouterFactory.create(
///   RouterConfig(
///     routes: [...],
///   ),
/// );
///
/// // 在 GoRouter 创建时添加 redirect
/// GoRouter(
///   redirect: (context, state) {
///     final isLoggedIn = checkLoginStatus();
///     final isLoginRoute = state.matchedLocation == '/login';
///
///     // 未登录且不在登录页，跳转到登录页
///     if (!isLoggedIn && !isLoginRoute) {
///       return '/login';
///     }
///
///     // 已登录且在登录页，跳转到首页
///     if (isLoggedIn && isLoginRoute) {
///       return '/home';
///     }
///
///     return null; // 不重定向
///   },
///   routes: [...],
/// );
/// ```
///
/// ---
///
/// ## 工具方法
///
/// ### 安全的异步操作
///
/// ```dart
/// // 在 await 后检查 context 是否仍然有效
/// final result = await NavigatorManager.safeAwait(
///   context,
///   fetchDataFromApi(),
/// );
///
/// if (result != null) {
///   // context 仍然有效，可以安全使用
///   print('Data: $result');
/// }
/// ```
///
/// ### 获取全局 Context
///
/// ```dart
/// // 在非 Widget 环境中使用（谨慎使用）
/// final context = NavigatorManager.context;
/// NavigatorManager.push('/home');
/// ```
///
/// ---
///
/// ## 注意事项
///
/// 1. **必须初始化**：RouterFactory.create() 会自动调用 NavigatorManager.init()
/// 2. **命名路由优先**：推荐使用命名路由，便于管理和重构
/// 3. **参数传递**：简单参数用 pathParameters/queryParameters，复杂对象用 extra
/// 4. **错误处理**：生产环境建议开启 showRouteErrorPage
/// 5. **RouteResult 已废弃**：不要使用 route_model.dart 中的类
///
/// ---
///
/// ## 示例项目结构
///
/// ```
/// lib/
/// ├── core/
/// │   └── router/
/// │       ├── router_core.dart          # 导出文件（本文件）
/// │       ├── factory/
/// │       │   └── router_factory.dart   # 路由工厂
/// │       ├── navigator/
/// │       │   ├── navigator_manager.dart # 导航管理器
/// │       └── pages/
/// │           └── route_error_page.dart # 错误页面
/// ├── routes/
/// │   ├── home_routes.dart              # 首页路由
/// │   ├── library_routes.dart           # 图书馆路由
/// │   └── reader_routes.dart            # 阅读器路由
/// └── main.dart                         # 应用入口
/// ```
///
/// ---

export 'factory/router_factory.dart';
export 'navigator/navigator_manager.dart';
export 'pages/route_error_page.dart';

/// 三方库导出
export 'package:go_router/go_router.dart';
