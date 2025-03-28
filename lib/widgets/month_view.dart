import 'package:flutter/material.dart';
import 'month_grid.dart';

class MonthView extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final Map<String, bool> svgCache;
  final VoidCallback onMonthTap;
  final bool isCurrentMonth;
  final DateTime displayedMonth;
  final bool isAnimated;
  final Animation<double>? animation;

  const MonthView({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
    required this.svgCache,
    required this.onMonthTap,
    this.isCurrentMonth = false,
    required this.displayedMonth,
    this.isAnimated = false,
    this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    Widget monthContent = Container(
      height: 420,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // 简化的月份标题，只显示月份数据
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            alignment: Alignment.center,
            child: Text(
              '${month.year}年${month.month}月',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: (displayedMonth.year == month.year &&
                            displayedMonth.month == month.month) ||
                        isCurrentMonth
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),
          // 月份网格
          Expanded(
            child: MonthGrid(
              month: month,
              selectedDate: selectedDate,
              svgCache: svgCache,
              onDateSelected: onDateSelected,
              isAnimated: isAnimated,
              animation: animation,
            ),
          ),
        ],
      ),
    );

    if (isAnimated && animation != null) {
      return AnimatedBuilder(
        animation: animation!,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * animation!.value),
            child: Opacity(
              opacity: animation!.value.clamp(0.0, 1.0),
              child: monthContent,
            ),
          );
        },
      );
    }

    return monthContent;
  }
}
