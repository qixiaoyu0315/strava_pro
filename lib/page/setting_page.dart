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

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _textEditingController = TextEditingController();
  TokenResponse? token;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final ApiKeyModel _apiKeyModel = ApiKeyModel();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
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
    try {
      // 获取当前时间并转换为 UTC
      final now = DateTime.now().toUtc();
      // 获取一年前的时间
      final oneYearAgo = now.subtract(Duration(days: 365));

      print('开始时间: ${oneYearAgo.toIso8601String()}');
      print('结束时间: ${now.toIso8601String()}');
      print('Access Token: ${token?.accessToken}');

      // 创建保存目录
      final saveDir = Directory('/storage/emulated/0/Download/strava_pro/svg');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final activities = await StravaClientManager()
          .stravaClient
          .activities
          .listLoggedInAthleteActivities(
            now,
            oneYearAgo,
            1,
            50,
          );

      print('获取到 ${activities.length} 个活动');

      int successCount = 0;
      for (var activity in activities) {
        try {
          if (activity.map?.summaryPolyline != null) {
            // 格式化活动日期
            final date = DateTime.parse(activity.startDate ?? '');
            final fileName = DateFormat('yyyy-MM-dd').format(date) + '.svg';
            final filePath = '${saveDir.path}/$fileName';

            // 生成并保存 SVG
            final svgContent = PolylineToSVG.generateAndSaveSVG(
              activity.map!.summaryPolyline!,
              filePath,
              strokeColor: 'green', // 红色线条
              strokeWidth: 10,
            );

            if (svgContent != null) {
              successCount++;
              print('成功生成 SVG: $fileName');
            }
          }
        } catch (e) {
          print('处理活动 ${activity.name} 时出错: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步完成，成功生成 $successCount 个 SVG 文件')),
      );
    } catch (e) {
      print('同步失败错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
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
                        .then((_) => ScaffoldMessenger.of(context).showSnackBar(
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
            const Divider(height: 40),
            if (token != null)
              ElevatedButton.icon(
                onPressed: syncActivities,
                icon: Icon(Icons.sync),
                label: const Text('同步数据'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
