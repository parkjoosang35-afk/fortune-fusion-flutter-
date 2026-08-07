import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [인트로 전면 개편] 인트로(첫 진입) 노출 여부를 결정하는 로컬 상태.
///
/// 기존 `onboarding_screen.dart`가 써오던 `onboarding_completed` bool 키를
/// 그대로 이어받아 `introSeen`으로 취급한다("유지 → 개선 → 연결" 원칙 —
/// 기존 사용자가 이미 온보딩을 봤다면 새 인트로도 다시 볼 필요가 없다).
///
/// 상태값:
/// - [introSeen]: 인트로(스플래시 이후 카드+CTA)를 끝까지 보거나 스킵해서
///   완료 처리된 적이 있는지. true면 다음 실행부터는 스플래시 이후 바로 홈/로그인으로.
/// - [skipped]: 이번 인트로를 스킵 버튼으로 건너뛰었는지(진입 정책 로그용, UI는
///   introSeen과 동일하게 취급).
/// - [continueAsGuest]: 마지막 CTA 화면에서 "바로 시작하기"(비회원 홈 진입)를
///   선택했는지 — 회원가입 유도 배너 노출 빈도 조절 등에 향후 활용 가능.
class IntroStateProvider extends ChangeNotifier {
  static const _kIntroSeenKey = 'onboarding_completed'; // 기존 키 재사용(하위호환)
  static const _kSkippedKey = 'intro_skipped_v1';
  static const _kContinueAsGuestKey = 'intro_continue_as_guest_v1';

  bool _introSeen = false;
  bool get introSeen => _introSeen;

  bool _skipped = false;
  bool get skipped => _skipped;

  bool _continueAsGuest = false;
  bool get continueAsGuest => _continueAsGuest;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _introSeen = prefs.getBool(_kIntroSeenKey) ?? false;
      _skipped = prefs.getBool(_kSkippedKey) ?? false;
      _continueAsGuest = prefs.getBool(_kContinueAsGuestKey) ?? false;
    } catch (e) {
      debugPrint('[IntroStateProvider] [load] 실패(기본값 유지) -> $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// 인트로를 끝까지 보고 CTA 버튼(가입 또는 바로시작) 중 하나를 눌러 완료.
  Future<void> markSeen({required bool asGuest}) async {
    _introSeen = true;
    _continueAsGuest = asGuest;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIntroSeenKey, true);
      await prefs.setBool(_kContinueAsGuestKey, asGuest);
    } catch (e) {
      debugPrint('[IntroStateProvider] [markSeen] 저장 실패(무시) -> $e');
    }
  }

  /// 스킵 버튼으로 인트로를 건너뜀 — 완료 처리는 동일하게 introSeen=true.
  Future<void> markSkipped() async {
    _introSeen = true;
    _skipped = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIntroSeenKey, true);
      await prefs.setBool(_kSkippedKey, true);
    } catch (e) {
      debugPrint('[IntroStateProvider] [markSkipped] 저장 실패(무시) -> $e');
    }
  }
}
