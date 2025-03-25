import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late PageController _pageController;
  final Map<String, bool> _svgCache = {}; // 缓存 SVG 存在状态

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _pageController = PageController(initialPage: 1200); // 从中间开始，支持前后滑动
    _preloadSvgForMonth(_displayedMonth);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final difference = page - 1200;
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + difference,
      );
    });
    _preloadSvgForMonth(_displayedMonth);
    _pageController.jumpToPage(1200); // 重置到中间页
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(
            width: 300,
            height: 400,
            child: YearMonthPicker(
              initialDate: _displayedMonth,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _displayedMonth) {
      setState(() {
        _displayedMonth = picked;
      });
      _preloadSvgForMonth(_displayedMonth);
    }
  }

  List<DateTime?> _getDaysInMonth(DateTime month) {
    final List<DateTime?> days = [];
    
    // 获取上个月的最后几天
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    if (firstWeekday > 1) {
      final lastDayOfPrevMonth = DateTime(month.year, month.month, 0);
      for (int i = firstWeekday - 2; i >= 0; i--) {
        days.add(DateTime(
          lastDayOfPrevMonth.year,
          lastDayOfPrevMonth.month,
          lastDayOfPrevMonth.day - i,
        ));
      }
    }

    // 当前月的天数
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    // 下个月的开始几天
    final lastDayWeekday = DateTime(month.year, month.month, daysInMonth).weekday;
    if (lastDayWeekday < 7) {
      for (int i = 1; i <= 7 - lastDayWeekday; i++) {
        days.add(DateTime(month.year, month.month + 1, i));
      }
    }

    // 确保总是显示6周
    while (days.length < 42) {
      days.add(DateTime(
        month.year,
        month.month + 1,
        days.length - daysInMonth + 1,
      ));
    }

    return days;
  }

  Future<void> _preloadSvgForMonth(DateTime month) async {
    final List<DateTime?> days = _getDaysInMonth(month);
    for (final day in days) {
      if (day == null) continue;
      String formattedDate = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
      String svgPath = 'assets/$formattedDate';

      _svgCache[svgPath] = await _doesSvgExist(svgPath);
    }
    setState(() {});
  }

  Future<bool> _doesSvgExist(String assetPath) async {
    if (_svgCache.containsKey(assetPath)) {
      return _svgCache[assetPath]!;
    }
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final otherMonthTextColor = isDark ? Colors.white38 : Colors.black38;
    final weekdayTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _selectMonth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_displayedMonth.year}年${_displayedMonth.month}月',
                style: TextStyle(
                  fontSize: 20,
                  color: textColor,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: textColor),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('一', style: TextStyle(color: weekdayTextColor)),
                Text('二', style: TextStyle(color: weekdayTextColor)),
                Text('三', style: TextStyle(color: weekdayTextColor)),
                Text('四', style: TextStyle(color: weekdayTextColor)),
                Text('五', style: TextStyle(color: weekdayTextColor)),
                Text('六', style: TextStyle(color: Colors.blue)),
                Text('日', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical, // 改为垂直方向滑动
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final monthDiff = index - 1200;
                final currentMonth = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month + monthDiff,
                );
                return _buildMonthGrid(currentMonth, textColor, otherMonthTextColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month, Color textColor, Color otherMonthTextColor) {
    final days = _getDaysInMonth(month);
    
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final day = days[index];
        if (day == null) return const SizedBox();

        final isToday = day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day;
            
        final isSelected = day.year == _selectedDate.year &&
            day.month == _selectedDate.month &&
            day.day == _selectedDate.day;
            
        final isCurrentMonth = day.month == month.month;
        
        final isWeekend = day.weekday == 6 || day.weekday == 7;

        String formattedDate = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
        String svgPath = 'assets/$formattedDate';

        String assetToLoad = (_svgCache.containsKey(svgPath) && _svgCache[svgPath]!)
            ? svgPath
            : 'assets/calendar_icon.svg';

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = day;
            });
          },
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
                        : isCurrentMonth
                            ? isWeekend
                                ? isToday
                                    ? Colors.blue
                                    : day.weekday == 7
                                        ? Colors.red
                                        : Colors.blue
                                : textColor
                            : otherMonthTextColor,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
                if (isCurrentMonth)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SvgPicture.asset(
                        assetToLoad,
                        colorFilter: ColorFilter.mode(
                          isSelected ? Colors.white : Colors.green,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class YearMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const YearMonthPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<YearMonthPicker> {
  late int _selectedYear;
  late int _selectedMonth;
  late PageController _yearController;
  late PageController _monthController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _yearController = PageController(
      initialPage: _selectedYear - widget.firstDate.year,
      viewportFraction: 0.3,
    );
    _monthController = PageController(
      initialPage: _selectedMonth - 1,
      viewportFraction: 0.3,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Text('选择年份', style: TextStyle(fontSize: 16)),
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _yearController,
            onPageChanged: (int index) {
              setState(() {
                _selectedYear = widget.firstDate.year + index;
              });
            },
            itemCount: widget.lastDate.year - widget.firstDate.year + 1,
            itemBuilder: (context, index) {
              final year = widget.firstDate.year + index;
              return Center(
                child: Text(
                  '$year',
                  style: TextStyle(
                    fontSize: year == _selectedYear ? 24 : 16,
                    fontWeight: year == _selectedYear ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const Text('选择月份', style: TextStyle(fontSize: 16)),
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _monthController,
            onPageChanged: (int index) {
              setState(() {
                _selectedMonth = index + 1;
              });
            },
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              return Center(
                child: Text(
                  '$month月',
                  style: TextStyle(
                    fontSize: month == _selectedMonth ? 24 : 16,
                    fontWeight: month == _selectedMonth ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  DateTime(_selectedYear, _selectedMonth),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ],
    );
  }
}
