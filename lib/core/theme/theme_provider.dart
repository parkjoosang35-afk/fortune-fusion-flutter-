import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 07단계 §10 다크모드 설계 - ThemeMode.system을 기본값으로 자동 추종하며,
/// 마이페이지 설정에서 수동 전환(light/dark/system) 가능하도록 지원한다.
/// 선택값은 shared_preferences에 저장되어 앱 재실행 시에도 유지된다.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    switch (saved) {
      case 'light':
        _mode = ThemeMode.light;
        break;
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      default:
        _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
