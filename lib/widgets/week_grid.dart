import 'package:flutter/material.dart';
import 'calendar_day.dart';

class WeekGrid extends StatelessWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final Map<String, bool> svgCache;
  final Function(DateTime)? onDateSelected;
  final double daySize;

  const WeekGrid({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.svgCache,
    this.onDateSelected,
    this.daySize = 50.0,
  });

  /// 获取周的所有日期
  List<DateTime> _getDaysInWeek() {
    final List<DateTime> days = [];

    // 获取以星期一为起始的当前周的所有日期
    for (int i = 0; i < 7; i++) {
      days.add(DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + i,
      ));
    }

    return days;
  }

  bool _hasSvg(DateTime day) {
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return svgCache[dateStr] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInWeek();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.map((day) {
        final isSelected = day.year == selectedDate.year &&
            day.month == selectedDate.month &&
            day.day == selectedDate.day;

        // 为SVG图提供更大的空间
        return SizedBox(
          width: daySize,
          height: daySize * 2, // 高度增加为宽度的两倍，增大SVG显示空间
          child: Column(
            children: [
              // 日期文本
              Container(
                height: daySize * 0.4, // 占总高度的20%
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: day.day == DateTime.now().day &&
                                day.month == DateTime.now().month &&
                                day.year == DateTime.now().year ||
                            isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getDateColor(context, day, isSelected),
                  ),
                ),
              ),
              // SVG路线图，占更大空间
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: _buildSvgIcon(context, day, isSelected),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 获取日期颜色
  Color _getDateColor(BuildContext context, DateTime date, bool isSelected) {
    if (isSelected) {
      return Colors.blue;
    }

    // 周末颜色
    if (date.weekday == 6) {
      // 周六
      return Theme.of(context).colorScheme.primary;
    } else if (date.weekday == 7) {
      // 周日
      return Colors.red;
    }

    // 普通日期颜色
    return Theme.of(context).colorScheme.onSurface;
  }

  // 构建SVG图标
  Widget _buildSvgIcon(BuildContext context, DateTime date, bool isSelected) {
    return CalendarDay(
      date: date,
      selectedDate: selectedDate,
      isSelected: isSelected,
      hasSvg: _hasSvg(date),
      onTap: onDateSelected ?? (_) {},
      svgSizeFactor: 1.8, // 增大SVG图标尺寸
    );
  }
}
