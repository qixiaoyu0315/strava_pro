import 'package:flutter/material.dart';
import '../widgets/vertical_calendar.dart';
import '../widgets/horizontal_calendar.dart';
import '../widgets/calendar_utils.dart';

class CalendarPage extends StatefulWidget {
  final bool isHorizontalLayout;

  const CalendarPage({
    super.key,
    this.isHorizontalLayout = true,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late AnimationController _animationController;
  final Map<String, bool> _svgCache = {}; // 缓存 SVG 存在状态
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 初始化SVG缓存
    _initializeCalendar();
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果布局类型改变，重新应用动画
    if (oldWidget.isHorizontalLayout != widget.isHorizontalLayout) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _initializeCalendar() async {
    if (!mounted) return;

    // 预加载当前月份和前两个月的SVG，仅在垂直布局时需要
    if (!widget.isHorizontalLayout) {
      final now = DateTime.now();
      for (int i = -2; i <= 0; i++) {
        final month = DateTime(now.year, now.month + i);
        final monthCache = await CalendarUtils.preloadSvgForMonth(month);
        _svgCache.addAll(monthCache);
      }
    } else {
      // 对于水平布局，我们只预加载当前月份
      final now = DateTime.now();
      final monthCache = await CalendarUtils.preloadSvgForMonth(now);
      _svgCache.addAll(monthCache);
    }

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // 开始播放动画
    _animationController.forward();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
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
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: widget.isHorizontalLayout
              ? HorizontalCalendar(
                  key: const ValueKey('horizontal'),
                  svgCache: _svgCache,
                  onDateSelected: _onDateSelected,
                )
              : VerticalCalendar(
                  key: const ValueKey('vertical'),
                  svgCache: _svgCache,
                  onDateSelected: _onDateSelected,
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
