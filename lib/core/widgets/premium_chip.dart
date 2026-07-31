import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] §3 칩 규칙(v2)
///
/// 기준 시안 반영: 선택 시 네온 옐로우그린(premiumNeonLime) 채움 + 다크 텍스트,
/// 비선택 시 연회색(premiumInactiveGrey) 채움 + 보더 없음. 선택 전환 시
/// AnimatedContainer로 컬러가 부드럽게 바뀐다.
///
/// [홈 화면 최종 마감 정돈 프롬프트] 이 위젯은 FortuneHubScreen/
/// CommunityHubScreen/AllCategoriesScreen에서도 기존 기본값(padding16/8,
/// radius999, premiumNeonLime 등)으로 그대로 쓰이고 있어, 값을 직접 바꾸면
/// 다른 화면이 깨진다. 그래서 아래 override 파라미터들을 모두 선택적(nullable)
/// 으로 추가하고, 값을 넘기지 않으면 기존 동작을 100% 그대로 유지한다.
/// 홈 화면(home_screen.dart)에서만 이 override들을 채워 정확한 스펙값
/// (height30/padding12/radius15/#C6F24E 등)을 적용한다.
class PremiumChip extends StatelessWidget {
  const PremiumChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.height,
    this.horizontalPadding,
    this.radius,
    this.activeBg,
    this.activeFg,
    this.inactiveBg,
    this.inactiveFg,
    this.labelStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// 아래는 모두 override 전용(null이면 기존 기본 동작 유지).
  final double? height;
  final double? horizontalPadding;
  final double? radius;
  final Color? activeBg;
  final Color? activeFg;
  final Color? inactiveBg;
  final Color? inactiveFg;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (activeBg ?? AppColors.premiumNeonLime)
        : (inactiveBg ?? AppColors.premiumInactiveGrey);
    final fg = selected
        ? (activeFg ?? AppColors.premiumNeonLimeOnColor)
        : (inactiveFg ?? AppColors.premiumInactiveGreyText);
    final textStyle =
        (labelStyle ??
                AppTypography.smallLabel.copyWith(fontWeight: FontWeight.w700))
            .copyWith(color: fg);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: height,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? 16,
          vertical: height != null ? 0 : 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius ?? 999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
