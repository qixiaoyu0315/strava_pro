import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

class CalendarDay extends StatelessWidget {
  final DateTime date;
  final DateTime selectedDate;
  final bool isSelected;
  final bool hasSvg;
  final Function(DateTime) onTap;
  final bool isAnimated;
  final Animation<double>? animation;

  /// 日历天组件
  /// [date] 日期
  /// [selectedDate] 当前选中的日期
  /// [isSelected] 是否被选中
  /// [hasSvg] 是否有SVG图标
  /// [onTap] 点击回调
  /// [isAnimated] 是否使用动画
  /// [animation] 动画控制器
  const CalendarDay({
    Key? key,
    required this.date,
    required this.selectedDate,
    required this.isSelected,
    required this.hasSvg,
    required this.onTap,
    this.isAnimated = false,
    this.animation,
  }) : super(key: key);

  bool get _isToday {
    final now = DateTime.now();
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

  Widget _buildSvgIcon(bool isSelected) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final svgPath = '/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg';

    if (!hasSvg) {
      return Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: isSelected ? Colors.white : Colors.grey[400],
        size: 20,
      );
    }

    try {
      return SvgPicture.file(
        File(svgPath),
        colorFilter: ColorFilter.mode(
          isSelected ? Colors.white : Colors.green,
          BlendMode.srcIn,
        ),
        fit: BoxFit.contain,
      );
    } catch (e) {
      print('Error loading SVG: $e');
      return Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: isSelected ? Colors.white : Colors.grey[400],
        size: 20,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget dayWidget = GestureDetector(
      onTap: () => onTap(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : _isToday
                  ? Colors.blue.withOpacity(0.3)
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
                child: _buildSvgIcon(isSelected),
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
}
