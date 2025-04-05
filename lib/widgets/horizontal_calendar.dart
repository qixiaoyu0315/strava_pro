import 'package:flutter/material.dart';
import 'month_view.dart';
import 'month_picker.dart';
import '../widgets/calendar_utils.dart';
import '../service/activity_service.dart';
import 'monthly_stats_widget.dart';
import 'activity_list_dialog.dart';

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
  final ActivityService _activityService = ActivityService();

  // 用于存储当前可见月份的缓存
  final Map<int, Map<String, bool>> _monthSvgCaches = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toLocal();
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

  // 获取指定月份的索引
  int _getMonthIndex(DateTime month) {
    final now = DateTime.now().toLocal();
    final startDate = DateTime(now.year - 2, now.month);
    return (month.year - startDate.year) * 12 + (month.month - startDate.month);
  }

  // 加载指定索引月份的SVG数据
  void _loadMonthSvgData(int monthIndex) {
    if (_monthSvgCaches.containsKey(monthIndex)) return;

    final now = DateTime.now().toLocal();
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

    // 处理屏幕方向变化时PageController的释放与创建
    if (isLandscape) {
      // 横屏模式：使用主PageController
      return _buildLandscapeLayout();
    } else {
      // 竖屏模式：上方日历，下方统计
      return _buildPortraitLayout();
    }
  }

  // 横屏布局：左侧日历，右侧统计
  Widget _buildLandscapeLayout() {
    final now = DateTime.now().toLocal();
    final startDate = DateTime(now.year - 2, now.month);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // 日历和统计并排显示
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

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧当前月日历
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
                        color: Colors.grey.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),

                      // 右侧月度统计（添加SingleChildScrollView使内容可滚动）
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: MonthlyStatsWidget(
                              key: ValueKey('stats_${month.year}_${month.month}'),
                              month: month,
                              activityService: _activityService,
                              showCard: false,
                            ),
                          ),
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

  // 竖屏布局：上方日历，下方统计
  Widget _buildPortraitLayout() {
    final now = DateTime.now().toLocal();
    final startDate = DateTime(now.year - 2, now.month);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // 整个页面放在一个PageView中滑动
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

                  // 返回一个包含日历和统计的Column
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 上方当前月日历
                      SizedBox(
                        height: constraints.maxHeight * 0.58, // 占页面高度的62%
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
                        height: 1,
                        color: Colors.grey.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                      ),

                      // 下方月度统计（可滚动）
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: MonthlyStatsWidget(
                              key: ValueKey('stats_${month.year}_${month.month}'),
                              month: month,
                              activityService: _activityService,
                              showCard: false,
                            ),
                          ),
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

  void _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
    });
    
    // 安全调用回调
    widget.onDateSelected?.call(date);
    
    // 获取所选日期的年-月-日格式
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // 查询该日期的活动数据
    final activities = await _activityService.getActivitiesByDate(dateString);
    
    if (!mounted) return;
    
    // 如果有活动数据，显示弹窗
    if (activities.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ActivityListDialog(
            date: date,
            activities: activities,
          );
        },
      );
    }
  }

  void _selectMonth() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return MonthPicker(
          initialMonth: _displayedMonth,
          onMonthSelected: (DateTime selectedMonth) {
            Navigator.of(context).pop();
            final index = _getMonthIndex(selectedMonth);
            if (index >= 0 && index < _totalMonths) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        );
      },
    );
  }
}
