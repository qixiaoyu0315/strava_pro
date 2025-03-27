import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import '../widgets/month_calendar.dart';
import '../widgets/month_picker.dart';
import '../widgets/horizontal_calendar.dart';

class CalendarPage extends StatefulWidget {
  final bool isHorizontalLayout;

  const CalendarPage({
    super.key,
    this.isHorizontalLayout = false,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late ScrollController _scrollController;
  final Map<String, bool> _svgCache = {}; // 缓存 SVG 存在状态
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

    // 初始化动画控制器，增加动画时长
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

    // 预加载最近三个月的SVG
    await Future.wait(_loadedMonths.map((month) => _preloadSvgForMonth(month)));

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

    // 批量预加载SVG
    await Future.wait(monthsToAdd.map((month) => _preloadSvgForMonth(month)));

    // 调整滚动位置以保持当前视图
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
          _scrollController.position.pixels + (420.0 * monthsToAdd.length));
    }
  }

  Future<void> _selectMonth(DateTime initialMonth) async {
    final now = DateTime.now();
    final result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return MonthPicker(
          initialDate: initialMonth,
          firstDate: DateTime(2000, 1),
          lastDate: DateTime(now.year, now.month),
          onMonthSelected: (DateTime date) {
            Navigator.pop(context, date);
          },
        );
      },
    );

    if (result != null && result != _displayedMonth) {
      // 检查是否需要加载选中月份之前的月份
      await _loadMonthsUntil(result);

      setState(() {
        _displayedMonth = result;
      });

      // 计算选中月份在列表中的位置
      final monthIndex = _loadedMonths
          .indexWhere((m) => m.year == result.year && m.month == result.month);

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

    // 预加载所有新月份的SVG
    await Future.wait(monthsToAdd.map((month) => _preloadSvgForMonth(month)));
  }

  Future<void> _preloadSvgForMonth(DateTime month) async {
    // 处理月份跨年的情况
    if (month.month == 0) {
      month = DateTime(month.year - 1, 12);
    } else if (month.month == 13) {
      month = DateTime(month.year + 1, 1);
    }

    final List<DateTime?> days = _getDaysInMonth(month);
    final List<Future<void>> preloadTasks = [];

    for (final day in days) {
      if (day == null) continue;
      String formattedDate =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
      String svgPath =
          '/storage/emulated/0/Download/strava_pro/svg/$formattedDate';

      if (!_svgCache.containsKey(svgPath)) {
        preloadTasks.add(_doesSvgExist(svgPath).then((exists) {
          _svgCache[svgPath] = exists;
        }));
      }
    }

    // 批量处理所有预加载任务
    await Future.wait(preloadTasks);

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _doesSvgExist(String filePath) async {
    if (_svgCache.containsKey(filePath)) {
      return _svgCache[filePath]!;
    }
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (_) {
      return false;
    }
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _animationController,
              curve: Curves.elasticOut,
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: widget.isHorizontalLayout
                    ? HorizontalCalendar(
                        initialDate: _selectedDate,
                        svgCache: _svgCache,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                      )
                    : Column(
                        children: [
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
                                Text('六',
                                    style: const TextStyle(color: Colors.blue)),
                                Text('日',
                                    style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _loadedMonths.length,
                              itemBuilder: (context, index) {
                                final currentMonth = _loadedMonths[index];
                                final delay =
                                    (index / _loadedMonths.length) * 0.5;
                                final itemAnimation = CurvedAnimation(
                                  parent: _animationController,
                                  curve: Interval(
                                    delay,
                                    delay + 0.5,
                                    curve: Curves.easeOutBack,
                                  ),
                                );

                                return MonthCalendar(
                                  month: currentMonth,
                                  selectedDate: _selectedDate,
                                  displayedMonth: _displayedMonth,
                                  onDateSelected: (date) {
                                    if (date.year == currentMonth.year &&
                                        date.month == currentMonth.month) {
                                      setState(() {
                                        _selectedDate = date;
                                      });
                                    } else {
                                      _selectMonth(date);
                                    }
                                  },
                                  svgCache: _svgCache,
                                  isAnimated: true,
                                  animation: itemAnimation,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
