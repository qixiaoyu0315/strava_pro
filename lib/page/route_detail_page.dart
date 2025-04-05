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
import '../utils/logger.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../service/activity_service.dart';
import '../utils/poly2svg.dart';
import '../utils/map_tile_cache_manager.dart';

class RouteDetailPage extends StatefulWidget {
  final String idStr;
  const RouteDetailPage({super.key, required this.idStr});

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  LatLng? initialCenter;
  String? gpxFilePath;
  ElevationData? elevationData;
  final ValueNotifier<LatLng?> selectedPoint = ValueNotifier<LatLng?>(null);
  final ValueNotifier<LatLng?> currentLocation = ValueNotifier<LatLng?>(null);
  final ValueNotifier<int?> currentSegmentIndex = ValueNotifier<int?>(null);
  final ValueNotifier<double?> currentMinDistance =
      ValueNotifier<double?>(null);
  bool isNavigationMode = false;
  List<LatLng>? gpxPoints;
  StreamSubscription<Position>? _positionStreamSubscription;
  final ValueNotifier<Position?> currentPosition =
      ValueNotifier<Position?>(null);
  late strava.Route _routeData; // 缓存路线数据，避免旋转重载
  bool _isDataLoaded = false;
  bool _isMapInitialized = false; // 添加地图初始化状态变量
  int? _selectedPointIndex; // 添加选中点索引变量
  
  // 添加选中的距离范围选项
  String _selectedRangeOption = '全程';
  
  // 添加距离选项列表
  final List<String> _rangeOptions = ['500米', '1000米', '2000米', '5000米', '10000米', '全程'];
  
  // 添加可视范围
  double? _visibleRangeStart;
  double? _visibleRangeEnd;

  // 添加手势相关变量
  int _touchCount = 0;
  Timer? _longPressTimer;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingGPXFile();
    WidgetsBinding.instance.addObserver(this);

    // 检查是否需要自动开启导航模式
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args != null &&
            args is Map<String, dynamic> &&
            args['startNavigation'] == true) {
          _startNavigationWhenReady();
        }
      }
    });

    // 初始化地图缓存管理器 
    // 这行已被移除
    MapTileCacheManager.instance.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isMapInitialized = true;
        });
      }
    }).catchError((error) {
      Logger.e('地图缓存初始化失败', error: error, tag: 'Route');
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _positionStreamSubscription?.cancel();
    selectedPoint.dispose();
    currentLocation.dispose();
    currentSegmentIndex.dispose();
    currentMinDistance.dispose();
    currentPosition.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 屏幕尺寸变化时（如旋转屏幕），更新地图而不重新加载数据
    if (_isDataLoaded && mounted) {
      // 只调整地图视图，不重新加载数据
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final bounds = _mapController.camera.visibleBounds;
          _mapController.move(
            bounds.center,
            _mapController.camera.zoom,
          );
        }
      });
    }
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
      Logger.d('GPX文件路径: ${file.path}', tag: 'Route');
      if (await file.exists()) {
        final data = await ElevationData.fromGPXFile(file.path);
        if (data != null) {
          setState(() {
            gpxFilePath = file.path;
            elevationData = data;
            gpxPoints =
                data.elevationPoints.map((point) => point.position).toList();
          });
        }
      }
    } catch (e) {
      Logger.e('检查GPX文件失败', error: e);
    }
  }

  Future<void> _exportGPX(strava.Route routeData) async {
    if (!mounted) return;

    try {
      // 首先检查文件是否已经存在
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/strava_pro/gpx');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      if (!mounted) return;

      final fileName = '${routeData.idStr}.gpx';
      final file = File('${directory.path}/$fileName');

      // 如果文件已存在，直接解析它
      if (await directory.exists() && await file.exists()) {
        final data = await ElevationData.fromGPXFile(file.path);
        if (data != null) {
          setState(() {
            gpxFilePath = file.path;
            elevationData = data;
            gpxPoints =
                data.elevationPoints.map((point) => point.position).toList();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('GPX文件已存在，直接解析完成')),
            );
          }
          return; // 文件已存在，直接返回
        }
      }

      // 检查 Android 版本并请求相应权限
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (!mounted) return;

        if (androidInfo.version.sdkInt >= 33) {
          // Android 13 及以上版本
          var status = await Permission.photos.status;
          if (!mounted) return;

          if (!status.isGranted) {
            status = await Permission.photos.request();
            if (!mounted) return;

            if (!status.isGranted) {
              if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('需要存储权限才能导出文件')),
              );
              }
              return;
            }
          }
        } else {
          // Android 13 以下版本
          var status = await Permission.storage.status;
          if (!mounted) return;

          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!mounted) return;

            if (!status.isGranted) {
              if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('需要存储权限才能导出文件')),
              );
              }
              return;
            }
          }
        }
      }

      // 获取下载目录
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      if (!mounted) return;

      // 获取访问令牌
      final tokenResponse = await StravaClientManager().authenticate();
      if (!mounted) return;

      final accessToken = tokenResponse.accessToken;

      // 直接从 Strava API 获取 GPX 数据
      final response = await http.get(
        Uri.parse(
            'https://www.strava.com/api/v3/routes/${routeData.id}/export_gpx'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('获取 GPX 数据失败: ${response.statusCode}');
      }

      // 写入二进制数据
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;

      // 解析GPX文件
      final data = await ElevationData.fromGPXFile(file.path);
      if (!mounted) return;

      if (data != null) {
        setState(() {
          gpxFilePath = file.path;
          elevationData = data;
          gpxPoints =
              data.elevationPoints.map((point) => point.position).toList();
        });
      }

      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPX文件已保存并解析完成')),
      );
      }
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
      }
    }
  }

  void _startLocationUpdates() {
    Logger.i('开始位置更新服务', tag: 'Location');
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

        Logger.d(
            '获取到新位置 - 位置: ${position.latitude}, ${position.longitude}, '
            '精度: ${position.accuracy}米, 海拔: ${position.altitude}米, '
            '速度: ${position.speed}m/s',
            tag: 'Location');

        currentPosition.value = position;
        final newLocation = LatLng(position.latitude, position.longitude);
        currentLocation.value = newLocation;
        _updateCurrentSegment();

        // 检查新位置是否在地图视野内
        if (isNavigationMode) {
          final bounds = _mapController.camera.visibleBounds;
          // 计算设备位置到视野边缘的距离比例
          final distanceToEdge = _calculateDistanceToEdge(newLocation, bounds);

          // 如果距离边缘太近或已经超出视野，移动地图
          if (distanceToEdge < 0.2 ||
              !_isLocationInBounds(newLocation, bounds)) {
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
      },
      onError: (error) {
        Logger.e('位置流错误', error: error);
        if (error is LocationServiceDisabledException && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请开启定位服务')),
          );
        }
      },
      cancelOnError: false,
    );
  }

  void _stopLocationUpdates() {
    Logger.i('停止位置更新服务', tag: 'Location');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    try {
      // 检查定位服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请开启定位服务')),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;

        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要定位权限才能获取位置')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('定位权限被永久拒绝，请在设置中开启')),
          );
        }
        await Geolocator.openAppSettings();
        return;
      }

      // 权限获取成功后，开始位置更新
      if (mounted) {
        _startLocationUpdates();
      }
    } catch (e) {
      Logger.e('检查位置权限失败', error: e);
    }
  }

  void _updateCurrentSegment() {
    if (currentLocation.value != null && gpxPoints != null) {
      final result = _findNearestSegment(currentLocation.value!, gpxPoints!);
      if (result != null) {
        currentSegmentIndex.value = result.$1;
        currentMinDistance.value = result.$2;
        
        // 当选择了某个距离范围选项（非全程）时，检查是否需要更新可视范围
        if (_selectedRangeOption != '全程' && elevationData != null) {
          // 获取当前位置的距离
          int index = result.$1;
          if (index < elevationData!.elevationPoints.length) {
            double currentDistance = elevationData!.elevationPoints[index].distance;
            
            // 检查当前位置是否在现有可视范围内
            bool isOutOfRange = false;
            
            // 只有当已设置了可视范围时才检查
            if (_visibleRangeStart != null && _visibleRangeEnd != null) {
              // 只需要检查当前位置是否小于起点或大于终点
              // 我们关心的是当前位置是否在范围内，或者已经超出了右侧终点
              isOutOfRange = currentDistance < _visibleRangeStart! || 
                             currentDistance > _visibleRangeEnd!;
            } else {
              // 如果尚未设置可视范围，则需要设置初始范围
              isOutOfRange = true;
            }
            
            // 只有当位置超出当前范围时，才更新范围
            if (isOutOfRange) {
              setState(() {
                switch (_selectedRangeOption) {
                  case '500米':
                    _visibleRangeStart = currentDistance;
                    _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 0.5);
                    break;
                  case '1000米':
                    _visibleRangeStart = currentDistance;
                    _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 1.0);
                    break;
                  case '2000米':
                    _visibleRangeStart = currentDistance;
                    _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 2.0);
                    break;
                  case '5000米':
                    _visibleRangeStart = currentDistance;
                    _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 5.0);
                    break;
                  case '10000米':
                    _visibleRangeStart = currentDistance;
                    _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 10.0);
                    break;
                }
              });
            }
          }
        }
      }
    }
  }

  // 计算点到线段的距离
  double _calculateDistanceToLine(
      LatLng point, LatLng lineStart, LatLng lineEnd) {
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

    if (t < 0) return d1; // 投影点在线段起点之前
    if (t > 1) return d2; // 投影点在线段终点之后

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
          deviceLocation, routePoints[i], routePoints[i + 1]);
      minDistance = distance < minDistance ? distance : minDistance;
    }
    Logger.d('最小距离: $minDistance', tag: 'Route');

    return minDistance <= 50; // 如果最小距离小于50米，返回true
  }

  // 计算最近的路线点和对应的距离
  (int, double)? _findNearestSegment(
      LatLng deviceLocation, List<LatLng> routePoints) {
    if (routePoints.length < 2) return null;

    double minDistance = double.infinity;
    int nearestSegmentIndex = -1;

    // 遍历所有相邻的路线点对
    for (int i = 0; i < routePoints.length - 1; i++) {
      double distance = _calculateDistanceToLine(
          deviceLocation, routePoints[i], routePoints[i + 1]);
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
          ? Listener(
              onPointerDown: (_) => _handleTouchCountChange(_touchCount + 1),
              onPointerUp: (_) => _handleTouchCountChange(_touchCount - 1),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 8.0,
                  onMapReady: () {
                    // 计算路线的边界
                    double minLat =
                        points.map((p) => p.latitude).reduce(math.min);
                    double maxLat =
                        points.map((p) => p.latitude).reduce(math.max);
                    double minLng =
                        points.map((p) => p.longitude).reduce(math.min);
                    double maxLng =
                        points.map((p) => p.longitude).reduce(math.max);

                    // 创建边界矩形并添加边距
                    final bounds = LatLngBounds.fromPoints([
                      LatLng(minLat - 0.02, minLng - 0.02),
                      LatLng(maxLat + 0.02, maxLng + 0.02)
                    ]);

                    // 调整地图以适应边界
                    Future.delayed(Duration(milliseconds: 100), () {
                      if (!mounted) return;

                      _mapController.move(
                        bounds.center,
                        _mapController.camera.zoom,
                      );

                      // 计算合适的缩放级别
                      if (!mounted) return;

                      final latZoom = _calculateZoomLevel(bounds.south,
                          bounds.north, MediaQuery.of(context).size.height);
                      final lngZoom = _calculateZoomLevel(bounds.west,
                          bounds.east, MediaQuery.of(context).size.width);

                      _mapController.move(
                        bounds.center,
                        math.min(latZoom, lngZoom) - 0.5, // 减少0.5级缩放以留出边距
                      );
                    });
                  },
                ),
                children: [
                  // 使用缓存管理器创建离线优先的图层
                  MapTileCacheManager.instance.createOfflineTileLayer(),
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
                        child: Icon(Icons.location_on,
                            color: Colors.green, size: 40.0),
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
                      final isNearRoute = gpxPoints != null
                          ? _isNearRoute(location, gpxPoints!)
                          : false;
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
                                        color: isNearRoute
                                            ? Colors.green
                                            : Colors.red,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isNearRoute
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withValues(alpha: .3),
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
                            child: Icon(Icons.location_on,
                                color: Colors.orange, size: 40.0),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
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
        point2.position.longitude);

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
        (bounds.north - location.latitude) / (bounds.north - bounds.south));

    final lngRatio = math.min(
        (location.longitude - bounds.west) / (bounds.east - bounds.west),
        (bounds.east - location.longitude) / (bounds.east - bounds.west));

    return math.min(latRatio, lngRatio);
  }

  // 根据设备朝向计算地图偏移中心点
  LatLng _calculateMapOffset(LatLng location, double bearing) {
    // 计算前方偏移距离（米）
    const offsetDistance = 100.0; // 100米

    // 将偏移距离和方向转换为坐标偏移
    final radiusBearing = (bearing * math.pi) / 180;
    final latOffset =
        math.cos(radiusBearing) * offsetDistance / 111320.0; // 约111.32km = 1度纬度
    final lngOffset = math.sin(radiusBearing) *
        offsetDistance /
        (111320.0 * math.cos(location.latitude * math.pi / 180));

    return LatLng(
        location.latitude + latOffset, location.longitude + lngOffset);
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
      body: _isDataLoaded
          ? _buildMainContent()
          : FutureBuilder<strava.Route>(
        future: getRoute(widget.idStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('获取路线失败: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('没有找到路线'));
          }

                _routeData = snapshot.data!;
                _isDataLoaded = true;
                return _buildMainContent();
              },
            ),
    );
  }

  Widget _buildMainContent() {
          List<LatLng> points = [];
    if (_routeData.map?.summaryPolyline != null) {
            PolylinePoints polylinePoints = PolylinePoints();
            List<PointLatLng> result =
          polylinePoints.decodePolyline(_routeData.map!.summaryPolyline!);
            points = result
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          }

          LatLng center = points.isNotEmpty
              ? LatLng(
                  points.map((p) => p.latitude).reduce((a, b) => a + b) /
                      points.length,
                  points.map((p) => p.longitude).reduce((a, b) => a + b) /
                      points.length,
                )
        : LatLng(39.9042, 116.4074);

    initialCenter ??= center;

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
                      final paddingBottom =
                          MediaQuery.of(context).padding.bottom;

                      if (isLandscape) {
                        // 横屏布局
                        final availableHeight =
                            screenHeight - paddingTop - paddingBottom - 32;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                            // 左侧地图
                Expanded(
                              flex: 3, // 增加地图区域比例
                              child: Container(
                                height: availableHeight,
                                margin: EdgeInsets.only(right: 8),
                                child: _buildMap(points, center),
                              ),
                            ),
                            // 右侧信息
                            Expanded(
                              flex: 3, // 减少信息区域比例
                              child: SizedBox(
                                height: availableHeight,
                                child: Column(
                    children: [
                                    // 海拔和坡度信息（2/5）
                      Container(
                                      height: availableHeight * 0.3,
                                      margin: EdgeInsets.only(bottom: 8),
                                      padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                            color: Theme.of(context)
                                                .shadowColor
                                                .withValues(alpha: 0.1),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                            ),
                          ],
                        ),
                                      child: ValueListenableBuilder<Position?>(
                                        valueListenable: currentPosition,
                                        builder: (context, position, child) {
                                          final gradient =
                                              _calculateCurrentGradient();
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                children: [
                                              // 海拔信息
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.height,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          size: 20),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        '海拔',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                      ),
                                    ],
                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    '${position?.altitude.toStringAsFixed(1) ?? '--'} 米',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                height: 36,
                                                width: 1,
                                                color: Theme.of(context)
                                                    .dividerColor
                                                    .withValues(alpha: 0.3),
                                              ),
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.trending_up,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          size: 20),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        '坡度',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    gradient != null
                                                        ? '${gradient.toStringAsFixed(1)}%'
                                                        : '--',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: gradient != null
                                                          ? _getGradientColor(
                                                              gradient)
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface,
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
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .shadowColor
                                                  .withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                child: elevationData != null
                                                    ? ValueListenableBuilder<int?>(
                                                        valueListenable:
                                                            currentSegmentIndex,
                                                        builder: (context,
                                                            segmentIndex, child) {
                                                          return ValueListenableBuilder<
                                                              double?>(
                                                            valueListenable:
                                                                currentMinDistance,
                                                            builder: (context,
                                                                minDistance, child) {
                                                              return ElevationChart(
                                                                data: elevationData!,
                                                                onPointSelected:
                                                                    (point) {
                                                                  selectedPoint
                                                                          .value =
                                                                      point.position;
                                                                },
                                                                currentSegmentIndex:
                                                                    minDistance !=
                                                                                null &&
                                                                            minDistance <=
                                                                                50
                                                                        ? segmentIndex
                                                                        : null,
                                                                visibleRangeStart: _visibleRangeStart,
                                                                visibleRangeEnd: _visibleRangeEnd,
                                                              );
                                                            },
                                                          );
                                                        },
                                                      )
                                                    : SizedBox(),
                                              ),
                                            ),
                                            // 添加距离选择器
                                            _buildRangeSelector(),
                                          ],
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
                        final availableHeight =
                            screenHeight - paddingTop - paddingBottom - 64;
                        final unit = availableHeight / 10;
                        return Column(
                          children: [
                            // 地图组件 (6份)
                            SizedBox(
                              height: unit * 5, // 增加地图高度比例
                              child: _buildMap(points, center),
                            ),
                            SizedBox(height: 16),
                            // 海拔和坡度信息卡片 (1.5份)
                            Container(
                              height: unit * 1, // 减少信息卡片高度
                              margin: EdgeInsets.symmetric(horizontal: 8),
                              padding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .shadowColor
                                        .withValues(alpha: 0.1),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // 海拔信息
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.height,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  size: 20),
                                              SizedBox(width: 6),
                                              Text(
                                                '海拔',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
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
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        height: 36,
                                        width: 1,
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withValues(alpha: 0.3),
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.trending_up,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  size: 20),
                                              SizedBox(width: 6),
                                              Text(
                                                '坡度',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            gradient != null
                                                ? '${gradient.toStringAsFixed(1)}%'
                                                : '--',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: gradient != null
                                                  ? _getGradientColor(gradient)
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
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
                            // 海拔图 (2.5份)
                            Container(
                              height: unit * 3.5, // 减少海拔图高度
                              margin: EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .shadowColor
                                        .withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: elevationData != null
                                          ? ValueListenableBuilder<int?>(
                                              valueListenable: currentSegmentIndex,
                                              builder:
                                                  (context, segmentIndex, child) {
                                                return ValueListenableBuilder<
                                                    double?>(
                                                  valueListenable: currentMinDistance,
                                                  builder:
                                                      (context, minDistance, child) {
                                                    return ElevationChart(
                                                      data: elevationData!,
                                                      onPointSelected: (point) {
                                                        selectedPoint.value =
                                                            point.position;
                                                      },
                                                      currentSegmentIndex:
                                                          minDistance != null &&
                                                                  minDistance <= 50
                                                              ? segmentIndex
                                                              : null,
                                                      visibleRangeStart: _visibleRangeStart,
                                                      visibleRangeEnd: _visibleRangeEnd,
                                                    );
                                                  },
                                                );
                                              },
                                            )
                                          : SizedBox(),
                                    ),
                                  ),
                                  // 添加距离选择器
                                  _buildRangeSelector(),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ] else ...[
                  // 地图组件
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45, // 增加地图高度
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
                            color: Theme.of(context)
                                .shadowColor
                                .withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: ElevationChart(
                                data: elevationData!,
                                onPointSelected: (point) {
                                  selectedPoint.value = point.position;
                                },
                                currentSegmentIndex: null,
                                visibleRangeStart: _visibleRangeStart,
                                visibleRangeEnd: _visibleRangeEnd,
                              ),
                            ),
                          ),
                          // 添加距离选择器
                          _buildRangeSelector(),
                        ],
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
                                  '路线名称: ${_routeData.name}',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (gpxFilePath == null)
                              IconButton(
                                  onPressed: () => _exportGPX(_routeData),
                                icon: Icon(Icons.download),
                                tooltip: '导出GPX文件',
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          // 使用Row来让信息水平对齐
                          Row(
                            children: [
                              // 左侧列
                              Expanded(
                                child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_bike),
                                  SizedBox(width: 8),
                                  Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                              '${((_routeData.distance ?? 0) / 1000).toStringAsFixed(2)} km',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                            Text('距离',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                                  ],
                                ),
                              ),
                              // 右侧列
                              Expanded(
                                child: Column(
                                  children: [
                              Row(
                                children: [
                                        Icon(Icons.access_time),
                                  SizedBox(width: 8),
                                  Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                              '${((_routeData.estimatedMovingTime ?? 0) / 3600).toStringAsFixed(2)} h',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                            Text('预计时间',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                    ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                          // 累计爬升单独一行
                              Row(
                                children: [
                              Icon(Icons.landscape_outlined),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                    '${_routeData.elevationGain?.toStringAsFixed(2) ?? 0} m',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                  Text('累计爬升',
                                      style: TextStyle(color: Colors.grey)),
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
  }

  // 准备好GPX文件后自动开启导航模式
  void _startNavigationWhenReady() {
    if (gpxFilePath != null) {
      // GPX文件已加载，直接开启导航
      setState(() {
        isNavigationMode = true;
      });
      _checkLocationPermission();
    } else {
      // GPX文件未加载，先等待加载完成
      // 设置一个延迟检查，等待GPX文件下载和解析
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          if (gpxFilePath != null) {
            setState(() {
              isNavigationMode = true;
            });
            _checkLocationPermission();
          } else if (_isDataLoaded) {
            // 数据已加载但没有GPX文件，尝试下载
            _exportGPX(_routeData).then((_) {
              if (mounted && gpxFilePath != null) {
                setState(() {
                  isNavigationMode = true;
                });
                _checkLocationPermission();
              }
            });
          } else {
            // 再次尝试
            _startNavigationWhenReady();
          }
        }
      });
    }
  }

  // 添加处理距离范围更改的方法
  void _updateVisibleRange(String option) {
    if (!mounted || elevationData == null) return;
    
    setState(() {
      _selectedRangeOption = option;
      
      // 如果选择全程，直接设置为null（显示整个范围）并返回
      if (option == '全程') {
        _visibleRangeStart = null;
        _visibleRangeEnd = null;
        return;
      }
      
      // 获取当前位置索引
      int? currentIndex = currentSegmentIndex.value;
      if (currentIndex == null || currentIndex >= elevationData!.elevationPoints.length) {
        // 如果没有当前位置，使用总距离的起点
        double startPoint = 0;
        
        // 根据选项设置可视范围
        switch (option) {
          case '500米':
            _visibleRangeStart = startPoint;
            _visibleRangeEnd = math.min(elevationData!.totalDistance, startPoint + 0.5);
            break;
          case '1000米':
            _visibleRangeStart = startPoint;
            _visibleRangeEnd = math.min(elevationData!.totalDistance, startPoint + 1.0);
            break;
          case '2000米':
            _visibleRangeStart = startPoint;
            _visibleRangeEnd = math.min(elevationData!.totalDistance, startPoint + 2.0);
            break;
          case '5000米':
            _visibleRangeStart = startPoint;
            _visibleRangeEnd = math.min(elevationData!.totalDistance, startPoint + 5.0);
            break;
          case '10000米':
            _visibleRangeStart = startPoint;
            _visibleRangeEnd = math.min(elevationData!.totalDistance, startPoint + 10.0);
            break;
        }
        return;
      }
      
      // 获取当前位置的距离
      double currentDistance = elevationData!.elevationPoints[currentIndex].distance;
      
      // 根据选项设置可视范围，从当前位置向右延伸
      switch (option) {
        case '500米':
          _visibleRangeStart = currentDistance;
          _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 0.5);
          break;
        case '1000米':
          _visibleRangeStart = currentDistance;
          _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 1.0);
          break;
        case '2000米':
          _visibleRangeStart = currentDistance;
          _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 2.0);
          break;
        case '5000米':
          _visibleRangeStart = currentDistance;
          _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 5.0);
          break;
        case '10000米':
          _visibleRangeStart = currentDistance;
          _visibleRangeEnd = math.min(elevationData!.totalDistance, currentDistance + 10.0);
          break;
      }
    });
  }

  // 添加距离选择器UI组件
  Widget _buildRangeSelector() {
    return Container(
      height: 40,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _rangeOptions.length,
        itemBuilder: (context, index) {
          final option = _rangeOptions[index];
          final isSelected = _selectedRangeOption == option;
          
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _updateVisibleRange(option);
                }
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              labelStyle: TextStyle(
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }

  // 添加手势处理方法
  void _handleTouchCountChange(int count) {
    _touchCount = count;
    
    // 取消之前的定时器
    _longPressTimer?.cancel();
    
    // 如果是双指触摸，开始计时
    if (_touchCount == 2) {
      _longPressTimer = Timer(const Duration(seconds: 3), () {
        if (_touchCount == 2 && mounted && !_isExiting) {
          setState(() {
            _isExiting = true;
            isNavigationMode = false;
          });
          _stopLocationUpdates();
          
          // 显示退出提示
          Fluttertoast.showToast(
            msg: '已退出导航模式',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
          );
        }
      });
    }
  }
}

Future<strava.Route> getRoute(String idStr) async {
  int routeId = int.parse(idStr);
  return await StravaClientManager().stravaClient.routes.getRoute(routeId);
}
