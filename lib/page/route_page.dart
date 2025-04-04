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

/// 排序方式
enum SortOrder {
  none,       // 默认排序
  ascending,  // 由短到长
  descending, // 由长到短
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
  
  // 搜索相关属性
  bool _isSearching = false;
  String _searchQuery = "";
  List<Map<String, dynamic>> _filteredRouteList = [];
  final TextEditingController _searchController = TextEditingController();
  
  // 排序相关属性
  SortOrder _sortOrder = SortOrder.none;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          Logger.d('路线总数: $_totalRoutes, 每页数量: $_perPage, 总页数: $_totalPages', tag: 'RoutePage');
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
      
      Logger.d('加载路线数据成功，数量: ${routes.length}', tag: 'RoutePage');
      
      setState(() {
        routeList = routes;
        // 重置筛选的路线列表
        _filteredRouteList = List.from(routes);
        // 应用当前排序
        _applySorting();
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
  
  /// 搜索路线
  void _searchRoutes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        // 如果搜索词为空，显示所有路线
        _filteredRouteList = List.from(routeList);
      } else {
        // 否则进行模糊匹配
        _filteredRouteList = routeList.where((route) {
          // 搜索路线名称，支持模糊匹配
          final routeName = route['name']?.toString().toLowerCase() ?? '';
          return routeName.contains(_searchQuery);
        }).toList();
      }
      // 应用当前排序
      _applySorting(_filteredRouteList);
    });
  }
  
  /// 切换搜索状态
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        // 退出搜索模式，清空搜索内容并恢复原始列表
        _searchController.clear();
        _searchQuery = "";
        _filteredRouteList = List.from(routeList);
        // 应用当前排序
        _applySorting(_filteredRouteList);
      }
    });
  }
  
  /// 切换排序方式
  void _toggleSortOrder() {
    setState(() {
      // 循环切换排序方式：无排序 -> 由短到长 -> 由长到短 -> 无排序
      switch (_sortOrder) {
        case SortOrder.none:
          _sortOrder = SortOrder.ascending;
          _showToast('按路线长度从短到长排序');
          break;
        case SortOrder.ascending:
          _sortOrder = SortOrder.descending;
          _showToast('按路线长度从长到短排序');
          break;
        case SortOrder.descending:
          _sortOrder = SortOrder.none;
          _showToast('恢复默认排序');
          // 恢复默认排序时重新加载数据以获取原始顺序
          if (!_isSearching) {
            _refreshData();
          } else {
            // 如果在搜索模式，重新应用搜索过滤
            _searchRoutes(_searchQuery);
          }
          return; // 提前返回避免应用排序
          break;
      }
      // 应用排序
      _applySorting();
    });
  }
  
  /// 应用排序
  void _applySorting([List<Map<String, dynamic>>? listToSort]) {
    final targetList = listToSort ?? (_isSearching ? _filteredRouteList : routeList);
    
    switch (_sortOrder) {
      case SortOrder.ascending:
        // 由短到长排序
        targetList.sort((a, b) {
          final distanceA = a['distance'] as num? ?? 0;
          final distanceB = b['distance'] as num? ?? 0;
          return distanceA.compareTo(distanceB);
        });
        break;
      case SortOrder.descending:
        // 由长到短排序
        targetList.sort((a, b) {
          final distanceA = a['distance'] as num? ?? 0;
          final distanceB = b['distance'] as num? ?? 0;
          return distanceB.compareTo(distanceA);
        });
        break;
      case SortOrder.none:
        // 无需排序，直接使用API返回的原始顺序
        // 注意：如果需要刷新列表，会在_loadRoutes方法中重新获取数据
        break;
    }
    
    // 如果是操作的引用列表，还需要更新状态触发重绘
    if (listToSort == null) {
      setState(() {
        if (_isSearching) {
          _filteredRouteList = List.from(_filteredRouteList);
        } else {
          routeList = List.from(routeList);
        }
      });
    }
  }
  
  /// 构建正常AppBar
  Widget _buildNormalAppBar() {
    return SliverAppBar(
      title: const Text('STRAVA-路线'),
      floating: true,
      snap: true,
      actions: [
        // 排序按钮
        IconButton(
          icon: Icon(_getSortIcon()),
          onPressed: _toggleSortOrder,
          tooltip: _getSortTooltip(),
        ),
        // 搜索按钮
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
          tooltip: '搜索路线',
        ),
      ],
    );
  }
  
  /// 获取当前排序状态的图标
  IconData _getSortIcon() {
    switch (_sortOrder) {
      case SortOrder.ascending:
        return Icons.arrow_upward;
      case SortOrder.descending:
        return Icons.arrow_downward;
      default:
        return Icons.sort;
    }
  }
  
  /// 获取当前排序状态的提示文本
  String _getSortTooltip() {
    switch (_sortOrder) {
      case SortOrder.ascending:
        return '当前：由短到长';
      case SortOrder.descending:
        return '当前：由长到短';
      default:
        return '排序路线';
    }
  }
  
  /// 构建搜索AppBar
  Widget _buildSearchAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '搜索路线名称...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: _searchRoutes,
      ),
      actions: [
        // 搜索模式下也保留排序按钮
        IconButton(
          icon: Icon(_getSortIcon()),
          onPressed: _toggleSortOrder,
          tooltip: _getSortTooltip(),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSearch,
          tooltip: '退出搜索',
        ),
      ],
    );
  }
  
  /// 构建分页控件
  Widget _buildPaginationControls() {
    // 始终显示调试信息，以便排查问题
    Logger.d('构建分页控件: totalRoutes=$_totalRoutes, perPage=$_perPage, totalPages=$_totalPages', tag: 'RoutePage');
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '第 $_currentPage/$_totalPages 页 (共 $_totalRoutes 条路线)',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 首页按钮
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: _currentPage > 1 ? () => _loadPage(1) : null,
              ),
              // 上一页按钮
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1 ? _loadPrevPage : null,
              ),
              // 页码选择器
              _buildPageSelector(),
              // 下一页按钮
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages ? _loadNextPage : null,
              ),
              // 尾页按钮
              IconButton(
                icon: const Icon(Icons.last_page),
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
    // 确定显示的路线列表（原始列表或搜索过滤后的列表）
    final displayedRouteList = _isSearching ? _filteredRouteList : routeList;

    return Scaffold(
      body: _isLoading && routeList.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _refreshData();
              },
              child: routeList.isEmpty
                  ? _buildEmptyView()
                  : CustomScrollView(
                      slivers: [
                        // 动态选择AppBar
                        _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
                        
                        // 搜索结果提示
                        if (_isSearching && _searchQuery.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '搜索 "$_searchQuery" 的结果: ${_filteredRouteList.length} 条',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        
                        // 路线内容
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8, 16),
                          sliver: isLandscape
                              // 横屏模式：使用横向布局组件
                              ? RouteLandscapeLayout(
                                  routeList: displayedRouteList,
                                  onRouteTap: (routeId) => _navigateToRouteDetail(routeId),
                                  onNavigateTap: (routeId) => _navigateToRouteDetail(routeId, startNavigation: true),
                                )
                              // 竖屏模式：使用纵向布局组件
                              : RoutePortraitLayout(
                                  routeList: displayedRouteList,
                                  onRouteTap: (routeId) => _navigateToRouteDetail(routeId),
                                  onNavigateTap: (routeId) => _navigateToRouteDetail(routeId, startNavigation: true),
                                ),
                        ),
                        
                        // 加载状态指示器
                        if (_isLoading && routeList.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                        
                        // 没有搜索结果时显示提示
                        if (_isSearching && _filteredRouteList.isEmpty)
                          SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '找不到包含 "$_searchQuery" 的路线',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        // 路线列表底部显示分页控件或路线总数信息
                        if (!_isSearching && displayedRouteList.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: _totalRoutes > _perPage && _totalPages > 1 
                                ? _buildPaginationControls() 
                                : Container(
                                  padding: const EdgeInsets.all(16.0),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '共 $_totalRoutes 条路线',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ),
                            ),
                          ),
                      ],
                    ),
            ),
    );
  }
}
