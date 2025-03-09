import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
  List<Map<String, String>> routeList = [];

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
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: routeList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('ID: ${routeList[index]['idStr']}'),
                    subtitle: Text('Name: ${routeList[index]['name']}'),
                    trailing: routeList[index]['mapUrl'] != '无地图链接'
                        ? Image.network(
                            routeList[index]['mapUrl']!,
                            width: 50, // 设置图片宽度
                            height: 50, // 设置图片高度
                            fit: BoxFit.cover, // 设置图片适应方式
                          )
                        : Text('无地图链接'), // 如果没有地图链接则显示文本
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
