import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/api_key_model.dart';
import '../model/athlete_model.dart';
import '../service/strava_client_manager.dart';
import '../utils/poly2svg.dart';
import '../utils/logger.dart';
import '../service/activity_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/calendar_exporter.dart';
import '../utils/widget_manager.dart';
import '../utils/date_utils.dart' as date_util;
import '../page/map_cache_page.dart';
import '../page/strava_api_page.dart';
import '../main.dart';
import '../utils/refresh_rate_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../service/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_settings_manager.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class SettingPage extends StatefulWidget {
  final Function(bool)? onLayoutChanged;
  final bool isAuthenticated;
  final DetailedAthlete? athlete;
  final Function(bool, DetailedAthlete?)? onAuthenticationChanged;

  const SettingPage({
    super.key,
    this.onLayoutChanged,
    this.isAuthenticated = false,
    this.athlete,
    this.onAuthenticationChanged,
  });

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage>
    with SingleTickerProviderStateMixin {
  TokenResponse? token;
  DetailedAthlete? _athlete;
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  String _syncMessage = ''; // 同步消息显示
  final Map<String, bool> _processedDates = {};
  String? _lastSyncTime;
  String? _lastActivitySyncTime;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  final AthleteModel _athleteModel = AthleteModel();
  final ActivityService _activityService = ActivityService();
  bool _isHorizontalLayout = true;

  // 新增显示模式相关变量
  bool _isFullscreenMode = false; // 是否使用全屏模式
  bool _routeFullscreenOverlay = false; // 是否启用路线导航全屏覆盖模式
  bool _useRainbowColors = false; // 是否启用彩虹线条模式
  int _svgColor = 0xFF00C853; // SVG颜色值，默认为绿色

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _athleteName;
  String? _athleteAvatar;
  int _activityCount = 0;
  double _totalDistance = 0.0; // 活动总公里数
  double _totalElevation = 0.0; // 活动总爬升
  double _totalKilojoules = 0.0; // 活动总能量
  int _totalMovingTime = 0; // 活动总时间（秒）
  Map<String, Map<String, dynamic>> _statsByType = {}; // 按活动类型分组的统计数据
  Map<String, dynamic>? _syncStatusMap;

  // 在_SettingPageState类中添加字段
  DateTime _selectedWeekStart =
      date_util.DateUtils.getWeekStart(DateTime.now());
  // 添加月历选择日期
  DateTime _selectedMonthDate = DateTime(DateTime.now().year, DateTime.now().month);
  
  // 应用版本信息
  String _appVersion = '';
  String _buildNumber = '';
  bool _isCheckingUpdate = false;
  bool _updateAvailable = false;
  final AppUpdateService _updateService = AppUpdateService();
  Map<String, dynamic>? _updateInfo;
  Timer? _updateCheckTimer;

  // 当前高刷新率模式
  String _refreshRateMode = RefreshRateManager.kAuto;
  // 设备是否支持高刷新率
  bool _deviceSupportsHighRefreshRate = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadSettings();

    // 调试和修复数据库问题
    _debugAndFixDatabase().then((_) {
      // 完成调试和修复后再加载数据
      _loadLastSyncTime();
      _loadLastActivitySyncTime();
      _loadAthleteFromDatabase();
    });

    // 使用外部传入的认证状态和运动员信息
    if (widget.isAuthenticated && widget.athlete != null) {
      setState(() {
        _athlete = widget.athlete;
        token = StravaClientManager().token;
      });
    }

    _checkAuthStatus();
    _loadActivityCount();
    _loadTotalDistance();
    _loadTotalElevation();
    _loadTotalKilojoules();
    _loadTotalMovingTime();
    _loadStatsByActivityType();
    _loadSyncStatus();
    
    // 获取当前应用版本信息
    _loadAppVersionInfo();
    
    // 只在设置界面检查更新，不再自动弹出提示
    _checkForUpdateSilently();
  }
  
  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }
  
  // 加载应用版本信息
  Future<void> _loadAppVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
        });
      }
    } catch (e) {
      Logger.e('获取应用版本信息失败', error: e, tag: 'AppUpdate');
    }
  }
  
  // 静默检查更新
  Future<void> _checkForUpdateSilently() async {
    try {
      if (_isCheckingUpdate) return;
      
      setState(() {
        _isCheckingUpdate = true;
      });
      
      _updateInfo = await _updateService.checkForUpdate();
      if (mounted) {
        setState(() {
          _updateAvailable = _updateInfo != null;
          _isCheckingUpdate = false;
        });
      }
    } catch (e) {
      Logger.e('检查更新失败', error: e, tag: 'AppUpdate');
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }
  
  // 手动检查更新并显示结果
  Future<void> _checkForUpdate({bool showResult = true}) async {
    try {
      if (_isCheckingUpdate) return;
      
      setState(() {
        _isCheckingUpdate = true;
      });
      
      _updateInfo = await _updateService.checkForUpdate();
      
      if (mounted) {
        setState(() {
          _updateAvailable = _updateInfo != null;
          _isCheckingUpdate = false;
        });
        
        if (showResult) {
          if (_updateAvailable && _updateInfo != null) {
            _showUpdateDialog(_updateInfo!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('当前已是最新版本')),
            );
          }
        }
      }
    } catch (e) {
      Logger.e('检查更新失败', error: e, tag: 'AppUpdate');
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
        if (showResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败: $e')),
          );
        }
      }
    }
  }

  @override
  void didUpdateWidget(SettingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当认证状态或用户信息从外部变化时更新内部状态
    if (widget.isAuthenticated != oldWidget.isAuthenticated ||
        widget.athlete != oldWidget.athlete) {
      setState(() {
        if (widget.isAuthenticated && widget.athlete != null) {
          _athlete = widget.athlete;
          token = StravaClientManager().token;
          _isAuthenticated = true;
          
          // 加载相关数据
          _loadLastSyncTime();
          _loadLastActivitySyncTime();
          _loadActivityCount();
          _loadTotalDistance();
          _loadTotalElevation();
          _loadTotalKilojoules();
          _loadTotalMovingTime();
          _loadStatsByActivityType();
          _loadSyncStatus();
        } else {
          _athlete = null;
          token = null;
          _isAuthenticated = false;
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isHorizontalLayout = prefs.getBool('isHorizontalLayout') ?? true;
      _isFullscreenMode = prefs.getBool('isFullscreenMode') ?? false;
      _routeFullscreenOverlay = prefs.getBool('routeFullscreenOverlay') ?? false;
      _useRainbowColors = prefs.getBool('useRainbowColors') ?? false;
      _svgColor = prefs.getInt('svgColor') ?? 0xFF00C853;
    });

    // 根据设置应用全屏模式
    _applyFullscreenMode();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isHorizontalLayout', _isHorizontalLayout);
    await prefs.setBool('isFullscreenMode', _isFullscreenMode);
    await prefs.setBool('routeFullscreenOverlay', _routeFullscreenOverlay);
    await prefs.setBool('useRainbowColors', _useRainbowColors);
    await prefs.setInt('svgColor', _svgColor);
    widget.onLayoutChanged?.call(_isHorizontalLayout);
  }

  // 新增：应用全屏模式方法
  void _applyFullscreenMode() {
    if (_isFullscreenMode) {
      // 启用全屏模式，隐藏状态栏和导航栏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      // 恢复正常模式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // 新增：切换全屏模式
  void _toggleFullscreenMode(bool value) {
    setState(() {
      _isFullscreenMode = value;
    });
    _saveSettings();
    _applyFullscreenMode();

    // 全屏模式变化后更新小组件 - 因为这可能影响系统UI状态
    WidgetManager.updateCalendarWidget().then((success) {
      if (success) {
        Logger.d('全屏模式切换后成功更新小组件', tag: 'SettingPage');
      } else {
        Logger.w('全屏模式切换后更新小组件失败', tag: 'SettingPage');
      }
    });
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _apiKeyModel.getApiKey();
    if (apiKey != null) {
      setState(() {
        _idController.text = apiKey['api_id']!;
        _keyController.text = apiKey['api_key']!;
      });
    }
  }

  Future<void> _loadLastSyncTime() async {
    final lastSyncTime = await _athleteModel.getLastSyncTime();
    if (lastSyncTime != null && mounted) {
      setState(() {
        _lastSyncTime = lastSyncTime;
      });
    }
  }

  Future<void> _loadLastActivitySyncTime() async {
    final lastActivitySyncTime = await _athleteModel.getLastActivitySyncTime();
    if (lastActivitySyncTime != null && mounted) {
      setState(() {
        _lastActivitySyncTime = lastActivitySyncTime;
      });
    }
  }

  Future<void> _loadAthleteFromDatabase() async {
    if (_athlete != null) return;

    final athleteData = await _athleteModel.getAthlete();
    if (athleteData != null && mounted) {
      try {
        // 使用现有的DetailedAthlete对象，然后添加数据库中的信息
        final athlete = DetailedAthlete.fromJson({
          'id': athleteData['id'],
          'resource_state': athleteData['resource_state'],
          'firstname': athleteData['firstname'],
          'lastname': athleteData['lastname'],
          'profile_medium': athleteData['profile_medium'],
          'profile': athleteData['profile'],
          'city': athleteData['city'],
          'state': athleteData['state'],
          'country': athleteData['country'],
          'sex': athleteData['sex'],
          'premium': athleteData['summit'] == 1,
          'follower_count': athleteData['follower_count'],
          'friend_count': athleteData['friend_count'],
          'measurement_preference': athleteData['measurement_preference'],
          'ftp': athleteData['ftp'],
          'weight': athleteData['weight'],
          // 确保时间字段是字符串类型
          'created_at': athleteData['created_at'] ?? '',
          'updated_at': athleteData['updated_at'] ?? '',
          // 添加必需的其他字段，使用默认值
          'username': '',
          'badge_type_id': 0,
          'friend': false,
          'follower': false,
          'mutual_friend_count': 0,
          'athlete_type': 0,
          'date_preference': '',
          'clubs': [],
        });

        setState(() {
          _athlete = athlete;
        });

        Logger.d('从数据库成功加载运动员信息', tag: 'AthleteDb');
      } catch (e) {
        Logger.e('从数据库加载运动员信息失败', error: e, tag: 'AthleteDb');
      }
    } else {
      Logger.d('数据库中没有运动员信息', tag: 'AthleteDb');
    }
  }

  void showErrorMessage(dynamic error, dynamic stackTrace) {
    if (!mounted) return;

    Widget content;
    String title;

    if (error is Fault) {
      title = "认证错误";
      content = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("错误信息: ${error.message}"),
            Divider(),
            if (error.errors != null && error.errors!.isNotEmpty) ...[
              Text("详细信息:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ...error.errors!
                  .map((e) => Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("代码: ${e.code ?? '未知'}"),
                            Text("资源: ${e.resource ?? '未知'}"),
                            Text("字段: ${e.field ?? '未知'}"),
                          ],
                        ),
                      ))
                  .toList(),
            ] else
              Text("无详细错误信息"),
          ],
        ),
      );
    } else {
      title = "发生错误";
      content = SingleChildScrollView(
        child: Text(error.toString()),
      );
    }

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: content,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("关闭"),
                ),
              ],
            ));
  }

  Future<void> _loadAthleteInfo({bool isSync = false}) async {
    try {
      if (isSync) {
        setState(() {
          _syncStatus = '正在获取运动员信息...';
        });
      }

      final athlete = await StravaClientManager()
          .stravaClient
          .athletes
          .getAuthenticatedAthlete();

      if (mounted) {
        setState(() {
          _athlete = athlete;
        });

        // 将运动员信息保存到数据库
        await _athleteModel.saveAthlete(athlete);

        // 更新最后同步时间
        await _loadLastSyncTime();

        // 通知主应用认证状态和用户信息已更新
        widget.onAuthenticationChanged?.call(true, athlete);

        if (isSync) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('运动员信息同步完成')),
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.e('获取运动员信息失败', error: e, stackTrace: stackTrace);
      if (mounted) {
        showErrorMessage(e, stackTrace);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取运动员信息失败，请重新授权')),
        );
      }
    }
  }

  // 同步运动员信息
  Future<void> _syncAthleteInfo() async {
    if (!mounted) return;
    await _loadAthleteInfo(isSync: true);
  }

  Future<void> testAuthentication() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      String id = _idController.text;
      String key = _keyController.text;

      if (id.isEmpty || key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请输入有效的 API ID 和 Key')),
        );
        return;
      }

      Logger.d(
          '开始认证，使用 API ID: $id, Key: ${key.substring(0, min(5, key.length))}...',
          tag: 'SettingPage');
      Logger.d(
          'API 配置详情: '
          '回调URL="stravaflutter://redirect", '
          '回调方案="stravaflutter"',
          tag: 'SettingPage');

      // 保存 API 密钥
      await _apiKeyModel.insertApiKey(id, key);
      if (!mounted) return;

      // 初始化 StravaClientManager
      await StravaClientManager().initialize(id, key);
      if (!mounted) return;

      Logger.d('StravaClientManager 初始化完成，开始进行认证', tag: 'SettingPage');

      // 进行认证
      final tokenResponse = await StravaClientManager().authenticate();
      if (!mounted) return;

      setState(() {
        token = tokenResponse;
        _syncMessage = tokenResponse.accessToken;
      });

      Logger.d(
          '认证成功，获取到令牌，过期时间: ${DateTime.fromMillisecondsSinceEpoch(tokenResponse.expiresAt.toInt() * 1000)}',
          tag: 'SettingPage');

      // 认证成功后加载运动员信息
      await _loadAthleteInfo();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('认证成功')),
      );
    } catch (e, stackTrace) {
      Logger.e('认证过程中出错', error: e, stackTrace: stackTrace, tag: 'SettingPage');

      if (mounted) {
        showErrorMessage(e, stackTrace);

        // 显示友好的错误提示
        String errorMsg = '认证失败';
        if (e is Fault) {
          errorMsg += ': ${e.message}';
          if (e.errors != null && e.errors!.isNotEmpty) {
            final firstError = e.errors!.first;
            errorMsg += ' (${firstError.code})';
          }
        } else {
          errorMsg += ': ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> testDeauth() async {
    if (!mounted) return;

    try {
      await StravaClientManager().deAuthenticate();
      if (!mounted) return;

      setState(() {
        token = null;
        _athlete = null;
        _syncMessage = '';
        _idController.clear();
        _keyController.clear();
        _lastSyncTime = null;
        _lastActivitySyncTime = null;
      });

      // 清除存储的 API 密钥
      await _apiKeyModel.deleteApiKey();

      // 清除存储的运动员信息
      await _athleteModel.deleteAthlete();

      if (!mounted) return;

      // 通知主应用认证状态已更新
      widget.onAuthenticationChanged?.call(false, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已取消认证')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorMessage(e, null);
      }
    }
  }

  bool _needsActivitySync() {
    if (_athlete?.updatedAt == null || _lastActivitySyncTime == null) {
      return true;
    }

    try {
      // 安全地处理updatedAt字段
      String updatedAtStr = '';
      if (_athlete!.updatedAt is String) {
        updatedAtStr = _athlete!.updatedAt as String;
      } else {
        updatedAtStr = _athlete!.updatedAt.toString();
      }

      final updatedAt = DateTime.parse(updatedAtStr);
      final lastSync = DateTime.parse(_lastActivitySyncTime!);

      Logger.d('更新时间: $updatedAt, 最后同步: $lastSync', tag: 'ActivitySync');
      return updatedAt.isAfter(lastSync);
    } catch (e) {
      Logger.e('解析时间失败', error: e, tag: 'ActivitySync');
      return true;
    }
  }

  Future<void> _syncActivities() async {
    // 检查是否已认证
    final manager = StravaClientManager();
    final isAuth = await manager.isAuthenticated();
    
    if (!isAuth || manager.token == null) {
      Fluttertoast.showToast(msg: '请先登录 Strava');
      return;
    }

    if (_isSyncing) {
      Fluttertoast.showToast(msg: '同步正在进行中，请等待完成');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = '准备同步...';
    });

    try {
      // 确保有运动员信息
      if (_athlete == null) {
        _athlete = await manager.stravaClient.athletes.getAuthenticatedAthlete();
      }
      
      // 使用 ActivityService 同步活动数据
      await _activityService.syncActivities(
          onProgress: (current, total, status) {
        if (mounted) {
          setState(() {
            _syncProgress = current / total;
            _syncStatus = status;
          });
        }
      });

      // 更新活动计数和同步状态
      await _loadActivityCount();
      await _loadTotalDistance(); // 更新总公里数
      await _loadTotalElevation(); // 更新总爬升
      await _loadTotalKilojoules(); // 更新总能量
      await _loadTotalMovingTime(); // 更新总时间
      await _loadStatsByActivityType(); // 更新按活动类型分组的统计数据
      await _loadSyncStatus();

      // 更新最后同步时间
      await _loadLastSyncTime();
      await _loadLastActivitySyncTime();

      setState(() {
        _syncMessage = '同步成功，时间: ${_formatDateTime(DateTime.now().toString())}';
      });

      Fluttertoast.showToast(msg: '同步成功');
    } catch (e) {
      Logger.e('同步活动数据失败: $e', tag: 'SettingPage');
      setState(() {
        _syncMessage = '同步失败: $e';
      });
      Fluttertoast.showToast(msg: '同步失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isSyncing = false;
        _syncStatus = '同步完成';
      });
    }
  }

  /// 检查认证状态
  Future<void> _checkAuthStatus() async {
    try {
      final apiKey = await _apiKeyModel.getApiKey();
      if (apiKey != null) {
        final manager = StravaClientManager();
        final isAuth = await manager.isAuthenticated();
        
        if (isAuth && manager.token != null) {
          // 如果已认证，尝试获取运动员信息
          try {
            final athlete = await manager.stravaClient.athletes.getAuthenticatedAthlete();
            setState(() {
              _isAuthenticated = true;
              _athlete = athlete;
              token = manager.token;
            });
            
            // 加载相关数据
            _loadLastSyncTime();
            _loadLastActivitySyncTime();
            _loadActivityCount();
            _loadTotalDistance();
            _loadTotalElevation();
            _loadTotalKilojoules();
            _loadTotalMovingTime();
            _loadStatsByActivityType();
            _loadSyncStatus();
          } catch (e) {
            Logger.e('获取运动员信息失败: $e', tag: 'SettingPage');
            setState(() {
              _isAuthenticated = true;
              _athleteName = '用户'; 
              _athleteAvatar = null;
            });
          }
        } else {
          setState(() {
            _isAuthenticated = false;
            _athleteName = null;
            _athleteAvatar = null;
          });
        }
      } else {
        setState(() {
          _isAuthenticated = false;
          _athleteName = null;
          _athleteAvatar = null;
        });
      }
    } catch (e) {
      Logger.e('检查认证状态失败: $e', tag: 'SettingPage');
    }
  }

  /// 更新运动员创建时间
  Future<void> _updateAthleteCreatedTime() async {
    try {
      // 仅作为示例，实际上需要从Strava API获取
      final createdAt =
          DateTime.now().subtract(const Duration(days: 365)).toIso8601String();
      await _activityService.updateAthleteCreatedAt(createdAt);
      Logger.d('已更新运动员创建时间: $createdAt', tag: 'SettingPage');
    } catch (e) {
      Logger.e('更新运动员创建时间失败: $e', tag: 'SettingPage');
    }
  }

  /// 加载活动数量
  Future<void> _loadActivityCount() async {
    try {
      final activities = await _activityService.getAllActivities();
      setState(() {
        _activityCount = activities.length;
      });
    } catch (e) {
      Logger.e('加载活动数量失败: $e', tag: 'SettingPage');
    }
  }

  /// 加载活动总公里数
  Future<void> _loadTotalDistance() async {
    try {
      final totalDistance = await _activityService.getTotalDistance();
      setState(() {
        _totalDistance = totalDistance;
      });
    } catch (e) {
      Logger.e('加载活动总公里数失败: $e', tag: 'SettingPage');
    }
  }

  /// 加载活动总爬升
  Future<void> _loadTotalElevation() async {
    try {
      final totalElevation = await _activityService.getTotalElevation();
      setState(() {
        _totalElevation = totalElevation;
      });
    } catch (e) {
      Logger.e('加载活动总爬升失败: $e', tag: 'SettingPage');
    }
  }
  
  /// 加载活动总能量
  Future<void> _loadTotalKilojoules() async {
    try {
      final totalKilojoules = await _activityService.getTotalKilojoules();
      setState(() {
        _totalKilojoules = totalKilojoules;
      });
    } catch (e) {
      Logger.e('加载活动总能量失败: $e', tag: 'SettingPage');
    }
  }
  
  /// 加载活动总时间
  Future<void> _loadTotalMovingTime() async {
    try {
      final totalMovingTime = await _activityService.getTotalMovingTime();
      setState(() {
        _totalMovingTime = totalMovingTime;
      });
    } catch (e) {
      Logger.e('加载活动总时间失败: $e', tag: 'SettingPage');
    }
  }
  
  /// 加载按活动类型分组的统计数据
  Future<void> _loadStatsByActivityType() async {
    try {
      final statsByType = await _activityService.getStatsByActivityType();
      setState(() {
        _statsByType = statsByType;
      });
    } catch (e) {
      Logger.e('加载按活动类型分组的统计数据失败: $e', tag: 'SettingPage');
    }
  }

  /// 加载同步状态
  Future<void> _loadSyncStatus() async {
    try {
      final status = await _activityService.getSyncStatus();
      setState(() {
        _syncStatusMap = status;
      });
      Logger.d('加载同步状态: $status', tag: 'SettingPage');
    } catch (e) {
      Logger.e('加载同步状态失败: $e', tag: 'SettingPage');
    }
  }

  /// 重置同步状态
  Future<void> _resetSyncStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _activityService.resetSyncStatus();
      await _loadSyncStatus();
      Fluttertoast.showToast(msg: '重置成功，下次将从第一页开始同步');
    } catch (e) {
      Logger.e('重置同步状态失败: $e', tag: 'SettingPage');
      Fluttertoast.showToast(msg: '重置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 重置数据库
  Future<void> _resetDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _activityService.resetDatabase();
      await _loadActivityCount();
      await _loadTotalDistance();
      await _loadTotalElevation();
      await _loadTotalKilojoules();
      await _loadTotalMovingTime();
      await _loadStatsByActivityType();
      await _loadSyncStatus();
      Fluttertoast.showToast(msg: '数据库已重置，请重新同步数据');
    } catch (e) {
      Logger.e('重置数据库失败: $e', tag: 'SettingPage');
      Fluttertoast.showToast(msg: '重置数据库失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 显示确认对话框
  void _showResetDatabaseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('重置数据库'),
          content: Text('这将删除所有已同步的数据，并重新创建数据库。确定要继续吗？'),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetDatabase();
              },
            ),
          ],
        );
      },
    );
  }

  // 加载高刷新率设置
  Future<void> _loadRefreshRateSettings() async {
    final refreshManager = RefreshRateManager.instance;
    setState(() {
      _refreshRateMode = refreshManager.currentMode;
      _deviceSupportsHighRefreshRate = refreshManager.deviceSupportsHighRefreshRate;
    });
  }

  // 设置高刷新率模式
  Future<void> _setRefreshRateMode(String mode) async {
    try {
      await RefreshRateManager.instance.setMode(mode);
      setState(() {
        _refreshRateMode = mode;
      });
      _showToast('已设置刷新率模式: ${_getRefreshRateModeText(mode)}');
    } catch (e) {
      Logger.e('设置刷新率模式失败', error: e, tag: 'Settings');
      _showToast('设置刷新率模式失败');
    }
  }
  
  // 显示Toast消息
  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
  
  // 获取刷新率模式的友好文本
  String _getRefreshRateModeText(String mode) {
    switch (mode) {
      case RefreshRateManager.kAuto:
        return '自动';
      case RefreshRateManager.kAlwaysOn:
        return '始终开启';
      case RefreshRateManager.kAlwaysOff:
        return '始终关闭';
      default:
        return '未知';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth < 600
                  ? _buildPortraitLayout(context)
                  : _buildLandscapeLayout(context);
            },
          ),
        ),
      ),
    );
  }

  // 竖屏布局
  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 用户信息卡片
        if (_athlete != null) ...[
          _buildUserInfoCard(context),
          const SizedBox(height: 8),
          _buildSyncCard(),
        ],
        // 布局切换开关
        _buildLayoutSwitchCard(),
        const SizedBox(height: 8),
        // 高刷新率设置卡片
        _buildRefreshRateCard(),
        const SizedBox(height: 8),
        // 地图设置卡片
        _buildMapSettingsCard(),
        const SizedBox(height: 8),
        // 应用更新卡片
        _buildAppUpdateCard(),
        const SizedBox(height: 8),
        // 权限管理卡片
        _buildPermissionCard(),
        const SizedBox(height: 8),
        // 高级选项（折叠面板）
        _buildAdvancedOptionsCard(),
      ],
    );
  }

  // 横屏布局
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧用户信息
        if (_athlete != null)
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildUserInfoCard(context),
                const SizedBox(height: 8),
                _buildSyncCard(),
              ],
            ),
          ),

        // 右侧设置项
        Expanded(
          flex: 1,
          child: Padding(
            padding: EdgeInsets.only(left: _athlete != null ? 16.0 : 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLayoutSwitchCard(),
                const SizedBox(height: 8),
                _buildRefreshRateCard(),
                const SizedBox(height: 8),
                _buildMapSettingsCard(),
                const SizedBox(height: 8),
                // 应用更新卡片
                _buildAppUpdateCard(),
                const SizedBox(height: 8),
                // 权限管理卡片
                _buildPermissionCard(),
                const SizedBox(height: 8),
                // 高级选项（折叠面板）
                _buildAdvancedOptionsCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 用户信息卡片
  Widget _buildUserInfoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和用户信息并排显示
            Row(
              children: [
                // 头像
                CircleAvatar(
                  radius: 32,
                  backgroundImage: _athlete?.profile != null
                      ? NetworkImage(_athlete!.profile!)
                      : null,
                  child: _athlete?.profile == null
                      ? Icon(Icons.person, size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 用户名
                      Text(
                        '${_athlete?.firstname ?? ''} ${_athlete?.lastname ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 用户所在城市和国家
                      if (_athlete?.city != null || _athlete?.country != null)
                        Text(
                          '${_athlete?.city ?? ''} ${_athlete?.country ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      // 查看详细信息按钮
                      TextButton(
                        onPressed: () => _showAthleteDetails(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('查看详细信息'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // 统计数据，使用网格布局
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                // 活动数
                GestureDetector(
                  onTap: () => _showActivityTypeStats(context, '活动数'),
                  child: _buildStatItem(
                    context,
                    '活动数',
                    _activityCount.toString(),
                    Icons.directions_run,
                  ),
                ),
                // 总公里数
                GestureDetector(
                  onTap: () => _showActivityTypeStats(context, '总公里'),
                  child: _buildStatItem(
                    context,
                    '总公里',
                    '${_totalDistance.toStringAsFixed(1)} km',
                    Icons.straighten,
                  ),
                ),
                // 总爬升
                GestureDetector(
                  onTap: () => _showActivityTypeStats(context, '总爬升'),
                  child: _buildStatItem(
                    context,
                    '总爬升',
                    '${_totalElevation.toStringAsFixed(0)} m',
                    Icons.trending_up,
                  ),
                ),
                // 总时间
                GestureDetector(
                  onTap: () => _showActivityTypeStats(context, '总时间'),
                  child: _buildStatItem(
                    context,
                    '总时间',
                    _formatDuration(_totalMovingTime),
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建统计项小部件
  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 显示活动类型统计数据对话框
  void _showActivityTypeStats(BuildContext context, String statsType) {
    // 如果没有数据，显示提示
    if (_statsByType.isEmpty) {
      Fluttertoast.showToast(msg: '暂无活动数据');
      return;
    }
    
    // 准备要显示的标题和单位
    String title = '';
    String unit = '';
    String field = '';
    
    switch (statsType) {
      case '活动数':
        title = '活动类型统计';
        field = 'count';
        unit = '个';
        break;
      case '总公里':
        title = '各类型活动距离';
        field = 'distance';
        unit = 'km';
        break;
      case '总爬升':
        title = '各类型活动爬升';
        field = 'total_elevation_gain';
        unit = 'm';
        break;
      case '总时间':
        title = '各类型活动用时';
        field = 'moving_time';
        unit = '';
        break;
      default:
        title = '活动类型统计';
        field = 'count';
        unit = '个';
    }
    
    // 构建统计数据列表
    List<Widget> statItems = [];
    
    // 按数值大小排序
    final sortedTypes = _statsByType.keys.toList()
      ..sort((a, b) {
        final valueA = _statsByType[a]?[field] ?? 0;
        final valueB = _statsByType[b]?[field] ?? 0;
        return (valueB is int ? valueB : (valueB as double))
            .compareTo(valueA is int ? valueA : (valueA as double));
      });
    
    for (final type in sortedTypes) {
      final value = _statsByType[type]?[field];
      if (value == null || (value is num && value <= 0)) continue;
      
      String displayValue;
      if (field == 'moving_time') {
        displayValue = _formatDuration(value as int);
        unit = ''; // 时间不需要单位，因为_formatDuration已经包含了
      } else if (value is int) {
        displayValue = value.toString();
      } else if (value is double) {
        displayValue = field == 'distance' 
            ? value.toStringAsFixed(1) 
            : value.toStringAsFixed(0);
      } else {
        displayValue = value.toString();
      }
      
      statItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$displayValue $unit'),
            ],
          ),
        ),
      );
    }
    
    // 显示对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...statItems,
            if (statItems.isEmpty)
              const Text('暂无数据'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 显示运动员详细信息
  void _showAthleteDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('运动员详细信息'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_athlete?.id != null)
                _buildDetailItem('ID', '${_athlete!.id}'),
              if (_athlete?.username != null)
                _buildDetailItem('用户名', _athlete!.username!),
              if (_athlete?.sex != null) _buildDetailItem('性别', _athlete!.sex!),
              if (_athlete?.premium != null)
                _buildDetailItem('高级会员', _athlete!.premium! ? '是' : '否'),
              if (_athlete?.country != null)
                _buildDetailItem('国家', _athlete!.country!),
              if (_athlete?.state != null)
                _buildDetailItem('州/省', _athlete!.state!),
              if (_athlete?.city != null)
                _buildDetailItem('城市', _athlete!.city!),
              if (_athlete?.measurementPreference != null)
                _buildDetailItem('测量单位',
                    _getMeasurePreference(_athlete!.measurementPreference!)),
              if (_athlete?.weight != null)
                _buildDetailItem(
                    '体重', '${_athlete!.weight!.toStringAsFixed(1)} kg'),
              if (_athlete?.ftp != null && _athlete!.ftp! > 0)
                _buildDetailItem('FTP', '${_athlete!.ftp!} W'),
              if (_athlete?.followerCount != null)
                _buildDetailItem('关注者', '${_athlete!.followerCount!}'),
              if (_athlete?.friendCount != null)
                _buildDetailItem('关注中', '${_athlete!.friendCount!}'),
              _buildDetailItem('活动总数', '$_activityCount'),
              _buildDetailItem('总公里数', '${_totalDistance.toStringAsFixed(1)} km'),
              _buildDetailItem('总爬升', '${_totalElevation.toStringAsFixed(0)} m'),
              _buildDetailItem('总时间', '${_formatDuration(_totalMovingTime)}'),
              if (_athlete?.createdAt != null)
                _buildDetailItem('创建时间', _formatDateTime(_athlete!.createdAt)),
              if (_athlete?.updatedAt != null)
                _buildDetailItem('更新时间', _formatDateTime(_athlete!.updatedAt)),
              if (_lastSyncTime != null)
                _buildDetailItem('最后同步时间', _formatDateTime(_lastSyncTime)),
              if (_lastActivitySyncTime != null)
                _buildDetailItem(
                    '最后活动同步时间', _formatDateTime(_lastActivitySyncTime)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 构建详细信息项
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 获取测量单位偏好的中文表示
  String _getMeasurePreference(String preference) {
    return preference == 'meters' ? '公制 (米)' : '英制 (英尺)';
  }

  // 通用的日期时间格式化方法
  String _formatDateTime(dynamic dateTime, {String format = 'yyyy-MM-dd HH:mm:ss', String defaultText = '--'}) {
    if (dateTime == null) {
      return defaultText;
    }

    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime).toLocal();
      } else if (dateTime is DateTime) {
        dt = dateTime.toLocal();
      } else {
        return dateTime.toString();
      }
      return DateFormat(format).format(dt);
    } catch (e) {
      return dateTime.toString();
    }
  }

  // 同步卡片
  Widget _buildSyncCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据同步',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(value: _syncProgress),
                  const SizedBox(height: 8.0),
                  Text(_syncStatus),
                ],
              ),
            const SizedBox(height: 8.0),
            // 同步信息
            if (_lastSyncTime != null)
              Text('上次同步: ${_formatDateTime(_lastSyncTime)}'),
            if (_lastActivitySyncTime != null)
              Text('上次活动同步: ${_formatDateTime(_lastActivitySyncTime)}'),
            if (_syncMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _syncMessage,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 16.0),
            // 同步按钮和生成SVG按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _syncActivities,
                    icon: const Icon(Icons.sync),
                    label: const Text('同步活动'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateAllSVG,
                    icon: const Icon(Icons.route),
                    label: const Text('生成路线'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            // 日历导出区域
            _buildCalendarExportSection(),
          ],
        ),
      ),
    );
  }

  // 日历导出区域组件
  Widget _buildCalendarExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日历导出',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12.0),
        
        // 月历选择和导出
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月历',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8.0),
            InkWell(
              onTap: () => _selectDateForCalendarExport(isMonth: true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatMonthTitle()),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _exportCalendar(isMonth: true),
                icon: const Icon(Icons.calendar_month),
                label: const Text('导出月历图片'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16.0),
        
        // 周历选择和导出
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '周历',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8.0),
            InkWell(
              onTap: () => _selectDateForCalendarExport(isMonth: false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(date_util.DateUtils.formatWeekTitle(_selectedWeekStart)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _exportCalendar(isMonth: false),
                icon: const Icon(Icons.calendar_view_week),
                label: const Text('导出周历图片'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 选择日期（月历或周历）
  Future<void> _selectDateForCalendarExport({required bool isMonth}) async {
    final DateTime initialDate = isMonth 
        ? DateTime(DateTime.now().year, DateTime.now().month) 
        : _selectedWeekStart;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: isMonth ? '选择月份' : '选择周',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null) {
      setState(() {
        if (isMonth) {
          // 选择的是月份，取当月第一天
          _selectedMonthDate = DateTime(picked.year, picked.month);
        } else {
          // 选择的是周，取周一
          _selectedWeekStart = date_util.DateUtils.getWeekStart(picked);
        }
      });
    }
  }

  // 格式化月份标题
  String _formatMonthTitle() {
    final monthNames = [
      '', '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月'
    ];
    
    return '${_selectedMonthDate.year}年${monthNames[_selectedMonthDate.month]}';
  }

  // 导出日历（月历或周历）
  Future<void> _exportCalendar({required bool isMonth}) async {
    if (_isLoading) {
      Fluttertoast.showToast(msg: '请等待当前操作完成');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _syncStatus = isMonth ? '正在导出月历...' : '正在导出周历...';
        _syncProgress = 0.5;
      });

      // 获取SVG缓存
      final svgCache = await _activityService.getSvgCache();

      String? result;
      if (isMonth) {
        // 导出月历
        result = await CalendarExporter.exportMonth(
          context: context,
          month: _selectedMonthDate,
          selectedDate: DateTime.now(),
          svgCache: svgCache,
        );
      } else {
        // 导出周历
        result = await CalendarExporter.exportWeek(
          context: context,
          weekStart: _selectedWeekStart,
          selectedDate: DateTime.now(),
          svgCache: svgCache,
        );
      }

      setState(() {
        _isLoading = false;
        _syncStatus = '';
        _syncMessage = result != null 
            ? '${isMonth ? "月历" : "周历"}导出成功' 
            : '${isMonth ? "月历" : "周历"}导出失败';
      });

      // 延迟清除消息
      _clearMessageAfterDelay();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _syncStatus = '';
        _syncMessage = '${isMonth ? "月历" : "周历"}导出错误: $e';
      });

      // 延迟清除消息
      _clearMessageAfterDelay();
    }
  }

  // 延迟清除消息
  void _clearMessageAfterDelay() {
    Future.delayed(Duration(seconds: 5), () {
      setState(() {
        _syncMessage = '';
      });
    });
  }

  // 布局切换卡片
  Widget _buildLayoutSwitchCard() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('使用水平布局'),
            subtitle: const Text('切换日历的显示方式'),
            value: _isHorizontalLayout,
            onChanged: (bool value) {
              setState(() {
                _isHorizontalLayout = value;
              });
              _saveSettings();
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('全屏模式'),
            subtitle: const Text('隐藏状态栏和导航栏，获得更多显示空间'),
            value: _isFullscreenMode,
            onChanged: _toggleFullscreenMode,
          ),
        ],
      ),
    );
  }

  // 地图设置卡片
  Widget _buildMapSettingsCard() {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              '地图设置',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('地图显示和交互设置'),
          ),
          SwitchListTile(
            title: const Text('路线导航全屏覆盖模式'),
            subtitle: const Text('在导航时使用全屏地图视图'),
            value: _routeFullscreenOverlay,
            secondary: Icon(Icons.fullscreen, color: Theme.of(context).colorScheme.primary),
            onChanged: (bool value) {
              setState(() {
                _routeFullscreenOverlay = value;
              });
              _saveSettings();
              
              // 更新全局缓存，确保立即生效
              AppSettingsManager().updateRouteFullscreenOverlay(value);
              // 清除缓存，强制下次获取最新设置
              AppSettingsManager().clearCache();
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('彩虹线条模式'),
            subtitle: const Text('日历图中按星期几显示不同颜色的SVG图'),
            value: _useRainbowColors,
            secondary: Icon(Icons.color_lens, color: Theme.of(context).colorScheme.primary),
            onChanged: (bool value) {
              setState(() {
                _useRainbowColors = value;
              });
              _saveSettings();
              
              // 更新全局缓存，确保立即生效
              AppSettingsManager().updateRainbowColors(value);
              // 清除缓存，强制下次获取最新设置
              AppSettingsManager().clearCache();
              
              // 提示已完成设置
              Fluttertoast.showToast(
                msg: "彩虹线条模式已${value ? '开启' : '关闭'}",
                toastLength: Toast.LENGTH_SHORT,
              );
            },
          ),
          // 非彩虹模式下显示颜色选择器入口
          if (!_useRainbowColors)
            ListTile(
              title: const Text('SVG颜色设置'),
              subtitle: const Text('设置单色模式下的SVG颜色'),
              leading: Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(_svgColor),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              onTap: _openColorPicker,
            ),
        ],
      ),
    );
  }

  // 跳转到Strava API设置页面
  void _navigateToStravaApiPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StravaApiPage(
          isAuthenticated: _isAuthenticated,
          athlete: _athlete,
          onAuthenticationChanged: (isAuthenticated, athlete) {
            setState(() {
              _isAuthenticated = isAuthenticated;
              _athlete = athlete;
            });
            widget.onAuthenticationChanged?.call(isAuthenticated, athlete);
          },
        ),
      ),
    ).then((_) {
      // 返回后刷新认证状态
      _checkAuthStatus();
    });
  }

  // 高级选项卡片
  Widget _buildAdvancedOptionsCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: const Text(
          '高级选项',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Strava API设置及数据管理'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // API相关按钮
                if (!_isAuthenticated) 
                  ElevatedButton.icon(
                    onPressed: _navigateToStravaApiPage,
                    icon: const Icon(Icons.login),
                    label: const Text('登录 Strava'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  )
                else 
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _navigateToStravaApiPage,
                          icon: const Icon(Icons.settings),
                          label: const Text('API设置'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: testDeauth,
                          icon: const Icon(Icons.logout),
                          label: const Text('取消认证'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // 重置同步按钮
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _resetSyncStatus,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('重置同步状态'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 8),
                // 重置数据库按钮
                OutlinedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _showResetDatabaseConfirmation(context),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('重置数据库'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 调试并修复数据库
  Future<void> _debugAndFixDatabase() async {
    try {
      Logger.d('开始调试和修复数据库...', tag: 'DatabaseInit');

      // 检查数据库表结构
      await _athleteModel.debugDatabaseTable();

      // 尝试常规修复
      await _athleteModel.fixLastActivitySyncTime();

      // 再次检查数据库状态
      await _athleteModel.debugDatabaseTable();

      // 如果还是有问题，完全重置数据库
      final lastActivitySyncTime =
          await _athleteModel.getLastActivitySyncTime();
      final lastSyncTime = await _athleteModel.getLastSyncTime();

      Logger.d('修复检查: 最后同步时间=$lastSyncTime, 最后活动同步时间=$lastActivitySyncTime',
          tag: 'DatabaseInit');

      // 如果最后活动同步时间依然为null但最后同步时间不为null，重置数据库
      if (lastSyncTime != null && lastActivitySyncTime == null) {
        Logger.w('检测到数据库异常，准备重置数据库', tag: 'DatabaseInit');

        // 备份运动员信息
        final athleteData = await _athleteModel.getAthlete();

        // 重置数据库
        await _athleteModel.resetDatabase();

        // 如果有运动员数据，重新保存
        if (athleteData != null && _athlete != null) {
          // 重新保存运动员信息
          await _athleteModel.saveAthlete(_athlete!);
          Logger.d('重置数据库后重新保存了运动员信息', tag: 'DatabaseInit');
        }
      }

      // 最终检查
      await _athleteModel.debugDatabaseTable();

      Logger.d('数据库调试和修复完成', tag: 'DatabaseInit');
    } catch (e) {
      Logger.e('数据库调试和修复失败', error: e, tag: 'DatabaseInit');
    }
  }

  // 生成SVG路线图
  Future<void> _generateAllSVG() async {
    if (_isLoading) {
      Fluttertoast.showToast(msg: '请等待当前操作完成');
      return;
    }

    setState(() {
      _isLoading = true;
      _syncProgress = 0.0;
      _syncStatus = '准备生成SVG...';
      _syncMessage = '正在准备生成SVG...';
    });

    // 将生成SVG的过程放在后台执行
    Future.delayed(Duration.zero, () async {
      try {
        // 获取所有活动数据
        final activities = await _activityService.getAllActivities();
        int total = activities.length;
        int current = 0;
        int success = 0;
        int skipped = 0;
        int error = 0;

        for (var activity in activities) {
          current++;

          // 更新进度
          if (mounted) {
            setState(() {
              _syncProgress = current / total;
              _syncStatus =
                  '处理: ${activity['name'] ?? activity['id']} ($current/$total)';
            });
          }

          // 检查是否有map_polyline
          final polyline = activity['map_polyline'] as String?;
          final id = activity['id']?.toString() ?? '';

          if (polyline == null || polyline.isEmpty) {
            skipped++;
            continue;
          }

          try {
            // 提取日期，格式为"yyyy-MM-dd"
            final startDate = DateTime.parse(activity['start_date'].toString()).toLocal();
            final dateStr =
                '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

            // 设置SVG输出路径
            String svgPath;
            if (Platform.isAndroid) {
              svgPath =
                  '/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg';
            } else {
              final dir = await getApplicationDocumentsDirectory();
              svgPath = '${dir.path}/strava_pro/svg/$dateStr.svg';
            }

            // 确保目录存在
            final file = File(svgPath);
            final directory = file.parent;
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }

            // 生成SVG文件
            await PolylineToSVG.generateAndSaveSVG(
              polyline,
              svgPath,
              strokeWidth: 6.0,
            );

            success++;
          } catch (e) {
            Logger.e('为活动 $id 生成SVG失败: $e', error: e, tag: 'SVG');
            error++;
          }

          // 每处理10个活动，暂停一下，避免阻塞UI
          if (current % 10 == 0) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }

        // 更新最终状态
        if (mounted) {
          setState(() {
            _syncMessage = '路线图生成完成: 成功=$success, 跳过=$skipped, 失败=$error';
          });
          Fluttertoast.showToast(msg: '路线图生成完成');
        }
      } catch (e) {
        Logger.e('生成SVG失败: $e', error: e, tag: 'SVG');
        if (mounted) {
          setState(() {
            _syncMessage = '生成SVG失败: $e';
          });
          Fluttertoast.showToast(msg: '生成SVG失败: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _syncStatus = '操作完成';
          });
        }
      }
    });

    // 立即释放UI，让用户可以做其他操作
    setState(() {
      _isLoading = false;
      _syncMessage = '路线图生成在后台进行中...';
    });

    Fluttertoast.showToast(msg: '路线图生成已在后台开始');
  }

  // 权限管理卡片
  Widget _buildPermissionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '权限管理',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '应用需要某些权限才能正常运行。如果您在使用某些功能时遇到问题，可能是因为缺少必要的权限。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () {
                  _checkAndRequestPermissions();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('检查和请求权限'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 检查和请求权限方法
  Future<void> _checkAndRequestPermissions() async {
    try {
      // 需要检查的权限列表
      List<Permission> permissions = [
        Permission.location,
        Permission.locationWhenInUse,
        Permission.storage,
      ];
      
      // 在Android 13+上额外请求媒体权限
      if (Platform.isAndroid) {
        try {
          final deviceInfoPlugin = DeviceInfoPlugin();
          final androidInfo = await deviceInfoPlugin.androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          
          // 添加安装包权限
          permissions.add(Permission.requestInstallPackages);
          
          if (sdkInt >= 33) { // Android 13+
            permissions.addAll([
              Permission.photos,
              Permission.videos,
              Permission.audio,
            ]);
            
            // Android 13及以上需要额外权限
            if (sdkInt >= 33) {
              permissions.add(Permission.manageExternalStorage);
            }
          } else {
            // 旧版Android需要存储权限
            permissions.add(Permission.storage);
          }
          
          Logger.d('Android SDK版本: $sdkInt，已添加相应权限', tag: 'Permissions');
        } catch (e) {
          Logger.e('获取设备信息失败', error: e, tag: 'Permissions');
        }
      }
      
      // 检查权限状态
      Map<Permission, PermissionStatus> statuses = {};
      for (var permission in permissions) {
        statuses[permission] = await permission.status;
      }
      
      // 找出未授权的权限
      List<Permission> deniedPermissions = [];
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          deniedPermissions.add(permission);
        }
      });
      
      // 如果有未授权权限，显示权限请求对话框
      if (deniedPermissions.isNotEmpty) {
        _showPermissionDialog(deniedPermissions);
      } else {
        // 所有权限已授予
        Fluttertoast.showToast(
          msg: "所有必要权限已授予",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      Logger.e('检查权限出错', error: e, tag: 'Permissions');
      Fluttertoast.showToast(
        msg: "权限检查过程中发生错误",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  // 显示权限对话框
  void _showPermissionDialog(List<Permission> deniedPermissions) {
    if (!mounted) return;
    
    // 创建权限名称和描述的映射
    Map<Permission, String> permissionNames = {
      Permission.location: '位置信息',
      Permission.locationWhenInUse: '使用时的位置信息',
      Permission.storage: '存储空间',
      Permission.photos: '照片',
      Permission.videos: '视频',
      Permission.audio: '音频',
    };
    
    Map<Permission, String> permissionDescriptions = {
      Permission.location: '用于跟踪您的位置并记录跑步路线',
      Permission.locationWhenInUse: '用于在使用应用时获取您的位置信息',
      Permission.storage: '用于存储路线数据和导出GPX文件',
      Permission.photos: '用于访问照片媒体，保存和导出图片',
      Permission.videos: '用于访问视频媒体，保存相关数据',
      Permission.audio: '用于访问音频媒体，支持相关功能',
    };
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('需要权限'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                const Text('此应用需要以下权限才能正常运行:'),
                const SizedBox(height: 16),
                ...deniedPermissions.map((permission) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          permissionNames[permission] ?? permission.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          permissionDescriptions[permission] ?? '需要此权限以确保应用正常运行',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // 请求所有未授权的权限
                Map<Permission, PermissionStatus> results = {};
                for (var permission in deniedPermissions) {
                  final status = await permission.request();
                  results[permission] = status;
                  Logger.d('$permission 请求结果: $status', tag: 'Permissions');
                }
                
                // 检查权限请求结果
                int granted = 0;
                bool hasPermanentlyDenied = false;
                
                for (var entry in results.entries) {
                  if (entry.value.isGranted) {
                    granted++;
                  } else if (await entry.key.isPermanentlyDenied) {
                    hasPermanentlyDenied = true;
                  }
                }
                
                // 显示结果提示
                if (granted == deniedPermissions.length) {
                  // 全部授予
                  Fluttertoast.showToast(
                    msg: "已获得所有所需权限",
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.BOTTOM,
                  );
                } else if (granted > 0) {
                  // 部分授予
                  Fluttertoast.showToast(
                    msg: "已获得部分权限，某些功能可能受限",
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.BOTTOM,
                  );
                }
                
                // 如果有永久拒绝的权限，提示用户前往设置
                if (hasPermanentlyDenied && mounted) {
                  _showAppSettingsDialog();
                }
              },
              child: const Text('授予权限'),
            ),
          ],
        );
      },
    );
  }
  
  // 显示前往设置的对话框
  void _showAppSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('权限被永久拒绝'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('某些权限被永久拒绝，需要在应用设置中手动开启。'),
              SizedBox(height: 8),
              Text(
                '这些权限对于应用的正常运行至关重要，没有这些权限，某些功能可能无法使用。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
              child: const Text('前往设置'),
            ),
          ],
        );
      },
    );
  }

  // 应用更新卡片
  Widget _buildAppUpdateCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '应用更新',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                // 更新选项按钮移到右侧
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'check') {
                      _checkForUpdate(showResult: true);
                    } else if (value == 'force_check') {
                      _checkForUpdate(showResult: true);
                    } else if (value == 'reset_ignore') {
                      await _updateService.resetIgnoredVersion();
                      Fluttertoast.showToast(msg: '已重置忽略的版本');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'check',
                      child: Text('检查更新'),
                    ),
                    const PopupMenuItem(
                      value: 'force_check',
                      child: Text('强制检查更新'),
                    ),
                    const PopupMenuItem(
                      value: 'reset_ignore',
                      child: Text('重置忽略的版本'),
                    ),
                  ],
                  icon: Icon(Icons.more_vert, 
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 当前版本信息
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('当前版本: '),
                Text('$_appVersion+$_buildNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('版本号比较: '),
                Text(_appVersion,
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                const Text(' (仅比较此部分)', 
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            if (_isCheckingUpdate) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              const Center(child: Text('正在检查更新...')),
            ] else if (_updateAvailable && _updateInfo != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('最新版本: '),
                  Text(
                    _updateInfo!['version'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: () {
                    _updateService.showUpdateDialog(context, _updateInfo!);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('立即更新'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '当前已是最新版本',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 高刷新率设置卡片
  Widget _buildRefreshRateCard() {
    if (!_deviceSupportsHighRefreshRate) {
      return Card(
        elevation: 2,
        child: ListTile(
          leading: const Icon(Icons.screen_rotation),
          title: const Text('高刷新率设置'),
          subtitle: const Text('您的设备不支持高刷新率显示'),
          enabled: false,
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.screen_rotation),
            title: const Text('高刷新率设置'),
            subtitle: Text('当前模式: ${_getRefreshRateModeText(_refreshRateMode)}'),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                _buildRefreshRateOption(
                  '自动', 
                  '根据电池状态和性能自动调整', 
                  RefreshRateManager.kAuto
                ),
                const Divider(height: 1),
                _buildRefreshRateOption(
                  '始终开启', 
                  '最流畅的体验，但耗电量更高', 
                  RefreshRateManager.kAlwaysOn
                ),
                const Divider(height: 1),
                _buildRefreshRateOption(
                  '始终关闭', 
                  '延长电池续航时间', 
                  RefreshRateManager.kAlwaysOff
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  // 构建刷新率选项
  Widget _buildRefreshRateOption(String title, String subtitle, String mode) {
    return RadioListTile<String>(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: mode,
      groupValue: _refreshRateMode,
      onChanged: (String? value) {
        if (value != null) {
          _setRefreshRateMode(value);
        }
      },
      dense: true,
    );
  }

  // 显示更新对话框
  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新版本：${updateInfo['version']}'),
            if (updateInfo['description'] != null) ...[
              SizedBox(height: 8),
              Text('更新内容：'),
              Text(updateInfo['description']),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('稍后再说'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUpdate(updateInfo);
            },
            child: Text('立即更新'),
          ),
        ],
      ),
    );
  }

  // 启动更新
  void _launchUpdate(Map<String, dynamic> updateInfo) {
    if (updateInfo['url'] != null) {
      final url = updateInfo['url'] as String;
      // 使用系统浏览器打开更新链接
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新链接无效')),
      );
    }
  }

  /// 将秒数格式化为小时:分钟
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours小时${minutes}分钟';
  }

  // 打开颜色选择器对话框
  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color currentColor = Color(_svgColor);
        return AlertDialog(
          title: const Text('选择SVG颜色'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                currentColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
              portraitOnly: true,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _svgColor = currentColor.value;
                });
                _saveSettings();
                
                // 更新全局缓存，确保立即生效
                AppSettingsManager().updateSvgColor(currentColor.value);
                // 清除缓存，强制下次获取最新设置
                AppSettingsManager().clearCache();
                
                // 提示已完成设置
                Fluttertoast.showToast(
                  msg: "SVG颜色已更新",
                  toastLength: Toast.LENGTH_SHORT,
                );
                
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
