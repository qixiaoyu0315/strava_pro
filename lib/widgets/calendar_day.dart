import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../utils/logger.dart';
import '../utils/app_settings_manager.dart';

class CalendarDay extends StatelessWidget {
  final DateTime date;
  final DateTime selectedDate;
  final bool isSelected;
  final bool hasSvg;
  final Function(DateTime) onTap;
  final bool isAnimated;
  final Animation<double>? animation;
  final double svgSizeFactor;

  /// 日历天组件
  /// [date] 日期
  /// [selectedDate] 当前选中的日期
  /// [isSelected] 是否被选中
  /// [hasSvg] 是否有SVG图标
  /// [onTap] 点击回调
  /// [isAnimated] 是否使用动画
  /// [animation] 动画控制器
  /// [svgSizeFactor] SVG图标尺寸因子
  const CalendarDay({
    super.key,
    required this.date,
    required this.selectedDate,
    required this.isSelected,
    required this.hasSvg,
    required this.onTap,
    this.isAnimated = false,
    this.animation,
    this.svgSizeFactor = 1.0,
  });

  bool get _isToday {
    final now = DateTime.now().toLocal();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get _isWeekend => date.weekday == 6 || date.weekday == 7;

  Color _getDateColor(BuildContext context) {
    if (isSelected) {
      return Colors.white;
    }
    if (_isWeekend) {
      return date.weekday == 6 ? Colors.blue : Colors.red;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  // 获取彩虹颜色
  Color _getRainbowColor(int weekday, bool isSelected) {
    if (isSelected) {
      return Colors.white;
    }
    
    // 七彩颜色，对应星期一到星期日，使用更鲜艳的颜色
    switch (weekday) {
      case 1: return const Color(0xFFFF1744);     // 周一 - 亮红色
      case 2: return const Color(0xFFFF9100);     // 周二 - 亮橙色
      case 3: return const Color(0xFFFFEA00);     // 周三 - 亮黄色
      case 4: return const Color(0xFF00C853);     // 周四 - 亮绿色
      case 5: return const Color(0xFF2979FF);     // 周五 - 亮蓝色
      case 6: return const Color(0xFF651FFF);     // 周六 - 亮靛蓝色
      case 7: return const Color(0xFFD500F9);     // 周日 - 亮紫色
      default: return const Color(0xFF00C853);    // 默认颜色 - 亮绿色
    }
  }

  Widget _buildSvgIcon(bool isSelected, bool useRainbowColors) {
    final localDate = date.toLocal();
    final dateStr =
        '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    final svgPath = '/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg';

    if (!hasSvg) {
      return Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: isSelected ? Colors.white : Colors.grey[400],
        size: 20 * svgSizeFactor,
      );
    }

    try {
      return SvgPicture.file(
        File(svgPath),
        colorFilter: ColorFilter.mode(
          useRainbowColors 
              ? _getRainbowColor(date.weekday, isSelected)
              : isSelected ? Colors.white : Colors.green,
          BlendMode.srcIn,
        ),
        fit: BoxFit.contain,
      );
    } catch (e) {
      Logger.e('SVG加载失败', error: e, tag: 'Calendar');
      return Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: isSelected ? Colors.white : Colors.grey[400],
        size: 20 * svgSizeFactor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      // 获取彩虹线条模式设置
      future: AppSettingsManager().getSettings().then((settings) => settings.useRainbowColors),
      builder: (context, snapshot) {
        final useRainbowColors = snapshot.data ?? false;
        
        Widget dayWidget = GestureDetector(
          onTap: () => onTap(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : _isToday
                      ? Colors.blue.withValues(alpha: 0.3)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: _getDateColor(context),
                    fontWeight: _isToday || isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: _buildSvgIcon(isSelected, useRainbowColors),
                  ),
                ),
              ],
            ),
          ),
        );

        if (isAnimated && animation != null) {
          return ScaleTransition(
            scale: animation!,
            child: dayWidget,
          );
        }

        return dayWidget;
      }
    );
  }
}
