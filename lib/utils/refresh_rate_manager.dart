import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

/// 高刷新率管理器 - 用于适配不同刷新率的设备
class RefreshRateManager {
  static final RefreshRateManager _instance = RefreshRateManager._();
  
  /// 用户设置的高刷新率模式 (自动，始终开启，始终关闭)
  static const String kAuto = 'auto';
  static const String kAlwaysOn = 'always_on';
  static const String kAlwaysOff = 'always_off';
  
  /// 配置存储键
  static const String _prefKey = 'high_refresh_rate_mode';
  
  /// 默认配置
  String _currentMode = kAuto;
  
  /// 设备是否支持高刷新率
  bool _deviceSupportsHighRefreshRate = false;
  
  /// 获取单例实例
  static RefreshRateManager get instance => _instance;
  
  /// 私有构造函数
  RefreshRateManager._();
  
  /// 获取当前模式
  String get currentMode => _currentMode;
  
  /// 获取设备是否支持高刷新率
  bool get deviceSupportsHighRefreshRate => _deviceSupportsHighRefreshRate;
  
  /// 初始化管理器
  Future<void> initialize() async {
    try {
      // 检测设备是否支持高刷新率
      _deviceSupportsHighRefreshRate = await _checkDeviceSupport();
      
      // 加载用户配置
      await _loadSettings();
      
      // 应用刷新率设置
      await applySettings();
      
      Logger.d('高刷新率管理器初始化成功: 设备支持高刷新率: $_deviceSupportsHighRefreshRate, 当前模式: $_currentMode', 
          tag: 'RefreshRate');
    } catch (e) {
      Logger.e('高刷新率管理器初始化失败', error: e, tag: 'RefreshRate');
      // 出错时使用默认配置
      _currentMode = kAuto;
    }
  }
  
  /// 检测设备是否支持高刷新率
  Future<bool> _checkDeviceSupport() async {
    try {
      // 尝试获取设备的刷新率
      final displayRefreshRate = await _getDeviceRefreshRate();
      
      // 如果刷新率大于60，则认为设备支持高刷新率
      return displayRefreshRate > 60;
    } catch (e) {
      Logger.e('检测设备刷新率失败', error: e, tag: 'RefreshRate');
      return false;
    }
  }
  
  /// 获取设备刷新率
  Future<double> _getDeviceRefreshRate() async {
    try {
      const channel = MethodChannel('com.example.strava_pro/refresh_rate');
      final refreshRate = await channel.invokeMethod<double>('getRefreshRate');
      return refreshRate ?? 60.0;
    } catch (e) {
      Logger.e('获取设备刷新率失败', error: e, tag: 'RefreshRate');
      // 如果无法获取，则默认为60Hz
      return 60.0;
    }
  }
  
  /// 加载用户设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentMode = prefs.getString(_prefKey) ?? kAuto;
    } catch (e) {
      Logger.e('加载高刷新率设置失败', error: e, tag: 'RefreshRate');
      _currentMode = kAuto;
    }
  }
  
  /// 设置高刷新率模式
  Future<void> setMode(String mode) async {
    if (mode != kAuto && mode != kAlwaysOn && mode != kAlwaysOff) {
      throw ArgumentError('无效的高刷新率模式: $mode');
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode);
      
      _currentMode = mode;
      
      // 应用新的设置
      await applySettings();
      
      Logger.d('设置高刷新率模式: $mode', tag: 'RefreshRate');
    } catch (e) {
      Logger.e('设置高刷新率模式失败', error: e, tag: 'RefreshRate');
      throw Exception('设置高刷新率模式失败: ${e.toString()}');
    }
  }
  
  /// 应用刷新率设置
  Future<void> applySettings() async {
    if (!_deviceSupportsHighRefreshRate) {
      // 如果设备不支持高刷新率，使用标准刷新率
      await _setStandardRefreshRate();
      return;
    }
    
    switch (_currentMode) {
      case kAuto:
        // 自动模式下，根据电池状态和性能考虑决定刷新率
        await _applyAutoMode();
        break;
      case kAlwaysOn:
        // 始终启用高刷新率
        await _setHighRefreshRate();
        break;
      case kAlwaysOff:
        // 始终禁用高刷新率
        await _setStandardRefreshRate();
        break;
      default:
        // 默认使用自动模式
        await _applyAutoMode();
    }
  }
  
  /// 应用自动模式
  Future<void> _applyAutoMode() async {
    try {
      // 在自动模式下检查电池状态和其他因素，决定是否使用高刷新率
      final shouldUseHighRefreshRate = await _shouldUseHighRefreshRateInAutoMode();
      
      if (shouldUseHighRefreshRate) {
        await _setHighRefreshRate();
      } else {
        await _setStandardRefreshRate();
      }
    } catch (e) {
      Logger.e('应用自动刷新率模式失败', error: e, tag: 'RefreshRate');
      // 错误时回退到标准刷新率
      await _setStandardRefreshRate();
    }
  }
  
  /// 在自动模式下决定是否使用高刷新率
  Future<bool> _shouldUseHighRefreshRateInAutoMode() async {
    try {
      const channel = MethodChannel('com.example.strava_pro/device_status');
      final batteryLevel = await channel.invokeMethod<int>('getBatteryLevel') ?? 100;
      final isCharging = await channel.invokeMethod<bool>('isCharging') ?? false;
      final isPowerSaveMode = await channel.invokeMethod<bool>('isPowerSaveMode') ?? false;
      
      // 如果是省电模式，不使用高刷新率
      if (isPowerSaveMode) {
        Logger.d('设备处于省电模式，使用标准刷新率', tag: 'RefreshRate');
        return false;
      }
      
      // 如果正在充电，使用高刷新率
      if (isCharging) {
        Logger.d('设备正在充电，使用高刷新率', tag: 'RefreshRate');
        return true;
      }
      
      // 如果电池电量低于30%，使用标准刷新率
      if (batteryLevel < 30) {
        Logger.d('电池电量低 ($batteryLevel%)，使用标准刷新率', tag: 'RefreshRate');
        return false;
      }
      
      // 其他情况下使用高刷新率
      Logger.d('自动模式下决定使用高刷新率', tag: 'RefreshRate');
      return true;
    } catch (e) {
      Logger.e('检查设备状态失败', error: e, tag: 'RefreshRate');
      // 错误情况下默认返回true (使用高刷新率)
      return true;
    }
  }
  
  /// 设置高刷新率
  Future<void> _setHighRefreshRate() async {
    try {
      const channel = MethodChannel('com.example.strava_pro/refresh_rate');
      await channel.invokeMethod<void>('setHighRefreshRate');
      Logger.d('已设置高刷新率模式', tag: 'RefreshRate');
    } catch (e) {
      Logger.e('设置高刷新率失败', error: e, tag: 'RefreshRate');
    }
  }
  
  /// 设置标准刷新率 (60Hz)
  Future<void> _setStandardRefreshRate() async {
    try {
      const channel = MethodChannel('com.example.strava_pro/refresh_rate');
      await channel.invokeMethod<void>('setStandardRefreshRate');
      Logger.d('已设置标准刷新率模式', tag: 'RefreshRate');
    } catch (e) {
      Logger.e('设置标准刷新率失败', error: e, tag: 'RefreshRate');
    }
  }
} 