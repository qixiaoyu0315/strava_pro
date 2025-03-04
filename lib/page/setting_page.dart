import 'package:flutter/material.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  void _authenticate() {
    String id = _idController.text;
    String key = _keyController.text;
    print('ID: $id, Key: $key');
  }

  void _cancelAuthentication() {
    _idController.clear();
    _keyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting Page'),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _authenticate,
                  child: const Text('认证'),
                ),
                ElevatedButton(
                  onPressed: _cancelAuthentication,
                  child: const Text('取消认证'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
