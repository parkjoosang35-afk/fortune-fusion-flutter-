import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';

/// [오늘의 운세 표준 플로우 §5 열림패스 정책] 잠금 카드 표기 규칙.
///
/// blur/gray overlay를 쓰지 않고, 카드 상단에 담백한 잠금 뱃지(자물쇠+Caption12)
/// 또는 카드 하단에 유도 문구("열림패스로 상세 보기")를 붙이는 두 가지 형태로
/// 재사용한다. 다른 운세 카테고리(사주/궁합/타로/관상/손금) 결과 화면에서도
/// 동일하게 재사용 가능하도록 core/widgets에 배치했다.
enum LockOverlayBadgeVariant { badge, hint }

class LockOverlayBadge extends StatelessWidget {
  /// 카드 상단용 — 자물쇠 아이콘 + "열림패스 필요".
  const LockOverlayBadge.badge({super.key, this.label = '프리패스 필요'})
    : variant = LockOverlayBadgeVariant.badge;

  /// 카드 하단용 — 화살표 아이콘 + "열림패스로 상세 보기".
  const LockOverlayBadge.hint({super.key, this.label = '프리패스로 상세 보기'})
    : variant = LockOverlayBadgeVariant.hint;

  final LockOverlayBadgeVariant variant;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isBadge = variant == LockOverlayBadgeVariant.badge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isBadge
              ? Icons.lock_outline_rounded
              : Icons.arrow_forward_ios_rounded,
          size: isBadge ? UnifiedTokens.iconSm : 10,
          color: UnifiedColors.textCaption,
        ),
        const SizedBox(width: 4),
        Text(label, style: UnifiedText.caption()),
      ],
    );
  }
}
