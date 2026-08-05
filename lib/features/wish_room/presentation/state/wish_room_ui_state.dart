/// [소원방 Riverpod 실험판] 화면 흐름(동기적 UI) 상태.
///
/// 로딩/에러 상태는 AsyncNotifier(AsyncValue)가 별도로 관리하므로 여기서는
/// "정상 데이터가 있을 때"의 화면 흐름만 다룬다.
enum WishRoomFlowStep {
  /// 기본 상태 — 평상시 메인 화면
  home,

  /// 빈 상태 — 등록된 소원이 0개
  empty,

  /// 소원 작성 화면으로 전환된 상태
  writingWish,

  /// 치성/정성 담기 화면(바텀시트)이 열린 상태 — 치성 종류 선택 포함
  praying,

  /// 기도 완료 연출이 노출 중인 상태
  prayerCompleted,

  /// 재방문 축하(연속 기도일수 임계값 도달) 배지가 함께 노출되는 상태
  revisitCelebration,

  /// 꾸미기 화면이 열린 상태
  customizing,

  /// 슬롯 확장 화면이 열린 상태
  unlockingSlot,
}

/// 1회성 애니메이션 신호. 위젯이 소비한 뒤 반드시 clearAnimation()을
/// 호출해 다음 rebuild에서 중복 재생되지 않도록 해야 한다.
enum WishRoomAnimationEvent {
  objectTouch,
  prayerBurst,
  streakLevelUp,
  growthStageUp,
  slotUnlocked,
}

class WishRoomUiState {
  final WishRoomFlowStep step;
  final bool showGuideDialog;
  final WishRoomAnimationEvent? pendingAnimationEvent;

  const WishRoomUiState({
    this.step = WishRoomFlowStep.home,
    this.showGuideDialog = false,
    this.pendingAnimationEvent,
  });

  WishRoomUiState copyWith({
    WishRoomFlowStep? step,
    bool? showGuideDialog,
    WishRoomAnimationEvent? pendingAnimationEvent,
    bool clearAnimationEvent = false,
  }) {
    return WishRoomUiState(
      step: step ?? this.step,
      showGuideDialog: showGuideDialog ?? this.showGuideDialog,
      pendingAnimationEvent: clearAnimationEvent
          ? null
          : (pendingAnimationEvent ?? this.pendingAnimationEvent),
    );
  }
}
