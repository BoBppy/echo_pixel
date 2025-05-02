import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import 'webdav_settings.dart';
import 'storage_management_page.dart';
import 'media_scan_settings_page.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableAutoSync = false;
  String _webDavStatus = '未连接';
  bool _isWebDavConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载自动同步设置
      final enableAutoSync = prefs.getBool('enable_auto_sync');

      // 检查WebDAV连接状态
      final webDavServer = prefs.getString('webdav_server');
      final webDavUsername = prefs.getString('webdav_username');

      setState(() {
        _enableAutoSync = enableAutoSync ?? false;

        if (webDavServer != null && webDavServer.isNotEmpty) {
          _isWebDavConnected = true;
          _webDavStatus = webDavUsername != null && webDavUsername.isNotEmpty
              ? '已连接 ($webDavUsername@$webDavServer)'
              : '已连接 ($webDavServer)';
        } else {
          _isWebDavConnected = false;
          _webDavStatus = '未连接';
        }
      });
    } catch (e) {
      debugPrint('加载设置错误: $e');
    }
  }

  Future<void> _saveAutoSync(bool enableAutoSync) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_auto_sync', enableAutoSync);
      setState(() {
        _enableAutoSync = enableAutoSync;
      });
    } catch (e) {
      debugPrint('保存自动同步设置错误: $e');
    }
  }

  Future<void> _openWebDavSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebDavSettingsScreen(),
      ),
    );

    // 如果WebDAV设置页面返回了结果，刷新设置状态
    if (result == true) {
      _loadSettings();
    }
  }

  void _openStorageManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StorageManagementPage(),
      ),
    );
  }

  void _openMediaScanSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MediaScanSettingsPage(),
      ),
    );
  }

  void _openAboutPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AboutPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: ListView(children: [
        // 应用设置标题
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '应用设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),

        SwitchListTile(
          title: const Text('跟随系统主题'),
          subtitle: const Text('是否启用深色模式跟随系统开关'),
          value: themeService.isSystemMode,
          onChanged: (value) => themeService.setSystemMode(value),
        ),

        SwitchListTile(
          title: const Text('深色模式'),
          subtitle: const Text('启用深色主题'),
          value: themeService.isDarkMode,
          onChanged: themeService.isSystemMode
              ? null
              : (value) => themeService.setDarkMode(value),
        ),

        // 云同步标题
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '云同步',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),

        ListTile(
          leading: Icon(
            _isWebDavConnected ? Icons.cloud_done : Icons.cloud_off,
            color: _isWebDavConnected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
          ),
          title: const Text('WebDAV 设置'),
          subtitle: Text(_webDavStatus),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openWebDavSettings,
        ),

        // 自动同步设置
        SwitchListTile(
          title: const Text('自动同步'),
          subtitle: const Text('当连接到Wi-Fi时自动同步媒体文件'),
          value: _enableAutoSync,
          onChanged: _isWebDavConnected ? _saveAutoSync : null,
        ),

        // 其他设置标题
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '媒体管理',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),

        // 存储空间管理
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('存储空间管理'),
          subtitle: const Text('管理缓存和本地媒体存储'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openStorageManagement,
        ),

        // 媒体扫描设置
        ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('媒体扫描设置'),
          subtitle: const Text('选择要扫描的文件夹'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openMediaScanSettings,
        ),

        // 关于应用
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '关于',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),

        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于 Echo Pixel'),
          subtitle: const Text('版本 1.0.0'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openAboutPage,
        ),
      ]),
    );
  }
}
