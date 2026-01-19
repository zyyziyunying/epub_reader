import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/common/log/log.dart';

void main() {
  group('AppLogger', () {
    test('应该能够创建日志器实例', () {
      final log = AppLogger('TestModule');
      expect(log.module, 'TestModule');
    });

    test('应该能够输出不同级别的日志', () {
      final log = AppLogger('TestModule');

      // 这些调用不应该抛出异常
      expect(() => log.debug('Debug message'), returnsNormally);
      expect(() => log.info('Info message'), returnsNormally);
      expect(() => log.warning('Warning message'), returnsNormally);
      expect(() => log.error('Error message'), returnsNormally);
    });

    test('应该能够输出带错误对象的日志', () {
      final log = AppLogger('TestModule');
      final error = Exception('Test error');

      expect(
        () => log.error('Error occurred', error: error),
        returnsNormally,
      );
    });

    test('应该能够输出带堆栈跟踪的日志', () {
      final log = AppLogger('TestModule');
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      expect(
        () => log.error('Error occurred', error: error, stackTrace: stackTrace),
        returnsNormally,
      );
    });
  });

  group('LogConfig', () {
    test('默认日志级别应该是 debug', () {
      expect(LogConfig.minLevel, LogLevel.debug);
    });

    test('应该能够设置生产环境模式', () {
      LogConfig.setProductionMode();
      expect(LogConfig.minLevel, LogLevel.warning);

      // 恢复默认值
      LogConfig.setDevelopmentMode();
    });

    test('应该能够设置开发环境模式', () {
      LogConfig.setDevelopmentMode();
      expect(LogConfig.minLevel, LogLevel.debug);
    });

    test('应该能够手动设置日志级别', () {
      LogConfig.minLevel = LogLevel.info;
      expect(LogConfig.minLevel, LogLevel.info);

      // 恢复默认值
      LogConfig.setDevelopmentMode();
    });
  });

  group('LogLevel', () {
    test('日志级别应该有正确的值', () {
      expect(LogLevel.debug.value, 0);
      expect(LogLevel.info.value, 800);
      expect(LogLevel.warning.value, 900);
      expect(LogLevel.error.value, 1000);
    });

    test('日志级别应该有正确的名称', () {
      expect(LogLevel.debug.name, 'DEBUG');
      expect(LogLevel.info.name, 'INFO');
      expect(LogLevel.warning.name, 'WARNING');
      expect(LogLevel.error.name, 'ERROR');
    });

    test('带颜色的名称应该包含 ANSI 代码', () {
      expect(LogLevel.debug.coloredName, contains('DEBUG'));
      expect(LogLevel.info.coloredName, contains('INFO'));
      expect(LogLevel.warning.coloredName, contains('WARNING'));
      expect(LogLevel.error.coloredName, contains('ERROR'));
    });
  });

  group('AnsiColor', () {
    test('应该能够包装文本', () {
      final text = 'Hello';
      final wrapped = AnsiColor.red.wrap(text);

      expect(wrapped, contains(text));
      expect(wrapped, startsWith('\x1B[31m'));
      expect(wrapped, endsWith('\x1B[0m'));
    });
  });
}
