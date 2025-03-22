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

  ElevationPoint({
    required this.distance,
    required this.elevation,
    required this.position,
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
        points.add(FlSpot(currentDistance, ele));
        elevationPoints.add(ElevationPoint(
          distance: currentDistance,
          elevation: ele,
          position: currentPosition,
        ));
        
        if (ele > maxElevation) maxElevation = ele;
        previousPoint = currentPosition;
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

  const ElevationChart({
    Key? key,
    required this.data,
    this.onPointSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 计算合适的横坐标刻度数量（约5-7个）
    int numberOfLabels = 6;
    double interval = data.totalDistance / (numberOfLabels - 1);
    // 向上取整到0.5或1的倍数，使刻度更整齐
    interval = (interval / 0.5).ceil() * 0.5;

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
                  horizontalInterval: 100,
                  verticalInterval: interval,
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
                    // axisNameWidget: const Text('距离 (km)'),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        // 对于起点和终点，显示完整数字
                        if (value == 0 || value >= data.totalDistance - 0.1) {
                          return Text('${value.toStringAsFixed(1)}');
                        }
                        // 对于中间点，显示整数部分
                        return Text('${value.toInt()}');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    // axisNameWidget: const Text('海拔 (m)'),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 100,
                      reservedSize: 40,
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
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
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
                        // 找到最接近的点位信息
                        int closestIndex = 0;
                        double minDistance = double.infinity;
                        
                        for (int i = 0; i < data.points.length; i++) {
                          final point = data.points[i];
                          final distance = (point.x - spot.x).abs();
                          if (distance < minDistance) {
                            minDistance = distance;
                            closestIndex = i;
                          }
                        }
                        
                        final pointData = data.elevationPoints[closestIndex];
                        
                        return LineTooltipItem(
                          '距离: ${pointData.distance.toStringAsFixed(1)} km\n'
                          '海拔: ${pointData.elevation.toStringAsFixed(0)} m',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlTapUpEvent && response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                      final spot = response.lineBarSpots!.first;
                      // 找到最接近的点位信息
                      int closestIndex = 0;
                      double minDistance = double.infinity;
                      
                      for (int i = 0; i < data.points.length; i++) {
                        final point = data.points[i];
                        final distance = (point.x - spot.x).abs();
                        if (distance < minDistance) {
                          minDistance = distance;
                          closestIndex = i;
                        }
                      }
                      
                      final pointData = data.elevationPoints[closestIndex];
                      onPointSelected?.call(pointData);
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