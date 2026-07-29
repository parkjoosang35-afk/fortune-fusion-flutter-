import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 07단계 §10 다크모드 설계 - 마이페이지 설정에서 수동 전환(light/dark) 가능하도록 지원한다.
/// 선택값은 shared_preferences에 저장되어 앱 재실행 시에도 유지된다.
///
/// [Fortune Fusion UI 리뉴얼 프롬프트] 우주 감성(딥네이비+골드/퍼플) 다크 테마가
/// 앱의 정체성이므로, 이전 "Sowoon.kr 리디자인" 단계에서 강제했던 라이트 고정을
/// 해제하고 다크 모드를 기본값으로 되돌린다. 사용자가 마이페이지에서 라이트로
/// 전환한 이력이 있다면(shared_preferences 저장값) 그 선택을 존중한다.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'light') {
      _mode = ThemeMode.light;
    } else {
      // 저장된 값이 없거나 'dark'인 경우 우주 감성 다크 모드를 기본값으로 사용.
      _mode = ThemeMode.dark;
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
