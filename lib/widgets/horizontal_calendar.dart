import 'package:flutter/material.dart';
import 'month_calendar.dart';

class HorizontalCalendar extends StatefulWidget {
  final DateTime initialDate;
  final Map<String, bool> svgCache;
  final Function(DateTime) onDateSelected;

  const HorizontalCalendar({
    Key? key,
    required this.initialDate,
    required this.svgCache,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<HorizontalCalendar> createState() => _HorizontalCalendarState();
}

class _HorizontalCalendarState extends State<HorizontalCalendar>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final List<DateTime> _months = [];
  final int _totalMonths = 48; // 显示4年的月份

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month);

    // 生成月份列表
    final now = DateTime.now();
    final startMonth = DateTime(now.year - 2, now.month); // 从2年前开始
    for (int i = 0; i < _totalMonths; i++) {
      _months.add(DateTime(
        startMonth.year,
        startMonth.month + i,
      ));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _displayedMonth = _months[index];
              });
              _animationController.forward(from: 0.0);
            },
            itemCount: _months.length,
            itemBuilder: (context, index) {
              return MonthCalendar(
                month: _months[index],
                selectedDate: _selectedDate,
                displayedMonth: _displayedMonth,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                  widget.onDateSelected(date);
                },
                svgCache: widget.svgCache,
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
