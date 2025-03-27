import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../service/strava_client_manager.dart';
import 'package:strava_client/strava_client.dart' as strava;
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../widgets/elevation_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class RouteDetailPage extends StatefulWidget {
  final String idStr;
  const RouteDetailPage({Key? key, required this.idStr}) : super(key: key);

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final MapController _mapController = MapController();
  LatLng? initialCenter;
  String? gpxFilePath;
  ElevationData? elevationData;
  final ValueNotifier<LatLng?> selectedPoint = ValueNotifier<LatLng?>(null);
  final ValueNotifier<LatLng?> currentLocation = ValueNotifier<LatLng?>(null);
  final ValueNotifier<int?> currentSegmentIndex = ValueNotifier<int?>(null);
  final ValueNotifier<double?> currentMinDistance = ValueNotifier<double?>(null);
  bool isNavigationMode = false;
  List<LatLng>? gpxPoints;
  StreamSubscription<Position>? _positionStreamSubscription;
  final ValueNotifier<Position?> currentPosition = ValueNotifier<Position?>(null);

  @override
  void initState() {
    super.initState();
    _checkExistingGPXFile();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    selectedPoint.dispose();
    currentLocation.dispose();
    currentSegmentIndex.dispose();
    currentMinDistance.dispose();
    currentPosition.dispose();
    super.dispose();
  }

  Future<void> _checkExistingGPXFile() async {
    try {
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/strava_pro/gpx');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // 检查目录是否存在
      if (!await directory.exists()) {
        return;
      }

      final file = File('${directory.path}/${widget.idStr}.gpx');
      print(file.path);
      if (await file.exists()) {
        final data = await ElevationData.fromGPXFile(file.path);
        if (data != null) {
          setState(() {
            gpxFilePath = file.path;
            elevationData = data;
            gpxPoints = data.elevationPoints.map((point) => point.position).toList();
          });
        }
      }
    } catch (e) {
      print('检查GPX文件失败: $e');
    }
  }

  Future<void> _exportGPX(strava.Route routeData) async {
    try {
      // 首先检查文件是否已经存在
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/strava_pro/gpx');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final fileName = '${routeData.idStr}.gpx';
      final file = File('${directory.path}/$fileName');
      
      // 如果文件已存在，直接解析它
      if (await directory.exists() && await file.exists()) {
        final data = await ElevationData.fromGPXFile(file.path);
        if (data != null) {
          setState(() {
            gpxFilePath = file.path;
            elevationData = data;
            gpxPoints = data.elevationPoints.map((point) => point.position).toList();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GPX文件已存在，直接解析完成')),
          );
          return; // 文件已存在，直接返回
        }
      }
      
      // 检查 Android 版本并请求相应权限
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13 及以上版本
          var status = await Permission.photos.status;
          if (!status.isGranted) {
            status = await Permission.photos.request();
            if (!status.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('需要存储权限才能导出文件')),
              );
              return;
            }
          }
        } else {
          // Android 13 以下版本
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('需要存储权限才能导出文件')),
              );
              return;
            }
          }
        }
      }

      // 获取下载目录
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 获取访问令牌
      final tokenResponse = await StravaClientManager().authenticate();
      final accessToken = tokenResponse.accessToken;
      if (accessToken == null) {
        throw Exception('未获取到访问令牌');
      }

      // 直接从 Strava API 获取 GPX 数据
      final response = await http.get(
        Uri.parse('https://www.strava.com/api/v3/routes/${routeData.id}/export_gpx'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode != 200) {
        throw Exception('获取 GPX 数据失败: ${response.statusCode}');
      }

      // 写入二进制数据
      await file.writeAsBytes(response.bodyBytes);
      
      // 解析GPX文件
      final data = await ElevationData.fromGPXFile(file.path);
      if (data != null) {
        setState(() {
          gpxFilePath = file.path;
          elevationData = data;
          gpxPoints = data.elevationPoints.map((point) => point.position).toList();
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX文件已保存并解析完成')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  void _startLocationUpdates() {
    print('开始位置更新服务...');
    _stopLocationUpdates();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // 每移动5米更新一次
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (!mounted) return;
        
        print('获取到新位置 - '
              '位置: ${position.latitude}, ${position.longitude}, '
              '精度: ${position.accuracy}米, '
              '海拔: ${position.altitude}米, '
              '速度: ${position.speed}m/s');
        
        currentPosition.value = position;
        final newLocation = LatLng(position.latitude, position.longitude);
        currentLocation.value = newLocation;
        _updateCurrentSegment();

        // 检查新位置是否在地图视野内
        if (isNavigationMode) {
          final bounds = _mapController.camera.visibleBounds;
          if (bounds != null) {
            // 计算设备位置到视野边缘的距离比例
            final distanceToEdge = _calculateDistanceToEdge(newLocation, bounds);
            
            // 如果距离边缘太近或已经超出视野，移动地图
            if (distanceToEdge < 0.2 || !_isLocationInBounds(newLocation, bounds)) {
              // 计算新的地图中心点，稍微向前偏移以显示更多前方区域
              final bearing = position.heading;
              final offset = _calculateMapOffset(newLocation, bearing);
              
              _mapController.move(
                offset,
                _mapController.camera.zoom,
                offset: Offset(0, -0.3), // 稍微向上偏移以显示更多前方区域
              );
            }
          }
        }
      },
      onError: (error) {
        print('位置流错误: $error');
        if (error is LocationServiceDisabledException) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请开启定位服务')),
          );
        }
      },
      cancelOnError: false,
    );
  }

  void _stopLocationUpdates() {
    print('停止位置更新服务...');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<void> _checkLocationPermission() async {
    try {
      // 检查定位服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请开启定位服务')),
        );
        await Geolocator.openLocationSettings();
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要定位权限才能获取位置')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('定位权限被永久拒绝，请在设置中开启')),
        );
        await Geolocator.openAppSettings();
        return;
      }

      // 权限获取成功后，开始位置更新
      _startLocationUpdates();
    } catch (e) {
      print('检查位置权限失败: $e');
    }
  }

  void _updateCurrentSegment() {
    if (currentLocation.value != null && gpxPoints != null) {
      final result = _findNearestSegment(currentLocation.value!, gpxPoints!);
      if (result != null) {
        currentSegmentIndex.value = result.$1;
        currentMinDistance.value = result.$2;
      }
    }
  }

  // 计算点到线段的距离
  double _calculateDistanceToLine(LatLng point, LatLng lineStart, LatLng lineEnd) {
    double lat = point.latitude;
    double lon = point.longitude;
    double lat1 = lineStart.latitude;
    double lon1 = lineStart.longitude;
    double lat2 = lineEnd.latitude;
    double lon2 = lineEnd.longitude;

    // 使用 Geolocator 计算点到两个端点的距离
    double d1 = Geolocator.distanceBetween(lat, lon, lat1, lon1);
    double d2 = Geolocator.distanceBetween(lat, lon, lat2, lon2);
    double lineLength = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

    // 如果线段长度为0，返回到端点的距离
    if (lineLength == 0) return d1;

    // 计算点到线段的投影是否在线段上
    double t = ((lat - lat1) * (lat2 - lat1) + (lon - lon1) * (lon2 - lon1)) / 
               ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1));

    if (t < 0) return d1;  // 投影点在线段起点之前
    if (t > 1) return d2;  // 投影点在线段终点之后

    // 计算投影点的坐标
    double projLat = lat1 + t * (lat2 - lat1);
    double projLon = lon1 + t * (lon2 - lon1);

    // 返回点到投影点的距离
    return Geolocator.distanceBetween(lat, lon, projLat, projLon);
  }

  // 检查设备位置是否在路线附近
  bool _isNearRoute(LatLng deviceLocation, List<LatLng> routePoints) {
    if (routePoints.length < 2) return false;

    double minDistance = double.infinity;
    // 遍历所有相邻的路线点对
    for (int i = 0; i < routePoints.length - 1; i++) {
      double distance = _calculateDistanceToLine(
        deviceLocation,
        routePoints[i],
        routePoints[i + 1]
      );
      minDistance = distance < minDistance ? distance : minDistance;
    }
    print('最小距离: $minDistance');

    return minDistance <= 50; // 如果最小距离小于20米，返回true
  }

  // 计算最近的路线点和对应的距离
  (int, double)? _findNearestSegment(LatLng deviceLocation, List<LatLng> routePoints) {
    if (routePoints.length < 2) return null;

    double minDistance = double.infinity;
    int nearestSegmentIndex = -1;

    // 遍历所有相邻的路线点对
    for (int i = 0; i < routePoints.length - 1; i++) {
      double distance = _calculateDistanceToLine(
        deviceLocation,
        routePoints[i],
        routePoints[i + 1]
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestSegmentIndex = i;
      }
    }

    return (nearestSegmentIndex, minDistance);
  }

  Widget _buildMap(List<LatLng> points, LatLng center) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: points.isNotEmpty
          ? FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 8.0,
                onMapReady: () {
                  // 计算路线的边界
                  double minLat = points.map((p) => p.latitude).reduce(math.min);
                  double maxLat = points.map((p) => p.latitude).reduce(math.max);
                  double minLng = points.map((p) => p.longitude).reduce(math.min);
                  double maxLng = points.map((p) => p.longitude).reduce(math.max);

                  // 创建边界矩形并添加边距
                  final bounds = LatLngBounds.fromPoints([
                    LatLng(minLat - 0.02, minLng - 0.02),
                    LatLng(maxLat + 0.02, maxLng + 0.02)
                  ]);

                  // 调整地图以适应边界
                  Future.delayed(Duration(milliseconds: 100), () {
                    _mapController.move(
                      bounds.center,
                      _mapController.camera.zoom,
                    );
                    
                    // 计算合适的缩放级别
                    final latZoom = _calculateZoomLevel(bounds.south, bounds.north, MediaQuery.of(context).size.height);
                    final lngZoom = _calculateZoomLevel(bounds.west, bounds.east, MediaQuery.of(context).size.width);
                    
                    _mapController.move(
                      bounds.center,
                      math.min(latZoom, lngZoom) - 0.5, // 减少0.5级缩放以留出边距
                    );
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.first,
                      child: Icon(Icons.location_on, color: Colors.green, size: 40.0),
                    ),
                    Marker(
                      point: points.last,
                      child: Icon(Icons.flag, color: Colors.red, size: 40.0),
                    ),
                  ],
                ),
                ValueListenableBuilder<LatLng?>(
                  valueListenable: currentLocation,
                  builder: (context, location, child) {
                    if (location == null) return const SizedBox();
                    final isNearRoute = gpxPoints != null ? 
                        _isNearRoute(location, gpxPoints!) : false;
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: location,
                          child: Container(
                            height: 32,
                            width: 32,
                            alignment: Alignment.center,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isNearRoute ? Colors.green : Colors.red,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isNearRoute ? Colors.green : Colors.red).withOpacity(0.3),
                                        spreadRadius: 4,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ValueListenableBuilder<LatLng?>(
                  valueListenable: selectedPoint,
                  builder: (context, point, child) {
                    if (point == null) return const SizedBox();
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          child: Icon(Icons.location_on, color: Colors.orange, size: 40.0),
                        ),
                      ],
                    );
                  },
                ),
              ],
            )
          : Center(child: Text('没有可用的路线数据')),
    );
  }

  // 添加计算坡度的方法
  double? _calculateCurrentGradient() {
    if (currentSegmentIndex.value == null || elevationData == null) return null;
    final points = elevationData!.elevationPoints;
    final index = currentSegmentIndex.value!;
    if (index >= points.length - 1) return null;

    final point1 = points[index];
    final point2 = points[index + 1];
    
    final elevationDiff = point2.elevation - point1.elevation;
    final distance = Geolocator.distanceBetween(
      point1.position.latitude,
      point1.position.longitude,
      point2.position.latitude,
      point2.position.longitude
    );
    
    if (distance == 0) return 0;
    return (elevationDiff / distance) * 100; // 转换为百分比
  }

  // 添加坡度颜色计算方法
  Color _getGradientColor(double gradient) {   
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


  // 添加计算缩放级别的辅助方法
  double _calculateZoomLevel(double min, double max, double screenSize) {
    final latDiff = (max - min).abs();
    final zoom = math.log(360.0 * screenSize / (latDiff * 256.0)) / math.ln2;
    return zoom;
  }

  // 计算位置到地图视野边缘的最小距离比例
  double _calculateDistanceToEdge(LatLng location, LatLngBounds bounds) {
    final latRatio = math.min(
      (location.latitude - bounds.south) / (bounds.north - bounds.south),
      (bounds.north - location.latitude) / (bounds.north - bounds.south)
    );
    
    final lngRatio = math.min(
      (location.longitude - bounds.west) / (bounds.east - bounds.west),
      (bounds.east - location.longitude) / (bounds.east - bounds.west)
    );
    
    return math.min(latRatio, lngRatio);
  }

  // 根据设备朝向计算地图偏移中心点
  LatLng _calculateMapOffset(LatLng location, double bearing) {
    // 计算前方偏移距离（米）
    const offsetDistance = 100.0; // 100米
    
    // 将偏移距离和方向转换为坐标偏移
    final radiusBearing = (bearing * math.pi) / 180;
    final latOffset = math.cos(radiusBearing) * offsetDistance / 111320.0; // 约111.32km = 1度纬度
    final lngOffset = math.sin(radiusBearing) * offsetDistance / (111320.0 * math.cos(location.latitude * math.pi / 180));
    
    return LatLng(
      location.latitude + latOffset,
      location.longitude + lngOffset
    );
  }

  // 检查位置是否在地图视野范围内
  bool _isLocationInBounds(LatLng location, LatLngBounds bounds) {
    final padding = 0.1; // 添加10%的边距判断
    final latRange = bounds.north - bounds.south;
    final lngRange = bounds.east - bounds.west;
    
    return location.latitude <= (bounds.north - latRange * padding) &&
           location.latitude >= (bounds.south + latRange * padding) &&
           location.longitude <= (bounds.east - lngRange * padding) &&
           location.longitude >= (bounds.west + lngRange * padding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<strava.Route>(
        future: getRoute(widget.idStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('获取路线失败: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('没有找到路线'));
          }

          final routeData = snapshot.data!;
          List<LatLng> points = [];
          if (routeData.map?.summaryPolyline != null) {
            PolylinePoints polylinePoints = PolylinePoints();
            List<PointLatLng> result = polylinePoints.decodePolyline(routeData.map!.summaryPolyline!);
            points = result.map((point) => LatLng(point.latitude, point.longitude)).toList();
          }

          LatLng center = points.isNotEmpty
              ? LatLng(
                  points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
                  points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
                )
              : LatLng(39.9042, 116.4074);

          if (initialCenter == null) {
            initialCenter = center;
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              if (!isNavigationMode)
                SliverAppBar(
                  title: Text('路线详情'),
                  floating: true,
                  snap: true,
                  forceElevated: innerBoxIsScrolled,
                ),
            ],
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (isNavigationMode) ...[
                        Builder(
                          builder: (context) {
                            final screenHeight = MediaQuery.of(context).size.height;
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isLandscape = screenWidth > screenHeight;
                            final paddingTop = MediaQuery.of(context).padding.top;
                            final paddingBottom = MediaQuery.of(context).padding.bottom;

                            if (isLandscape) {
                              // 横屏布局
                              final availableHeight = screenHeight - paddingTop - paddingBottom - 32;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 左侧地图
                                  Expanded(
                                    child: Container(
                                      height: availableHeight,
                                      margin: EdgeInsets.only(right: 8),
                                      child: _buildMap(points, center),
                                    ),
                                  ),
                                  // 右侧信息
                                  Expanded(
                                    child: Container(
                                      height: availableHeight,
                                      child: Column(
                                        children: [
                                          // 海拔和坡度信息（2/5）
                                          Container(
                                            height: availableHeight * 0.4,
                                            margin: EdgeInsets.only(bottom: 8),
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).cardColor,
                                              borderRadius: BorderRadius.circular(15),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: ValueListenableBuilder<Position?>(
                                              valueListenable: currentPosition,
                                              builder: (context, position, child) {
                                                final gradient = _calculateCurrentGradient();
                                                return Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    // 海拔信息
                                                    Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(Icons.height, 
                                                              color: Theme.of(context).colorScheme.primary,
                                                              size: 20
                                                            ),
                                                            SizedBox(width: 6),
                                                            Text(
                                                              '海拔',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 2),
                                                        Text(
                                                          '${position?.altitude.toStringAsFixed(1) ?? '--'} 米',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      height: 36,
                                                      width: 1,
                                                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                                                    ),
                                                    Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Row(
                                                          
                                                          children: [
                                                            Icon(Icons.trending_up,
                                                              color: Theme.of(context).colorScheme.primary,
                                                              size: 20
                                                            ),
                                                            SizedBox(width: 6),
                                                            Text(
                                                              '坡度',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 2),
                                                        Text(
                                                          gradient != null ? '${gradient.toStringAsFixed(1)}%' : '--',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: gradient != null ? _getGradientColor(gradient) : Theme.of(context).colorScheme.onSurface,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          // 海拔图（3/5）
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).cardColor,
                                                borderRadius: BorderRadius.circular(15),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(15),
                                                child: elevationData != null
                                                  ? ValueListenableBuilder<int?>(
                                                      valueListenable: currentSegmentIndex,
                                                      builder: (context, segmentIndex, child) {
                                                        return ValueListenableBuilder<double?>(
                                                          valueListenable: currentMinDistance,
                                                          builder: (context, minDistance, child) {
                                                            return ElevationChart(
                                                              data: elevationData!,
                                                              onPointSelected: (point) {
                                                                selectedPoint.value = point.position;
                                                              },
                                                              currentSegmentIndex: minDistance != null && minDistance <= 50 ? segmentIndex : null,
                                                            );
                                                          },
                                                        );
                                                      },
                                                    )
                                                  : SizedBox(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // 竖屏布局
                              final availableHeight = screenHeight - paddingTop - paddingBottom - 64;
                              final unit = availableHeight / 10;
                              return Column(
                                children: [
                                  // 地图组件 (5份)
                                  Container(
                                    height: unit * 5,
                                    child: _buildMap(points, center),
                                  ),
                                  SizedBox(height: 16),
                                  // 海拔和坡度信息卡片 (2份)
                                  Container(
                                    height: unit * 2,
                                    margin: EdgeInsets.symmetric(horizontal: 8),
                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).shadowColor.withOpacity(0.1),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ValueListenableBuilder<Position?>(
                                      valueListenable: currentPosition,
                                      builder: (context, position, child) {
                                        final gradient = _calculateCurrentGradient();
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            // 海拔信息
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.height, 
                                                      color: Theme.of(context).colorScheme.primary,
                                                      size: 20
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      '海拔',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  '${position?.altitude.toStringAsFixed(1) ?? '--'} 米',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              height: 36,
                                              width: 1,
                                              color: Theme.of(context).dividerColor.withOpacity(0.3),
                                            ),
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.trending_up,
                                                      color: Theme.of(context).colorScheme.secondary,
                                                      size: 20
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      '坡度',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  gradient != null ? '${gradient.toStringAsFixed(1)}%' : '--',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: gradient != null ? _getGradientColor(gradient) : Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // 海拔图 (3份)
                                  Container(
                                    height: unit * 3,
                                    margin: EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).shadowColor.withOpacity(0.1),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: elevationData != null
                                        ? ValueListenableBuilder<int?>(
                                            valueListenable: currentSegmentIndex,
                                            builder: (context, segmentIndex, child) {
                                              return ValueListenableBuilder<double?>(
                                                valueListenable: currentMinDistance,
                                                builder: (context, minDistance, child) {
                                                  return ElevationChart(
                                                    data: elevationData!,
                                                    onPointSelected: (point) {
                                                      selectedPoint.value = point.position;
                                                    },
                                                    currentSegmentIndex: minDistance != null && minDistance <= 50 ? segmentIndex : null,
                                                  );
                                                },
                                              );
                                            },
                                          )
                                        : SizedBox(),
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ] else ...[
                        // 地图组件
                        Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: _buildMap(points, center),
                        ),
                        SizedBox(height: 16),
                        // 海拔图
                        if (elevationData != null)
                          Container(
                            height: 200,
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: ElevationChart(
                                data: elevationData!,
                                onPointSelected: (point) {
                                  selectedPoint.value = point.position;
                                },
                                currentSegmentIndex: null,
                              ),
                            ),
                          ),
                        // 路线信息部分
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '路线名称: ${routeData.name}',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (gpxFilePath == null)
                                      IconButton(
                                        onPressed: () => _exportGPX(routeData),
                                        icon: Icon(Icons.download),
                                        tooltip: '导出GPX文件',
                                      ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.directions_bike),
                                        SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${((routeData.distance ?? 0) / 1000).toStringAsFixed(2)} km',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            Text('距离', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.landscape_outlined),
                                        SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${routeData.elevationGain?.toStringAsFixed(2) ?? 0} m',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            Text('累计爬升', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time),
                                        SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${((routeData.estimatedMovingTime ?? 0) / 3600).toStringAsFixed(2)} h',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            Text('预计时间', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: gpxFilePath != null
          ? FloatingActionButton(
              onPressed: () async {
                setState(() {
                  isNavigationMode = !isNavigationMode;
                });
                
                if (isNavigationMode) {
                  // 进入导航模式时检查权限并开始位置更新
                  await _checkLocationPermission();
                } else {
                  _stopLocationUpdates();
                }
              },
              child: Icon(isNavigationMode ? Icons.close : Icons.navigation),
              backgroundColor: isNavigationMode ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

Future<strava.Route> getRoute(String idStr) async {
  int routeId = int.parse(idStr);
  return await StravaClientManager().stravaClient.routes.getRoute(routeId);
}
