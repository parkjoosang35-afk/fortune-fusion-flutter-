// ═══════════════════════════════════════════════════════════════
// FILE: sintong_guiin_cta.dart
// [귀인지도 메인 매핑] C-05 · GuiinCta — Handoff.html §06
// "♥ 귀인지도 만들기" 풀폭 버튼. height 48, bg rose #B04A5A, radius 14,
// shadow 0 6 18 rgba(rose,.28).
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../guinji_home_tokens.dart';

class GuinjiGuiinCta extends StatelessWidget {
  const GuinjiGuiinCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GuinjiHomeColors.rose,
          borderRadius: BorderRadius.circular(GuinjiHomeRadii.md + 2),
          boxShadow: [
            BoxShadow(
              color: GuinjiHomeColors.rose.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '♥',
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text('귀인지도 만들기', style: GuinjiHomeText.cta),
          ],
        ),
      ),
    );
  }
}
