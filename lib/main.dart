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
import 'utils/route_image_cache_manager.dart';
import 'utils/refresh_rate_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  // 初始化路线图片缓存管理器
  await RouteImageCacheManager.instance.initialize();
  
  // 初始化高刷新率管理器
  await RefreshRateManager.instance.initialize();

  // 尝试更新小组件显示，默认显示固定路径的日历图片
  await WidgetManager.updateCalendarWidget().then((success) {
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
    // 应用启动时检查权限
    _checkPermissions();
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
      Logger.d('主应用收到认证状态变化: isAuthenticated=$isAuthenticated, athlete=${athlete?.firstname}', tag: 'Main');
      setState(() {
        _isAuthenticated = isAuthenticated;
        _athlete = athlete;
        // 重新初始化所有页面以确保状态同步
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

  /// 检查应用所需的权限
  Future<void> _checkPermissions() async {
    // 在Web平台上不请求权限
    if (kIsWeb) {
      Logger.d('Web平台不需要请求权限', tag: 'Permissions');
      return;
    }
    
    try {
      // 需要检查的权限列表
      List<Permission> permissions = [
        Permission.location,
        Permission.locationWhenInUse,
        Permission.storage,
      ];
      
      // 添加Android 13+的媒体权限
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final deviceInfo = await DeviceInfoPlugin().androidInfo;
          final sdkInt = deviceInfo.version.sdkInt;
          if (sdkInt >= 33) { // Android 13+
            permissions.addAll([
              Permission.photos,
              Permission.videos,
              Permission.audio,
            ]);
          }
        } catch (e) {
          Logger.e('获取设备信息失败', error: e, tag: 'Permissions');
        }
      }
      
      // 检查每个权限的状态（不立即请求）
      Map<Permission, PermissionStatus> statuses = {};
      for (var permission in permissions) {
        statuses[permission] = await permission.status;
      }
      
      // 找出未授权的权限
      List<Permission> deniedPermissions = [];
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          deniedPermissions.add(permission);
        }
      });
      
      // 记录权限状态到日志
      Logger.d('权限状态: $statuses', tag: 'Permissions');
      
      // 如果有未授权的权限，显示权限对话框
      if (deniedPermissions.isNotEmpty) {
        // 确保界面已初始化完成后才显示对话框
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 确保context有效后再显示对话框
          if (mounted && context.mounted) {
            // 添加一个短暂延迟以确保界面已完全初始化
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && context.mounted) {
                _showPermissionDialog(deniedPermissions);
              }
            });
          }
        });
      }
    } catch (e) {
      Logger.e('检查权限出错', error: e, tag: 'Permissions');
      // 错误处理：显示提示
      Fluttertoast.showToast(
        msg: "权限检查过程中发生错误，部分功能可能无法正常使用",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
  
  /// 显示权限对话框
  void _showPermissionDialog(List<Permission> deniedPermissions) {
    // 防止重复显示或在未准备好时显示
    if (!mounted || !context.mounted) return;
    
    // 创建权限名称和描述的映射
    Map<Permission, String> permissionNames = {
      Permission.location: '位置信息',
      Permission.locationWhenInUse: '使用时的位置信息',
      Permission.storage: '存储空间',
      Permission.photos: '照片',
      Permission.videos: '视频',
      Permission.audio: '音频',
    };
    
    Map<Permission, String> permissionDescriptions = {
      Permission.location: '用于跟踪您的位置并记录跑步路线',
      Permission.locationWhenInUse: '用于在使用应用时获取您的位置信息',
      Permission.storage: '用于存储路线数据和导出GPX文件',
      Permission.photos: '用于访问照片媒体，保存和导出图片',
      Permission.videos: '用于访问视频媒体，保存相关数据',
      Permission.audio: '用于访问音频媒体，支持相关功能',
    };
    
    try {
      // 避免异常状态下尝试再次显示对话框
      if (ModalRoute.of(context)?.isCurrent != true) {
        Logger.w('当前路由非活跃，跳过显示权限对话框', tag: 'Permissions');
        return;
      }
      
      showDialog(
        context: context,
        barrierDismissible: false, // 用户必须点按按钮才能关闭对话框
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('需要权限'),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  const Text('此应用需要以下权限才能正常运行:'),
                  const SizedBox(height: 16),
                  ...deniedPermissions.map((permission) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permissionNames[permission] ?? permission.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            permissionDescriptions[permission] ?? '需要此权限以确保应用正常运行',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // 记录用户推迟授权
                  Logger.d('用户选择稍后授予权限', tag: 'Permissions');
                  
                  // 显示提示，告知用户如何稍后授予权限
                  Fluttertoast.showToast(
                    msg: "您可以在设置页面中随时授予所需权限",
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.BOTTOM,
                  );
                },
                child: const Text('稍后再说'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  
                  // 请求所有未授权的权限
                  Map<Permission, PermissionStatus> results = {};
                  for (var permission in deniedPermissions) {
                    final status = await permission.request();
                    results[permission] = status;
                    Logger.d('$permission 请求结果: $status', tag: 'Permissions');
                  }
                  
                  // 检查权限请求结果
                  int granted = 0;
                  bool hasPermanentlyDenied = false;
                  
                  for (var entry in results.entries) {
                    if (entry.value.isGranted) {
                      granted++;
                    } else if (await entry.key.isPermanentlyDenied) {
                      hasPermanentlyDenied = true;
                    }
                  }
                  
                  // 显示结果提示
                  if (granted == deniedPermissions.length) {
                    // 全部授予
                    Fluttertoast.showToast(
                      msg: "已获得所有所需权限",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.BOTTOM,
                    );
                  } else if (granted > 0) {
                    // 部分授予
                    Fluttertoast.showToast(
                      msg: "已获得部分权限，某些功能可能受限",
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.BOTTOM,
                    );
                  }
                  
                  // 如果有永久拒绝的权限，提示用户前往设置
                  if (hasPermanentlyDenied && mounted && context.mounted) {
                    // 延迟显示，避免连续弹窗带来的用户体验问题
                    Future.delayed(const Duration(milliseconds: 800), () {
                      if (mounted && context.mounted) {
                        _showAppSettingsDialog();
                      }
                    });
                  }
                },
                child: const Text('授予权限'),
              ),
            ],
          );
        },
      ).catchError((error) {
        Logger.e('显示权限对话框失败', error: error, tag: 'Permissions');
      });
    } catch (e) {
      Logger.e('显示权限对话框出错', error: e, tag: 'Permissions');
      
      // 在对话框显示失败时通过Toast提示用户
      Fluttertoast.showToast(
        msg: "权限对话框无法显示，请前往应用设置手动授予权限",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
    }
  }
  
  /// 显示前往应用设置的对话框
  void _showAppSettingsDialog() {
    if (!mounted || !context.mounted) return;
    
    try {
      // 避免异常状态下尝试再次显示对话框
      if (ModalRoute.of(context)?.isCurrent != true) {
        Logger.w('当前路由非活跃，跳过显示设置对话框', tag: 'Permissions');
        return;
      }
      
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('权限被永久拒绝'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('某些权限被永久拒绝，需要在应用设置中手动开启。'),
                SizedBox(height: 8),
                Text(
                  '这些权限对于应用的正常运行至关重要，没有这些权限，某些功能可能无法使用。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // 记录用户拒绝前往设置
                  Logger.d('用户拒绝前往设置页面', tag: 'Permissions');
                  
                  // 显示提示，告知用户缺少权限的影响
                  Fluttertoast.showToast(
                    msg: "缺少必要权限，部分功能可能无法正常使用",
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.BOTTOM,
                  );
                },
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // 打开应用设置页面
                  openAppSettings().then((success) {
                    Logger.d('打开应用设置页面结果: $success', tag: 'Permissions');
                    
                    if (!success) {
                      // 如果打开设置页面失败，显示提示
                      Fluttertoast.showToast(
                        msg: "无法打开设置页面，请手动前往系统设置",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                      );
                    } else {
                      // 提示用户从设置页面返回应用后，重启应用以应用权限变更
                      Fluttertoast.showToast(
                        msg: "权限修改后，建议重启应用以确保正常运行",
                        toastLength: Toast.LENGTH_LONG,
                        gravity: ToastGravity.BOTTOM,
                      );
                    }
                  });
                },
                child: const Text('前往设置'),
              ),
            ],
          );
        },
      ).catchError((error) {
        Logger.e('显示设置对话框失败', error: error, tag: 'Permissions');
      });
    } catch (e) {
      Logger.e('显示设置对话框出错', error: e, tag: 'Permissions');
      
      // 在对话框显示失败时通过Toast提示用户
      Fluttertoast.showToast(
        msg: "无法显示设置提示，请手动前往系统设置授予权限",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
    }
  }

  /// 用于从设置页面手动请求权限
  Future<void> requestAppPermissions() async {
    if (kIsWeb) return;
    
    try {
      _checkPermissions();
    } catch (e) {
      Logger.e('手动请求权限失败', error: e, tag: 'Permissions');
    }
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
                              icon: Icon(Icons.person),
                              label: Text('我的'),
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
                              icon: Icon(Icons.person),
                              label: '我的',
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
