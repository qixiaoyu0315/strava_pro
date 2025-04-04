import 'package:flutter/material.dart';

/// 路线卡片组件，在不同布局下显示路线信息
class RouteCard extends StatelessWidget {
  final Map<String, dynamic> routeData;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  
  /// 创建路线卡片组件
  /// [routeData] 路线数据
  /// [onTap] 点击卡片回调
  /// [onNavigate] 点击导航按钮回调
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
    final cardHeight = isLandscape ? 140.0 : 150.0;
    // 根据屏幕方向调整图片宽度比例
    final mapWidthRatio = isLandscape ? 0.2 : 0.4;

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
                    child: _buildMapImage(isDarkMode),
                  ),

                  // 右侧信息区域
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildRouteInfo(context, isLandscape),
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

  /// 构建地图图片组件
  Widget _buildMapImage(bool isDarkMode) {
    return Container(
      color: Colors.grey.shade200,
      child: Image.network(
        routeData['mapUrl'] != '无地图链接'
            ? isDarkMode
                ? routeData['mapDarkUrl']!
                : routeData['mapUrl']!
            : 'https://via.placeholder.com/150',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
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
    );
  }

  /// 构建路线信息组件
  Widget _buildRouteInfo(BuildContext context, bool isLandscape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 路线名称
        _buildRouteName(isLandscape),
        
        // 距离和时间信息
        _buildDistanceTimeInfo(isLandscape),
        
        // 爬升和导航按钮
        _buildElevationNavigation(isLandscape),
      ],
    );
  }
  
  /// 构建路线名称组件
  Widget _buildRouteName(bool isLandscape) {
    return Padding(
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
    );
  }
  
  /// 构建距离和时间信息组件
  Widget _buildDistanceTimeInfo(bool isLandscape) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：距离
          Expanded(
            child: Row(
              children: [
                Icon(Icons.directions_bike, size: 16, color: Colors.black54),
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
                Icon(Icons.access_time, size: 16, color: Colors.black54),
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
    );
  }
  
  /// 构建爬升和导航按钮组件
  Widget _buildElevationNavigation(bool isLandscape) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：爬升信息
          Expanded(
            child: Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: Colors.black54),
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
    );
  }
} 