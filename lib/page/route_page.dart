import 'dart:async';

import 'package:flutter/material.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'route_detail_page.dart'; // 导入新页面
import '../service/strava_client_manager.dart';

// 提取出路线组件
class RouteCard extends StatelessWidget {
  final Map<String, dynamic> routeData;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  const RouteCard({
    super.key,
    required this.routeData,
    required this.onTap,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    // 根据屏幕方向调整高度
    final cardHeight = isLandscape ? 120.0 : 150.0;
    // 根据屏幕方向调整图片宽度比例
    final mapWidthRatio = isLandscape ? 0.3 : 0.35;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            // 上半部分：地图和路线名称
            SizedBox(
              height: cardHeight, // 动态高度
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧地图，宽度根据屏幕方向调整
                  SizedBox(
                    width: screenWidth * mapWidthRatio,
                    child: Container(
                      color: Colors.grey.shade200,
                      child: Image.network(
                        routeData['mapUrl'] != '无地图链接'
                            ? isDarkMode
                                ? routeData['mapDarkUrl']!
                                : routeData['mapUrl']!
                            : 'https://via.placeholder.com/150',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.broken_image,
                                size: 50, color: Colors.grey)),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 右侧信息区域
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 路线名称
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              routeData['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isLandscape ? 16 : 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 距离和时间信息
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 左侧：距离
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.directions_bike,
                                          size: 16, color: Colors.black54),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${routeData['distance']?.toStringAsFixed(1)} km',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLandscape ? 14 : 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(width: 8),

                                // 右侧：时间
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 16, color: Colors.black54),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${routeData['estimatedMovingTime']?.toStringAsFixed(2)} h',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLandscape ? 14 : 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 爬升和导航按钮
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 左侧：爬升信息
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.trending_up,
                                          size: 16, color: Colors.black54),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${routeData['elevationGain']?.toStringAsFixed(0)} m',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLandscape ? 14 : 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 右侧：导航按钮
                                InkWell(
                                  onTap: onNavigate,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isLandscape ? 15 : 25,
                                        vertical: isLandscape ? 2 : 4),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrangeAccent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.navigation,
                                      size: isLandscape ? 18 : 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutePage extends StatefulWidget {
  final bool isAuthenticated;
  final Function(bool, DetailedAthlete?)? onAuthenticationChanged;

  const RoutePage({
    super.key,
    this.isAuthenticated = false,
    this.onAuthenticationChanged,
  });

  @override
  _RoutePageState createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  String id = '';
  String key = '';

  final ApiKeyModel _apiKeyModel = ApiKeyModel();
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

  Future<void> _loadAthleteAndRoutes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (athlete == null) {
        athlete = await StravaClientManager()
            .stravaClient
            .athletes
            .getAuthenticatedAthlete();
        widget.onAuthenticationChanged?.call(true, athlete);
      }
      await getRoutes();
    } catch (e) {
      _showToast('加载数据失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> getRoutes() async {
    try {
      final routes = await StravaClientManager()
          .stravaClient
          .routes
          .listAthleteRoutes(115603263, 1, 10);
      routeList.clear();
      for (var route in routes) {
        routeList.add({
          'idStr': route.idStr ?? '未知',
          'name': route.name ?? '未知',
          'mapUrl': route.mapUrls?.url ?? '无地图链接',
          'mapDarkUrl': route.mapUrls?.darkUrl ?? route.mapUrls?.url ?? '无地图链接',
          'distance': (route.distance ?? 0) / 1000, // 转换为公里
          'elevationGain': route.elevationGain ?? 0, // 高度
          'estimatedMovingTime':
              (route.estimatedMovingTime ?? 0) / 3600, // 转换为小时
        });
      }
      setState(() {});
    } catch (e) {
      _showToast('获取路线失败: $e');
    }
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _apiKeyModel.getApiKey();
    if (apiKey != null) {
      id = apiKey['api_id']!;
      key = apiKey['api_key']!;
    }
  }

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
        athlete = await StravaClientManager()
            .stravaClient
            .athletes
            .getAuthenticatedAthlete();
        widget.onAuthenticationChanged?.call(true, athlete);
      } catch (e) {
        debugPrint('获取运动员信息失败: $e');
      }

      _showToast('认证成功');
      getRoutes();
    }).catchError((error) {
      showErrorMessage(error, null);
      _showToast('认证失败: 请检查您的 API ID 和密钥。');
    }).whenComplete(() {
      setState(() {
        _isLoading = false;
      });
    });
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

  void _showToast(String message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  // 导航到路线详情页面
  void _navigateToRouteDetail(String routeId, {bool startNavigation = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailPage(idStr: routeId),
        settings:
            RouteSettings(arguments: {'startNavigation': startNavigation}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检测是否为横屏模式
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await getRoutes();
              },
              child: routeList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('没有找到路线数据'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: widget.isAuthenticated
                                ? getRoutes
                                : _authenticate,
                            child: Text(
                                widget.isAuthenticated ? '刷新数据' : '登录Strava'),
                          )
                        ],
                      ),
                    )
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
                              // 横屏模式：并排显示两个路线
                              ? _buildLandscapeRouteList()
                              // 竖屏模式：单列显示路线
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final routeData = routeList[index];
                                      return RouteCard(
                                        routeData: routeData,
                                        onTap: () => _navigateToRouteDetail(
                                            routeData['idStr']!),
                                        onNavigate: () =>
                                            _navigateToRouteDetail(
                                                routeData['idStr']!,
                                                startNavigation: true),
                                      );
                                    },
                                    childCount: routeList.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
            ),
    );
  }

  // 横屏模式下的路线列表构建方法
  Widget _buildLandscapeRouteList() {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 两列
        childAspectRatio: 2.8, // 调整宽高比，使卡片更扁平
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= routeList.length) return null;
          final routeData = routeList[index];
          return RouteCard(
            routeData: routeData,
            onTap: () => _navigateToRouteDetail(routeData['idStr']!),
            onNavigate: () => _navigateToRouteDetail(routeData['idStr']!,
                startNavigation: true),
          );
        },
        childCount: routeList.length,
      ),
    );
  }
}
