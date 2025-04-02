import 'dart:io';
import '../utils/logger.dart';

/// 日历PNG相关工具类，提供PNG文件存在性检查和预加载功能
class CalendarPngUtils {
  // PNG文件路径
  static const String _pngPath = '/storage/emulated/0/Download/strava_pro/png';

  /// 检查某个日期的PNG文件是否存在
  static Future<bool> doesPngExist(String dateStr) async {
    try {
      final file = File('$_pngPath/$dateStr.png');
      return await file.exists();
    } catch (e) {
      Logger.e('检查PNG文件存在时出错', error: e, tag: 'Calendar');
      return false;
    }
  }

  /// 预加载指定月份的所有PNG文件状态
  static Future<Map<String, bool>> preloadPngForMonth(DateTime month) async {
    final Map<String, bool> monthCache = {};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final dateStr =
          '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      monthCache[dateStr] = await doesPngExist(dateStr);
    }

    return monthCache;
  }

  /// 格式化日期为字符串
  static String formatDateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取PNG文件路径
  static String getPngPath(String dateStr) {
    return '$_pngPath/$dateStr.png';
  }
} 