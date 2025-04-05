import 'package:intl/intl.dart';

/// 日期工具类
class DateUtils {
  /// 获取包含指定日期的周的起始日期（周一）
  static DateTime getWeekStart(DateTime date) {
    // 确保使用本地时间
    final localDate = date.toLocal();
    // 获取当前日期是星期几 (1 = 周一, 7 = 周日)
    int weekday = localDate.weekday;

    // 计算到周一的偏移量
    int offset = weekday - 1;

    // 获取本周的周一日期
    return DateTime(localDate.year, localDate.month, localDate.day - offset);
  }

  /// 获取包含指定日期的周的结束日期（周日）
  static DateTime getWeekEnd(DateTime date) {
    DateTime weekStart = getWeekStart(date);
    // 周一 + 6天 = 周日
    return DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  }

  /// 格式化日期为指定格式
  static String formatDate(DateTime date, String format) {
    return DateFormat(format).format(date.toLocal());
  }

  /// 格式化周标题，例如：3月20日 - 3月26日
  static String formatWeekTitle(DateTime weekStart) {
    DateTime weekEnd = getWeekEnd(weekStart);
    return '${DateFormat('MM月dd日').format(weekStart.toLocal())} - ${DateFormat('MM月dd日').format(weekEnd.toLocal())}';
  }

  /// 解析日期字符串为DateTime对象
  static DateTime? parseDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return null;
    try {
      return DateTime.parse(dateTimeString).toLocal();
    } catch (e) {
      print('解析日期时间失败: $dateTimeString, 错误: $e');
      return null;
    }
  }
}
