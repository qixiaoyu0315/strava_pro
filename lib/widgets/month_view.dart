import 'package:flutter/material.dart';
import 'month_grid.dart';

class MonthView extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final Map<String, bool> svgCache;
  final Function(DateTime) onDateSelected;
  final VoidCallback onMonthTap;
  final bool isAnimated;
  final Animation<double>? animation;

  const MonthView({
    Key? key,
    required this.month,
    required this.selectedDate,
    required this.displayedMonth,
    required this.svgCache,
    required this.onDateSelected,
    required this.onMonthTap,
    this.isAnimated = false,
    this.animation,
  }) : super(key: key);

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
          // 月份标题
          GestureDetector(
            onTap: onMonthTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: displayedMonth.year == month.year &&
                        displayedMonth.month == month.month
                    ? Colors.blue.withOpacity(0.1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${month.year}年${month.month}月',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: displayedMonth.year == month.year &&
                              displayedMonth.month == month.month
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: textColor,
                    size: 20,
                  ),
                ],
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
