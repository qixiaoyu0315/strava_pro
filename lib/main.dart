import 'package:flutter/material.dart';
import 'page/route_page.dart'; // 导入 route_page
import 'page/setting_page.dart'; // 导入 setting_page

void main() {
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
    const Center(child: Text('Hello World!')),
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
