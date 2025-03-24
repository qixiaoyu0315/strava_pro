import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';
import '../service/strava_client_manager.dart';

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
      await ExampleAuthentication(StravaClientManager().stravaClient).testDeauthorize();
      
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
                      ClipboardData(text: _textEditingController.text)
                    ).then((_) => ScaffoldMessenger.of(context).showSnackBar(
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
          ],
        ),
      ),
    );
  }
}
