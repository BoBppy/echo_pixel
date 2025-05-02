import 'package:echo_pixel/screens/media_scan_settings_page.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:echo_pixel/screens/permission_guide_page.dart';
import 'package:echo_pixel/screens/webdav_status_page.dart';
import 'package:echo_pixel/services/thumbnail_service.dart';
import 'package:echo_pixel/services/foreground_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/theme_service.dart';
import 'services/webdav_service.dart';
import 'services/media_sync_service.dart';
import 'services/media_index_service.dart';
import 'screens/photo_gallery_page.dart';
import 'screens/settings_page.dart';

void main() async {
  // 确保初始化Flutter绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化SharedPreferences
  await initPrefs();

  // 初始化MediaKit
  MediaKit.ensureInitialized();

  // 在移动平台上初始化前台任务服务
  if (!isDesktopPlatform()) {
    await ForegroundSyncService.initForegroundTask();
  }

  // 初始化WebDAV服务和媒体同步服务
  final webDavService = WebDavService();
  final mediaSyncService = await MediaSyncService.builder(webDavService);

  // 初始化其他服务
  final themeService = ThemeService();
  final mediaIndexService = await MediaIndexService.build();

  final prefs = await SharedPreferences.getInstance();

  final serverUrl = prefs.getString('webdav_server');
  final username = prefs.getString('webdav_username');
  final password = prefs.getString('webdav_password');
  final uploadRootPath = prefs.getString('webdav_upload_root_path');

  await themeService.initialize();
  if (serverUrl != null) {
    webDavService.initialize(serverUrl,
        username: username, password: password, uploadRootPath: uploadRootPath);
  }

  runApp(
    // 使用Provider提供服务
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        // 添加MediaSyncService作为Provider
        ChangeNotifierProvider<MediaSyncService>.value(value: mediaSyncService),
        // 添加WebDavService作为Provider
        ChangeNotifierProvider<WebDavService>.value(value: webDavService),
        Provider<ThumbnailService>.value(value: ThumbnailService()),
        // 添加MediaIndexService作为Provider
        ChangeNotifierProvider<MediaIndexService>.value(
            value: mediaIndexService),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> initPrefs() async {
  // 初始化SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final defaultMediaFolders =
      await MediaScanSettingsPage.getDefaultMediaFolders();
  if (prefs.getStringList('scan_folders') == null) {
    // 如果没有存储的扫描文件夹，则设置默认值
    await prefs.setStringList('scan_folders', defaultMediaFolders);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      title: 'Echo Pixel',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          textTheme: GoogleFonts.notoSansScTextTheme(textTheme)),
      darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.notoSansScTextTheme(textTheme)),
      themeMode: themeService.themeMode,
      home: const AppStartupController(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  // 判断设备方向
  bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // 页面列表
  Widget _getPageForIndex(int index) {
    return switch (index) {
      0 => PhotoGalleryPage(),
      1 => const WebDavStatusPage(),
      _ => const SettingsPage(),
    };
  }

  // 底部导航项目
  final List<NavigationDestination> _navigationDestinations = [
    const NavigationDestination(icon: Icon(Icons.photo_library), label: '相册'),
    const NavigationDestination(
        icon: Icon(Icons.cloud_outlined), label: 'WebDAV'),
    const NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 检测设备是否为平板或大屏设备（宽度 > 600dp）
    final bool isTabletOrLarger = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
          title: Text(_selectedIndex == 0
              ? '照片库'
              : _selectedIndex == 1
                  ? 'WebDAV'
                  : '设置')),
      drawer: isDesktopPlatform() || isTabletOrLarger
          ? null
          : NavigationDrawer(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                Navigator.pop(context);
              },
              children: [
                Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Echo Pixel',
                      style: Theme.of(context).textTheme.titleLarge,
                    )),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('相册'),
                  selectedIcon: const Icon(Icons.photo_library_rounded),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('WebDAV'),
                  selectedIcon: const Icon(Icons.cloud),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('设置'),
                  selectedIcon: const Icon(Icons.settings),
                )
              ],
            ),
      body: Row(
        children: [
          // 在桌面端或平板横屏模式显示永久侧边栏
          if (isDesktopPlatform() || (isTabletOrLarger && isLandscape(context)))
            NavigationRail(
              extended: isDesktopPlatform() ||
                  MediaQuery.of(context).size.width > 800,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.photo_library),
                  label: Text('相册'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.cloud_outlined),
                  label: Text('WebDAV'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  label: Text('设置'),
                ),
              ],
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
            ),
          // 主内容区域
          Expanded(child: _getPageForIndex(_selectedIndex)),
        ],
      ),
      // 在移动端显示底部导航栏，桌面端不显示
      bottomNavigationBar:
          (!isDesktopPlatform() && (!isTabletOrLarger || !isLandscape(context)))
              ? NavigationBar(
                  destinations: _navigationDestinations,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                )
              : null,
    );
  }
}

bool isDesktopPlatform() {
  return !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}

/// 应用启动控制器，用于管理应用启动流程
class AppStartupController extends StatefulWidget {
  const AppStartupController({super.key});

  @override
  State<AppStartupController> createState() => _AppStartupControllerState();
}

class _AppStartupControllerState extends State<AppStartupController> {
  bool _isLoading = true;
  bool _showPermissionGuide = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    // 非Android平台不需要显示权限引导
    if (!Platform.isAndroid) {
      setState(() {
        _isLoading = false;
        _showPermissionGuide = false;
      });
      return;
    }

    // 检查是否已经授予了权限
    final prefs = await SharedPreferences.getInstance();
    final permissionsGranted = prefs.getBool('permissions_granted') ?? false;

    // 如果已经授予权限，直接进入主页面
    if (permissionsGranted) {
      setState(() {
        _isLoading = false;
        _showPermissionGuide = false;
      });
      return;
    }

    // 检查Android版本和权限状态
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    bool needPermission = false;

    // 检查通知权限
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      needPermission = true;
    }

    // 根据Android版本检查不同的媒体权限
    if (sdkInt >= 33) {
      // Android 13及以上
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      if (!photosStatus.isGranted || !videosStatus.isGranted) {
        needPermission = true;
      }
    } else {
      // 低版本Android
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        needPermission = true;
      }
    }

    setState(() {
      _isLoading = false;
      _showPermissionGuide = needPermission;
    });
  }

  void _onPermissionsGranted() {
    setState(() {
      _showPermissionGuide = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 显示加载画面
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon/foreground.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('正在加载应用...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    // 如果需要显示权限引导，则显示权限引导页面
    if (_showPermissionGuide && Platform.isAndroid) {
      return PermissionGuidePage(
        onPermissionsGranted: _onPermissionsGranted,
      );
    }

    // 否则显示主界面
    return const HomeScreen();
  }
}
