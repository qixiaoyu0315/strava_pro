import 'package:flutter/material.dart';
import 'route_card.dart';

/// 路线列表纵向布局组件
class RoutePortraitLayout extends StatelessWidget {
  final List<Map<String, dynamic>> routeList;
  final Function(String) onRouteTap;
  final Function(String) onNavigateTap;

  /// 创建路线列表纵向布局组件
  /// [routeList] 路线数据列表
  /// [onRouteTap] 点击路线回调
  /// [onNavigateTap] 点击导航按钮回调
  const RoutePortraitLayout({
    super.key,
    required this.routeList,
    required this.onRouteTap,
    required this.onNavigateTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final routeData = routeList[index];
          return RouteCard(
            routeData: routeData,
            onTap: () => onRouteTap(routeData['idStr']!),
            onNavigate: () => onNavigateTap(routeData['idStr']!),
          );
        },
        childCount: routeList.length,
      ),
    );
  }
} 