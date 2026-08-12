import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';

/// 위기 감지 배너 — `03_FLUTTER_IMPL.md` CrisisBanner 전체 코드를 이식.
/// tel:1393(자살예방상담전화)로 바로 연결한다.
class WishCounselCrisisBanner extends StatelessWidget {
  const WishCounselCrisisBanner({super.key});

  Future<void> _call() async {
    final uri = Uri.parse('tel:1393');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WishCounselColors.crisisBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WishCounselColors.crisisBorder, width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.favorite,
            color: WishCounselColors.crisisBorder,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '혼자가 아니에요. 자살예방상담전화 1393과 24시간 연결돼 있어요.',
              style: WishCounselText.bodySmall(
                color: WishCounselColors.crisisText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _call,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: WishCounselColors.crisisBorder,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '1393 전화',
                style: WishCounselText.uiLabel(
                  color: const Color(0xFF3A1620),
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
