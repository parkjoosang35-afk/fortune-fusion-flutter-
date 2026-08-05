import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/wish_item_model.dart';
import '../../data/models/wish_room_visual_state_model.dart';
import '../state/wish_room_ui_state.dart';
import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 메인 인터랙티브 오브제.
///
/// 성능 원칙: 이 위젯 전체를 RepaintBoundary로 감싸고, 애니메이션은
/// 로컬 AnimationController가 직접 재생한다(Riverpod 상태를 프레임 단위로
/// 갈아끼우지 않음). Riverpod은 "터치했다/치성을 마쳤다/성장 단계가
/// 올랐다" 같은 1회성 신호(WishRoomAnimationEvent)만 상위로 올려줄 뿐,
/// 실제 발광/버스트 애니메이션 재생은 이 위젯이 로컬 상태로 스스로
/// 담당한다.
///
/// [애니메이션 이벤트 소비] [pendingAnimationEvent]로 objectTouch /
/// prayerBurst / growthStageUp 신호가 들어오면 즉시 강한 버스트 연출을
/// 1회 재생하고, 재생이 끝나면 반드시 [onAnimationConsumed]를 호출해
/// 상위(WishRoomUiController.clearAnimation())가 신호를 비우게 한다 —
/// 그러지 않으면 다음 rebuild에서 동일 애니메이션이 중복 재생된다.
class WishRoomObject extends StatefulWidget {
  final WishRoomVisualState visualState;
  final VoidCallback? onTap;

  /// 지금 재생해야 할 1회성 애니메이션 신호. objectTouch/prayerBurst/
  /// growthStageUp만 이 위젯이 직접 소비한다(streakLevelUp/slotUnlocked는
  /// 오브제가 아닌 다른 화면 요소의 연출이라 여기서는 무시하고 그대로
  /// 흘려보낸다 — 상위가 다른 위젯에서 소비할 수 있게 clearAnimation을
  /// 호출하지 않고 지나간다).
  final WishRoomAnimationEvent? pendingAnimationEvent;

  /// 이 위젯이 [pendingAnimationEvent]를 소비(연출 재생 완료)했음을
  /// 상위에 알리는 콜백. 상위는 이 콜백에서 반드시
  /// `ref.read(wishRoomUiProvider.notifier).clearAnimation()`을 호출해야
  /// 한다.
  final VoidCallback? onAnimationConsumed;

  const WishRoomObject({
    super.key,
    required this.visualState,
    this.onTap,
    this.pendingAnimationEvent,
    this.onAnimationConsumed,
  });

  @override
  State<WishRoomObject> createState() => _WishRoomObjectState();
}

class _WishRoomObjectState extends State<WishRoomObject>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  double _touchBoost = 0.0;

  /// [애니메이션 이벤트 소비] 치성 버스트/성장 단계 상승 시 breathe 글로우
  /// 위에 추가로 겹쳐지는 확산 강도(0~1). touchBoost보다 더 크고 오래
  /// 지속되는 "축하" 톤의 연출을 위해 별도 값으로 관리한다.
  double _burstBoost = 0.0;

  /// [타이머 누수 방지] `_handleTap`/`_playBurst`/`_maybeConsumePendingEvent`
  /// 가 예약한 지연 콜백을 각각 별도 Timer로 추적한다. 위젯이 애니메이션
  /// 도중 dispose되면(예: 화면 전환) 반드시 pending timer를 취소해야 한다
  /// — 그러지 않으면 위젯 테스트에서 "A Timer is still pending even after
  /// the widget tree was disposed" 어서션에 걸리고, 실 앱에서도 이미 dispose
  /// 된 State에 setState를 시도하게 된다.
  Timer? _touchTimer;
  Timer? _burstTimer;
  Timer? _consumeTimer;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _maybeConsumePendingEvent();
  }

  @override
  void didUpdateWidget(WishRoomObject oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingAnimationEvent != null &&
        widget.pendingAnimationEvent != oldWidget.pendingAnimationEvent) {
      _maybeConsumePendingEvent();
    }
  }

  @override
  void dispose() {
    _touchTimer?.cancel();
    _burstTimer?.cancel();
    _consumeTimer?.cancel();
    _breatheController.dispose();
    super.dispose();
  }

  /// [애니메이션 이벤트 소비] objectTouch/prayerBurst/growthStageUp만 이
  /// 위젯이 직접 처리한다. 처리 후에는 항상 [onAnimationConsumed]를 호출해
  /// 신호를 비우도록 요청한다 — 그렇지 않으면 다음 프레임에서 동일 신호가
  /// 남아있어 재생이 중복될 수 있다.
  void _maybeConsumePendingEvent() {
    final event = widget.pendingAnimationEvent;
    if (event == null) return;
    switch (event) {
      case WishRoomAnimationEvent.objectTouch:
        _playBurst(intensity: 0.3, duration: const Duration(milliseconds: 250));
        break;
      case WishRoomAnimationEvent.prayerBurst:
      case WishRoomAnimationEvent.growthStageUp:
        // 치성 완료/성장 단계 상승은 오브제가 표현할 수 있는 가장 강한
        // 시각 보상이므로 더 크고 길게 확산시킨다.
        _playBurst(intensity: 0.6, duration: const Duration(milliseconds: 700));
        break;
      case WishRoomAnimationEvent.streakLevelUp:
      case WishRoomAnimationEvent.slotUnlocked:
        // 오브제 전용 연출이 아니므로 여기서는 소비하지 않고 그대로
        // 흘려보낸다(다른 위젯이 처리하거나, 처리하는 위젯이 없으면
        // 별도 조치 없이 다음 방문 때까지 신호가 유지된다).
        return;
    }
    // [빌드 중 Provider 수정 방지] initState/didUpdateWidget은 위젯 빌드
    // 라이프사이클 도중이라 이 시점에 곧바로 Riverpod provider를 수정하면
    // "Tried to modify a provider while the widget tree was building"
    // 예외가 발생한다. 현재 빌드가 끝난 다음 프레임에서 안전하게 소비
    // 신호를 비우도록 Timer.run으로 지연시킨다(microtask보다 늦게, 다음
    // 이벤트 루프 턴에 실행되어 build가 완전히 끝난 뒤 provider를 수정).
    _consumeTimer?.cancel();
    _consumeTimer = Timer(Duration.zero, () {
      if (mounted) widget.onAnimationConsumed?.call();
    });
  }

  void _playBurst({required double intensity, required Duration duration}) {
    setState(() => _burstBoost = intensity);
    _burstTimer?.cancel();
    _burstTimer = Timer(duration, () {
      if (mounted) setState(() => _burstBoost = 0.0);
    });
  }

  void _handleTap() {
    setState(() => _touchBoost = 0.3);
    _touchTimer?.cancel();
    _touchTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _touchBoost = 0.0);
    });
    widget.onTap?.call();
  }

  double _sizeForLevel(WishObjectLevel level) {
    switch (level) {
      case WishObjectLevel.seed:
        return 96;
      case WishObjectLevel.glow:
        return 108;
      case WishObjectLevel.bloom:
        return 120;
      case WishObjectLevel.radiant:
        return 132;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseGlow = widget.visualState.glowIntensity;
    final size = _sizeForLevel(widget.visualState.objectLevel);
    // [소원 성장 시스템 연동] 대표 소원의 정성 누적 단계에 따라 오브제의
    // 색조가 붉은 불씨 → 눈부신 금빛으로 점진 변화한다(정책표 ⑥).
    final stage = widget.visualState.representativeGrowthStage;
    final stageTone = WishRoomColors.forGrowthStage(stage);
    final stageGradient = WishRoomColors.objectGradientForStage(stage);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _breatheController,
          builder: (context, child) {
            final breathe = 0.05 * _breatheController.value;
            final intensity = (baseGlow + _touchBoost + _burstBoost + breathe)
                .clamp(0.0, 1.0);
            // 버스트 연출은 터치보다 더 큰 스케일 반응으로 "빛이 확 퍼지는"
            // 체감을 강화한다(치성 완료/성장 단계 상승 시).
            final scale = 1.0 + _touchBoost + _burstBoost * 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: size + 60,
              height: size + 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: stageTone.withValues(alpha: 0.15 + 0.35 * intensity),
                    blurRadius: 30 + 30 * intensity,
                    spreadRadius: 4 + 10 * intensity,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: stageGradient,
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      stage.emoji,
                      key: ValueKey(stage),
                      style: TextStyle(fontSize: size * 0.32),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
