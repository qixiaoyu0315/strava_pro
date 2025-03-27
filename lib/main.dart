import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'page/route_page.dart';
import 'page/setting_page.dart';
import 'page/calendar_name.dart';
import 'service/strava_client_manager.dart';
import 'model/api_key_model.dart';

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
      home: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
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
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}
