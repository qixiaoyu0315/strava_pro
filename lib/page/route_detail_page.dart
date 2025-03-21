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

class RouteDetailPage extends StatefulWidget {
  final String idStr;

  const RouteDetailPage({Key? key, required this.idStr}) : super(key: key);

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final MapController _mapController = MapController();
  LatLng? initialCenter; // 用于存储初始中心点

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
        directory = Directory('/storage/emulated/0/Download');
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
      final fileName = '${routeData.name?.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') ?? 'route'}_${DateTime.now().millisecondsSinceEpoch}.gpx';
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX文件已保存到: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('路线详情'),
      ),
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 地图部分
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: points.isNotEmpty
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
                                        points: points,
                                        strokeWidth: 4.0,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      if (points.isNotEmpty) ...[
                                        Marker(
                                          point: points.first,
                                          child: Icon(
                                            Icons.location_on,
                                            color: Colors.green,
                                            size: 40.0,
                                          ),
                                        ),
                                        Marker(
                                          point: points.last,
                                          child: Icon(
                                            Icons.flag,
                                            color: Colors.red,
                                            size: 40.0,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              )
                            : Center(child: Text('没有可用的路线数据')),
                      ),
                      // 添加返回起点按钮
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton(
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
                      ),
                      // 添加重置地图按钮
                      Positioned(
                        right: 16,
                        bottom: 80, // 调整位置以避免重叠
                        child: FloatingActionButton(
                          heroTag: 'reset_map',
                          mini: true,
                          onPressed: () {
                            if (initialCenter != null) {
                              _mapController.move(initialCenter!, 8.0); // 重置到初始位置
                            }
                          },
                          child: Icon(Icons.refresh),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // 路线信息部分
                Expanded(
                  flex: 2,
                  child: Card(
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<strava.Route> getRoute(String idStr) async {
  int routeId = int.parse(idStr);
  return await StravaClientManager().stravaClient.routes.getRoute(routeId);
}
