import 'package:flutter/material.dart';
import 'route_card.dart';

/// 路线列表横屏布局组件
class RouteLandscapeLayout extends StatelessWidget {
  final List<Map<String, dynamic>> routeList;
  final Function(String) onRouteTap;
  final Function(String) onNavigateTap;

  /// 创建路线列表横屏布局组件
  /// [routeList] 路线数据列表
  /// [onRouteTap] 点击路线回调
  /// [onNavigateTap] 点击导航按钮回调
  const RouteLandscapeLayout({
    super.key,
    required this.routeList,
    required this.onRouteTap,
    required this.onNavigateTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            onTap: () => onRouteTap(routeData['idStr']!),
            onNavigate: () => onNavigateTap(routeData['idStr']!),
          );
        },
        childCount: routeList.length,
      ),
    );
  }
} 