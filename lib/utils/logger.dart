import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 日志工具类
class Logger {
  /// 输出信息日志
  static void i(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// 输出调试日志
  static void d(String message, {String? tag}) {
    _log('DEBUG', message, tag: tag);
  }

  /// 输出警告日志
  static void w(String message, {String? tag}) {
    _log('WARN', message, tag: tag);
  }

  /// 输出错误日志
  static void e(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 内部日志输出方法
  static void _log(
    String level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kReleaseMode) {
      final logTag = tag != null ? '[$tag]' : '';
      final logMessage = '$level$logTag: $message';

      if (error != null) {
        developer.log(
          logMessage,
          time: DateTime.now(),
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        developer.log(
          logMessage,
          time: DateTime.now(),
        );
      }
    }
  }
}
