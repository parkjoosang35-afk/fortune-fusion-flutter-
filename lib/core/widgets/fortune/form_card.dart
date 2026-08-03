import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../premium_card.dart';

/// 재사용 위젯 ⑨ FormCard — 정보입력 화면의 입력 카드 컨테이너.
/// 배경 #F6F5FA(cardSection), radius16, padding14. 필드 간 세로 간격 12.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});

  final List<Widget> children;

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
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: UnifiedTokens.spaceMd),
            children[i],
          ],
        ],
      ),
    );
  }
}
