import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:great_circle_distance_calculator/great_circle_distance_calculator.dart';
import 'dart:io';

class ElevationPoint {
  final double distance;  // 距离（公里）
  final double elevation;  // 海拔（米）
  final LatLng position;  // 地理位置
  final double gradient;  // 坡度（百分比）

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
        final ele = double.parse(point.findElements('ele').first.text);
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
        
        final currentDistance = distance / 1000;  // 转换为公里
        
        // 计算坡度
        double gradient = 0.0;
        if (previousElevation != null && previousDistance != null) {
          final elevationDiff = ele - previousElevation;  // 高度差（米）
          final horizontalDist = (currentDistance - previousDistance) * 1000;  // 水平距离（米）
          if (horizontalDist > 0) {
            gradient = (elevationDiff / horizontalDist) * 100;  // 转换为百分比
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
      print('解析GPX文件失败: $e');
      return null;
    }
  }
}

class ElevationChart extends StatelessWidget {
  final ElevationData data;
  final Function(ElevationPoint point)? onPointSelected;
  final int? currentSegmentIndex;  // 添加当前段索引参数

  const ElevationChart({
    Key? key,
    required this.data,
    this.onPointSelected,
    this.currentSegmentIndex,  // 添加到构造函数
  }) : super(key: key);

  Color _getGradientColor(double gradient) {
    if (gradient > 10) return Colors.red;
    if (gradient > 6) return Colors.orange;
    if (gradient > 3) return Colors.yellow;
    if (gradient > 0) return Colors.green;
    if (gradient < -10) return Colors.purple;
    if (gradient < -6) return Colors.blue;
    if (gradient < -3) return Colors.lightBlue;
    return Colors.green;
  }

  String _getGradientText(double gradient) {
    if (gradient.abs() < 0.1) return '平路';
    return '${gradient.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
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
              Text(
                '海拔高度',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '总距离: ${data.totalDistance.toStringAsFixed(2)}km',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: (data.maxElevation / 5).ceil() * 100,
                  verticalInterval: data.totalDistance / 5,
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
                      interval: data.totalDistance / 5,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value >= data.totalDistance - 0.1) {
                          return Text('${value.toStringAsFixed(1)}');
                        }
                        return Text('${value.toInt()}');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (data.maxElevation / 5).ceil() * 100,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value % 100 == 0) {
                          return Text('${value.toInt()}');
                        }
                        return const SizedBox();
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
                minX: 0,
                maxX: data.totalDistance,
                minY: 0,
                maxY: (data.maxElevation / 100).ceil() * 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.points,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        Color color = Colors.transparent;
                        double radius = 0;
                        
                        // 如果是当前段的点，显示绿色点
                        if (currentSegmentIndex != null && index == currentSegmentIndex) {
                          color = Colors.green;
                          radius = 4;
                          
                          // 自动显示提示信息
                          final pointData = data.elevationPoints[index];
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onPointSelected?.call(pointData);
                          });
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: currentSegmentIndex == null, // 当显示当前位置时禁用触摸
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipBorder: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        int index = spot.x.round();
                        if (index >= 0 && index < data.elevationPoints.length) {
                          final pointData = data.elevationPoints[index];
                          final gradientColor = _getGradientColor(pointData.gradient);
                          final gradientText = _getGradientText(pointData.gradient);
                          
                          return LineTooltipItem(
                            '距离: ${pointData.distance.toStringAsFixed(1)} km\n'
                            '海拔: ${pointData.elevation.toStringAsFixed(0)} m\n'
                            '坡度: $gradientText',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text: '\n',
                              ),
                              TextSpan(
                                text: '●',
                                style: TextStyle(
                                  color: gradientColor,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                      final spot = response.lineBarSpots!.first;
                      int index = spot.x.round();
                      if (index >= 0 && index < data.elevationPoints.length) {
                        final pointData = data.elevationPoints[index];
                        onPointSelected?.call(pointData);
                      }
                    }
                  },
                  handleBuiltInTouches: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 