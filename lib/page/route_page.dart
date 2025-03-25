import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'route_detail_page.dart'; // 导入新页面
import '../service/strava_client_manager.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({Key? key}) : super(key: key);
  
  @override
  _RoutePageState createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  String id = '';
  String key = '';

  final ApiKeyModel _apiKeyModel = ApiKeyModel();
  TokenResponse? token;
  DetailedAthlete? athlete;
  List<Map<String, dynamic>> routeList = [];

  @override
  void initState() {
    super.initState();
    _loadApiKey().then((_) {
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

  Future<void> getRoutes() async {
    try {
      final routes = await StravaClientManager().stravaClient.routes.listAthleteRoutes(115603263, 1, 10);
      routeList.clear();
      for (var route in routes) {
        routeList.add({
          'idStr': route.idStr ?? '未知',
          'name': route.name ?? '未知',
          'mapUrl': route.mapUrls?.url ?? '无地图链接',
          'mapDarkUrl': route.mapUrls?.darkUrl ?? route.mapUrls?.url ?? '无地图链接',
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
    StravaClientManager().authenticate().then((token) {
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
      body: RefreshIndicator(
        onRefresh: () async {
          await getRoutes();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('STRAVA-路线'),
              floating: true, // 向上滑动时隐藏，向下滑动时显示
              snap: true, // 确保完全显示或完全隐藏
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 8, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteDetailPage(idStr: routeList[index]['idStr']!),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.38 - 16,
                                child: Image.network(
                                  routeList[index]['mapUrl'] != '无地图链接'
                                      ? Theme.of(context).brightness == Brightness.dark
                                          ? routeList[index]['mapDarkUrl']!
                                          : routeList[index]['mapUrl']!
                                      : 'https://via.placeholder.com/100',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        routeList[index]['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                                                    maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          // 左列
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.directions_bike),
                                                    SizedBox(width: 4),
                                                    Text('${routeList[index]['distance']?.toStringAsFixed(1)} km'),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.landscape_outlined),
                                                    SizedBox(width: 4),
                                                    Text('${routeList[index]['elevationGain']?.toInt()} m'),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 右列
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.access_time),
                                                    SizedBox(width: 4),
                                                    Text('${routeList[index]['estimatedMovingTime']?.toStringAsFixed(2)} h'),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                SizedBox(height: 24),
                                              ],
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
                      ),
                    );
                  },
                  childCount: routeList.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
