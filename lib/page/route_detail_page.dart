import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../service/strava_client_manager.dart';
import 'package:strava_client/strava_client.dart' as strava;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../widgets/elevation_chart.dart';
import 'package:geolocator/geolocator.dart';

class RouteDetailPage extends StatefulWidget {
  final String idStr;

  const RouteDetailPage({Key? key, required this.idStr}) : super(key: key);

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final MapController _mapController = MapController();
  LatLng? initialCenter; // 用于存储初始中心点
  String? gpxFilePath; // 添加变量存储 GPX 文件路径
  ElevationData? elevationData;
  final ValueNotifier<LatLng?> selectedPoint = ValueNotifier<LatLng?>(null);
  bool isNavigationMode = false; // 添加导航模式状态
  List<LatLng>? gpxPoints; // 存储GPX文件中的路线点
  LatLng? currentLocation; // 添加当前位置变量

  @override
  void initState() {
    super.initState();
    _checkExistingGPXFile(); // 添加检查文件的方法
  }

  @override
  void dispose() {
    selectedPoint.dispose();
    super.dispose();
  }

  Future<void> _checkExistingGPXFile() async {
    try {
      Directory directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/strava_pro');
      } else {
        directory = await getApplicationDocumentsDirectory();
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
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/strava_pro');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法访问存储目录')),
        );
        return;
      }

      // 确保目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 创建文件名
      final fileName = '${routeData.idStr}.gpx';
      final file = File('${directory.path}/$fileName');

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

  Future<void> _getCurrentLocation() async {
    try {
      print('开始获取位置...');
      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      print('当前位置权限状态: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('请求权限后的状态: $permission');
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要位置权限才能获取当前位置')),
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置权限被永久拒绝，请在设置中开启')),
        );
        return;
      }

      // 获取当前位置
      print('开始获取具体位置...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      print('获取到的位置: 纬度=${position.latitude}, 经度=${position.longitude}');
      
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
      print('已更新当前位置标记');

      // 移动地图到当前位置
      _mapController.move(currentLocation!, 15.0);
      print('已将地图移动到当前位置');
    } catch (e) {
      print('获取位置失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败: $e')),
      );
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

    return minDistance <= 20; // 如果最小距离小于20米，返回true
  }

  Widget _buildMap(List<LatLng> points, LatLng center) {
    final displayPoints = isNavigationMode && gpxPoints != null ? gpxPoints! : points;
    final bool isNearRoute = currentLocation != null ? 
        _isNearRoute(currentLocation!, displayPoints) : false;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: displayPoints.isNotEmpty
          ? FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 8.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: displayPoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // 起点标记
                    Marker(
                      point: displayPoints.first,
                      child: Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40.0,
                      ),
                    ),
                    // 终点标记
                    Marker(
                      point: displayPoints.last,
                      child: Icon(
                        Icons.flag,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                    // 当前位置标记
                    if (currentLocation != null)
                      Marker(
                        point: currentLocation!,
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
                ),
                ValueListenableBuilder<LatLng?>(
                  valueListenable: selectedPoint,
                  builder: (context, point, child) {
                    if (point == null) return const SizedBox();
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          child: Icon(
                            Icons.location_on,
                            color: Colors.orange,
                            size: 40.0,
                          ),
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
            List<PointLatLng> result =
                polylinePoints.decodePolyline(routeData.map!.summaryPolyline!);
            points = result
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
          }

          // 计算地图的中心点
          LatLng center = points.isNotEmpty
              ? LatLng(
                  points.map((p) => p.latitude).reduce((a, b) => a + b) /
                      points.length,
                  points.map((p) => p.longitude).reduce((a, b) => a + b) /
                      points.length,
                )
              : LatLng(39.9042, 116.4074); // 默认位置（北京）

          // 设置初始中心点
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
                      Container(
                        height: isNavigationMode ? MediaQuery.of(context).size.height * 0.6 : 300,
                        child: Stack(
                          children: [
                            _buildMap(points, center),
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isNavigationMode) ...[
                                    FloatingActionButton(
                                      heroTag: 'return_start',
                                      mini: true,
                                      onPressed: () {
                                        if (points.isNotEmpty) {
                                          _mapController.move(points.first, 15.0);
                                        }
                                      },
                                      child: Icon(Icons.my_location),
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.blue,
                                    ),
                                    SizedBox(height: 8),
                                    FloatingActionButton(
                                      heroTag: 'reset_map',
                                      mini: true,
                                      onPressed: () {
                                        if (initialCenter != null) {
                                          _mapController.move(initialCenter!, 8.0);
                                        }
                                      },
                                      child: Icon(Icons.refresh),
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.blue,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      if (elevationData != null)
                        ElevationChart(
                          data: elevationData!,
                          onPointSelected: (point) {
                            selectedPoint.value = point.position;
                          },
                        ),
                      if (!isNavigationMode) ...[
                        SizedBox(height: 16),
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
              onPressed: () {
                setState(() {
                  isNavigationMode = !isNavigationMode;
                  if (isNavigationMode) {
                    _getCurrentLocation(); // 在进入导航模式时获取位置
                  }
                });
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
