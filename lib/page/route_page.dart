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
import '../utils/logger.dart';

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
  
  // 分页相关属性
  int _currentPage = 1;
  int _totalRoutes = 0;
  final int _perPage = 20;
  int get _totalPages => (_totalRoutes / _perPage).ceil();

  @override
  void initState() {
    super.initState();
    _loadApiKey().then((_) async {
      // 检查认证状态并加载路线数据
      final isAuthenticated = widget.isAuthenticated || 
                             await StravaClientManager().isAuthenticated();
                             
      if (isAuthenticated) {
        _loadAthleteAndRoutes();
        _loadTotalRoutes();
      }
    });
  }

  @override
  void didUpdateWidget(RoutePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当认证状态从外部变化时，重新加载数据
    if (!oldWidget.isAuthenticated && widget.isAuthenticated) {
      _loadAthleteAndRoutes();
      _loadTotalRoutes();
    }
  }

  /// 加载API密钥
  Future<void> _loadApiKey() async {
    await _apiKeyModel.getApiKey();
  }
  
  /// 加载路线总数
  Future<void> _loadTotalRoutes() async {
    try {
      final count = await _routeService.getRoutesCount();
      if (mounted) {
        setState(() {
          _totalRoutes = count;
        });
      }
    } catch (e) {
      _showToast('获取路线总数失败: $e');
    }
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
      final routes = await _routeService.getRoutes(
        page: _currentPage, 
        perPage: _perPage
      );
      setState(() {
        routeList = routes;
      });
    } catch (e) {
      _showToast('获取路线失败: $e');
    }
  }
  
  /// 加载指定页码的数据
  Future<void> _loadPage(int page) async {
    if (page < 1 || page > _totalPages) return;
    
    setState(() {
      _currentPage = page;
      _isLoading = true;
    });
    
    await _loadRoutes();
    
    setState(() {
      _isLoading = false;
    });
  }
  
  /// 加载下一页
  void _loadNextPage() {
    if (_currentPage < _totalPages) {
      _loadPage(_currentPage + 1);
    }
  }
  
  /// 加载上一页
  void _loadPrevPage() {
    if (_currentPage > 1) {
      _loadPage(_currentPage - 1);
    }
  }
  
  /// 刷新数据
  Future<void> _refreshData() async {
    setState(() {
      _currentPage = 1;
      _isLoading = true;
    });
    
    await _loadTotalRoutes();
    await _loadRoutes();
    
    setState(() {
      _isLoading = false;
    });
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
              _refreshData();
            }
          },
        ),
      ),
    ).then((_) {
      // 如果已认证，刷新路线数据
      if (widget.isAuthenticated) {
        _refreshData();
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
            onPressed: widget.isAuthenticated ? _refreshData : _navigateToStravaApiPage,
            child: Text(widget.isAuthenticated ? '刷新数据' : '登录Strava'),
          )
        ],
      ),
    );
  }
  
  /// 构建分页控件
  Widget _buildPaginationControls() {
    if (_totalRoutes <= _perPage) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '第 $_currentPage/$_totalPages 页 (共$_totalRoutes条路线)',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 首页按钮
              IconButton(
                icon: Icon(Icons.first_page),
                onPressed: _currentPage > 1 ? () => _loadPage(1) : null,
              ),
              // 上一页按钮
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: _currentPage > 1 ? _loadPrevPage : null,
              ),
              // 页码选择器
              _buildPageSelector(),
              // 下一页按钮
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages ? _loadNextPage : null,
              ),
              // 尾页按钮
              IconButton(
                icon: Icon(Icons.last_page),
                onPressed: _currentPage < _totalPages ? () => _loadPage(_totalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建页码选择器
  Widget _buildPageSelector() {
    // 最多显示5个页码按钮
    List<Widget> pageButtons = [];
    int startPage = 1;
    int endPage = _totalPages;
    
    // 如果总页数超过5页，则只显示当前页附近的页码
    if (_totalPages > 5) {
      startPage = _currentPage - 2;
      endPage = _currentPage + 2;
      
      // 确保起始页和结束页在有效范围内
      if (startPage < 1) {
        startPage = 1;
        endPage = 5;
      } else if (endPage > _totalPages) {
        endPage = _totalPages;
        startPage = _totalPages - 4;
      }
    }
    
    // 添加页码按钮
    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            onPressed: i == _currentPage ? null : () => _loadPage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == _currentPage ? Theme.of(context).primaryColor : null,
              foregroundColor: i == _currentPage ? Colors.white : null,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: Size(36, 36),
            ),
            child: Text('$i'),
          ),
        ),
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pageButtons,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 检测是否为横屏模式
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      body: _isLoading && routeList.isEmpty 
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _refreshData();
              },
              child: routeList.isEmpty
                  ? _buildEmptyView()
                  : Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
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
                              // 加载状态指示器
                              if (_isLoading && routeList.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 分页控件
                        _buildPaginationControls(),
                      ],
                    ),
            ),
    );
  }
}
