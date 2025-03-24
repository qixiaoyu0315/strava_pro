import 'package:flutter/material.dart';
import 'page/route_page.dart'; // 导入 route_page
import 'page/setting_page.dart'; // 导入 setting_page
import 'service/strava_client_manager.dart';
import 'model/api_key_model.dart'; // 导入 ApiKeyModel

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 获取 API 密钥
  final apiKeyModel = ApiKeyModel();
  final apiKey = await apiKeyModel.getApiKey();
  
  if (apiKey != null) {
    // 初始化 StravaClientManager
    await StravaClientManager().initialize(apiKey['api_id']!, apiKey['api_key']!);
  } else {
    // 处理没有找到 API 密钥的情况
    print('未找到 API 密钥');
  }

  runApp(const MainApp());
}

class MainApp extends StatefulWidget { // 将 StatelessWidget 改为 StatefulWidget
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0; // 当前选中的索引

  final List<Widget> _pages = [ // 页面列表
    const Center(child: Text('Hello Strava!')),
    const RoutePage(), // 跳转到 route_page
    const SettingPage(), // 跳转到 setting_page
  ];

  void _onItemTapped(int index) { // 处理底部导航栏点击事件
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ThemeData.light().colorScheme,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ThemeData.dark().colorScheme,
      ),
      themeMode: ThemeMode.system, // 跟随系统主题
      home: Scaffold(
        body: _pages[_selectedIndex], // 根据选中的索引显示对应页面
        bottomNavigationBar: BottomNavigationBar( // 添加底部导航栏
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.route),
              label: '路线',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
