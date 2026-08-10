import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../premium_card.dart';
import '../simple_markdown_text.dart';
import 'lock_overlay_badge.dart';

/// 재사용 위젯 ② SectionCard — 결과 화면 "전체 흐름" 카드(섹션2) 및
/// "세부 운세 5종" 카드(섹션4~8)에서 공통으로 사용하는 제목+본문(+지수뱃지) 카드.
///
/// 배경 #F6F5FA(cardSection), radius16, padding14. 좌측 제목(Title15),
/// 우측 상단 트레일링(지수 뱃지 등), 본문(Body14, 행간1.4).
///
/// [isLocked]가 true면 §5 정책에 따라 상단에 잠금 뱃지, 본문은 1줄 요약만
/// 보여준다(blur 금지). 열림패스 유도 문구는 카드마다 반복하지 않고,
/// 결과 화면 상단에 단 하나의 안내 카드로 모아 보여준다(과도한 반복 노출 금지).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.body,
    this.trailing,
    this.child,
    this.isLocked = false,
    this.lockSummary,
    this.icon,
  });

  final String title;
  final String? body;
  final Widget? trailing;

  /// body 대신 커스텀 콘텐츠를 넣고 싶을 때 사용(잠금 시에는 무시됨).
  final Widget? child;
  final bool isLocked;

  /// [§6-4] 세부 운세 5종(연애/금전/인간관계/건강/일학업) 카드에 표시하는
  /// line-style 아이콘. 20px(iconLg) 고정, 제목 좌측에 배치.
  final IconData? icon;

  /// 잠금 상태에서 노출할 1줄 요약(없으면 body를 1줄로 축약해 보여줌).
  final String? lockSummary;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLocked) ...[
            const LockOverlayBadge.badge(),
            const SizedBox(height: UnifiedTokens.spaceSm),
          ],
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: UnifiedTokens.iconLg,
                  color: UnifiedColors.textSecondary,
                ),
                const SizedBox(width: UnifiedTokens.spaceSm),
              ],
              Expanded(child: Text(title, style: UnifiedText.title())),
              if (trailing != null && !isLocked) trailing!,
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          if (!isLocked && child != null)
            child!
          else if (isLocked)
            Text(
              lockSummary ?? body ?? '',
              style: UnifiedText.body(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            SimpleMarkdownText(data: body ?? '', baseStyle: UnifiedText.body()),
        ],
      ),
    );
  }
}
