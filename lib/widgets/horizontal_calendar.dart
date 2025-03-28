import 'package:flutter/material.dart';
import 'month_view.dart';
import 'month_picker.dart';
import '../widgets/calendar_utils.dart';

class HorizontalCalendar extends StatefulWidget {
  final DateTime? initialMonth;
  final DateTime? selectedDate;
  final Function(DateTime)? onDateSelected;
  final Map<String, bool> svgCache;
  final bool isAnimated;

  const HorizontalCalendar({
    super.key,
    this.initialMonth,
    this.selectedDate,
    this.onDateSelected,
    required this.svgCache,
    this.isAnimated = false,
  });

  @override
  State<HorizontalCalendar> createState() => _HorizontalCalendarState();
}

class _HorizontalCalendarState extends State<HorizontalCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late PageController _pageController;
  late AnimationController _animationController;
  late int _totalMonths; // 显示的总月数

  // 用于存储当前可见月份的缓存
  final Map<int, Map<String, bool>> _monthSvgCaches = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.selectedDate ?? now;
    _displayedMonth = widget.initialMonth ?? DateTime(now.year, now.month);

    // 计算从2年前到当前月份的总月数
    final startDate = DateTime(now.year - 2, now.month);
    _totalMonths =
        (now.year - startDate.year) * 12 + now.month - startDate.month + 1;

    // 计算当前月份的索引
    final currentIndex =
        (now.year - startDate.year) * 12 + (now.month - startDate.month);

    // 初始化PageController
    _pageController = PageController(
      initialPage: currentIndex,
      viewportFraction: 1.0,
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 预加载当前月份的数据
    _loadMonthSvgData(currentIndex);

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 加载指定索引月份的SVG数据
  void _loadMonthSvgData(int monthIndex) {
    if (_monthSvgCaches.containsKey(monthIndex)) return;

    final now = DateTime.now();
    final startDate = DateTime(now.year - 2, now.month);
    final targetMonth = DateTime(
      startDate.year,
      startDate.month + monthIndex,
    );

    // 预加载数据
    CalendarUtils.preloadSvgForMonth(targetMonth).then((monthCache) {
      if (mounted) {
        setState(() {
          _monthSvgCaches[monthIndex] = Map.from(monthCache);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 检测是否是横屏模式
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    if (isLandscape) {
      // 横屏模式：并排显示两个月份
      return _buildLandscapeLayout();
    } else {
      // 竖屏模式：单月份翻页视图
      return _buildPortraitLayout();
    }
  }

  // 横屏布局：并排显示两个月
  Widget _buildLandscapeLayout() {
    final now = DateTime.now();
    final startDate = DateTime(now.year - 2, now.month);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // 并排显示两个月
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  // 预加载前后月份的数据
                  _loadMonthSvgData(index - 1);
                  _loadMonthSvgData(index);
                  _loadMonthSvgData(index + 1);

                  // 更新显示的月份
                  final month = DateTime(
                    startDate.year,
                    startDate.month + index,
                  );
                  setState(() {
                    _displayedMonth = month;
                  });
                },
                itemCount: _totalMonths,
                itemBuilder: (context, index) {
                  final month = DateTime(
                    startDate.year,
                    startDate.month + index,
                  );

                  // 如果是当前索引，显示当月和下个月
                  final nextMonth = DateTime(month.year, month.month + 1);

                  // 获取月份缓存
                  final monthCache = _monthSvgCaches[index] ?? widget.svgCache;
                  final nextMonthCache =
                      _monthSvgCaches[index + 1] ?? widget.svgCache;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 当前月
                      Expanded(
                        child: MonthView(
                          month: month,
                          selectedDate: _selectedDate,
                          onDateSelected: _selectDate,
                          svgCache: monthCache,
                          isCurrentMonth: month.year == now.year &&
                              month.month == now.month,
                          displayedMonth: _displayedMonth,
                          onMonthTap: _selectMonth,
                        ),
                      ),

                      // 分隔线
                      Container(
                        width: 1,
                        color: Colors.grey.withValues(alpha: 0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),

                      // 下个月
                      Expanded(
                        child: MonthView(
                          month: nextMonth,
                          selectedDate: _selectedDate,
                          onDateSelected: _selectDate,
                          svgCache: nextMonthCache,
                          isCurrentMonth: nextMonth.year == now.year &&
                              nextMonth.month == now.month,
                          displayedMonth: _displayedMonth,
                          onMonthTap: _selectMonth,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // 竖屏布局：单月份翻页视图
  Widget _buildPortraitLayout() {
    final now = DateTime.now();
    final startDate = DateTime(now.year - 2, now.month);

    return Column(
      children: [
        // 月份视图
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              // 预加载前后月份的数据
              _loadMonthSvgData(index - 1);
              _loadMonthSvgData(index);
              _loadMonthSvgData(index + 1);

              // 更新显示的月份
              final month = DateTime(
                startDate.year,
                startDate.month + index,
              );
              setState(() {
                _displayedMonth = month;
              });
            },
            itemCount: _totalMonths,
            itemBuilder: (context, index) {
              final month = DateTime(
                startDate.year,
                startDate.month + index,
              );

              // 获取月份缓存
              final monthCache = _monthSvgCaches[index] ?? widget.svgCache;

              return MonthView(
                month: month,
                selectedDate: _selectedDate,
                onDateSelected: _selectDate,
                svgCache: monthCache,
                isCurrentMonth:
                    month.year == now.year && month.month == now.month,
                displayedMonth: _displayedMonth,
                onMonthTap: _selectMonth,
              );
            },
          ),
        ),
      ],
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    // 安全调用回调
    widget.onDateSelected?.call(date);
  }

  void _selectMonth() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MonthPicker(
          initialDate: _displayedMonth,
          firstDate: DateTime(DateTime.now().year - 2),
          lastDate: DateTime(DateTime.now().year + 2),
          onMonthSelected: (DateTime date) {
            if (mounted) {
              setState(() {
                _displayedMonth = date;
              });
              // 选择月份后也更新选中的日期
              _selectDate(date);
            }
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
