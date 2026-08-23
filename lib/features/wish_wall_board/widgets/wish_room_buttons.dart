import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용] `wish-screens.jsx` 공통 스타일 객체
/// (`btnPrimary`/`btnGhost`/`btnSecondary`/`iconBtn`/`pill`)을 그대로
/// Flutter 위젯으로 재구현한 공용 버튼/칩 세트. 8개 화면 전체가 공유한다.
///
/// 원본 스펙(주석에 픽셀값 그대로 유지):
/// - btnPrimary: width 100%, padding 15px 20px, radius 14, bg var(--glow),
///   color #2a1a0a, Gowun Batang 700 15px, boxShadow(글로우+inset 하이라이트)
/// - btnGhost: width 100%, padding 13px 20px, radius 14, transparent,
///   color var(--muted), Gowun Batang 400 13px, border 1px var(--line)
/// - btnSecondary: padding 12px 16px, radius 12, bg var(--card),
///   color var(--fg), Gowun Batang 700 13px, border 1px var(--line)
/// - iconBtn: 36x36, radius 18, bg var(--card), border 1px var(--line),
///   fontSize 16
/// - pill: padding 4px 10px, radius 999, bg var(--glow-shadow),
///   color var(--glow), fontSize 11, border 1px var(--glow)
class WishRoomPrimaryButton extends StatelessWidget {
  const WishRoomPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: disabled
            ? WishRoomColors.glow.withValues(alpha: 0.4)
            : WishRoomColors.glow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: WishRoomColors.glowShadow,
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  Text(leading!, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF2A1A0A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WishRoomGhostButton extends StatelessWidget {
  const WishRoomGhostButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          side: const BorderSide(color: WishRoomColors.surfaceCardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'GowunBatangWish',
            fontWeight: FontWeight.w400,
            fontSize: 13,
            color: WishRoomColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class WishRoomSecondaryButton extends StatelessWidget {
  const WishRoomSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WishRoomColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WishRoomColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'GowunBatangWish',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: WishRoomColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class WishRoomIconButton extends StatelessWidget {
  const WishRoomIconButton({
    super.key,
    required this.icon,
    this.onPressed,
  });

  final String icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WishRoomColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: WishRoomColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(
                fontSize: 16,
                color: WishRoomColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WishRoomPill extends StatelessWidget {
  const WishRoomPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WishRoomColors.glowShadow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WishRoomColors.glow),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'GowunBatangWish',
          fontSize: 11,
          color: WishRoomColors.glow,
        ),
      ),
    );
  }
}
