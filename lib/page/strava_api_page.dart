import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_client_manager.dart';
import '../utils/logger.dart';

class StravaApiPage extends StatefulWidget {
  final bool isAuthenticated;
  final DetailedAthlete? athlete;
  final Function(bool, DetailedAthlete?)? onAuthenticationChanged;

  const StravaApiPage({
    super.key,
    this.isAuthenticated = false,
    this.athlete,
    this.onAuthenticationChanged,
  });

  @override
  State<StravaApiPage> createState() => _StravaApiPageState();
}

class _StravaApiPageState extends State<StravaApiPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  
  TokenResponse? token;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    
    // 使用外部传入的认证状态和运动员信息
    if (widget.isAuthenticated) {
      setState(() {
        token = StravaClientManager().token;
        _tokenController.text = token?.accessToken ?? '';
      });
    }
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

  Future<void> _authenticate() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      String id = _idController.text;
      String key = _keyController.text;

      if (id.isEmpty || key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的 API ID 和 Key')),
        );
        return;
      }

      Logger.d(
          '开始认证，使用 API ID: $id, Key: ${key.substring(0, min(5, key.length))}...',
          tag: 'StravaApiPage');

      // 保存 API 密钥
      await _apiKeyModel.insertApiKey(id, key);
      if (!mounted) return;

      // 初始化 StravaClientManager
      await StravaClientManager().initialize(id, key);
      if (!mounted) return;

      Logger.d('StravaClientManager 初始化完成，开始进行认证', tag: 'StravaApiPage');

      // 进行认证
      final tokenResponse = await StravaClientManager().authenticate();
      if (!mounted) return;

      setState(() {
        token = tokenResponse;
        _tokenController.text = tokenResponse.accessToken;
      });

      // 获取运动员信息
      final athlete = await StravaClientManager()
          .stravaClient.athletes.getAuthenticatedAthlete();
      if (!mounted) return;

      // 通知认证状态变化
      widget.onAuthenticationChanged?.call(true, athlete);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('认证成功')),
      );
    } catch (e, stackTrace) {
      Logger.e('认证过程中出错', error: e, stackTrace: stackTrace, tag: 'StravaApiPage');
      if (mounted) {
        _showErrorMessage(e, stackTrace);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deauthenticate() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await StravaClientManager().deAuthenticate();
      
      setState(() {
        token = null;
        _tokenController.clear();
      });

      // 通知认证状态变化
      widget.onAuthenticationChanged?.call(false, null);
      
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已取消认证')));
    } catch (e, stackTrace) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('取消认证失败: $e')));
      Logger.e('取消认证失败', error: e, stackTrace: stackTrace, tag: 'StravaApiPage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorMessage(dynamic error, dynamic stackTrace) {
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
            const Divider(),
            if (error.errors != null && error.errors!.isNotEmpty) ...[
              const Text("详细信息:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...error.errors!
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
              const Text("无详细错误信息"),
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
                  child: const Text("关闭"),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strava API 设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // API 设置卡片
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
                              helperText: '在 Strava 开发者网站获取的客户端 ID',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _keyController,
                            decoration: const InputDecoration(
                              labelText: '请输入 API Key',
                              border: OutlineInputBorder(),
                              helperText: '在 Strava 开发者网站获取的客户端密钥',
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            minLines: 1,
                            maxLines: 3,
                            controller: _tokenController,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: "Access Token",
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _tokenController.text),
                                  ).then((_) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("已复制到剪贴板")),
                                      );
                                    }
                                  });
                                },
                              ),
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 16),
                          // Strava API 配置提示
                          const Card(
                            color: Color(0xFFF5F5F5),
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Strava API 配置说明',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text('1. 在 Strava 开发者网站创建应用'),
                                  Text('2. 授权回调域：localhost'),
                                  Text('3. 确保添加了回调 URL：stravaflutter://redirect'),
                                  SizedBox(height: 8),
                                  Text(
                                    '如果认证失败，请检查您的 API 配置是否正确。',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!widget.isAuthenticated) 
                            ElevatedButton.icon(
                              onPressed: _authenticate,
                              icon: const Icon(Icons.login),
                              label: const Text('登录 Strava'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _deauthenticate,
                              icon: const Icon(Icons.logout),
                              label: const Text('取消认证'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 