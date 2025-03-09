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
          ],
        ),
      ),
    );
  }
}
