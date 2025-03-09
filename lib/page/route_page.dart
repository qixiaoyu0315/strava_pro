import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'route_detail_page.dart'; // 导入新页面

class RoutePage extends StatefulWidget {
  const RoutePage({Key? key}) : super(key: key);
  @override
  _RoutePageState createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  String id = '';
  String key = '';

  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  late final StravaClient stravaClient;
  TokenResponse? token;
  DetailedAthlete? athlete;
  List<Map<String, dynamic>> routeList = [];

  @override
  void initState() {
    super.initState();
    _loadApiKey().then((_) {
      stravaClient = StravaClient(
        secret: key,
        clientId: id,
      );
      _authenticate();
    });
  }

  // void getAthletes() {
  //   try {
  //     stravaClient.athletes.getAuthenticatedAthlete().then((athlete) {
  //       setState(() {
  //         this.athlete = athlete;
  //       });
  //     });
  //   } catch (e) {
  //     _showToast('获取运动员信息失败: $e');
  //   }
  // }

  void getRoutes() async {
    try {
      final routes = await stravaClient.routes.listAthleteRoutes(115603263, 1, 10);
      routeList.clear();
      for (var route in routes) {
        routeList.add({
          'idStr': route.idStr ?? '未知',
          'name': route.name ?? '未知',
          'mapUrl': route.mapUrls?.url ?? '无地图链接',
          'distance': (route.distance ?? 0) / 1000, // 转换为公里
          'elevationGain': route.elevationGain ?? 0, // 高度
          'estimatedMovingTime': (route.estimatedMovingTime ?? 0) / 3600, // 转换为小时
        });
      }
      setState(() {});
    } catch (e) {
      _showToast('获取路线失败: $e');
    }
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _apiKeyModel.getApiKey();
    if (apiKey != null) {
      id = apiKey['api_id']!;
      key = apiKey['api_key']!;
    }
  }

  void _authenticate() {
    ExampleAuthentication(stravaClient).testAuthentication(
      [
        AuthenticationScope.profile_read_all,
        AuthenticationScope.read_all,
        AuthenticationScope.activity_read_all
      ], 
      "stravaflutter://redirect",
    ).then((token) {
      setState(() {
        this.token = token;
      });
      print('Access Token: ${token.accessToken}');
      _showToast('认证成功: ${token.accessToken}');
      getRoutes();
    }).catchError((error) {
      showErrorMessage(error, null);
      _showToast('认证失败: 请检查您的 API ID 和密钥。');
    });
  }

  FutureOr<Null> showErrorMessage(dynamic error, dynamic stackTrace) {
    if (error is Fault) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Did Receive Fault"),
              content: Text(
                  "Message: ${error.message}\n-----------------\nErrors:\n${(error.errors ?? []).map((e) => "Code: ${e.code}\nResource: ${e.resource}\nField: ${e.field}\n").toList().join("\n----------\n")}"),
            );
          });
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black54,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: routeList.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0), // 每个卡片之间的垂直间距
                    elevation: 4, // 卡片阴影
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // 圆角边框
                    ),
                    child: ListTile(
                      title: Text(
                        '名称: ${routeList[index]['name']}',
                        style: TextStyle(fontWeight: FontWeight.bold), // 加粗名称
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 距离和高度放在同一行
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 在水平方向上均匀分配空间
                            children: [
                              // 距离
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.directions_bike), // 使用自行车图标
                                    SizedBox(width: 4), // 图标与文本之间的间距
                                    Text('${routeList[index]['distance']?.toStringAsFixed(2)} km'),
                                  ],
                                ),
                              ),
                              // 高度
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start, // 右对齐
                                  children: [
                                    Icon(Icons.landscape_outlined), // 使用地形图标
                                    SizedBox(width: 4),
                                    Text('${routeList[index]['elevationGain']?.toInt()} m'), // 只保留整数部分
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8), // 图标与下一个信息之间的间距
                          // 预计时间放在下一行
                          Row(
                            children: [
                              Icon(Icons.access_time), // 使用时间图标
                              SizedBox(width: 4),
                              Text('${routeList[index]['estimatedMovingTime']?.toStringAsFixed(2)} h'), // 显示预计时间
                            ],
                          ),
                        ],
                      ),
                      trailing: routeList[index]['mapUrl'] != '无地图链接'
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10), // 设置圆角半径
                              child: Image.network(
                                routeList[index]['mapUrl']!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text('无地图链接'),
                      onTap: () {
                        // 点击时导航到新页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteDetailPage(idStr: routeList[index]['idStr']!), // 传递 idStr
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
