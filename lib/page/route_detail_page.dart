import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../service/strava_client_manager.dart';
import 'package:strava_client/strava_client.dart' as strava;

class RouteDetailPage extends StatelessWidget {
  final String idStr;

  const RouteDetailPage({Key? key, required this.idStr}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('路线详情'),
      ),
      body: FutureBuilder<strava.Route>(
        future: getRoute(idStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('获取路线失败: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('没有找到路线'));
          }

          final routeData = snapshot.data!;

          // 使用 flutter_polyline_points 解析路线的多边形数据
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 地图部分 - 使用圆角装饰
                Expanded(
                  flex: 3, // 占据更多空间
                  child: Container(
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
                    clipBehavior: Clip.antiAlias, // 确保内容也是圆角的
                    child: points.isNotEmpty
                        ? FlutterMap(
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
                ),

                SizedBox(height: 16), // 地图和信息之间的间距

                // 路线信息部分
                Expanded(
                  flex: 2, // 占据较少空间
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
                          Text(
                            '路线名称: ${routeData.name}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 16),
                          Column(
                            children: [
                              // 距离信息
                              Row(
                                children: [
                                  Icon(Icons.directions_bike),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(routeData.distance ?? 0) / 1000} km',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      Text('距离', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 12), // 添加垂直间距
                              // 累计爬升信息
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
                              SizedBox(height: 12), // 添加垂直间距
                              // 预计时间信息
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
