import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';
import '../service/strava_client_manager.dart';
import '../utils/poly2svg.dart';

class SettingPage extends StatefulWidget {
  final Function(bool)? onLayoutChanged;
  final bool isAuthenticated;
  final DetailedAthlete? athlete;
  final Function(bool, DetailedAthlete?)? onAuthenticationChanged;

  const SettingPage({
    Key? key,
    this.onLayoutChanged,
    this.isAuthenticated = false,
    this.athlete,
    this.onAuthenticationChanged,
  }) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _textEditingController = TextEditingController();
  TokenResponse? token;
  DetailedAthlete? _athlete;
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  final Map<String, bool> _processedDates = {};

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  bool _isHorizontalLayout = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadSettings();

    // 使用外部传入的认证状态和运动员信息
    if (widget.isAuthenticated && widget.athlete != null) {
      setState(() {
        _athlete = widget.athlete;
        token = StravaClientManager().token;
        _textEditingController.text = token?.accessToken ?? '';
      });
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

  FutureOr<Null> showErrorMessage(dynamic error, dynamic stackTrace) {
    if (error is Fault) {
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

        // 通知主应用认证状态和用户信息已更新
        widget.onAuthenticationChanged?.call(true, athlete);
      }
    } catch (e) {
      debugPrint('获取运动员信息失败: $e');
    }
  }

  Future<void> testAuthentication() async {
    try {
      String id = _idController.text;
      String key = _keyController.text;

      // 保存 API 密钥
      await _apiKeyModel.insertApiKey(id, key);

      // 初始化 StravaClientManager
      await StravaClientManager().initialize(id, key);

      // 进行认证
      final tokenResponse = await StravaClientManager().authenticate();

      setState(() {
        token = tokenResponse;
        _textEditingController.text = tokenResponse.accessToken;
      });

      // 认证成功后加载运动员信息
      await _loadAthleteInfo();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('认证成功')),
      );
    } catch (e) {
      showErrorMessage(e, null);
    }
  }

  Future<void> testDeauth() async {
    try {
      await StravaClientManager().deAuthenticate();

      setState(() {
        token = null;
        _athlete = null;
        _textEditingController.clear();
        _idController.clear();
        _keyController.clear();
      });

      // 清除存储的 API 密钥
      await _apiKeyModel.deleteApiKey();

      // 通知主应用认证状态已更新
      widget.onAuthenticationChanged?.call(false, null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已取消认证')),
      );
    } catch (e) {
      showErrorMessage(e, null);
    }
  }

  Future<void> syncActivities() async {
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步正在进行中，请等待完成')),
      );
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

      // 按开始时间排序活动，确保每天处理最早的活动
      final activities = await StravaClientManager()
          .stravaClient
          .activities
          .listLoggedInAthleteActivities(
            now,
            oneYearAgo,
            1,
            200,
          );

      activities.sort((a, b) {
        final dateA = DateTime.parse(a.startDate ?? '');
        final dateB = DateTime.parse(b.startDate ?? '');
        return dateA.compareTo(dateB);
      });

      int totalActivities = activities.length;
      int processedCount = 0;
      int successCount = 0;

      setState(() {
        _syncStatus = '获取到 $totalActivities 个活动，开始生成SVG...';
      });

      for (var activity in activities) {
        try {
          if (activity.map?.summaryPolyline != null) {
            final date = DateTime.parse(activity.startDate ?? '');
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final fileName = '$dateStr.svg';
            final filePath = '${saveDir.path}/$fileName';

            // 检查是否已处理过该日期
            if (!_processedDates.containsKey(dateStr)) {
              _processedDates[dateStr] = true;

              setState(() {
                _syncStatus = '正在处理: ${activity.name ?? fileName} ($dateStr)';
              });

              // 生成SVG文件
              final svgContent = PolylineToSVG.generateAndSaveSVG(
                activity.map!.summaryPolyline!,
                filePath,
                strokeColor: 'green',
                strokeWidth: 10,
              );

              if (svgContent != null) {
                successCount++;
              }
            }
          }

          processedCount++;
          setState(() {
            _syncProgress = processedCount / totalActivities;
            _syncStatus = '已处理: $processedCount/$totalActivities';
          });

        } catch (e) {
          print('处理活动 ${activity.name} 时出错: $e');
        }
      }

      setState(() {
        _isSyncing = false;
        _syncStatus = '同步完成';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步完成，成功生成 $successCount 个 SVG 文件')),
      );
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncStatus = '同步失败: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败: $e')),
      );
    }
  }

  bool _isValidSvg(String content) {
    if (content.isEmpty) return false;
    if (!content.trim().startsWith('<svg') ||
        !content.trim().endsWith('</svg>')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 用户信息卡片
            if (_athlete != null) ...[
              Card(
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
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      // 运动统计
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            context,
                            '关注者',
                            '${_athlete?.followerCount ?? 0}',
                          ),
                          _buildStatItem(
                            context,
                            '关注中',
                            '${_athlete?.friendCount ?? 0}',
                          ),
                          _buildStatItem(
                            context,
                            '活动',
                            '${_athlete?.resourceState ?? 0}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // 布局切换开关
            Card(
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
            ),
            const SizedBox(height: 24),
            // API设置卡片
            Card(
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: '请输入 API ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: '请输入 API Key',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
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
                            ).then((_) =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("已复制到剪贴板")),
                                ));
                          },
                        ),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: testAuthentication,
                          icon: Icon(Icons.login),
                          label: const Text('认证'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: testDeauth,
                          icon: Icon(Icons.logout),
                          label: const Text('取消认证'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 同步按钮和进度
            if (token != null) ...[
              Card(
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
                        SizedBox(height: 16),
                      ],
                      ElevatedButton.icon(
                        onPressed: _isSyncing ? null : syncActivities,
                        icon: Icon(Icons.sync),
                        label: Text(_isSyncing ? '同步中...' : '同步数据'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 构建统计项小部件
  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
