import 'package:flutter/material.dart';
import 'month_view.dart';
import 'month_picker.dart';
import '../widgets/calendar_utils.dart';

class VerticalCalendar extends StatefulWidget {
  final DateTime? initialMonth;
  final DateTime? selectedDate;
  final Function(DateTime)? onDateSelected;
  final Map<String, bool> svgCache;
  final bool isAnimated;

  const VerticalCalendar({
    super.key,
    this.initialMonth,
    this.selectedDate,
    this.onDateSelected,
    required this.svgCache,
    this.isAnimated = false,
  });

  @override
  State<VerticalCalendar> createState() => _VerticalCalendarState();
}

class _VerticalCalendarState extends State<VerticalCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // 存储当前已加载月份的SVG数据
  final Map<String, Map<String, bool>> _monthSvgCaches = {};

  // 存储已加载的月份列表
  final List<DateTime> _loadedMonths = [];

  // 存储可见的月份widget
  final Map<String, Widget> _monthWidgets = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.selectedDate ?? now;
    _displayedMonth = widget.initialMonth ?? DateTime(now.year, now.month);

    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 初始加载当前月和前一个月
    _initializeMonths();

    _animationController.forward();
  }

  Future<void> _initializeMonths() async {
    final now = DateTime.now();

    // 加载当月
    await _loadMonthData(DateTime(now.year, now.month));

    // 加载前一个月
    await _loadMonthData(DateTime(now.year, now.month - 1));

    if (mounted) {
      setState(() {
        // 更新状态以触发重建
      });
    }
  }

  void _scrollListener() {
    // 当滚动到底部时尝试加载更多月份
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreMonths();
    }
  }

  Future<void> _loadMoreMonths() async {
    if (_loadedMonths.isEmpty) return;

    // 获取最早的月份并加载之前的月份
    final earliestMonth = _loadedMonths.reduce((a, b) => a.isBefore(b) ? a : b);

    // 加载前一个月
    final prevMonth = DateTime(earliestMonth.year, earliestMonth.month - 1);

    await _loadMonthData(prevMonth);

    if (mounted) {
      setState(() {
        // 更新状态以显示新加载的月份
      });
    }
  }

  // 加载特定月份的数据
  Future<void> _loadMonthData(DateTime month) async {
    final monthKey = '${month.year}-${month.month}';

    // 如果已经加载，则跳过
    if (_monthSvgCaches.containsKey(monthKey)) {
      return;
    }

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
        _monthSvgCaches[monthKey] = monthCache;

        // 如果是新月份，则添加到加载月份列表
        if (!_loadedMonths
            .any((m) => m.year == month.year && m.month == month.month)) {
          _loadedMonths.add(month);

          // 按日期排序，较新的月份在前面
          _loadedMonths.sort((a, b) => b.compareTo(a));
        }

        // 构建该月的widget
        _buildMonthWidget(month);
      });
    }
  }

  // 构建月份Widget并缓存
  void _buildMonthWidget(DateTime month) {
    final monthKey = '${month.year}-${month.month}';
    final monthCache = _monthSvgCaches[monthKey] ?? {};

    _monthWidgets[monthKey] = Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: MonthView(
        month: month,
        selectedDate: _selectedDate,
        displayedMonth: _displayedMonth,
        svgCache: monthCache,
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
          });
          widget.onDateSelected?.call(date);
        },
        onMonthTap: () => _selectMonth(month),
        isAnimated: widget.isAnimated,
        animation: _animation,
      ),
    );
  }

  Future<void> _selectMonth(DateTime initialMonth) async {
    if (!mounted) return;

    final now = DateTime.now();
    final DateTime? picked = await MonthPicker.show(
      context,
      initialDate: initialMonth,
      firstDate: DateTime(now.year - 2, now.month),
      lastDate: DateTime(now.year, now.month),
    );

    if (picked != null && mounted) {
      // 确保我们有选择的月份数据
      await _loadMonthData(picked);

      if (mounted) {
        setState(() {
          _displayedMonth = picked;
        });

        // 滚动到选择的月份
        _scrollToMonth(picked);
      }
    }
  }

  void _scrollToMonth(DateTime month) {
    // 查找目标月份在列表中的位置
    final monthIndex = _loadedMonths
        .indexWhere((m) => m.year == month.year && m.month == month.month);

    if (monthIndex != -1) {
      // 计算滚动位置（粗略估计）
      final targetPosition = monthIndex * 350.0;

      // 滚动到目标位置
      _scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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
        // 月份列表
        Expanded(
          child: _loadedMonths.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _loadedMonths.length,
                  itemBuilder: (context, index) {
                    final month = _loadedMonths[index];
                    final monthKey = '${month.year}-${month.month}';
                    return _monthWidgets[monthKey] ?? Container();
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
