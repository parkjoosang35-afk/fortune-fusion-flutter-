import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [소원방 Riverpod 실험판] 기도 완료 연출 바텀시트.
///
/// 빛 확산 애니메이션(글로우 강화) + 완료 메시지 + 재방문 유도 문구.
/// [didLevelUp]이 true면(성장 단계가 이번 치성으로 올라간 경우) 강조
/// 배지를 추가로 노출한다(정책표 ⑥ "성장 단계 상승" 강한 시각 보상 요건).
class PrayerCompleteSheet extends StatefulWidget {
  final int pouchUsed;
  final int consecutivePrayerDays;
  final bool didLevelUp;
  final String? newStageLabel;

  /// [슬롯 시스템 + 재방문 축하 연출] 이번 치성으로 연속 방문일수가 슬롯
  /// 해금 조건(3일/7일)에 새로 도달했는지. true면 성장 단계 배지와는 별도로
  /// "새로운 자리가 열렸어요" 골드 배지를 추가로 노출한다(정책표 ①+⑩).
  final bool didUnlockNewSlot;

  const PrayerCompleteSheet({
    super.key,
    this.pouchUsed = 1,
    this.consecutivePrayerDays = 1,
    this.didLevelUp = false,
    this.newStageLabel,
    this.didUnlockNewSlot = false,
  });

  @override
  State<PrayerCompleteSheet> createState() => _PrayerCompleteSheetState();
}

class _PrayerCompleteSheetState extends State<PrayerCompleteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glow = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        WishRoomSpacing.lg,
        WishRoomSpacing.lg,
        WishRoomSpacing.lg,
        WishRoomSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: WishRoomColors.backgroundMid,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WishRoomRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _glow,
              builder: (context, child) => Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: WishRoomColors.objectGlowGradient,
                  boxShadow: [
                    BoxShadow(
                      color: WishRoomColors.gold.withValues(
                        alpha: 0.4 * _glow.value,
                      ),
                      blurRadius: 40 * _glow.value,
                      spreadRadius: 8 * _glow.value,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: WishRoomSpacing.lg),
            AnimatedBuilder(
              animation: _glow,
              builder: (context, child) =>
                  Opacity(opacity: _glow.value, child: child),
              child: Text(
                '당신의 소원이 방 안에 고이 담겼어요',
                style: WishRoomTextStyles.titleLg,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: WishRoomSpacing.sm),
            Text(
              '당신의 진심이 빛으로 남았어요',
              style: WishRoomTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: WishRoomSpacing.md),
            Text(
              widget.pouchUsed > 0
                  ? '복주머니 ${widget.pouchUsed}개로 정성을 담았고, '
                        '연속 ${widget.consecutivePrayerDays}일째 이 방을 밝히고 있어요'
                  : '오늘의 무료 정성을 담았고, '
                        '연속 ${widget.consecutivePrayerDays}일째 이 방을 밝히고 있어요',
              style: WishRoomTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            if (widget.didLevelUp) ...[
              const SizedBox(height: WishRoomSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: WishRoomSpacing.md,
                  vertical: WishRoomSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: WishRoomColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                  border: Border.all(color: WishRoomColors.gold),
                ),
                child: Text(
                  '🎉 ${widget.newStageLabel ?? ''} 단계로 성장했어요',
                  style: WishRoomTextStyles.bodySm.copyWith(
                    color: WishRoomColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            // [재방문 축하 연출] 성장 단계 상승 배지와는 독립적으로, 연속
            // 방문일수가 슬롯 해금 조건에 막 도달했을 때만 별도 배지를
            // 노출한다 — 두 조건이 같은 치성에서 동시에 만족될 수도 있어
            // if 블록을 분리했다.
            if (widget.didUnlockNewSlot) ...[
              const SizedBox(height: WishRoomSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: WishRoomSpacing.md,
                  vertical: WishRoomSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: WishRoomColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                  border: Border.all(color: WishRoomColors.success),
                ),
                child: Text(
                  '✨ 새로운 소원 자리가 열렸어요',
                  style: WishRoomTextStyles.bodySm.copyWith(
                    color: WishRoomColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: WishRoomSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WishRoomColors.gold,
                  padding: const EdgeInsets.symmetric(
                    vertical: WishRoomSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WishRoomRadius.pill),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text('내일도 밝히러 올게요', style: WishRoomTextStyles.ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
