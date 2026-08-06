import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [9단계 화이트톤 전환] 마이페이지 설정 화면(settings_screen.dart)에서
/// 다크모드 토글 UI는 이미 완전히 제거되었고, "앱은 항상 화이트/골드 라이트
/// 테마로만 동작한다(ThemeProvider는 ThemeMode.light 고정)"는 정책이 확정되어
/// 있다. 과거 "우주 감성 다크 테마" 실험 단계에서 이 파일의 기본값만 dark로
/// 되돌려진 채 방치되어 정책과 실제 동작이 모순되던 문제를 여기서 바로잡는다.
///
/// - 다크모드로 진입할 수 있는 UI 경로가 앱 전체에 없다(setMode 호출부 0건).
/// - 과거 버전에서 shared_preferences에 'dark'가 저장되어 있던 사용자도
///   이제는 라이트로 강제 전환된다(라이트 고정 정책이므로 잔존값을 무시).
/// - AppTheme.dark / MaterialApp.darkTheme 정의 자체는 코드에서 삭제하지
///   않고 유지한다(유지→수정→통합→off→삭제 원칙). 단, 이 Provider가 항상
///   light를 반환하므로 다크 테마 경로는 실질적으로 비활성(off) 상태가 된다.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    // 화이트/골드 라이트 테마 고정 정책 — 과거 저장된 'dark' 잔존값이 있어도
    // 무시하고 항상 라이트 모드로 고정한다. setMode()는 향후 다크모드를
    // 다시 도입할 경우를 위해 남겨두되, 현재는 어떤 화면에서도 호출하지 않는다.
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
