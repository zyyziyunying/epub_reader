import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// 路由错误页面
/// ! 统一处理 GoRouter 的路由异常
class RouteErrorPage extends StatelessWidget {
  final GoRouterState state;

  const RouteErrorPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final GoException? error = state.error;
    final String errorMessage = _getErrorMessage(error);
    final String location = state.matchedLocation;

    return CupertinoPageScaffold(
      backgroundColor: Color(0xFF110F12),
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: Color(0xFF110F12),
        border: null,
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.white,
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                'Route error',
                style: TextStyle(color: CupertinoColors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    color: CupertinoColors.white.withAlpha(200),
                    fontSize: 16,
                  ),

                  textAlign: TextAlign.center,
                ),
              ),
              if (kDebugMode && location.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Path: $location',
                    style: TextStyle(
                      color: CupertinoColors.white.withAlpha(200),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              CupertinoButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取错误信息
  String _getErrorMessage(Object? error) {
    if (error == null) {
      return 'Unknown error';
    }

    if (error is ArgumentError) {
      return error.message ?? 'Argument error';
    }

    if (error is FormatException) {
      return 'Format error: ${error.message}';
    }

    return error.toString();
  }
}
