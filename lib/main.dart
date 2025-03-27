import 'package:flutter/material.dart';
import 'page/route_page.dart';
import 'page/setting_page.dart';
import 'page/calendar_name.dart';
import 'service/strava_client_manager.dart';
import 'model/api_key_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiKeyModel = ApiKeyModel();
  final apiKey = await apiKeyModel.getApiKey();

  if (apiKey != null) {
    await StravaClientManager()
        .initialize(apiKey['api_id']!, apiKey['api_key']!);
  }
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  bool _isHorizontalLayout = true;
  List<Widget> _pages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDefaultPages();
    _loadSettings();
  }

  void _initDefaultPages() {
    _pages = [
      const CalendarPage(isHorizontalLayout: true),
      const RoutePage(),
      SettingPage(onLayoutChanged: _onLayoutChanged),
    ];
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLayout = prefs.getBool('isHorizontalLayout');

      if (mounted) {
        setState(() {
          _isHorizontalLayout = savedLayout ?? true;
          _initPages();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('加载设置出错: $e');
    }
  }

  void _initPages() {
    _pages = [
      CalendarPage(isHorizontalLayout: _isHorizontalLayout),
      const RoutePage(),
      SettingPage(onLayoutChanged: _onLayoutChanged),
    ];
  }

  void _onLayoutChanged(bool isHorizontal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isHorizontalLayout', isHorizontal);

    if (mounted) {
      setState(() {
        _isHorizontalLayout = isHorizontal;
        _initPages();
      });
    }
  }

  void _onItemTapped(int index) {
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
      themeMode: ThemeMode.system,
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : Scaffold(
              body: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
              bottomNavigationBar: BottomNavigationBar(
                items: const <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month),
                    label: '日历',
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
