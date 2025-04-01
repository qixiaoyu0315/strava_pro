import 'dart:async';
import 'dart:io';

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
  final Map<String, bool> _processedDates = {};
  String? _lastSyncTime;
  String? _lastActivitySyncTime;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  final AthleteModel _athleteModel = AthleteModel();
  final ActivityService _activityService = ActivityService();
  bool _isHorizontalLayout = true;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _athleteName;
  String? _athleteAvatar;
  int _activityCount = 0;

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
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isHorizontalLayout', _isHorizontalLayout);
    widget.onLayoutChanged?.call(_isHorizontalLayout);
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

  FutureOr<Null> showErrorMessage(dynamic error, dynamic stackTrace) {
    if (error is Fault && mounted) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("认证错误"),
              content: Text(
                  "错误信息: ${error.message}\n-----------------\n详细信息:\n${(error.errors ?? []).map((e) => "代码: ${e.code}\n资源: ${e.resource}\n字段: ${e.field}\n").toList().join("\n----------\n")}"),
            );
          });
    }
  }

  Future<void> _loadAthleteInfo() async {
    try {
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
      }
    } catch (e) {
      Logger.e('获取运动员信息失败', error: e);
    }
  }

  Future<void> testAuthentication() async {
    if (!mounted) return;

    try {
    String id = _idController.text;
    String key = _keyController.text;

      // 保存 API 密钥
      await _apiKeyModel.insertApiKey(id, key);
      if (!mounted) return;

      // 初始化 StravaClientManager
      await StravaClientManager().initialize(id, key);
      if (!mounted) return;

      // 进行认证
      final tokenResponse = await StravaClientManager().authenticate();
      if (!mounted) return;

      setState(() {
        token = tokenResponse;
        _textEditingController.text = tokenResponse.accessToken;
      });

      // 认证成功后加载运动员信息
      await _loadAthleteInfo();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('认证成功')),
      );
    } catch (e) {
      if (mounted) {
        showErrorMessage(e, null);
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

  Future<void> syncActivities() async {
    if (!mounted) return;

    if (_isSyncing) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步正在进行中，请等待完成')),
        );
      }
      return;
    }

    if (_athlete == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请先登录并获取运动员信息')),
        );
      }
      return;
    }

    try {
      setState(() {
        _isSyncing = true;
        _syncProgress = 0.0;
        _syncStatus = '准备同步...';
      });

      final now = DateTime.now().toUtc();
      final oneYearAgo = now.subtract(Duration(days: 365));

      final saveDir = Directory('/storage/emulated/0/Download/strava_pro/svg');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      if (!mounted) return;

      // 按开始时间排序活动，确保每天处理最早的活动
      final activities = await StravaClientManager()
          .stravaClient
          .activities
          .listLoggedInAthleteActivities(
            now,
            oneYearAgo,
            1,
            100,
          );
      if (!mounted) return;

      activities.sort((a, b) {
        final dateA = DateTime.parse(a.startDate ?? '');
        final dateB = DateTime.parse(b.startDate ?? '');
        return dateA.compareTo(dateB);
      });

      int totalActivities = activities.length;
      int processedCount = 0;
      int successCount = 0;

      if (mounted) {
        setState(() {
          _syncStatus = '获取到 $totalActivities 个活动，开始生成SVG...';
        });
      }

      for (var activity in activities) {
        if (!mounted) break;

        try {
          if (activity.map?.summaryPolyline != null) {
            final date = DateTime.parse(activity.startDate ?? '');
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final fileName = '$dateStr.svg';
            final filePath = '${saveDir.path}/$fileName';

            // 检查是否已处理过该日期
            if (!_processedDates.containsKey(dateStr)) {
              _processedDates[dateStr] = true;

              if (mounted) {
                setState(() {
                  _syncStatus = '正在处理: ${activity.name ?? fileName} ($dateStr)';
                });
              }

              // 生成SVG文件
              final svgContent = await PolylineToSVG.generateAndSaveSVG(
                activity.map!.summaryPolyline!,
                filePath,
                strokeColor: 'green',
                strokeWidth: 10,
              );
              if (!mounted) break;

              if (svgContent != null) {
                successCount++;
              }
            }
          }

          processedCount++;
          if (mounted) {
            setState(() {
              _syncProgress = processedCount / totalActivities;
              _syncStatus = '已处理: $processedCount/$totalActivities';
            });
          }
        } catch (e) {
          Logger.e('处理活动 ${activity.name} 时出错', error: e);
        }
      }

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = '同步完成';
        });

        try {
          // 更新最后同步时间
          await _athleteModel.updateLastSyncTime();
          Logger.d('最后同步时间更新成功', tag: 'SyncTime');
          
          // 强制等待一下，确保两次更新之间有时间差
          await Future.delayed(Duration(milliseconds: 100));
          
          // 直接更新数据库中的last_activity_sync_time字段
          final db = await _athleteModel.database;
          final now = DateTime.now().toUtc().toIso8601String();
          final athleteData = await _athleteModel.getAthlete();
          
          if (athleteData != null) {
            int recordId = athleteData['id'] as int;
            
            // 直接使用SQL语句更新
            int result = await db.rawUpdate(
              'UPDATE athlete SET last_activity_sync_time = ? WHERE id = ?',
              [now, recordId]
            );
            
            Logger.d('直接SQL更新last_activity_sync_time字段: $now, 结果: $result行受影响', tag: 'SyncTime');
            
            // 验证更新
            final verification = await db.query(
              'athlete',
              columns: ['last_activity_sync_time'],
              where: 'id = ?',
              whereArgs: [recordId]
            );
            
            if (verification.isNotEmpty) {
              final updatedValue = verification.first['last_activity_sync_time'];
              Logger.d('验证更新结果: $updatedValue', tag: 'SyncTime');
              
              if (mounted) {
                setState(() {
                  _lastActivitySyncTime = updatedValue as String?;
                });
                
                Logger.d('状态已更新 - 最后活动同步时间: $_lastActivitySyncTime', tag: 'SyncTime');
              }
            } else {
              Logger.w('无法验证更新结果', tag: 'SyncTime');
            }
          } else {
            Logger.w('找不到运动员记录，无法更新最后活动同步时间', tag: 'SyncTime');
          }
          
          // 重新加载最后同步时间以确保UI显示正确
          await _loadLastSyncTime();
          await _loadLastActivitySyncTime();
        } catch (timeError) {
          Logger.e('更新同步时间失败', error: timeError, tag: 'SyncTime');
          // 即使更新时间失败，也不影响主要功能，继续完成
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步完成，成功生成 $successCount 个 SVG 文件')),
        );
      }
    } catch (e) {
      Logger.e('同步活动数据失败', error: e, tag: 'SyncActivities');

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncStatus = '同步失败: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步活动数据失败: $e')),
        );
      }
    }
  }

  // 同步运动员信息
  Future<void> _syncAthleteInfo() async {
    if (!mounted) return;

    try {
      setState(() {
        _syncStatus = '正在获取运动员信息...';
      });

      // 获取最新的运动员信息
      final athlete = await StravaClientManager()
          .stravaClient
          .athletes
          .getAuthenticatedAthlete();

      if (mounted) {
        setState(() {
          _athlete = athlete;
        });

        try {
          // 将运动员信息保存到数据库
          await _athleteModel.saveAthlete(athlete);

          try {
            // 更新最后同步时间
            await _loadLastSyncTime();
          } catch (timeError) {
            Logger.e('加载同步时间失败', error: timeError, tag: 'AthleteSync');
            // 即使获取时间失败，也不影响主要功能
          }

          // 通知主应用认证状态和用户信息已更新
          widget.onAuthenticationChanged?.call(true, athlete);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('运动员信息同步完成')),
          );
        } catch (dbError) {
          Logger.e('保存运动员信息到数据库失败', error: dbError, tag: 'AthleteSync');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('同步成功但保存到数据库失败: $dbError')),
            );
          }
        }
      }
    } catch (e) {
      Logger.e('从Strava获取运动员信息失败', error: e, tag: 'AthleteSync');

      if (mounted) {
        setState(() {
          _syncStatus = '同步失败: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('从Strava获取运动员信息失败: $e')),
        );
      }
    }
  }

  Future<void> _syncActivities() async {
    if (!widget.isAuthenticated) {
      _showToast('请先登录Strava');
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await _activityService.syncActivities();
      _showToast('活动数据同步成功');
    } catch (e) {
      _showToast('同步失败: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检测是否为横屏模式
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    
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
      // 竖屏布局 - 保持原样
    return Scaffold(
      appBar: AppBar(
          title: const Text('设置'),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (widget.isAuthenticated) {
              await _syncActivities();
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _buildPortraitLayout(context),
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
                '上次同步: ${_formatLastSyncTime(_lastSyncTime!)}',
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
                  _isSyncing ? '同步中...' : '已同步',
                  Icons.sync,
                ),
              ],
            ),
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
                _buildDetailItem(
                    '创建时间', _formatAthleteTime(_athlete!.createdAt)),
              if (_athlete?.updatedAt != null)
                _buildDetailItem(
                    '更新时间', _formatAthleteTime(_athlete!.updatedAt)),
              if (_lastSyncTime != null)
                _buildDetailItem('最后同步时间', _formatLastSyncTime(_lastSyncTime!)),
              if (_lastActivitySyncTime != null)
                _buildDetailItem('最后活动同步时间', _formatLastSyncTime(_lastActivitySyncTime!)),
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

  // 格式化日期时间
  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (e) {
      return dateTime;
    }
  }

  // 格式化最后同步时间
  String _formatLastSyncTime(String isoTimeString) {
    try {
      final dateTime = DateTime.parse(isoTimeString);
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return isoTimeString;
    }
  }

  // 安全格式化运动员对象中的时间字段（可能是字符串或DateTime）
  String _formatAthleteTime(dynamic timeValue) {
    if (timeValue == null) return '';

    try {
      if (timeValue is String) {
        return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(timeValue));
      } else if (timeValue is DateTime) {
        return DateFormat('yyyy-MM-dd HH:mm').format(timeValue);
      }
      return timeValue.toString();
    } catch (e) {
      return timeValue.toString();
    }
  }

  // 同步卡片
  Widget _buildSyncCard() {
    final needsSync = _needsActivitySync();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSyncing) ...[
              LinearProgressIndicator(value: _syncProgress),
              SizedBox(height: 8),
              Text(_syncStatus),
              SizedBox(height: 8),
            ],
            if (_lastActivitySyncTime != null) ...[
              Text(
                '最后活动同步: ${_formatLastSyncTime(_lastActivitySyncTime!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: _isSyncing || !needsSync ? null : syncActivities,
              icon: Icon(Icons.sync),
              label: Text(_isSyncing ? '同步中...' : '同步活动数据'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: needsSync ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
            if (!needsSync && !_isSyncing) ...[
              SizedBox(height: 8),
              Text(
                '所有活动已同步',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 布局切换卡片
  Widget _buildLayoutSwitchCard() {
    return Card(
      elevation: 2,
      child: SwitchListTile(
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
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: '请输入 API Key',
                border: OutlineInputBorder(),
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
      final lastActivitySyncTime = await _athleteModel.getLastActivitySyncTime();
      final lastSyncTime = await _athleteModel.getLastSyncTime();
      
      Logger.d('修复检查: 最后同步时间=$lastSyncTime, 最后活动同步时间=$lastActivitySyncTime', tag: 'DatabaseInit');
      
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
      }
    } catch (e) {
      print('检查认证状态失败: $e');
    }
  }

  /// 加载活动数量
  Future<void> _loadActivityCount() async {
    try {
      final activities = await ActivityService().getAllActivities();
      setState(() {
        _activityCount = activities.length;
      });
    } catch (e) {
      print('加载活动数量失败: $e');
    }
  }
}
