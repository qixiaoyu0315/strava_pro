import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:great_circle_distance_calculator/great_circle_distance_calculator.dart';
import 'dart:io';
import 'dart:async';
import '../utils/logger.dart';
import 'dart:math' as math;

class ElevationPoint {
  final double distance; // 距离（公里）
  final double elevation; // 海拔（米）
  final LatLng position; // 地理位置
  final double gradient; // 坡度（百分比）

  ElevationPoint({
    required this.distance,
    required this.elevation,
    required this.position,
    required this.gradient,
  });
}

class ElevationData {
  final List<FlSpot> points;
  final List<ElevationPoint> elevationPoints;
  final double maxElevation;
  final double totalDistance;

  ElevationData({
    required this.points,
    required this.elevationPoints,
    required this.maxElevation,
    required this.totalDistance,
  });

  static Future<ElevationData?> fromGPXFile(String filePath) async {
    try {
      final file = File(filePath);
      final contents = await file.readAsString();
      final document = XmlDocument.parse(contents);
      final trackPoints = document.findAllElements('trkpt');

      List<FlSpot> points = [];
      List<ElevationPoint> elevationPoints = [];
      double distance = 0;
      double maxElevation = 0;
      LatLng? previousPoint;
      double? previousElevation;
      double? previousDistance;

      for (var point in trackPoints) {
        final lat = double.parse(point.getAttribute('lat')!);
        final lon = double.parse(point.getAttribute('lon')!);
        final ele = double.parse(point.findElements('ele').first.innerText);
        final currentPosition = LatLng(lat, lon);

        if (previousPoint != null) {
          final distanceInMeters = GreatCircleDistance.fromDegrees(
            latitude1: previousPoint.latitude,
            longitude1: previousPoint.longitude,
            latitude2: lat,
            longitude2: lon,
          ).haversineDistance();
          distance += distanceInMeters;
        }

        final currentDistance = distance / 1000; // 转换为公里

        // 计算坡度
        double gradient = 0.0;
        if (previousElevation != null && previousDistance != null) {
          final elevationDiff = ele - previousElevation; // 高度差（米）
          final horizontalDist =
              (currentDistance - previousDistance) * 1000; // 水平距离（米）
          if (horizontalDist > 0) {
            gradient = (elevationDiff / horizontalDist) * 100; // 转换为百分比
          }
        }

        points.add(FlSpot(currentDistance, ele));
        elevationPoints.add(ElevationPoint(
          distance: currentDistance,
          elevation: ele,
          position: currentPosition,
          gradient: gradient,
        ));

        if (ele > maxElevation) maxElevation = ele;
        previousPoint = currentPosition;
        previousElevation = ele;
        previousDistance = currentDistance;
      }

      return ElevationData(
        points: points,
        elevationPoints: elevationPoints,
        maxElevation: maxElevation,
        totalDistance: distance / 1000,
      );
    } catch (e) {
      Logger.e('解析GPX文件失败', error: e, tag: 'SVG');
      return null;
    }
  }
}

class ElevationChart extends StatefulWidget {
  final ElevationData data;
  final Function(ElevationPoint) onPointSelected;
  final int? currentSegmentIndex;
  final double? visibleRangeStart;
  final double? visibleRangeEnd;

  const ElevationChart({
    super.key,
    required this.data,
    required this.onPointSelected,
    this.currentSegmentIndex,
    this.visibleRangeStart,
    this.visibleRangeEnd,
  });

  @override
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  Timer? _tooltipTimer;
  bool _showTooltip = false;
  int? _lastSegmentIndex;
  double _currentRangeValue = 7; // 默认显示全程
  List<double> _rangeValues = [];

  @override
  void initState() {
    super.initState();
    _calculateRangeValues();
  }

  @override
  void didUpdateWidget(ElevationChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.totalDistance != widget.data.totalDistance) {
      _calculateRangeValues();
    }
    if (widget.currentSegmentIndex != _lastSegmentIndex &&
        widget.currentSegmentIndex != null) {
      _lastSegmentIndex = widget.currentSegmentIndex;
    }
  }

  void _calculateRangeValues() {
    final baseRange = widget.data.totalDistance / 2;
    _rangeValues = List.generate(7, (index) => baseRange / math.pow(2, 6 - index));
    _rangeValues.add(widget.data.totalDistance); // 添加全程选项
  }

  // 获取当前范围的描述文本
  String _getRangeText() {
    final range = _rangeValues[_currentRangeValue.toInt()];
    if (_currentRangeValue == 7) {
      return '全程';
    } else {
      return '${range.toStringAsFixed(1)}km';
    }
  }

  Color _getGradientColor(double gradient) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      // 夜间模式下的颜色
      if (gradient > 15) return Color(0xFFFF5252); // 深红色
      if (gradient > 10) return Color(0xFFFFB74D); // 深橙色
      if (gradient > 5) return Color(0xFFFFEB3B); // 深黄色
      if (gradient > 0) return Color(0xFF66BB6A); // 深绿色
      if (gradient < -15) return Color(0xFFE040FB); // 深紫色
      if (gradient < -10) return Color(0xFF448AFF); // 深蓝色
      if (gradient < -5) return Color(0xFF40C4FF); // 浅蓝色
      return Color(0xFF81D4FA); // 最浅蓝色
    } else {
      // 日间模式下的颜色
      if (gradient > 15) return Colors.red;
      if (gradient > 10) return Colors.orange;
      if (gradient > 5) return Colors.yellow.shade800;
      if (gradient > 0) return Colors.green;
      if (gradient < -15) return Colors.purple;
      if (gradient < -10) return Colors.blue;
      if (gradient < -5) return Colors.lightBlue;
      return Colors.blue.shade200;
    }
  }

  String _getGradientText(double gradient) {
    if (gradient.abs() < 0.1) return '平路';
    return '${gradient.toStringAsFixed(1)}%';
  }

  Widget _buildTooltip(BuildContext context, ElevationPoint pointData) {
    final gradientColor = _getGradientColor(pointData.gradient);
    final gradientText = _getGradientText(pointData.gradient);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '距离: ${pointData.distance.toStringAsFixed(1)} km',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '海拔: ${pointData.elevation.toStringAsFixed(0)} m',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '坡度: $gradientText',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: gradientColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 计算可见范围
    double minX = 0;
    double maxX = widget.data.totalDistance;
    
    // 根据滑块值计算实际显示范围
    if (_currentRangeValue < 7) { // 不是全程
      final rangeDistance = _rangeValues[_currentRangeValue.toInt()];
      if (widget.currentSegmentIndex != null && 
          widget.currentSegmentIndex! < widget.data.elevationPoints.length) {
        // 以当前位置为中心
        final currentX = widget.data.points[widget.currentSegmentIndex!].x;
        minX = math.max(0, currentX - rangeDistance / 2);
        maxX = math.min(widget.data.totalDistance, currentX + rangeDistance / 2);
      } else {
        // 没有当前位置时，显示起点开始的范围
        maxX = math.min(widget.data.totalDistance, rangeDistance);
      }
    }
    
    // 确保范围不超出总距离
    minX = minX.clamp(0, widget.data.totalDistance);
    maxX = maxX.clamp(0, widget.data.totalDistance);
    
    // 确保minX < maxX
    if (minX >= maxX) {
      minX = 0;
      maxX = widget.data.totalDistance;
    }

    // 计算当前可视范围内的最大和最小海拔
    double minElevation = double.infinity;
    double maxElevation = double.negativeInfinity;
    
    for (var point in widget.data.points) {
      if (point.x >= minX && point.x <= maxX) {
        if (point.y < minElevation) minElevation = point.y;
        if (point.y > maxElevation) maxElevation = point.y;
      }
    }
    
    // 如果没有找到有效值，使用整体范围
    if (minElevation == double.infinity || maxElevation == double.negativeInfinity) {
      minElevation = 0;
      maxElevation = widget.data.maxElevation;
    }
    
    // 添加上下边距
    final elevationRange = maxElevation - minElevation;
    final padding = elevationRange * 0.1; // 10%的边距
    minElevation = math.max(0, minElevation - padding);
    maxElevation = maxElevation + padding;
    
    // 检查当前位置是否在可视范围内
    bool isCurrentPointInRange = true;
    if (widget.currentSegmentIndex != null && 
        widget.currentSegmentIndex! < widget.data.elevationPoints.length) {
      double currentX = widget.data.points[widget.currentSegmentIndex!].x;
      isCurrentPointInRange = currentX >= minX && currentX <= maxX;
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左侧三等分信息区域（距离、海拔、坡度）
              widget.currentSegmentIndex != null && widget.currentSegmentIndex! < widget.data.elevationPoints.length
                ? Expanded(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pointData = widget.data.elevationPoints[widget.currentSegmentIndex!];
                        final gradientText = _getGradientText(pointData.gradient);
                        final gradientColor = _getGradientColor(pointData.gradient);
                        
                        // 单行布局 - 平均分配信息到一行
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 距离信息
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  Icon(Icons.straighten, size: 14),
                                  SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '${pointData.distance.toStringAsFixed(1)}km',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 海拔信息
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.height, size: 14),
                                  SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '${pointData.elevation.toStringAsFixed(0)}m',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 坡度信息
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.trending_up, size: 14),
                                  SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      gradientText,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: gradientColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                : Expanded(
                    flex: 3,
                    child: Text(
                      '海拔高度',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
              // 右侧一等分（全程显示 + 警告提示）
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 当当前位置不在可视范围内时显示指示器（小图标）
                    if (widget.currentSegmentIndex != null && !isCurrentPointInRange)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: widget.data.points[widget.currentSegmentIndex!].x > maxX
                              ? '位置超出右侧范围'
                              : '位置在视图左侧',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 14,
                          ),
                        ),
                      ),
                    // 显示范围文本
                    Row(
                      children: [
                        Icon(Icons.zoom_out_map, size: 14),
                        SizedBox(width: 2),
                        Text(
                          _getRangeText(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 添加滑块控件
          Row(
            children: [
              Icon(Icons.zoom_out, size: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    trackHeight: 2.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _currentRangeValue,
                    min: 0,
                    max: 7,
                    divisions: 7,
                    onChanged: (value) {
                      setState(() {
                        _currentRangeValue = value;
                      });
                    },
                  ),
                ),
              ),
              Icon(Icons.zoom_in, size: 16),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: (maxElevation - minElevation) / 5,
                      verticalInterval: (maxX - minX) / 5,
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (maxX - minX) / 5,
                          getTitlesWidget: (value, meta) {
                            if (value == minX || value >= maxX - 0.1) {
                              return Text(value.toStringAsFixed(1));
                            }
                            return Text('${value.toInt()}');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (maxElevation - minElevation) / 5,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    minX: minX,
                    maxX: maxX,
                    minY: minElevation,
                    maxY: maxElevation,
                    lineBarsData: [
                      LineChartBarData(
                        spots: widget.data.points,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            Color color = Colors.transparent;
                            double radius = 0;

                            // 如果点在可显示范围外，不显示
                            if (spot.x < minX || spot.x > maxX) {
                              return FlDotCirclePainter(
                                radius: 0,
                                color: Colors.transparent,
                                strokeWidth: 0,
                                strokeColor: Colors.transparent,
                              );
                            }

                            if (widget.currentSegmentIndex != null &&
                                index == widget.currentSegmentIndex) {
                              color = Colors.green;
                              radius = 4;
                            }

                            return FlDotCirclePainter(
                              radius: radius,
                              color: color,
                              strokeWidth: 2,
                              strokeColor: color,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .2),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(0),  // 减小内边距
                        tooltipMargin: 0,  // 减小外边距
                        fitInsideHorizontally: true,  // 确保tooltip在图表内水平显示
                        fitInsideVertically: true,    // 确保tooltip在图表内垂直显示
                        getTooltipColor: (_) => Colors.transparent,  // 透明背景
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            // 找到最接近的点
                            int closestIndex = 0;
                            double minDistance = double.infinity;

                            for (int i = 0;
                                i < widget.data.points.length;
                                i++) {
                              final point = widget.data.points[i];
                              final distance = (point.x - spot.x).abs();
                              if (distance < minDistance) {
                                minDistance = distance;
                                closestIndex = i;
                              }
                            }

                            final pointData =
                                widget.data.elevationPoints[closestIndex];
                            final gradientColor =
                                _getGradientColor(pointData.gradient);

                            return LineTooltipItem(
                              '',  // 移除折线图中的信息显示
                              TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: '●',
                                  style: TextStyle(
                                    color: gradientColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                      touchCallback:
                          (FlTouchEvent event, LineTouchResponse? response) {
                        if (event is FlTapUpEvent &&
                            response?.lineBarSpots != null &&
                            response!.lineBarSpots!.isNotEmpty) {
                          final spot = response.lineBarSpots!.first;

                          // 找到最接近的点
                          int closestIndex = 0;
                          double minDistance = double.infinity;

                          for (int i = 0; i < widget.data.points.length; i++) {
                            final point = widget.data.points[i];
                            final distance = (point.x - spot.x).abs();
                            if (distance < minDistance) {
                              minDistance = distance;
                              closestIndex = i;
                            }
                          }

                          final pointData =
                              widget.data.elevationPoints[closestIndex];
                          widget.onPointSelected.call(pointData);
                        }
                      },
                      handleBuiltInTouches: true,
                    ),
                  ),
                ),
                // 如果当前点在可视范围外，在图表右边添加指示箭头
                if (widget.currentSegmentIndex != null && 
                    widget.currentSegmentIndex! < widget.data.elevationPoints.length && 
                    !isCurrentPointInRange)
                  Positioned(
                    left: _getArrowPosition(
                      widget.data.points[widget.currentSegmentIndex!].x, 
                      minX, maxX, 
                      MediaQuery.of(context).size.width - 32 - 32
                    ),
                    bottom: 10,
                    child: Icon(
                      _getArrowIcon(
                        widget.data.points[widget.currentSegmentIndex!].x, 
                        minX, maxX
                      ),
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 计算箭头位置
  double _getArrowPosition(double pointX, double minX, double maxX, double chartWidth) {
    // 由于我们只关心设备位置是否超出右侧边界，所以只在右侧显示箭头
    if (pointX > maxX) {
      return chartWidth; // 右侧
    } else {
      return -1000; // 不显示
    }
  }
  
  // 获取箭头图标
  IconData _getArrowIcon(double pointX, double minX, double maxX) {
    // 只返回向右的箭头
    return Icons.arrow_forward; // 右侧箭头
  }
}
