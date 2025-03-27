import 'package:flutter/material.dart';
import 'month_view.dart';
import 'month_picker.dart';

class HorizontalCalendar extends StatefulWidget {
  final Map<String, bool> svgCache;
  final Function(DateTime) onDateSelected;

  const HorizontalCalendar({
    Key? key,
    required this.svgCache,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<HorizontalCalendar> createState() => _HorizontalCalendarState();
}

class _HorizontalCalendarState extends State<HorizontalCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late int _totalMonths; // 显示的总月数
  final List<DateTime> _months = []; // 所有可用月份

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _displayedMonth = DateTime(now.year, now.month);

    // 计算从2年前到当前月份的总月数
    final startDate = DateTime(now.year - 2, now.month);
    _totalMonths =
        (now.year - startDate.year) * 12 + now.month - startDate.month + 1;

    // 生成所有月份
    for (int i = 0; i < _totalMonths; i++) {
      final month = DateTime(startDate.year, startDate.month + i);
      _months.add(month);
    }

    // 计算初始页面索引
    final initialIndex = _months.indexWhere((month) =>
        month.year == _displayedMonth.year &&
        month.month == _displayedMonth.month);

    _pageController = PageController(
      initialPage: initialIndex,
      viewportFraction: 1.0,
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectMonth(DateTime initialMonth) async {
    final now = DateTime.now();
    final DateTime? picked = await MonthPicker.show(
      context,
      initialDate: initialMonth,
      firstDate: DateTime(now.year - 2, now.month),
      lastDate: DateTime(now.year, now.month),
    );

    if (picked != null) {
      // 找到选择的月份索引
      final monthIndex = _months.indexWhere(
          (month) => month.year == picked.year && month.month == picked.month);

      if (monthIndex != -1) {
        _pageController.animateToPage(
          monthIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 星期标题行
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('一',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              Text('二',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              Text('三',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              Text('四',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              Text('五',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              Text('六', style: const TextStyle(color: Colors.blue)),
              Text('日', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
        // 月份PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final newMonth = _months[index];
              setState(() {
                _displayedMonth = newMonth;
              });
              _animationController.forward(from: 0.0);
            },
            itemCount: _months.length,
            itemBuilder: (context, index) {
              final month = _months[index];

              return MonthView(
                month: month,
                selectedDate: _selectedDate,
                displayedMonth: _displayedMonth,
                svgCache: widget.svgCache,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                  widget.onDateSelected(date);
                },
                onMonthTap: () => _selectMonth(month),
                isAnimated: true,
                animation: _animation,
              );
            },
          ),
        ),
      ],
    );
  }
}
