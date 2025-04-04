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
import '../page/strava_api_page.dart';

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
      // 无论是否已认证，都尝试加载数据
      _loadAthleteAndRoutes();
    });
  }

  @override
  void didUpdateWidget(RoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当认证状态从外部变化时，重新加载数据
    if (widget.isAuthenticated != oldWidget.isAuthenticated) {
      _loadAthleteAndRoutes();
    }
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
      // 判断是否已认证
      final isAuthenticated = widget.isAuthenticated || 
                            await StravaClientManager().isAuthenticated();
      
      if (!isAuthenticated) {
        setState(() {
          _isLoading = false;
          routeList = []; // 清空路线列表
        });
        return; // 未认证，直接返回
      }
      
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

  /// 跳转到Strava API设置页面
  void _navigateToStravaApiPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StravaApiPage(
          isAuthenticated: widget.isAuthenticated,
          athlete: athlete,
          onAuthenticationChanged: (isAuthenticated, newAthlete) {
            widget.onAuthenticationChanged?.call(isAuthenticated, newAthlete);
            if (isAuthenticated && newAthlete != null) {
              setState(() {
                athlete = newAthlete;
              });
              _loadRoutes();
            }
          },
        ),
      ),
    ).then((_) {
      // 如果已认证，刷新路线数据
      if (widget.isAuthenticated) {
        _loadRoutes();
      }
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
            onPressed: widget.isAuthenticated ? _loadRoutes : _navigateToStravaApiPage,
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
