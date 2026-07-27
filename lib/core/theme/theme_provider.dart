import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 07단계 §10 다크모드 설계 - 마이페이지 설정에서 수동 전환(light/dark) 가능하도록 지원한다.
/// 선택값은 shared_preferences에 저장되어 앱 재실행 시에도 유지된다.
///
/// [Sowoon.kr 리디자인 프롬프트] 기존 다크(밤하늘) 컨셉을 완전히 걷어내고
/// 화이트/골드 라이트 테마를 앱의 기본 첫인상으로 채택한다.
/// 사용자가 아직 아무 것도 선택하지 않은 최초 실행 시점에는
/// 항상 라이트 모드를 기본값으로 노출한다(다크모드 토글 자체도 노출하지 않음).
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    // [Sowoon.kr 리디자인 프롬프트] 다크모드 완전 제거 - 항상 라이트 모드로 고정.
    // (기존에 저장된 'dark' 값이 있어도 무시하고 라이트로 강제한다)
    _mode = ThemeMode.light;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
