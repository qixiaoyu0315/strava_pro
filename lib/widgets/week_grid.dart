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

        return SizedBox(
          width: daySize,
          height: daySize,
          child: CalendarDay(
            date: day,
            selectedDate: selectedDate,
            isSelected: isSelected,
            hasSvg: _hasSvg(day),
            onTap: onDateSelected ?? (_) {},
          ),
        );
      }).toList(),
    );
  }
}
