import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/vertical_calendar.dart';
import '../widgets/horizontal_calendar.dart';
import '../widgets/calendar_utils.dart';
import '../utils/app_settings_manager.dart';

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
  late AnimationController _animationController;
  final Map<String, bool> _svgCache = {}; // 缓存 SVG 存在状态
  bool _isInitialized = false;
  StreamSubscription<String>? _settingsSubscription;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 初始化SVG缓存
    _initializeCalendar();
    
    // 监听设置变更事件
    _settingsSubscription = AppSettingsManager().events.listen((event) {
      // 当彩虹线条设置或SVG颜色更改时，自动刷新页面
      if (event == AppSettingsManager.EVENT_RAINBOW_COLORS_CHANGED ||
          event == AppSettingsManager.EVENT_SVG_COLOR_CHANGED ||
          event == AppSettingsManager.EVENT_ACTIVITIES_SYNCED) {
        // 强制重新渲染日历页面
        if (mounted) {
          // 显示刷新指示器
          setState(() {
            _isInitialized = false;
          });
          
          // 重新初始化日历
          _initializeCalendar();
        }
      }
    });
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
    
    // 清空缓存，确保获取最新状态
    _svgCache.clear();

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
    _animationController.reset();
    _animationController.forward();
  }

  void _onDateSelected(DateTime date) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.elasticOut,
                ),
                child: const CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
              const Text('正在刷新日历...')
            ],
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
                  key: const ValueKey('horizontal-calendar'),
                  svgCache: _svgCache,
                  onDateSelected: _onDateSelected,
                )
              : VerticalCalendar(
                  key: const ValueKey('vertical-calendar'),
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
    _settingsSubscription?.cancel();
    super.dispose();
  }
}
