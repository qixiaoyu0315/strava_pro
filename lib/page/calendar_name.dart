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
  late ScrollController _scrollController;
  final Map<String, bool> _svgCache = {}; // 缓存 SVG 存在状态
  final List<DateTime> _loadedMonths = [];
  bool _isScrolling = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _displayedMonth = DateTime(now.year, now.month);
    
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
    await Future.wait(
      _loadedMonths.map((month) => _preloadSvgForMonth(month))
    );

    if (!mounted) return;
    
    setState(() {
      _isInitialized = true;
    });

    // 滚动到当前月份（最后一个）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _preloadDefaultIcon() async {
    try {
      await rootBundle.load('assets/calendar_icon.svg');
    } catch (e) {
      debugPrint('Failed to load default calendar icon: $e');
    }
  }

  void _onScroll() {
    if (!_isScrolling) {
      _isScrolling = true;
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          // 检测是否需要加载更多历史月份
          if (_scrollController.position.pixels < 500) {
            await _loadPreviousMonth();
          }
          
          // 更新当前显示的月份
          final visibleIndex = (_scrollController.position.pixels / 420.0).round();
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

  Future<void> _loadPreviousMonth() async {
    if (_loadedMonths.isEmpty) return;
    
    final firstMonth = _loadedMonths.first;
    final prevMonth = DateTime(firstMonth.year, firstMonth.month - 1);
    
    DateTime monthToAdd;
    if (prevMonth.month == 0) {
      monthToAdd = DateTime(prevMonth.year - 1, 12);
    } else {
      monthToAdd = prevMonth;
    }
    
    // 检查是否已经加载了这个月份
    if (_loadedMonths.any((m) => m.year == monthToAdd.year && m.month == monthToAdd.month)) {
      return;
    }
    
    setState(() {
      _loadedMonths.insert(0, monthToAdd);
    });
    
    // 预加载新月份的SVG
    await _preloadSvgForMonth(monthToAdd);
    
    // 调整滚动位置以保持当前视图
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.pixels + 420);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final otherMonthTextColor = isDark ? Colors.white38 : Colors.black38;
    final weekdayTextColor = isDark ? Colors.white54 : Colors.black54;

    // 如果还没有初始化完成，显示加载指示器
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
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
                  // 正向构建月份，最早的月份在顶部
                  final currentMonth = _loadedMonths[index];
                  
                  return Container(
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
                              color: _displayedMonth.year == currentMonth.year && 
                                    _displayedMonth.month == currentMonth.month
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
                                    fontWeight: _displayedMonth.year == currentMonth.year && 
                                              _displayedMonth.month == currentMonth.month
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
                          child: _buildMonthGrid(currentMonth, textColor, otherMonthTextColor),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
      final monthIndex = _loadedMonths.indexWhere(
        (m) => m.year == picked.year && m.month == picked.month
      );
      
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
    if (_loadedMonths.any((m) => m.year == targetMonth.year && m.month == targetMonth.month)) {
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
        currentMonth.month == 12 ? 1 : currentMonth.month + 1
      );
    }
    
    // 按时间顺序添加月份
    monthsToAdd = monthsToAdd.reversed.toList();
    
    // 批量加载月份
    setState(() {
      _loadedMonths.insertAll(0, monthsToAdd);
    });
    
    // 预加载所有新月份的SVG
    await Future.wait(
      monthsToAdd.map((month) => _preloadSvgForMonth(month))
    );
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

  Widget _buildMonthGrid(DateTime month, Color textColor, Color otherMonthTextColor) {
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
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
    String formattedDate = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
    String svgPath = 'assets/$formattedDate';
    
    // 如果SVG缓存中没有该日期，或者缓存显示该SVG不存在，使用默认图标
    String assetToLoad = (_svgCache.containsKey(svgPath) && _svgCache[svgPath]!)
        ? svgPath
        : 'assets/calendar_icon.svg';

    return SvgPicture.asset(
      assetToLoad,
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
    for (final day in days) {
      if (day == null) continue;
      String formattedDate = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
      String svgPath = 'assets/$formattedDate';

      if (!_svgCache.containsKey(svgPath)) {
        _svgCache[svgPath] = await _doesSvgExist(svgPath);
      }
    }
    if (mounted) {
      setState(() {});
    }
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
  void dispose() {
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
