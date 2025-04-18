class AppSettings {
  final bool isHorizontalLayout;
  final bool isFullscreenMode;
  final bool useDynamicRefreshRate;
  final int displayMode;
  final bool routeFullscreenOverlay; // 路线导航全屏覆盖模式

  AppSettings({
    this.isHorizontalLayout = false,
    this.isFullscreenMode = false,
    this.useDynamicRefreshRate = true,
    this.displayMode = 0,
    this.routeFullscreenOverlay = false, // 默认为false，使用常规布局
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isHorizontalLayout: json['isHorizontalLayout'] ?? false,
      isFullscreenMode: json['isFullscreenMode'] ?? false,
      useDynamicRefreshRate: json['useDynamicRefreshRate'] ?? true,
      displayMode: json['displayMode'] ?? 0,
      routeFullscreenOverlay: json['routeFullscreenOverlay'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isHorizontalLayout': isHorizontalLayout,
      'isFullscreenMode': isFullscreenMode,
      'useDynamicRefreshRate': useDynamicRefreshRate,
      'displayMode': displayMode,
      'routeFullscreenOverlay': routeFullscreenOverlay,
    };
  }

  AppSettings copyWith({
    bool? isHorizontalLayout,
    bool? isFullscreenMode,
    bool? useDynamicRefreshRate,
    int? displayMode,
    bool? routeFullscreenOverlay,
  }) {
    return AppSettings(
      isHorizontalLayout: isHorizontalLayout ?? this.isHorizontalLayout,
      isFullscreenMode: isFullscreenMode ?? this.isFullscreenMode,
      useDynamicRefreshRate: useDynamicRefreshRate ?? this.useDynamicRefreshRate,
      displayMode: displayMode ?? this.displayMode,
      routeFullscreenOverlay: routeFullscreenOverlay ?? this.routeFullscreenOverlay,
    );
  }
} 