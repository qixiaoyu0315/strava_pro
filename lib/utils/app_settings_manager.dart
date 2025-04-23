import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../model/app_settings.dart';

class AppSettingsManager {
  static final AppSettingsManager _instance = AppSettingsManager._internal();
  
  factory AppSettingsManager() {
    return _instance;
  }
  
  // 创建一个事件流控制器，用于通知设置变更
  final StreamController<String> _eventController = StreamController<String>.broadcast();

  // 设置变更的事件类型
  static const String EVENT_RAINBOW_COLORS_CHANGED = 'rainbow_colors_changed';
  static const String EVENT_SVG_COLOR_CHANGED = 'svg_color_changed';
  static const String EVENT_LAYOUT_CHANGED = 'layout_changed';
  static const String EVENT_FULLSCREEN_CHANGED = 'fullscreen_changed';
  static const String EVENT_SETTINGS_CHANGED = 'settings_changed';
  static const String EVENT_ACTIVITIES_SYNCED = 'activities_synced';
  
  // 提供一个getter来获取事件流
  Stream<String> get events => _eventController.stream;
  
  AppSettingsManager._internal();
  
  AppSettings? _cachedSettings;
  
  /// 获取应用设置
  Future<AppSettings> getSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(
      isHorizontalLayout: prefs.getBool('isHorizontalLayout') ?? true,
      isFullscreenMode: prefs.getBool('isFullscreenMode') ?? false,
      useDynamicRefreshRate: prefs.getBool('useDynamicRefreshRate') ?? true,
      displayMode: prefs.getInt('displayMode') ?? 0,
      routeFullscreenOverlay: prefs.getBool('routeFullscreenOverlay') ?? false,
      useRainbowColors: prefs.getBool('useRainbowColors') ?? false,
      svgColor: prefs.getInt('svgColor') ?? 0xFF00C853,
    );
    
    _cachedSettings = settings;
    return settings;
  }
  
  /// 保存应用设置
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final oldSettings = _cachedSettings;
    
    await prefs.setBool('isHorizontalLayout', settings.isHorizontalLayout);
    await prefs.setBool('isFullscreenMode', settings.isFullscreenMode);
    await prefs.setBool('useDynamicRefreshRate', settings.useDynamicRefreshRate);
    await prefs.setInt('displayMode', settings.displayMode);
    await prefs.setBool('routeFullscreenOverlay', settings.routeFullscreenOverlay);
    await prefs.setBool('useRainbowColors', settings.useRainbowColors);
    await prefs.setInt('svgColor', settings.svgColor);
    
    _cachedSettings = settings;
    
    // 检查是否有设置变更，并发送相应的事件
    if (oldSettings != null) {
      if (oldSettings.useRainbowColors != settings.useRainbowColors) {
        _eventController.add(EVENT_RAINBOW_COLORS_CHANGED);
      }
      if (oldSettings.svgColor != settings.svgColor) {
        _eventController.add(EVENT_SVG_COLOR_CHANGED);
      }
      if (oldSettings.isHorizontalLayout != settings.isHorizontalLayout) {
        _eventController.add(EVENT_LAYOUT_CHANGED);
      }
      if (oldSettings.isFullscreenMode != settings.isFullscreenMode) {
        _eventController.add(EVENT_FULLSCREEN_CHANGED);
      }
    }
    
    // 始终发送设置变更事件
    _eventController.add(EVENT_SETTINGS_CHANGED);
  }
  
  /// 更新路线导航覆盖模式设置
  Future<void> updateRouteFullscreenOverlay(bool value) async {
    final settings = await getSettings();
    final newSettings = settings.copyWith(routeFullscreenOverlay: value);
    await saveSettings(newSettings);
  }
  
  /// 更新彩虹线条模式设置
  Future<void> updateRainbowColors(bool value) async {
    final settings = await getSettings();
    final newSettings = settings.copyWith(useRainbowColors: value);
    await saveSettings(newSettings);
  }
  
  /// 更新SVG颜色设置
  Future<void> updateSvgColor(int colorValue) async {
    final settings = await getSettings();
    final newSettings = settings.copyWith(svgColor: colorValue);
    await saveSettings(newSettings);
  }
  
  /// 清除缓存的设置
  void clearCache() {
    _cachedSettings = null;
  }
  
  /// 关闭事件流
  void dispose() {
    _eventController.close();
  }
  
  /// 通知活动同步完成
  void notifyActivitiesSynced() {
    _eventController.add(EVENT_ACTIVITIES_SYNCED);
  }
} 