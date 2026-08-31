// ═══════════════════════════════════════════════════════════════
// FILE: sintong_button.dart
// PURPOSE: Primary / Ghost 버튼 (테마에도 등록되어 있지만 명시 위젯)
//
// 사용:
//   SintongPrimaryButton(label: '촬영 시작하기', icon: Icons.camera_alt, onPressed: ...)
//   SintongGhostButton(label: '갤러리에서 불러오기', icon: Icons.photo_library, onPressed: ...)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/sintong_colors.dart';
import '../theme/sintong_typography.dart';

class SintongPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const SintongPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: SintongColors.glowShadow,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SintongColors.glow,
          foregroundColor: SintongColors.fg,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: SintongColors.fg),
              const SizedBox(width: 8),
            ],
            Text(label, style: SintongType.button),
          ],
        ),
      ),
    );
  }
}

class SintongGhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const SintongGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: SintongColors.fg,
        minimumSize: const Size(double.infinity, 48),
        side: BorderSide(color: SintongColors.line, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: SintongColors.fg),
            const SizedBox(width: 8),
          ],
          Text(label, style: SintongType.button),
        ],
      ),
    );
  }
}
