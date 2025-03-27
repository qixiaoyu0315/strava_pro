import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'page/route_page.dart';
import 'page/setting_page.dart';
import 'page/calendar_name.dart';
import 'service/strava_client_manager.dart';
import 'model/api_key_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strava_client/strava_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiKeyModel = ApiKeyModel();
  final apiKey = await apiKeyModel.getApiKey();

  if (apiKey != null) {
    await StravaClientManager()
        .initialize(apiKey['api_id']!, apiKey['api_key']!);

    // 尝试加载现有的token
    try {
      await StravaClientManager().loadExistingAuthentication();
    } catch (e) {
      print('无法加载现有认证: $e');
    }
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
  // 添加认证状态
  bool _isAuthenticated = false;
  DetailedAthlete? _athlete;

  @override
  void initState() {
    super.initState();
    _initDefaultPages();
    _loadSettings();
    _checkAuthenticationStatus();
  }

  void _initDefaultPages() {
    _pages = [
      const CalendarPage(isHorizontalLayout: true),
      RoutePage(
        isAuthenticated: _isAuthenticated,
        onAuthenticationChanged: _handleAuthenticationChanged,
      ),
      SettingPage(
        onLayoutChanged: _onLayoutChanged,
        isAuthenticated: _isAuthenticated,
        athlete: _athlete,
        onAuthenticationChanged: _handleAuthenticationChanged,
      ),
    ];
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLayout = prefs.getBool('isHorizontalLayout');

      if (mounted) {
        setState(() {
          _isHorizontalLayout = savedLayout ?? true;
          _isLoading = false;
        });
        _initPages();
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

  // 检查认证状态
  Future<void> _checkAuthenticationStatus() async {
    try {
      final manager = StravaClientManager();
      final isAuthenticated = await manager.isAuthenticated();

      // 如果已认证，获取运动员信息
      DetailedAthlete? athlete;
      if (isAuthenticated) {
        try {
          athlete =
              await manager.stravaClient.athletes.getAuthenticatedAthlete();
        } catch (e) {
          print('获取运动员信息失败: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _athlete = athlete;
          _initPages();
        });
      }
    } catch (e) {
      print('检查认证状态失败: $e');
    }
  }

  // 处理认证状态变化
  void _handleAuthenticationChanged(
      bool isAuthenticated, DetailedAthlete? athlete) {
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
        _athlete = athlete;
        _initPages();
      });
    }
  }

  void _initPages() {
    _pages = [
      CalendarPage(isHorizontalLayout: _isHorizontalLayout),
      RoutePage(
        isAuthenticated: _isAuthenticated,
        onAuthenticationChanged: _handleAuthenticationChanged,
      ),
      SettingPage(
        onLayoutChanged: _onLayoutChanged,
        isAuthenticated: _isAuthenticated,
        athlete: _athlete,
        onAuthenticationChanged: _handleAuthenticationChanged,
      ),
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isHorizontalLayout = prefs.getBool('isHorizontalLayout') ?? true;
    });
  }

  void _updateCalendarLayout(bool value) {
    setState(() {
      _isHorizontalLayout = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      CalendarPage(isHorizontalLayout: _isHorizontalLayout),
      const RoutePage(),
      SettingPage(onLayoutChanged: _updateCalendarLayout),
    ];

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
