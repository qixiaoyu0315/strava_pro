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

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _textEditingController = TextEditingController();
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

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _athleteName;
  String? _athleteAvatar;
  int _activityCount = 0;
  Map<String, dynamic>? _syncStatusMap;

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
        _textEditingController.text = token?.accessToken ?? '';
      });
    }

    _checkAuthStatus();
    _loadActivityCount();
    _loadSyncStatus();
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
          _textEditingController.text = token?.accessToken ?? '';
        } else {
          _athlete = null;
          token = null;
          _textEditingController.clear();
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isHorizontalLayout = prefs.getBool('isHorizontalLayout') ?? true;
      _isFullscreenMode = prefs.getBool('isFullscreenMode') ?? false;
    });

    // 根据设置应用全屏模式
    _applyFullscreenMode();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isHorizontalLayout', _isHorizontalLayout);
    await prefs.setBool('isFullscreenMode', _isFullscreenMode);
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
        _textEditingController.text = tokenResponse.accessToken;
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
        _textEditingController.clear();
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
    if (!_isAuthenticated) {
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
        // 暂时注释掉获取用户信息的逻辑
        // final athlete = await StravaClientManager()
        //     .stravaClient
        //     .athletes
        //     .getAthlete(0); // 0 表示获取当前登录用户
        // setState(() {
        //   _isAuthenticated = true;
        //   _athleteName = athlete.firstname;
        //   _athleteAvatar = athlete.profile;
        // });
        setState(() {
          _isAuthenticated = true;
          _athleteName = '用户'; // 暂时设置为默认值
          _athleteAvatar = null; // 暂时设置为 null
        });

        // 尝试获取运动员信息并更新创建时间
        _updateAthleteCreatedTime();
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

  @override
  Widget build(BuildContext context) {
    // 检测是否为横屏模式
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    if (isLandscape) {
      // 横屏布局 - 使用CustomScrollView来实现滚动隐藏AppBar
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('设置'),
              floating: true,
              snap: true,
              pinned: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: _buildLandscapeLayout(context),
              ),
            ),
          ],
        ),
      );
    } else {
      // 竖屏布局 - 使用CustomScrollView实现滚动隐藏AppBar
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            if (widget.isAuthenticated) {
              await _syncActivities();
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('设置'),
                floating: true,
                snap: true,
                pinned: false,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  child: _buildPortraitLayout(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
        // API设置卡片
        _buildApiSettingsCard(context),
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
        // 同步按钮和进度
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
                _buildApiSettingsCard(context),
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
                  onPressed: _isLoading
                      ? null
                      : () => _showResetDatabaseConfirmation(context),
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
          children: [
            // 头像
            CircleAvatar(
              radius: 50,
              backgroundImage: _athlete?.profile != null
                  ? NetworkImage(_athlete!.profile!)
                  : null,
              child: _athlete?.profile == null
                  ? Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 8),
            // 用户名
            Text(
              '${_athlete?.firstname ?? ''} ${_athlete?.lastname ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            // 用户所在城市和国家
            if (_athlete?.city != null || _athlete?.country != null)
              Text(
                '${_athlete?.city ?? ''} ${_athlete?.country ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 8),
            // 显示最后同步时间
            if (_lastSyncTime != null)
              Text(
                '上次同步: ${_formatDateTime(_lastSyncTime)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            // 运动统计
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context,
                  '活动数',
                  _activityCount.toString(),
                  Icons.directions_run,
                ),
                _buildStatItem(
                  context,
                  '同步状态',
                  _isLoading ? '同步中...' : '已同步',
                  Icons.sync,
                ),
              ],
            ),
            // 显示同步状态信息
            if (_syncStatusMap != null) ...[
              const Divider(height: 32),
              Text(
                '同步信息',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildSyncInfo(
                '当前页数',
                '${_syncStatusMap!['last_page'] ?? 0}',
                Icons.bookmark,
              ),
              _buildSyncInfo(
                '最后同步',
                _formatDateTime(_syncStatusMap!['last_sync_time']?.toString()),
                Icons.access_time,
              ),
              _buildSyncInfo(
                '起始时间',
                _formatDateTime(
                    _syncStatusMap!['athlete_created_at']?.toString()),
                Icons.calendar_today,
              ),
            ],
            const SizedBox(height: 8),
            // 详细信息按钮
            TextButton(
              onPressed: () => _showAthleteDetails(context),
              child: Text('查看详细信息'),
            ),
          ],
        ),
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
  String _formatDateTime(dynamic dateTime,
      {String format = 'yyyy-MM-dd HH:mm', String defaultText = '未设置'}) {
    if (dateTime == null ||
        (dateTime is String && (dateTime == 'null' || dateTime.isEmpty))) {
      return defaultText;
    }

    try {
      DateTime dt;
      if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
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
            // 添加一个文本显示最后同步时间
            Text('最后同步: ${_lastSyncTime ?? "未同步"}'),
            Text('最后获取活动时间: ${_lastActivitySyncTime ?? "未同步"}'),
            if (_syncMessage.isNotEmpty)
              Text(
                _syncMessage,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 16.0),
            // 按钮行：添加同步按钮和生成SVG按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _syncActivities,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('同步活动数据'),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _generateAllSVG,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('生成SVG路线'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            // 添加导出月历按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _exportMonthCalendar,
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
      ),
    );
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

  // API设置卡片
  Widget _buildApiSettingsCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'API 设置',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: '请输入 API ID',
                border: OutlineInputBorder(),
                helperText: '在 Strava 开发者网站获取的客户端 ID',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: '请输入 API Key',
                border: OutlineInputBorder(),
                helperText: '在 Strava 开发者网站获取的客户端密钥',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              minLines: 1,
              maxLines: 3,
              controller: _textEditingController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Access Token",
                suffixIcon: IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _textEditingController.text),
                    ).then((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("已复制到剪贴板")),
                        );
                      }
                    });
                  },
                ),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 8),
            // Strava API 配置提示
            const Card(
              color: Color(0xFFF5F5F5),
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strava API 配置说明',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('1. 在 Strava 开发者网站创建应用'),
                    Text('2. 授权回调域：localhost'),
                    Text('3. 确保添加了回调 URL：stravaflutter://redirect'),
                    SizedBox(height: 4),
                    Text(
                      '如果认证失败，请检查您的 API 配置是否正确。',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: testAuthentication,
                  icon: Icon(Icons.login),
                  label: const Text('认证'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: testDeauth,
                  icon: Icon(Icons.logout),
                  label: const Text('取消认证'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // 构建同步状态信息项
  Widget _buildSyncInfo(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
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
            final startDate = DateTime.parse(activity['start_date'].toString());
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

  // 导出当前月份日历
  Future<void> _exportMonthCalendar() async {
    if (_isLoading) {
      Fluttertoast.showToast(msg: '请等待当前操作完成');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _syncMessage = '准备导出月历...';
      });

      // 获取当前月份
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);

      // 使用月份选择器选择要导出的月份
      final DateTime? selectedMonth = await _showMonthPicker(currentMonth);
      if (selectedMonth == null) {
        setState(() {
          _isLoading = false;
          _syncMessage = '已取消导出';
        });
        return;
      }

      // 获取选中月份的SVG缓存
      final svgCache = await _getSvgCacheForMonth(selectedMonth);

      // 导出月历为图片
      final String? exportedPath = await CalendarExporter.exportMonth(
        context: context,
        month: selectedMonth,
        selectedDate: DateTime.now(),
        svgCache: svgCache,
      );

      if (exportedPath != null) {
        setState(() {
          _syncMessage = '月历已导出至: $exportedPath';
        });
      } else {
        setState(() {
          _syncMessage = '导出失败，请检查权限设置';
        });
      }
    } catch (e) {
      Logger.e('导出月历失败', error: e, tag: 'ExportCalendar');
      setState(() {
        _syncMessage = '导出失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 显示月份选择器
  Future<DateTime?> _showMonthPicker(DateTime initialDate) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 2),
      lastDate: initialDate,
      initialDatePickerMode: DatePickerMode.year,
      // 只显示月份
      selectableDayPredicate: (DateTime date) {
        // 只允许选择每月的第一天（显示月份选择器时）
        return date.day == 1;
      },
    );

    if (selectedDate != null) {
      return DateTime(selectedDate.year, selectedDate.month);
    }

    return null;
  }

  // 获取指定月份的SVG缓存
  Future<Map<String, bool>> _getSvgCacheForMonth(DateTime month) async {
    try {
      // 获取该月所有日期
      final Map<String, bool> svgCache = {};

      // 获取当月天数
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

      // 遍历当月每一天，检查SVG文件是否存在
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(month.year, month.month, day);
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final svgPath =
            '/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg';

        final file = File(svgPath);
        svgCache[dateStr] = await file.exists();
      }

      return svgCache;
    } catch (e) {
      Logger.e('获取SVG缓存失败', error: e, tag: 'ExportCalendar');
      return {};
    }
  }
}
