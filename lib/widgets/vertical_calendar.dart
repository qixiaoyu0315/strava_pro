import 'package:flutter/material.dart';
import 'month_view.dart';
import 'month_picker.dart';
import 'dart:io';

class VerticalCalendar extends StatefulWidget {
  final Map<String, bool> svgCache;
  final Function(DateTime) onDateSelected;

  const VerticalCalendar({
    Key? key,
    required this.svgCache,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<VerticalCalendar> createState() => _VerticalCalendarState();
}

class _VerticalCalendarState extends State<VerticalCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late ScrollController _scrollController;
  final List<DateTime> _loadedMonths = [];
  bool _isScrolling = false;
  bool _isInitialized = false;

  // 添加动画控制器
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _displayedMonth = DateTime(now.year, now.month);

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 初始化加载最近三个月
    _initializeMonths();

    // 初始化ScrollController并添加监听
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // 延迟初始化以等待布局完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCalendar();
    });
  }

  void _initializeMonths() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    // 添加当前月份和前两个月（按时间正序添加）
    for (int i = -2; i <= 0; i++) {
      final month = DateTime(currentMonth.year, currentMonth.month + i);
      if (month.month == 0) {
        _loadedMonths.add(DateTime(month.year - 1, 12));
      } else if (month.month == 13) {
        _loadedMonths.add(DateTime(month.year + 1, 1));
      } else {
        _loadedMonths.add(month);
      }
    }
  }

  Future<void> _initializeCalendar() async {
    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // 开始播放动画
    _animationController.forward();

    // 滚动到当前月份（最后一个）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _onScroll() {
    if (!_isScrolling) {
      _isScrolling = true;

      // 使用防抖，减少滚动过程中的计算频率
      Future.delayed(const Duration(milliseconds: 150), () async {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          // 提前预加载，避免滚动时卡顿
          if (_scrollController.position.pixels < 1000) {
            // 批量加载多个月份，减少频繁加载
            await _loadPreviousMonths(3); // 一次加载3个月
          }

          // 更新当前显示的月份，使用节流避免频繁更新
          final visibleIndex =
              (_scrollController.position.pixels / 420.0).round();
          if (visibleIndex >= 0 && visibleIndex < _loadedMonths.length) {
            final newDisplayedMonth = _loadedMonths[visibleIndex];
            if (newDisplayedMonth.year != _displayedMonth.year ||
                newDisplayedMonth.month != _displayedMonth.month) {
              setState(() {
                _displayedMonth = newDisplayedMonth;
              });
            }
          }
        }
        _isScrolling = false;
      });
    }
  }

  Future<void> _loadPreviousMonths(int count) async {
    if (_loadedMonths.isEmpty) return;

    final firstMonth = _loadedMonths.first;
    List<DateTime> monthsToAdd = [];

    // 计算需要加载的月份
    for (int i = 1; i <= count; i++) {
      final prevMonth = DateTime(firstMonth.year, firstMonth.month - i);
      DateTime monthToAdd;

      if (prevMonth.month == 0) {
        monthToAdd = DateTime(prevMonth.year - 1, 12);
      } else if (prevMonth.month < 0) {
        final yearOffset = (prevMonth.month.abs() / 12).ceil();
        final newMonth = 12 - (prevMonth.month.abs() % 12);
        monthToAdd = DateTime(prevMonth.year - yearOffset, newMonth);
      } else {
        monthToAdd = prevMonth;
      }

      // 检查是否已经加载了这个月份
      if (!_loadedMonths.any(
          (m) => m.year == monthToAdd.year && m.month == monthToAdd.month)) {
        monthsToAdd.add(monthToAdd);
      }
    }

    if (monthsToAdd.isEmpty) return;

    // 按照从新到旧的顺序排序月份
    monthsToAdd.sort((a, b) => a.compareTo(b));

    // 批量更新状态
    setState(() {
      _loadedMonths.insertAll(0, monthsToAdd);
    });

    // 调整滚动位置以保持当前视图
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
          _scrollController.position.pixels + (420.0 * monthsToAdd.length));
    }
  }

  Future<void> _selectMonth(DateTime initialMonth) async {
    final now = DateTime.now();
    final DateTime? picked = await MonthPicker.show(
      context,
      initialDate: initialMonth,
      firstDate: DateTime(2000, 1),
      lastDate: DateTime(now.year, now.month),
    );

    if (picked != null && picked != _displayedMonth) {
      // 检查是否需要加载选中月份之前的月份
      await _loadMonthsUntil(picked);

      setState(() {
        _displayedMonth = picked;
      });

      // 计算选中月份在列表中的位置
      final monthIndex = _loadedMonths
          .indexWhere((m) => m.year == picked.year && m.month == picked.month);

      if (monthIndex != -1) {
        // 滚动到选中的月份
        _scrollController.animateTo(
          monthIndex * 420.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _loadMonthsUntil(DateTime targetMonth) async {
    if (_loadedMonths.isEmpty) return;

    // 检查目标月份是否已加载
    if (_loadedMonths.any(
        (m) => m.year == targetMonth.year && m.month == targetMonth.month)) {
      return;
    }

    // 计算需要加载的月份
    final firstLoadedMonth = _loadedMonths.first;
    final monthsDiff = (firstLoadedMonth.year - targetMonth.year) * 12 +
        (firstLoadedMonth.month - targetMonth.month);

    if (monthsDiff <= 0) return; // 目标月份在已加载月份之后，无需加载

    // 逐个加载月份直到目标月份
    DateTime currentMonth = targetMonth;
    List<DateTime> monthsToAdd = [];

    while (currentMonth.year != firstLoadedMonth.year ||
        currentMonth.month != firstLoadedMonth.month) {
      monthsToAdd.add(currentMonth);
      currentMonth = DateTime(
          currentMonth.year + (currentMonth.month == 12 ? 1 : 0),
          currentMonth.month == 12 ? 1 : currentMonth.month + 1);
    }

    // 按时间顺序添加月份
    monthsToAdd = monthsToAdd.reversed.toList();

    // 批量加载月份
    setState(() {
      _loadedMonths.insertAll(0, monthsToAdd);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
          ),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // 星期标题行
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('一',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      Text('二',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      Text('三',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      Text('四',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      Text('五',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color)),
                      Text('六', style: const TextStyle(color: Colors.blue)),
                      Text('日', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                // 月份列表
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _loadedMonths.length,
                    itemBuilder: (context, index) {
                      final currentMonth = _loadedMonths[index];
                      final delay = (index / _loadedMonths.length) * 0.5;
                      final itemAnimation = CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          delay,
                          delay + 0.5,
                          curve: Curves.easeOutBack,
                        ),
                      );

                      return MonthView(
                        month: currentMonth,
                        selectedDate: _selectedDate,
                        displayedMonth: _displayedMonth,
                        svgCache: widget.svgCache,
                        onDateSelected: (date) {
                          if (date.year == currentMonth.year &&
                              date.month == currentMonth.month) {
                            setState(() {
                              _selectedDate = date;
                            });
                            widget.onDateSelected(date);
                          } else {
                            _selectMonth(date);
                          }
                        },
                        onMonthTap: () => _selectMonth(currentMonth),
                        isAnimated: true,
                        animation: itemAnimation,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
