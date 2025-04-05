import 'package:flutter/material.dart';
import 'dart:ui';
import 'cached_route_image.dart';

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
    final cardHeight = isLandscape ? 200.0 : 180.0;
    // 底部信息栏高度
    final infoBarHeight = isLandscape ? 56.0 : 48.0;

    return SizedBox(
      height: cardHeight,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // 底层：路线地图作为背景
              Positioned.fill(
                child: _buildMapBackground(isDarkMode),
              ),
              
              // 半透明遮罩层，增加对比度
              Positioned.fill(
                child: Container(
                  color: isDarkMode 
                      ? Colors.black.withOpacity(0.1) 
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              
              // 上层：路线信息
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 路线名称
                      Text(
                        routeData['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isLandscape ? 18 : 20,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          shadows: [
                            Shadow(
                              blurRadius: 2.0,
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // 弹性空间，使底部信息栏固定在底部
                      const Spacer(),
                      
                      // 底部信息栏
                      _buildInfoBar(isLandscape, isDarkMode),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建地图背景
  Widget _buildMapBackground(bool isDarkMode) {
    final defaultImageUrl = 'https://via.placeholder.com/700x292';
    final imageUrl = routeData['mapUrl'] != '无地图链接' ? routeData['mapUrl']! : defaultImageUrl;
    final darkImageUrl = routeData['mapDarkUrl'] != '无地图链接' ? routeData['mapDarkUrl']! : defaultImageUrl;
    
    return CachedRouteImage(
      imageUrl: imageUrl,
      darkImageUrl: darkImageUrl,
      fit: BoxFit.cover,
      placeholder: Center(
        child: CircularProgressIndicator(),
      ),
      errorBuilder: (context, error) => Container(
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      ),
    );
  }

  /// 构建底部信息栏
  Widget _buildInfoBar(bool isLandscape, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    
    // 使用普通半透明容器而不是磨砂效果，降低质感
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.black.withOpacity(0.7) 
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDarkMode 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 12.0, 
        vertical: isLandscape ? 10.0 : 8.0
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 距离信息
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_bike, 
                  size: isLandscape ? 18 : 16, 
                  color: subtitleColor),
              const SizedBox(width: 4),
              Text(
                '${routeData['distance']?.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 14 : 13,
                  color: textColor,
                ),
              ),
            ],
          ),

          // 时间信息
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time, 
                   size: isLandscape ? 18 : 16, 
                   color: subtitleColor),
              const SizedBox(width: 4),
              Text(
                '${routeData['estimatedMovingTime']?.toStringAsFixed(1)} h',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 14 : 13,
                  color: textColor,
                ),
              ),
            ],
          ),

          // 爬升信息
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up, 
                   size: isLandscape ? 18 : 16, 
                   color: subtitleColor),
              const SizedBox(width: 4),
              Text(
                '${routeData['elevationGain']?.toStringAsFixed(0)} m',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 14 : 13,
                  color: textColor,
                ),
              ),
            ],
          ),

          // 导航按钮
          InkWell(
            onTap: onNavigate,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 12 : 10,
                vertical: isLandscape ? 6 : 4),
              decoration: BoxDecoration(
                color: Colors.deepOrangeAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.navigation,
                    size: isLandscape ? 16 : 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '导航',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isLandscape ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 