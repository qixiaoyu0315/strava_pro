import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

class MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final Function(DateTime) onDateSelected;
  final Map<String, bool> svgCache;
  final bool isAnimated;
  final Animation<double>? animation;

  const MonthCalendar({
    Key? key,
    required this.month,
    required this.selectedDate,
    required this.displayedMonth,
    required this.onDateSelected,
    required this.svgCache,
    this.isAnimated = false,
    this.animation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final otherMonthTextColor = isDark ? Colors.white38 : Colors.black38;

    Widget monthContent = Container(
      height: 420,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildMonthHeader(context, textColor),
          Expanded(
            child: _buildMonthGrid(context, textColor, otherMonthTextColor),
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

  Widget _buildMonthHeader(BuildContext context, Color textColor) {
    return GestureDetector(
      onTap: () => onDateSelected(month),
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
    );
  }

  Widget _buildMonthGrid(
      BuildContext context, Color textColor, Color otherMonthTextColor) {
    final days = _getDaysInMonth(month);

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

        final isToday = day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day;

        final isSelected = day.year == selectedDate.year &&
            day.month == selectedDate.month &&
            day.day == selectedDate.day;

        final isWeekend = day.weekday == 6 || day.weekday == 7;

        return GestureDetector(
          onTap: () => onDateSelected(day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : isToday
                      ? Colors.blue.withOpacity(0.3)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.day.toString(),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isWeekend
                            ? isToday
                                ? Colors.blue
                                : day.weekday == 7
                                    ? Colors.red
                                    : Colors.blue
                            : textColor,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: _buildDayIcon(day, isSelected),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayIcon(DateTime day, bool isSelected) {
    String formattedDate =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
    String svgPath =
        '/storage/emulated/0/Download/strava_pro/svg/$formattedDate';

    if (!svgCache.containsKey(svgPath) || !svgCache[svgPath]!) {
      return Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: isSelected ? Colors.white : Colors.grey[400],
        size: 20,
      );
    }

    return SvgPicture.file(
      File(svgPath),
      colorFilter: ColorFilter.mode(
        isSelected ? Colors.white : Colors.green,
        BlendMode.srcIn,
      ),
      fit: BoxFit.contain,
    );
  }

  List<DateTime?> _getDaysInMonth(DateTime month) {
    final List<DateTime?> days = List.filled(42, null);

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int i = 0; i < daysInMonth; i++) {
      days[firstWeekday - 1 + i] = DateTime(month.year, month.month, i + 1);
    }

    return days;
  }
}
