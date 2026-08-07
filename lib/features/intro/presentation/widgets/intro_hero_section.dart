import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';

/// [인트로 전면 개편] 2~3단계 카드 상단의 "미니 비주얼" 영역.
///
/// 사용자 요구사항의 "과한 별/마법진/네온/3D/영상형 금지" 원칙에 따라 사진이나
/// 복잡한 일러스트 대신 아이콘 + 옅은 카드 배경 + (선택)배지만으로 구성한다.
/// - 카드1(프리패스): 잠금 해제 아이콘 + "1시간" 배지
/// - 카드2(복주머니): 복주머니 아이콘 + 개수가 올라가는 카운터 애니메이션
class IntroHeroSection extends StatelessWidget {
  final IconData icon;
  final String? badgeText;
  final Color cardColor;

  /// true면 [counterTarget]까지 숫자가 올라가는 카운트업 애니메이션을 보여준다
  /// (복주머니 카드 전용 — "복주머니 개수 증가" 요구사항 대응).
  final bool showCounter;
  final int counterTarget;
  final String counterSuffix;

  const IntroHeroSection({
    super.key,
    required this.icon,
    this.badgeText,
    this.cardColor = UnifiedColors.cardMain,
    this.showCounter = false,
    this.counterTarget = 12,
    this.counterSuffix = '개',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: UnifiedColors.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: UnifiedColors.black),
                ),
                if (showCounter) ...[
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: counterTarget),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '+$value$counterSuffix',
                      style: UnifiedText.titleLarge().copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: UnifiedTokens.spaceXl,
              right: UnifiedTokens.spaceXl,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnifiedTokens.spaceMd,
                  vertical: UnifiedTokens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: UnifiedColors.black,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
                child: Text(
                  badgeText!,
                  style: UnifiedText.chipLabel(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
