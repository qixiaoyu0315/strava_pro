import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 日志工具类，用于记录应用程序运行时的日志信息
class Logger {
  /// 记录调试级别的日志信息
  static void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('DEBUG', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录信息级别的日志信息
  static void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('INFO', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录警告级别的日志信息
  static void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('WARN', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录错误级别的日志信息
  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 记录日志的内部实现方法
  static void _log(String level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final now = DateTime.now();
    final timeString = '${now.hour}:${now.minute}:${now.second}.${now.millisecond}';
    final tagString = tag != null ? '[$tag]' : '';
    
    final logMessage = '[$timeString] $level$tagString: $message';
    
    // 在控制台输出日志信息
    developer.log(
      logMessage,
      time: now,
      name: tag ?? 'App',
      error: error,
      stackTrace: stackTrace,
    );
    
    // 同时也在控制台打印，便于在设备上查看
    print(logMessage);
    if (error != null) {
      print('Error: $error');
    }
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }
}
