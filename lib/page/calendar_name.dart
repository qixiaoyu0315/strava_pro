import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

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
      duration: const Duration(milliseconds: 1200), // 从800ms增加到1200ms
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

    // 预加载默认图标
    await _preloadDefaultIcon();

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

  Future<void> _preloadDefaultIcon() async {
    // 不再需要预加载默认SVG，因为使用系统图标
    return;
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

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final otherMonthTextColor = isDark ? Colors.white38 : Colors.black38;
    final weekdayTextColor = isDark ? Colors.white54 : Colors.black54;

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
                child: Column(
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
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _loadedMonths.length,
                        itemBuilder: (context, index) {
                          final currentMonth = _loadedMonths[index];
                          return AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
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

                              return Transform.scale(
                                scale: 0.8 + (0.2 * itemAnimation.value),
                                child: Opacity(
                                  opacity: itemAnimation.value.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              height: 420,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => _selectMonth(currentMonth),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: _displayedMonth.year ==
                                                    currentMonth.year &&
                                                _displayedMonth.month ==
                                                    currentMonth.month
                                            ? Colors.blue.withOpacity(0.1)
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${currentMonth.year}年${currentMonth.month}月',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 16,
                                              fontWeight: _displayedMonth
                                                              .year ==
                                                          currentMonth.year &&
                                                      _displayedMonth.month ==
                                                          currentMonth.month
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
                                  ),
                                  Expanded(
                                    child: _buildMonthGrid(currentMonth,
                                        textColor, otherMonthTextColor),
                                  ),
                                ],
                              ),
                            ),
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

  Future<void> _selectMonth(DateTime initialMonth) async {
    final now = DateTime.now();
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(
            width: 300,
            height: 400,
            child: YearMonthPicker(
              initialDate: initialMonth,
              firstDate: DateTime(2000, 1),
              lastDate: DateTime(now.year, now.month),
            ),
          ),
        );
      },
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

    // 预加载所有新月份的SVG
    await Future.wait(monthsToAdd.map((month) => _preloadSvgForMonth(month)));
  }

  List<DateTime?> _getDaysInMonth(DateTime month) {
    final List<DateTime?> days = List.filled(42, null); // 保持42个格子的大小，但用null填充

    // 获取当月第一天是星期几
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;

    // 获取当月天数
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // 只添加当月的日期
    for (int i = 0; i < daysInMonth; i++) {
      days[firstWeekday - 1 + i] = DateTime(month.year, month.month, i + 1);
    }

    return days;
  }

  Widget _buildMonthGrid(
      DateTime month, Color textColor, Color otherMonthTextColor) {
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

        final isSelected = day.year == _selectedDate.year &&
            day.month == _selectedDate.month &&
            day.day == _selectedDate.day;

        final isWeekend = day.weekday == 6 || day.weekday == 7;

        // 构建日期格子
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

    // 如果SVG缓存中没有该日期，或者缓存显示该SVG不存在，使用默认笑脸图标
    if (!_svgCache.containsKey(svgPath) || !_svgCache[svgPath]!) {
      return Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: isSelected ? Colors.white : Colors.grey[400],
        size: 20,
      );
    }

    // 如果有对应的SVG图标，则使用SVG
    return SvgPicture.file(
      File(svgPath),
                                colorFilter: ColorFilter.mode(
                                  isSelected ? Colors.white : Colors.green,
                                  BlendMode.srcIn,
                                ),
      fit: BoxFit.contain,
    );
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

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      initialPage: widget.initialDate.year - widget.firstDate.year,
      viewportFraction: 0.3,
    );
    _monthController = PageController(
      initialPage: widget.initialDate.month - 1,
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
                    fontWeight: year == _selectedYear
                        ? FontWeight.bold
                        : FontWeight.normal,
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
                    fontWeight: month == _selectedMonth
                        ? FontWeight.bold
                        : FontWeight.normal,
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
