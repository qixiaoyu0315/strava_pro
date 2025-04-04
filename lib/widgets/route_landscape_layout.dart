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
    // 计算横屏下的卡片宽高比
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 24) / 2; // 两列的宽度减去间距
    final itemHeight = 200.0; // 与RouteCard中的横屏高度保持一致
    final aspectRatio = itemWidth / itemHeight;
    
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 两列
        childAspectRatio: aspectRatio, // 动态计算宽高比，确保高度正确
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