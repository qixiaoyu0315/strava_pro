import 'dart:async';

import 'package:flutter/material.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'route_detail_page.dart';
import '../service/strava_client_manager.dart';
import '../service/route_service.dart';
import '../widgets/route_landscape_layout.dart';
import '../widgets/route_portrait_layout.dart';

/// 路线页面组件
class RoutePage extends StatefulWidget {
  final bool isAuthenticated;
  final Function(bool, DetailedAthlete?)? onAuthenticationChanged;

  const RoutePage({
    super.key,
    this.isAuthenticated = false,
    this.onAuthenticationChanged,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  final RouteService _routeService = RouteService();
  
  TokenResponse? token;
  DetailedAthlete? athlete;
  List<Map<String, dynamic>> routeList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey().then((_) {
      if (widget.isAuthenticated) {
        // 如果已认证，直接加载数据
        _loadAthleteAndRoutes();
      } else {
        // 否则尝试认证
        _authenticate();
      }
    });
  }

  /// 加载API密钥
  Future<void> _loadApiKey() async {
    await _apiKeyModel.getApiKey();
  }

  /// 加载运动员信息和路线数据
  Future<void> _loadAthleteAndRoutes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (athlete == null) {
        athlete = await _routeService.getAthleteInfo();
        widget.onAuthenticationChanged?.call(true, athlete);
      }
      await _loadRoutes();
    } catch (e) {
      _showToast('加载数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载路线数据
  Future<void> _loadRoutes() async {
    try {
      final routes = await _routeService.getRoutes();
      setState(() {
        routeList = routes;
      });
    } catch (e) {
      _showToast('获取路线失败: $e');
    }
  }

  /// 执行Strava认证
  void _authenticate() {
    setState(() {
      _isLoading = true;
    });

    StravaClientManager().authenticate().then((token) async {
      setState(() {
        this.token = token;
      });

      // 获取运动员信息并通知状态变化
      try {
        athlete = await _routeService.getAthleteInfo();
        widget.onAuthenticationChanged?.call(true, athlete);
      } catch (e) {
        debugPrint('获取运动员信息失败: $e');
      }

      _showToast('认证成功');
      _loadRoutes();
    }).catchError((error) {
      _showErrorMessage(error);
      _showToast('认证失败: 请检查您的 API ID 和密钥。');
    }).whenComplete(() {
      setState(() {
        _isLoading = false;
      });
    });
  }

  /// 显示认证错误信息
  void _showErrorMessage(dynamic error) {
    if (error is Fault && mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("认证错误"),
            content: Text(
              "错误信息: ${error.message}\n-----------------\n详细信息:\n${(error.errors ?? []).map((e) => "代码: ${e.code}\n资源: ${e.resource}\n字段: ${e.field}\n").toList().join("\n----------\n")}",
            ),
          );
        },
      );
    }
  }

  /// 显示Toast消息
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

  /// 导航到路线详情页面
  void _navigateToRouteDetail(String routeId, {bool startNavigation = false}) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailPage(idStr: routeId),
        settings: RouteSettings(arguments: {'startNavigation': startNavigation}),
      ),
    );
  }

  /// 构建空数据视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('没有找到路线数据'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.isAuthenticated ? _loadRoutes : _authenticate,
            child: Text(widget.isAuthenticated ? '刷新数据' : '登录Strava'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检测是否为横屏模式
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadRoutes();
              },
              child: routeList.isEmpty
                  ? _buildEmptyView()
                  : CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          title: const Text('STRAVA-路线'),
                          floating: true,
                          snap: true,
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8, 16),
                          sliver: isLandscape
                              // 横屏模式：使用横向布局组件
                              ? RouteLandscapeLayout(
                                  routeList: routeList,
                                  onRouteTap: (routeId) => _navigateToRouteDetail(routeId),
                                  onNavigateTap: (routeId) => _navigateToRouteDetail(routeId, startNavigation: true),
                                )
                              // 竖屏模式：使用纵向布局组件
                              : RoutePortraitLayout(
                                  routeList: routeList,
                                  onRouteTap: (routeId) => _navigateToRouteDetail(routeId),
                                  onNavigateTap: (routeId) => _navigateToRouteDetail(routeId, startNavigation: true),
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }
}
