import 'dart:io';

class CalendarUtils {
  /// 检查SVG文件是否存在
  static Future<bool> doesSvgExist(String dateStr) async {
    final svgPath = '/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg';
    try {
      final file = File(svgPath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// 格式化日期为字符串
  static String formatDateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取SVG文件路径
  static String getSvgPath(String dateStr) {
    return '/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg';
  }

  /// 批量预加载一个月份的SVG状态
  static Future<Map<String, bool>> preloadSvgForMonth(DateTime month) async {
    final Map<String, bool> svgCache = {};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final dateStr =
          '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      svgCache[dateStr] = await doesSvgExist(dateStr);
    }

    return svgCache;
  }
}
