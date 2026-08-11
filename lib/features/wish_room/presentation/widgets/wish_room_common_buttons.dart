import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 공통 버튼/필 스타일.
///
/// `wish-screens.jsx` 하단 "공통 스타일" 섹션(btnPrimary/btnGhost/
/// btnSecondary/iconBtn/pill)을 Flutter 위젯으로 재구현. 8개 화면 전반에서
/// 재사용해 시각적 일관성을 보장한다.

/// btnPrimary: width 100%, padding 15px 20px, radius 14, glow 배경,
/// #2a1a0a 텍스트, Gowun Batang 700 15px, boxShadow glow-shadow + inset.
class WishRoomPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  const WishRoomPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: WishRoomColors.glow,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: WishRoomColors.glowShadow,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(label, style: WishRoomTextStyles.buttonLabel.copyWith(
              color: const Color(0xFF2A1A0A),
            )),
          ],
        ),
      ),
    );
  }
}

/// btnGhost: transparent 배경, border 1px line, muted 텍스트 13px.
class WishRoomGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const WishRoomGhostButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: WishRoomTextStyles.pillLabel.copyWith(
            fontSize: 13,
            color: WishRoomColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// btnSecondary: card 배경, radius 12, 13px 700.
class WishRoomSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const WishRoomSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: WishRoomTextStyles.buttonLabel.copyWith(
            fontSize: 13,
            color: WishRoomColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// iconBtn: 36px 원형, card 배경, border line.
class WishRoomIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;

  const WishRoomIconButton({super.key, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TapBounce(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: WishRoomColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        child: icon,
      ),
    );
  }
}

/// pill: padding 4px 10px, radius 999, glow-shadow 배경, glow 텍스트,
/// border glow, 11px.
class WishRoomPill extends StatelessWidget {
  final String label;

  const WishRoomPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WishRoomColors.glowShadow,
        borderRadius: BorderRadius.circular(WishRoomRadius.pill),
        border: Border.all(color: WishRoomColors.glow),
      ),
      child: Text(
        label,
        style: WishRoomTextStyles.pillLabel.copyWith(
          fontSize: 11,
          color: WishRoomColors.glow,
        ),
      ),
    );
  }
}
