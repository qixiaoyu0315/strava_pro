import 'package:strava_client/strava_client.dart';
import '../service/strava_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StravaClientManager {
  static final StravaClientManager _instance = StravaClientManager._internal();
  late StravaClient stravaClient;
  TokenResponse? _token;
  String? _clientId;
  String? _secret;
  bool _isAuthenticated = false;

  factory StravaClientManager() {
    return _instance;
  }

  StravaClientManager._internal();

  Future<void> initialize(String clientId, String secret) async {
    _clientId = clientId;
    _secret = secret;
    stravaClient = StravaClient(clientId: clientId, secret: secret);
  }

  /// 验证用户是否已认证
  Future<bool> isAuthenticated() async {
    if (_isAuthenticated && _token != null) {
      return true;
    }

    try {
      // 尝试加载现有的认证
      final success = await loadExistingAuthentication();
      return success;
    } catch (e) {
      debugPrint('检查认证状态时出错: $e');
      return false;
    }
  }

  /// 尝试从本地存储加载现有的认证信息
  Future<bool> loadExistingAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJson = prefs.getString('strava_token');

      if (tokenJson != null && tokenJson.isNotEmpty) {
        final tokenMap = json.decode(tokenJson) as Map<String, dynamic>;
        final token = TokenResponse.fromJson(tokenMap);

        // 检查token是否仍然有效
        if (token.expiresAt > DateTime.now().millisecondsSinceEpoch / 1000) {
          _token = token;
          _isAuthenticated = true;

          // 我们会继续使用现有的stravaClient，在API请求时手动添加token
          return true;
        } else {
          // 尝试刷新token
          return await _refreshToken(token);
        }
      }
      return false;
    } catch (e) {
      debugPrint('加载认证时出错: $e');
      return false;
    }
  }

  /// 刷新token
  Future<bool> _refreshToken(TokenResponse token) async {
    try {
      if (_clientId == null || _secret == null) {
        return false;
      }

      // 使用HTTP包直接调用刷新API
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': _clientId!,
          'client_secret': _secret!,
          'grant_type': 'refresh_token',
          'refresh_token': token.refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final refreshedToken = TokenResponse.fromJson(responseData);
        _token = refreshedToken;
        _isAuthenticated = true;

        // 保存新的token
        await _saveToken(refreshedToken);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('刷新token时出错: $e');
      return false;
    }
  }

  /// 保存token到本地存储
  Future<void> _saveToken(TokenResponse token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenJson = json.encode(token.toJson());
      await prefs.setString('strava_token', tokenJson);
    } catch (e) {
      debugPrint('保存token时出错: $e');
    }
  }

  /// 获取当前token
  TokenResponse? get token => _token;

  /// 清除认证信息
  Future<void> clearAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('strava_token');
      _token = null;
      _isAuthenticated = false;
    } catch (e) {
      debugPrint('清除认证信息时出错: $e');
    }
  }

  Future<TokenResponse> authenticate() async {
    final token = await ExampleAuthentication(stravaClient).testAuthentication(
      [
        AuthenticationScope.profile_read_all,
        AuthenticationScope.read_all,
        AuthenticationScope.activity_read_all
      ],
      "stravaflutter://redirect",
    );

    _token = token;
    _isAuthenticated = true;
    await _saveToken(token);
    return token;
  }

  /// 取消认证
  Future<void> deAuthenticate() async {
    await ExampleAuthentication(stravaClient).testDeauthorize();
    await clearAuthentication();
  }
}
