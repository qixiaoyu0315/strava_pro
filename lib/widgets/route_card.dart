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
    final cardHeight = isLandscape ? 160.0 : 160.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
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
            SizedBox(
              height: cardHeight,
              width: double.infinity,
              child: _buildMapBackground(isDarkMode),
            ),
            
            // 半透明遮罩层，增加对比度
            Positioned.fill(
              child: Container(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.3),
              ),
            ),
            
            // 上层：路线信息
            SizedBox(
              height: cardHeight,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildRouteInfoOverlay(context, isLandscape, isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建地图背景
  Widget _buildMapBackground(bool isDarkMode) {
    return Image.network(
      routeData['mapUrl'] != '无地图链接'
          ? isDarkMode
              ? routeData['mapDarkUrl']!
              : routeData['mapUrl']!
          : 'https://via.placeholder.com/700x292',
      fit: BoxFit.fill,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      ),
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
    );
  }

  /// 构建路线信息覆盖层
  Widget _buildRouteInfoOverlay(BuildContext context, bool isLandscape, bool isDarkMode) {
    // 设置文本颜色，以适应深色/浅色背景
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 路线名称
        Text(
          routeData['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isLandscape ? 18 : 20,
            color: textColor,
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(1.0, 1.0),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
const Spacer(),
        // 添加磨砂背景
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 距离信息
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bike, size: 16, color: subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    '${routeData['distance']?.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              // 时间信息
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 16, color: subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    '${routeData['estimatedMovingTime']?.toStringAsFixed(2)} h',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              // 爬升信息
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, size: 16, color: subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    '${routeData['elevationGain']?.toStringAsFixed(0)} m',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              // 导航按钮
              InkWell(
                onTap: onNavigate,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrangeAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation, size: 14, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        '导航',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
    );
  }
} 