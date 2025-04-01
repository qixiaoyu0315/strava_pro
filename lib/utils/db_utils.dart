import 'package:sqflite/sqflite.dart';

/// 数据库工具类，用于处理SQLite数据类型转换
class DbUtils {
  /// 将对象转换为SQLite支持的格式（主要处理日期和布尔类型）
  static Map<String, dynamic> sanitizeForDb(Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is DateTime) {
        // DateTime转为ISO8601字符串
        result[key] = value.toIso8601String();
      } else if (value is bool) {
        // 布尔值转为0/1
        result[key] = value ? 1 : 0;
      } else if (value == null) {
        // null值可能会导致问题，根据具体情况处理
        // 这里选择不添加到结果中，依赖数据库默认值
      } else if (value is! String && value is! num && value is! List<int>) {
        // 如果不是SQLite支持的类型，转为字符串
        result[key] = value.toString();
      } else {
        // 其他SQLite原生支持的类型直接使用
        result[key] = value;
      }
    });

    return result;
  }

  /// 从DateTime转换为SQLite可接受的时间字符串
  static String? dateTimeToString(DateTime? dateTime) {
    if (dateTime == null) return null;
    return dateTime.toIso8601String();
  }

  /// 从字符串解析为DateTime（如果解析失败返回null）
  static DateTime? stringToDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      print('解析日期时间失败: $dateTimeString, 错误: $e');
      return null;
    }
  }

  /// 安全地执行数据库插入操作
  static Future<int> safeInsert(
      Database db, String table, Map<String, dynamic> values,
      {ConflictAlgorithm? conflictAlgorithm}) async {
    // 清理数据，确保所有值都是SQLite支持的类型
    final sanitizedValues = sanitizeForDb(values);
    return db.insert(table, sanitizedValues,
        conflictAlgorithm: conflictAlgorithm);
  }

  /// 安全地执行数据库更新操作
  static Future<int> safeUpdate(
      Database db, String table, Map<String, dynamic> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) async {
    // 清理数据，确保所有值都是SQLite支持的类型
    final sanitizedValues = sanitizeForDb(values);
    return db.update(table, sanitizedValues,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm);
  }
}
