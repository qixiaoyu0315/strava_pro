import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';
import '../service/strava_client_manager.dart';
import '../utils/poly2svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingPage extends StatefulWidget {
  final Function(bool)? onLayoutChanged;

  const SettingPage({
    Key? key,
    this.onLayoutChanged,
  }) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _textEditingController = TextEditingController();
  TokenResponse? token;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('认证成功')),
      );
    } catch (e) {
      showErrorMessage(e, null);
    }
  }

  Future<void> testDeauth() async {
    try {
      await ExampleAuthentication(StravaClientManager().stravaClient)
          .testDeauthorize();

      setState(() {
        token = null;
        _textEditingController.clear();
        _idController.clear();
        _keyController.clear();
      });

      // 清除存储的 API 密钥
      await _apiKeyModel.deleteApiKey();

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '日历布局设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('水平滑动布局'),
                subtitle: const Text('开启后可以左右滑动切换月份'),
                value: _isHorizontalLayout,
                onChanged: (bool value) {
                  setState(() {
                    _isHorizontalLayout = value;
                  });
                  _saveSettings();
                },
              ),
              const Divider(),
              const Text(
                'Strava API设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: '请输入 API ID',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: '请输入 API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
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
                              ClipboardData(text: _textEditingController.text))
                          .then(
                              (_) => ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("已复制到剪贴板")),
                                  ));
                    },
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: testAuthentication,
                    icon: Icon(Icons.login),
                    label: const Text('认证'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: testDeauth,
                    icon: Icon(Icons.logout),
                    label: const Text('取消认证'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const Divider(height: 40),
              if (token != null) ...[
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
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
