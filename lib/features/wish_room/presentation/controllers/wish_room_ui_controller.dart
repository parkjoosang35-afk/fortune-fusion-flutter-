import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/wish_room_ui_state.dart';

/// [소원방 Riverpod 실험판] 화면 흐름/팝업/애니메이션 트리거 등 순수 UI 상태.
/// 서버 데이터는 절대 이 클래스에 두지 않는다(WishRoomController가 담당).
class WishRoomUiController extends Notifier<WishRoomUiState> {
  @override
  WishRoomUiState build() => const WishRoomUiState();

  void goTo(WishRoomFlowStep step) {
    state = state.copyWith(step: step);
  }

  void openGuide() {
    state = state.copyWith(showGuideDialog: true);
  }

  void closeGuide() {
    state = state.copyWith(showGuideDialog: false);
  }

  void triggerAnimation(WishRoomAnimationEvent event) {
    state = state.copyWith(pendingAnimationEvent: event);
  }

  /// 애니메이션을 재생한 위젯은 반드시 이 메서드를 호출해 신호를 비워야
  /// 다음 rebuild에서 동일 애니메이션이 중복 재생되지 않는다.
  void clearAnimation() {
    state = state.copyWith(clearAnimationEvent: true);
  }
}
