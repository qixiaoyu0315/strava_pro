import 'package:flutter/material.dart';

import 'month_view.dart';
import 'month_picker.dart';
import '../widgets/calendar_utils.dart';

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

  // 用于存储当前可见月份的缓存
  final Map<int, Map<String, bool>> _monthSvgCaches = {};


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

    // 计算当前月份的索引
    final currentMonthIndex =
        (now.year - startDate.year) * 12 + (now.month - startDate.month);

    // 初始化PageController
    _pageController = PageController(
      initialPage: currentMonthIndex,

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

    // 预加载当前月份的数据
    _loadMonthSvgData(currentMonthIndex);

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }


  // 根据索引获取对应的月份
  DateTime _getMonthFromIndex(int index) {
    final now = DateTime.now();
    final startDate = DateTime(now.year - 2, now.month);
    return DateTime(startDate.year, startDate.month + index);
  }

  // 加载指定月份的SVG数据
  Future<void> _loadMonthSvgData(int monthIndex) async {
    // 如果已经加载过，则跳过
    if (_monthSvgCaches.containsKey(monthIndex)) {
      return;
    }

    final month = _getMonthFromIndex(monthIndex);

    // 先从全局缓存中查找该月的数据
    Map<String, bool> monthCache = {};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final dateStr =
          '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      if (widget.svgCache.containsKey(dateStr)) {
        monthCache[dateStr] = widget.svgCache[dateStr]!;
      } else {
        // 如果全局缓存中没有，则从文件系统加载
        monthCache[dateStr] = await CalendarUtils.doesSvgExist(dateStr);
      }
    }

    if (mounted) {
      setState(() {
        _monthSvgCaches[monthIndex] = monthCache;
      });
    }
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
      // 计算选择的月份索引
      final startDate = DateTime(now.year - 2, now.month);
      final monthIndex = (picked.year - startDate.year) * 12 +
          (picked.month - startDate.month);

      if (monthIndex >= 0 && monthIndex < _totalMonths) {
        // 确保该月份的数据已加载
        await _loadMonthSvgData(monthIndex);

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

              final newMonth = _getMonthFromIndex(index);
              setState(() {
                _displayedMonth = newMonth;
              });

              // 加载当前月份的数据
              _loadMonthSvgData(index);

              // 预加载下一个月的数据（如果不是最后一个月）
              if (index < _totalMonths - 1) {
                _loadMonthSvgData(index + 1);
              }

              // 预加载上一个月的数据（如果不是第一个月）
              if (index > 0) {
                _loadMonthSvgData(index - 1);
              }

              _animationController.forward(from: 0.0);
            },
            itemCount: _totalMonths,
            itemBuilder: (context, index) {
              final month = _getMonthFromIndex(index);
              // 使用缓存的SVG数据，如果还没加载则使用空Map
              final svgCache = _monthSvgCaches[index] ?? {};

              return MonthView(
                month: month,
                selectedDate: _selectedDate,
                displayedMonth: _displayedMonth,
                svgCache: svgCache,

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
