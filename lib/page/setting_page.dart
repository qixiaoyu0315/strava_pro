import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:strava_client/strava_client.dart';
import '../model/api_key_model.dart';
import '../service/strava_service.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _textEditingController = TextEditingController();
  late final StravaClient stravaClient;

  TokenResponse? token;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final ApiKeyModel _apiKeyModel = ApiKeyModel();

  @override
  void initState() {
    super.initState();
    _loadApiKey().then((_) {
      stravaClient = StravaClient(
        secret: _keyController.text,
        clientId: _idController.text,
      );
    });
  }

  Future<void> _loadApiKey() async {
    final apiKey = await _apiKeyModel.getApiKey();
    if (apiKey != null) {
      _idController.text = apiKey['api_id']!;
      _keyController.text = apiKey['api_key']!;
    }
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

  void testAuthentication() {
    String id = _idController.text;
    String key = _keyController.text;
    _apiKeyModel.insertApiKey(id, key);
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
        _textEditingController.text = token.accessToken;
      });
    }).catchError(showErrorMessage);
  }

  void testDeauth() {
    _idController.clear();
    _keyController.clear();
    ExampleAuthentication(stravaClient).testDeauthorize().then((value) {
      setState(() {
        this.token = null;
        _textEditingController.clear();
      });
    }).catchError(showErrorMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: '请输入 API ID',
              ),
            ),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: '请输入 API Key',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            TextField(
              minLines: 1,
              maxLines: 3,
              controller: _textEditingController,
              decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  label: Text("Access Token"),
                  suffixIcon: TextButton(
                    child: Text("Copy"),
                    onPressed: () {
                      Clipboard.setData(
                              ClipboardData(text: _textEditingController.text))
                          .then((value) => ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text("Copied!"),
                              )));
                    },
                  )),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: testAuthentication,
                  child: const Text('认证'),
                ),
                ElevatedButton(
                  onPressed: testDeauth,
                  child: const Text('取消认证'),
                ),
              ],
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
