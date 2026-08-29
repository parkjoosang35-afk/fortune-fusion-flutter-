import 'package:flutter/material.dart';
import '../theme/app_unified_style.dart';
import '../../features/pass/presentation/pass_gate_helper.dart';

/// [홈 "상담" 카드 → "관상/손금" 통합 카드 교체] 관상/손금을 하나의 카드로
/// 합쳐 눌렀을 때 나타나는 선택 바텀시트.
///
/// 기존 `all_categories_screen.dart`의 "얼굴/손금" 그룹과 동일한 두 진입점
/// (오늘의 관상 → `/ai-fortune/face/capture`, 손금 → `/ai-fortune/palm/capture`)
/// 으로 연결하며, 각각 [navigateWithPassGate]를 그대로 재사용해 열림패스
/// 게이트(로그인 체크 → AccessChecker → PassProvider.consume())를 동일하게
/// 적용한다. 새 라우트/화면은 만들지 않는다(기존 face/palm capture 화면
/// 그대로 유지).
Future<void> showFacePalmSelectSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: UnifiedColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          left: UnifiedTokens.spaceXl,
          right: UnifiedTokens.spaceXl,
          top: UnifiedTokens.spaceLg,
          bottom: UnifiedTokens.spaceXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: UnifiedTokens.spaceLg),
                decoration: BoxDecoration(
                  color: UnifiedColors.border,
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
            ),
            Text('관상 · 손금 보기', style: UnifiedText.title()),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(
              '얼굴과 손에 담긴 이야기를 읽어보세요',
              style: UnifiedText.caption(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UnifiedTokens.spaceXl),
            Row(
              children: [
                Expanded(
                  child: _FacePalmOptionTile(
                    icon: Icons.face_outlined,
                    label: '오늘의 관상',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      navigateWithPassGate(
                        context,
                        title: '오늘의 관상',
                        route: '/ai-fortune/face/capture',
                        requiresPass: true,
                      );
                    },
                  ),
                ),
                const SizedBox(width: UnifiedTokens.spaceMd),
                Expanded(
                  child: _FacePalmOptionTile(
                    icon: Icons.back_hand_outlined,
                    label: '손금',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      navigateWithPassGate(
                        context,
                        title: '손금',
                        route: '/ai-fortune/palm/capture',
                        requiresPass: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _FacePalmOptionTile extends StatelessWidget {
  const _FacePalmOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: UnifiedColors.cardAllMenu,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(label, style: UnifiedText.bodyStrong()),
          ],
        ),
      ),
    );
  }
}
