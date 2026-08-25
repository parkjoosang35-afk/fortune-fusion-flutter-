import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_home_screen.dart';
import 'wish_room_onboarding_screen.dart';

/// 소원방(Wish Room) — 탭/카드 진입 게이트.
///
/// [Phase 01 · 2단계 · orphan 화면 연결] `wish_room_onboarding_screen.dart`가
/// 이미 예고해 둔 대로("이 화면은 '소원방' 탭에 처음 진입할 때 1회 노출되는
/// 게이트로 사용된다") 이 위젯이 그 게이트 역할을 한다.
/// [wishRoomOnboardingSeenPrefsKey] 플래그가 false면 온보딩을 먼저 보여주고,
/// "소원방 들어가기"/"이미 계정이 있어요"를 누르면 플래그를 true로 저장한
/// 뒤 [WishRoomHomeScreen]으로 전환한다. 이미 본 적이 있으면 온보딩 없이
/// 곧바로 홈을 보여준다.
///
/// [앱 전역 인트로와는 별개] 앱 전역 인트로(IntroStateProvider,
/// `onboarding_completed` 키)와 이름이 비슷해 보이지만 완전히 다른 키
/// ([wishRoomOnboardingSeenPrefsKey])를 쓴다 — "회원가입 인트로를 이미
/// 봤다"와 "소원방 제단에 처음 들어와 봤다"는 서로 다른 사실이므로 절대
/// 같은 키를 공유하면 안 된다.
///
/// [빈 상태 전체화면 연결] 온보딩을 이번에 처음 통과해 들어온 경우에만
/// [WishRoomHomeScreen.showEmptyScreenIfEmpty]를 true로 넘긴다 — "온보딩
/// 직후 첫 진입인데 소원이 하나도 없는" 시나리오에서만 02 Empty 전체화면을
/// 강조해서 보여주기 위함이다(문서 §2단계 (a) 시나리오). 이미 온보딩을
/// 봤던 기존 사용자는 지금까지처럼 [WishRoomHomeScreen] 내부의 축소된
/// 인라인 빈 상태를 그대로 사용한다(과거 세션 구현, 손대지 않음).
class WishRoomEntryGate extends StatefulWidget {
  const WishRoomEntryGate({super.key});

  @override
  State<WishRoomEntryGate> createState() => _WishRoomEntryGateState();
}

/// 소원방 온보딩 완료 여부를 저장하는 SharedPreferences 키.
///
/// [app_router.dart]의 독립 `/onboarding` named route(딥링크 등으로 직접
/// 진입할 수 있는 경로)도 동일한 키를 공유해야 게이트와 상태가 어긋나지
/// 않는다 — 그래서 private으로 숨기지 않고 top-level 상수로 공개한다.
const String wishRoomOnboardingSeenPrefsKey = 'wish_room_onboarding_seen';

/// 소원방 온보딩을 "봤음"으로 표시한다. 저장 실패해도 예외를 던지지 않고
/// 조용히 무시한다(다음 실행에 온보딩이 다시 뜨는 정도는 허용 가능한 실패).
Future<void> markWishRoomOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(wishRoomOnboardingSeenPrefsKey, true);
  } catch (_) {
    // 저장 실패 - 무시.
  }
}

class _WishRoomEntryGateState extends State<WishRoomEntryGate> {
  bool? _seen; // null = 로딩 중
  bool _justOnboarded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool seen = true; // 저장소 접근 실패 시 온보딩을 반복 노출하지 않는 안전 기본값.
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(wishRoomOnboardingSeenPrefsKey) ?? false;
    } catch (_) {
      // 저장소 접근 실패 - 바로 홈으로.
    }
    if (!mounted) return;
    setState(() => _seen = seen);
  }

  Future<void> _handleEnter() async {
    if (!mounted) return;
    setState(() {
      _seen = true;
      _justOnboarded = true;
    });
    await markWishRoomOnboardingSeen();
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      // 로딩 중에도 온보딩/홈과 동일한 배경색으로 화면 깜빡임을 방지.
      return const Scaffold(backgroundColor: WishRoomColors.backgroundDeep);
    }
    if (_seen == false) {
      return WishRoomOnboardingScreen(onEnter: _handleEnter);
    }
    return WishRoomHomeScreen(
      showEmptyScreenIfEmpty: _justOnboarded,
      // [Phase 01 · 2단계 · orphan 화면 연결] 사용자가 실제로 이 게이트를
      // 통해(=카드/라우트를 눌러) 소원방에 들어왔을 때만 07 개봉 화면 자동
      // 체크를 켠다. AppShell 탭의 WishRoomHomeScreen()은 이 플래그 없이
      // 그대로 둔다(기본값 false).
      checkBoxOpening: true,
    );
  }
}
