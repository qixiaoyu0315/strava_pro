import 'package:shared_preferences/shared_preferences.dart';
import '../model/app_settings.dart';

class AppSettingsManager {
  static final AppSettingsManager _instance = AppSettingsManager._internal();
  
  factory AppSettingsManager() {
    return _instance;
  }
  
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
    );
    
    _cachedSettings = settings;
    return settings;
  }
  
  /// 保存应用设置
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isHorizontalLayout', settings.isHorizontalLayout);
    await prefs.setBool('isFullscreenMode', settings.isFullscreenMode);
    await prefs.setBool('useDynamicRefreshRate', settings.useDynamicRefreshRate);
    await prefs.setInt('displayMode', settings.displayMode);
    await prefs.setBool('routeFullscreenOverlay', settings.routeFullscreenOverlay);
    
    _cachedSettings = settings;
  }
  
  /// 更新路线导航覆盖模式设置
  Future<void> updateRouteFullscreenOverlay(bool value) async {
    final settings = await getSettings();
    final newSettings = settings.copyWith(routeFullscreenOverlay: value);
    await saveSettings(newSettings);
  }
  
  /// 清除缓存的设置
  void clearCache() {
    _cachedSettings = null;
  }
} 