import 'package:shared_preferences/shared_preferences.dart';

/// [Phase C - 03_Welcome_Reward.html Flow notes 반영] 웰컴 리워드 팝업의
/// 1회성 노출 플래그.
///
/// 핸드오프 원문: "한 번만 트리거되도록 `user.welcome_gift_claimed` 플래그로
/// 관리. 재로그인 시엔 노출 안 됨." — 서버(UserModel/DB)에는 아직 해당
/// 필드가 없어(user_model.dart 확인 완료), 이번 단계에서는 클라이언트
/// 로컬(SharedPreferences)에 사용자 ID별로 키를 나눠 저장하는 방식으로
/// 구현한다. `AuthTokenStore`와 동일한 패턴(정적 클래스 + 캐시 없는 단순
/// prefs 접근)을 따른다.
///
/// [트레이드오프 - 명시적으로 알려진 한계] 로컬 저장 방식이므로 동일
/// 계정으로 다른 기기에서 로그인하면 팝업이 다시 노출될 수 있다(서버
/// 필드가 아직 없어 기기 간 동기화 불가). 회원가입 직후 발급되는
/// `lastSignupReward`는 프로세스 메모리에만 존재하는 1회성 값이라, 이미
/// "같은 프로세스 내 최초 1회"라는 자연스러운 제약이 걸려 있어 실사용상
/// 중복 노출 위험은 낮다(앱을 재시작하면 lastSignupReward 자체가 null이
/// 되어 트리거 조건이 성립하지 않는다 — 아래 [HomeScreen] 연동부 참고).
class WelcomeRewardFlagStore {
  WelcomeRewardFlagStore._();

  static String _keyFor(String userId) => 'welcome_gift_claimed_$userId';

  /// 이미 이 사용자에게 팝업을 노출(수령 완료)했는지 여부.
  static Future<bool> isClaimed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(userId)) ?? false;
  }

  /// 팝업 CTA("복주머니 받기") 수령 처리 완료 표시.
  static Future<void> markClaimed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(userId), true);
  }
}
