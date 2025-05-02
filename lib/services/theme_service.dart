import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _systemModeKey = 'system_mode';
  static const String _darkModeKey = 'dark_mode';

  // 单例模式
  static final ThemeService _instance = ThemeService._internal();

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal();

  // 主题模式
  ThemeMode _themeMode = ThemeMode.system;

  // 获取当前主题模式
  ThemeMode get themeMode => _themeMode;

  // 跟随系统开启模式
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // 黑暗ui开启模式
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // 初始化
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isSystemMode = prefs.getBool(_systemModeKey);
    final isDarkMode = prefs.getBool(_darkModeKey);

    if (isSystemMode != null && isSystemMode) {
      _themeMode = ThemeMode.system;
    } else if (isDarkMode != null && isDarkMode) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    notifyListeners();
  }

  // 设置跟随系统模式
  Future<void> setSystemMode(bool isSystemMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_systemModeKey, isSystemMode);

    _themeMode = isSystemMode ? ThemeMode.system : ThemeMode.light;
    notifyListeners();
  }

  // 切换跟随系统模式
  Future<void> toggleSystemMode() async {
    await setSystemMode(!isSystemMode);
  }

  // 设置深色模式
  Future<void> setDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode);

    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // 切换主题模式
  Future<void> toggleThemeMode() async {
    await setDarkMode(!isDarkMode);
  }
}
