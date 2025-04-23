import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/activity_service.dart';
import '../utils/logger.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/calendar_utils.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivityDetailPage extends StatefulWidget {
  final String activityId;

  const ActivityDetailPage({
    super.key,
    required this.activityId,
  });

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  final ActivityService _activityService = ActivityService();
  bool _isLoading = true;
  Map<String, dynamic>? _activityData;
  String? _errorMessage;
  bool _hasStoragePermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadActivityData();
  }

  Future<void> _checkPermissions() async {
    try {
      final storageStatus = await Permission.storage.status;
      setState(() {
        _hasStoragePermission = storageStatus.isGranted;
      });
      
      if (!storageStatus.isGranted) {
        final result = await Permission.storage.request();
        setState(() {
          _hasStoragePermission = result.isGranted;
        });
      }
    } catch (e) {
      Logger.e('检查权限失败: $e', tag: 'ActivityDetailPage');
    }
  }

  Future<void> _loadActivityData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final data = await _activityService.getActivity(widget.activityId);
      
      if (data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未找到活动数据';
        });
        return;
      }

      setState(() {
        _activityData = data;
        _isLoading = false;
      });
    } catch (e) {
      Logger.e('加载活动详情失败: $e', tag: 'ActivityDetailPage');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载活动详情失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activityData?['name'] ?? '活动详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivityData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadActivityData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_activityData == null) {
      return const Center(child: Text('没有活动数据'));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivityHeader(),
            const Divider(height: 32),
            _buildCombinedInfoCard(),
            const Divider(height: 32),
            _buildActivityRoute(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityHeader() {
    final activity = _activityData!;
    final startDate = DateTime.parse(activity['start_date_local'] as String);
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');
    final formattedDate = dateFormat.format(startDate);
    final activityType = _translateActivityType(activity['type'] as String? ?? '未知');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getActivityColor(activity['type'] as String? ?? '未知').withOpacity(0.1),
                  child: Icon(_getActivityIcon(activity['type'] as String? ?? '未知'), 
                    color: _getActivityColor(activity['type'] as String? ?? '未知')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['name'] as String? ?? '未命名活动',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '$activityType · $formattedDate',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedInfoCard() {
    final activity = _activityData!;
    final distance = (activity['distance'] as double?) ?? 0.0;
    final movingTime = (activity['moving_time'] as int?) ?? 0;
    final elapsedTime = (activity['elapsed_time'] as int?) ?? 0;
    final elevationGain = (activity['total_elevation_gain'] as double?) ?? 0.0;
    
    final avgSpeed = (activity['average_speed'] as double?) ?? 0.0;
    final maxSpeed = (activity['max_speed'] as double?) ?? 0.0;
    final avgHeartRate = (activity['average_heartrate'] as double?) ?? 0.0;
    final maxHeartRate = (activity['max_heartrate'] as int?) ?? 0;
    final kilojoules = (activity['kilojoules'] as double?) ?? 0.0;
    final activityType = activity['type'] as String? ?? '';
    final hasPace = activityType == 'Run' || activityType == 'Walk' || activityType == 'Hike';
    
    // 格式化时间
    final movingTimeStr = _formatDuration(movingTime);
    final elapsedTimeStr = _formatDuration(elapsedTime);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('活动数据', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            
            // 基本数据
            _buildInfoRow('距离', '${(distance / 1000).toStringAsFixed(2)} 公里'),
            _buildInfoRow('运动时间', movingTimeStr),
            _buildInfoRow('总时间', elapsedTimeStr),
            if (elevationGain > 0) _buildInfoRow('爬升', '${elevationGain.toInt()} 米'),
            
            const Divider(height: 32),
            
            // 详细数据
            if (hasPace) ...[
              _buildInfoRow('平均配速', _formatPace(avgSpeed)),
              _buildInfoRow('最快配速', _formatPace(maxSpeed)),
            ] else ...[
              _buildInfoRow('平均速度', '${(avgSpeed * 3.6).toStringAsFixed(1)} km/h'),
              _buildInfoRow('最大速度', '${(maxSpeed * 3.6).toStringAsFixed(1)} km/h'),
            ],
            if (avgHeartRate > 0) _buildInfoRow('平均心率', '${avgHeartRate.round()} bpm'),
            if (maxHeartRate > 0) _buildInfoRow('最大心率', '$maxHeartRate bpm'),
            if (kilojoules > 0) _buildInfoRow('消耗能量', '${kilojoules.toStringAsFixed(0)} kJ'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRoute() {
    final activity = _activityData!;
    final mapPolyline = activity['map_polyline'] as String?;
    
    if (mapPolyline == null || mapPolyline.isEmpty) {
      Logger.d('活动无路线数据: Activity ID=${activity['activity_id']}', tag: 'ActivityDetailPage');
      return _buildNoRouteWidget('此活动没有路线数据');
    }
    
    try {
      Logger.d('开始解析活动路线: ${mapPolyline.substring(0, min(30, mapPolyline.length))}...', tag: 'ActivityDetailPage');
      
      // 解码polyline
      final points = _decodePolyline(mapPolyline);
      
      if (points.isEmpty) {
        Logger.w('解析的路线点为空: Activity ID=${activity['activity_id']}', tag: 'ActivityDetailPage');
        return _buildNoRouteWidget('路线数据无效');
      }
      
      Logger.d('成功解析活动路线，共${points.length}个点', tag: 'ActivityDetailPage');
      
      // 创建路线边界框
      final bounds = LatLngBounds.fromPoints(points);
      
      // 给边界框添加一些填充，确保路线完全显示
      final paddedBounds = _padBounds(bounds, 0.15); // 15%的填充
      
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('活动路线', style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${points.length}个点', 
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _openInExternalMap(points),
                        tooltip: '在地图应用中打开',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    options: MapOptions(
                      // 使用边界自动设置地图视图
                      initialCameraFit: CameraFit.bounds(
                        bounds: paddedBounds,
                      ),
                      // 启用所有交互选项
                      minZoom: 4,
                      maxZoom: 18,
                      keepAlive: true,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.strava_pro',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 4.0,
                            color: _getActivityColor(activity['type'] as String? ?? '未知'),
                          ),
                        ],
                      ),
                      // 显示路线的起点和终点
                      MarkerLayer(
                        markers: [
                          // 起点标记
                          if (points.isNotEmpty)
                            Marker(
                              point: points.first,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          // 终点标记
                          if (points.length > 1)
                            Marker(
                              point: points.last,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Logger.e('绘制路线图出错: $e', tag: 'ActivityDetailPage');
      return _buildNoRouteWidget('路线图绘制失败: ${e.toString().substring(0, min(50, e.toString().length))}');
    }
  }

  // 解码Polyline为LatLng点列表
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        double latitude = lat / 1E5;
        double longitude = lng / 1E5;
        points.add(LatLng(latitude, longitude));
      }
    } catch (e) {
      Logger.e('解码polyline失败: $e', tag: 'ActivityDetailPage');
    }

    return points;
  }

  // 在外部地图应用中打开路线
  void _openInExternalMap(List<LatLng> points) async {
    try {
      if (points.isEmpty) return;

      // 取中间点作为地图中心
      final centerPoint = points[points.length ~/ 2];
      
      // 构建Google Maps URL
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${centerPoint.latitude},${centerPoint.longitude}'
      );
      
      // 尝试启动URL
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      Logger.e('无法打开外部地图: $e', tag: 'ActivityDetailPage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开地图应用: $e')),
      );
    }
  }

  // 显示暂无路线图片的小部件
  Widget _buildNoRouteWidget([String message = '暂无路线图片']) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 格式化持续时间
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '$hours小时${minutes.toString().padLeft(2, '0')}分${remainingSeconds.toString().padLeft(2, '0')}秒';
    } else {
      return '${minutes.toString().padLeft(2, '0')}分${remainingSeconds.toString().padLeft(2, '0')}秒';
    }
  }

  // 格式化配速（分钟/公里）
  String _formatPace(double speedMeterPerSecond) {
    if (speedMeterPerSecond <= 0) return '-';
    
    // 将米/秒转换为分钟/公里
    final paceInSeconds = 1000 / speedMeterPerSecond; // 秒/公里
    final paceMinutes = (paceInSeconds / 60).floor();
    final paceSeconds = (paceInSeconds % 60).round();
    
    return '$paceMinutes\'${paceSeconds.toString().padLeft(2, '0')}"/km';
  }

  // 将活动类型转换为中文
  String _translateActivityType(String type) {
    switch (type) {
      case 'Run':
        return '跑步';
      case 'Ride':
        return '骑行';
      case 'Swim':
        return '游泳';
      case 'Walk':
        return '步行';
      case 'Hike':
        return '徒步';
      case 'Workout':
        return '锻炼';
      case 'WeightTraining':
        return '力量训练';
      case 'Yoga':
        return '瑜伽';
      case 'VirtualRide':
        return '虚拟骑行';
      case 'VirtualRun':
        return '虚拟跑步';
      default:
        return type;
    }
  }
  
  // 根据活动类型获取图标
  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Run':
        return Icons.directions_run;
      case 'Ride':
        return Icons.directions_bike;
      case 'Swim':
        return Icons.pool;
      case 'Walk':
        return Icons.directions_walk;
      case 'Hike':
        return Icons.terrain;
      case 'Workout':
        return Icons.fitness_center;
      case 'WeightTraining':
        return Icons.fitness_center;
      case 'Yoga':
        return Icons.self_improvement;
      case 'VirtualRide':
        return Icons.computer;
      case 'VirtualRun':
        return Icons.computer;
      default:
        return Icons.directions_run;
    }
  }
  
  // 根据活动类型获取颜色
  Color _getActivityColor(String type) {
    switch (type) {
      case 'Run':
        return Colors.orange;
      case 'Ride':
        return Colors.blue;
      case 'Swim':
        return Colors.lightBlue;
      case 'Walk':
        return Colors.green;
      case 'Hike':
        return Colors.brown;
      case 'Workout':
        return Colors.deepPurple;
      case 'WeightTraining':
        return Colors.indigo;
      case 'Yoga':
        return Colors.teal;
      case 'VirtualRide':
        return Colors.cyan;
      case 'VirtualRun':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  // 为边界添加填充，确保路线完全可见
  LatLngBounds _padBounds(LatLngBounds bounds, double paddingRatio) {
    final latPadding = (bounds.north - bounds.south) * paddingRatio;
    final lngPadding = (bounds.east - bounds.west) * paddingRatio;
    
    // 至少有0.01度的填充，确保单点路线也能正常显示
    final minPadding = 0.01;
    final effectiveLatPadding = max(latPadding, minPadding); 
    final effectiveLngPadding = max(lngPadding, minPadding);
    
    return LatLngBounds(
      LatLng(bounds.south - effectiveLatPadding, bounds.west - effectiveLngPadding),
      LatLng(bounds.north + effectiveLatPadding, bounds.east + effectiveLngPadding),
    );
  }
} 