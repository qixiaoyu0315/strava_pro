import 'package:flutter/material.dart';
import 'calendar_day.dart';

class MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Map<String, bool> svgCache;
  final Function(DateTime) onDateSelected;
  final bool isAnimated;
  final Animation<double>? animation;

  const MonthGrid({
    Key? key,
    required this.month,
    required this.selectedDate,
    required this.svgCache,
    required this.onDateSelected,
    this.isAnimated = false,
    this.animation,
  }) : super(key: key);

  /// 获取月份的所有日期
  List<DateTime?> _getDaysInMonth() {
    final List<DateTime?> days = List.filled(42, null);

    // 获取当月第一天是星期几
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;

    // 获取当月天数
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // 只添加当月的日期
    for (int i = 0; i < daysInMonth; i++) {
      days[firstWeekday - 1 + i] = DateTime(month.year, month.month, i + 1);
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
    final days = _getDaysInMonth();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final day = days[index];
        if (day == null) return const SizedBox();

        final isSelected = day.year == selectedDate.year &&
            day.month == selectedDate.month &&
            day.day == selectedDate.day;

        return CalendarDay(
          date: day,
          selectedDate: selectedDate,
          isSelected: isSelected,
          hasSvg: _hasSvg(day),
          onTap: onDateSelected,
          isAnimated: isAnimated,
          animation: animation,
        );
      },
    );
  }
}
