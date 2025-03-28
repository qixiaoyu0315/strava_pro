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
    final currentMonthIndex =
        (now.year - startDate.year) * 12 + (now.month - startDate.month);

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
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDate = date;
                            });
                            widget.onDateSelected(date);
                          },
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
                        color: Colors.grey.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),

                      // 下个月
                      Expanded(
                        child: MonthView(
                          month: nextMonth,
                          selectedDate: _selectedDate,
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDate = date;
                            });
                            widget.onDateSelected(date);
                          },
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
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                  widget.onDateSelected(date);
                },
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

  // 显示月份选择器
  void _selectMonth() async {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    // 调整对话框大小以适应屏幕
    final dialogWidth =
        isLandscape ? screenSize.width * 0.4 : screenSize.width * 0.8;
    final dialogHeight =
        isLandscape ? screenSize.height * 0.6 : screenSize.height * 0.4;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          child: MonthPicker(
            initialDate: _displayedMonth,
            firstDate: DateTime(DateTime.now().year - 2, 1),
            lastDate: DateTime.now(),
            onMonthSelected: (date) {
              Navigator.of(context).pop(date);
            },
          ),
        ),
      ),
    );

    if (picked != null && mounted) {
      final now = DateTime.now();
      final startDate = DateTime(now.year - 2, now.month);
      final targetIndex = (picked.year - startDate.year) * 12 +
          (picked.month - startDate.month);

      // 滚动到选中的月份
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
}
