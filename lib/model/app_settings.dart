class AppSettings {
  final bool isHorizontalLayout;
  final bool isFullscreenMode;
  final bool useDynamicRefreshRate;
  final int displayMode;
  final bool routeFullscreenOverlay; // 路线导航全屏覆盖模式
  final bool useRainbowColors; // 日历SVG彩虹线条模式
  final int svgColor; // 自定义SVG颜色（非彩虹模式下使用）

  AppSettings({
    this.isHorizontalLayout = false,
    this.isFullscreenMode = false,
    this.useDynamicRefreshRate = true,
    this.displayMode = 0,
    this.routeFullscreenOverlay = false, // 默认为false，使用常规布局
    this.useRainbowColors = false, // 默认为false，使用单色
    this.svgColor = 0xFF00C853, // 默认为绿色
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isHorizontalLayout: json['isHorizontalLayout'] ?? false,
      isFullscreenMode: json['isFullscreenMode'] ?? false,
      useDynamicRefreshRate: json['useDynamicRefreshRate'] ?? true,
      displayMode: json['displayMode'] ?? 0,
      routeFullscreenOverlay: json['routeFullscreenOverlay'] ?? false,
      useRainbowColors: json['useRainbowColors'] ?? false,
      svgColor: json['svgColor'] ?? 0xFF00C853,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isHorizontalLayout': isHorizontalLayout,
      'isFullscreenMode': isFullscreenMode,
      'useDynamicRefreshRate': useDynamicRefreshRate,
      'displayMode': displayMode,
      'routeFullscreenOverlay': routeFullscreenOverlay,
      'useRainbowColors': useRainbowColors,
      'svgColor': svgColor,
    };
  }

  AppSettings copyWith({
    bool? isHorizontalLayout,
    bool? isFullscreenMode,
    bool? useDynamicRefreshRate,
    int? displayMode,
    bool? routeFullscreenOverlay,
    bool? useRainbowColors,
    int? svgColor,
  }) {
    return AppSettings(
      isHorizontalLayout: isHorizontalLayout ?? this.isHorizontalLayout,
      isFullscreenMode: isFullscreenMode ?? this.isFullscreenMode,
      useDynamicRefreshRate: useDynamicRefreshRate ?? this.useDynamicRefreshRate,
      displayMode: displayMode ?? this.displayMode,
      routeFullscreenOverlay: routeFullscreenOverlay ?? this.routeFullscreenOverlay,
      useRainbowColors: useRainbowColors ?? this.useRainbowColors,
      svgColor: svgColor ?? this.svgColor,
    );
  }
} 