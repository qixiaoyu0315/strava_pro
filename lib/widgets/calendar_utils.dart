import 'dart:io';
import '../utils/logger.dart';
import '../utils/date_utils.dart';

/// 日历相关工具类，提供SVG文件存在性检查和预加载功能
class CalendarUtils {
  // SVG文件路径
  static const String _svgPath = '/storage/emulated/0/Download/strava_pro/svg';

  /// 检查某个日期的SVG文件是否存在
  static Future<bool> doesSvgExist(String dateStr) async {
    try {
      final file = File('$_svgPath/$dateStr.svg');
      return await file.exists();
    } catch (e) {
      Logger.e('检查SVG文件存在时出错', error: e, tag: 'Calendar');
      return false;
    }
  }

  /// 预加载指定月份的所有SVG文件状态
  static Future<Map<String, bool>> preloadSvgForMonth(DateTime month) async {
    final Map<String, bool> monthCache = {};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day).toLocal();
      final dateStr = DateUtils.formatStandardDate(date);
      monthCache[dateStr] = await doesSvgExist(dateStr);
    }

    return monthCache;
  }

  /// 格式化日期为字符串
  static String formatDateToString(DateTime date) {
    return DateUtils.formatStandardDate(date);
  }

  /// 获取SVG文件路径
  static String getSvgPath(String dateStr) {
    return '$_svgPath/$dateStr.svg';
  }
}
