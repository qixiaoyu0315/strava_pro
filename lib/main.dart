import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'page/route_page.dart';
import 'page/setting_page.dart';
import 'page/calendar_name.dart';
import 'service/strava_client_manager.dart';
import 'model/api_key_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strava_client/strava_client.dart';
import 'utils/logger.dart';
import 'utils/widget_manager.dart';

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
      Logger.e('无法加载现有认证', error: e);
    }
  }

  // 加载并应用全屏设置
  final prefs = await SharedPreferences.getInstance();
  final isFullscreenMode = prefs.getBool('isFullscreenMode') ?? false;

  if (isFullscreenMode) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  } else {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // 初始化小组件服务
  await WidgetManager.initialize();

  // 尝试更新小组件显示，默认显示固定路径的日历图片
  WidgetManager.updateCalendarWidget().then((success) {
    if (success) {
      Logger.d('应用启动时成功更新小组件', tag: 'Main');
    } else {
      Logger.w('应用启动时更新小组件失败', tag: 'Main');
    }
  });

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isHorizontalLayout = true;
  List<Widget> _pages = [];
  bool _isLoading = true;
  // 添加认证状态
  bool _isAuthenticated = false;
  DetailedAthlete? _athlete;

  // 添加当前主题模式的跟踪
  Brightness? _lastBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDefaultPages();
    _loadSettings();
    _checkAuthenticationStatus();
    // 初始化当前亮度模式
    _lastBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final currentBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    // 如果亮度模式发生变化，更新小组件
    if (_lastBrightness != currentBrightness) {
      _lastBrightness = currentBrightness;
      Logger.d(
          '系统主题模式变化: ${currentBrightness == Brightness.dark ? "暗色" : "亮色"}',
          tag: 'Main');

      // 更新小组件以应用新主题
      WidgetManager.updateCalendarWidget().then((success) {
        if (success) {
          Logger.d('主题变化后成功更新小组件', tag: 'Main');
        } else {
          Logger.w('主题变化后更新小组件失败', tag: 'Main');
        }
      });
    }

    // 通知框架重建，但这通常不需要，因为我们使用了ThemeMode.system
    if (mounted) setState(() {});
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
      Logger.e('加载设置出错', error: e);
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
          Logger.e('获取运动员信息失败', error: e);
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
      Logger.e('检查认证状态失败', error: e);
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;

                return Scaffold(
                  body: Row(
                    children: [
                      // 横屏时显示左侧导航栏，竖屏时隐藏
                      if (isLandscape)
                        NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _onItemTapped,
                          labelType: NavigationRailLabelType.selected,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.calendar_month),
                              label: Text('日历'),
                              padding: EdgeInsets.symmetric(vertical: 24),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.route),
                              label: Text('路线'),
                              padding: EdgeInsets.symmetric(vertical: 24),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.settings),
                              label: Text('设置'),
                              padding: EdgeInsets.symmetric(vertical: 24),
                            ),
                          ],
                          minWidth: 60,
                          useIndicator: true,
                          // 设置均等间距
                          groupAlignment: -0.5,
                        ),

                      // 内容区域
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: _pages,
                        ),
                      ),
                    ],
                  ),
                  // 竖屏时显示底部导航栏，样式与横屏一致
                  bottomNavigationBar: isLandscape
                      ? null
                      : BottomNavigationBar(
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
                          // 确保每个项目占三分之一
                          type: BottomNavigationBarType.fixed,
                          // 显示未选中的标签
                          showUnselectedLabels: true,
                          // 使用与NavigationRail一致的样式
                          selectedItemColor:
                              Theme.of(context).colorScheme.primary,
                          unselectedItemColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                );
              },
            ),
    );
  }
}
