import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// [Fortune Fusion 서브 디자인 통일 마스터 프롬프트] 원형 액션 버튼
///
/// 기준 시안의 카드 우측 상단에 겹쳐지는 원형 아이콘 버튼(네온라임/블랙 채움 +
/// 화이트 아이콘)을 공통화한다. 정보 더보기, 펼침/접힘, 이동 등의 소형 액션에
/// 사용한다.
enum PremiumCircleButtonStyle { neon, black, lavender }

class PremiumCircleButton extends StatefulWidget {
  const PremiumCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.style = PremiumCircleButtonStyle.neon,
    this.size = 32,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final PremiumCircleButtonStyle style;
  final double size;

  @override
  State<PremiumCircleButton> createState() => _PremiumCircleButtonState();
}

class _PremiumCircleButtonState extends State<PremiumCircleButton> {
  bool _pressed = false;

  ({Color bg, Color fg}) get _colors {
    switch (widget.style) {
      case PremiumCircleButtonStyle.neon:
        return (bg: AppColors.premiumNeonLime, fg: AppColors.premiumNeonLimeOnColor);
      case PremiumCircleButtonStyle.black:
        return (bg: AppColors.premiumBlackCta, fg: Colors.white);
      case PremiumCircleButtonStyle.lavender:
        return (bg: AppColors.premiumSoftLavender, fg: AppColors.premiumDeepNavy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
          child: Icon(widget.icon, size: widget.size * 0.5, color: c.fg),
        ),
      ),
    );
  }
}
