import 'package:flutter/material.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨] 골드 그라디언트 CTA 버튼. CSS 대응: .oz-primary-cta /
/// .oz-hero-card-cta.
///
/// README 금지사항 준수: 검은색 drop-shadow 대신 골드 글로우만 사용.
class OzPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final IconData? trailingIcon;
  const OzPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(OzTokens.radiusMd),
          onTap: enabled ? onPressed : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? OzColors.goldGradient
                  : const LinearGradient(
                      colors: [Color(0xFF4A3D63), Color(0xFF352A4D)],
                    ),
              borderRadius: BorderRadius.circular(OzTokens.radiusMd),
              boxShadow: enabled ? OzColors.goldGlow(alpha: 0.4, blur: 22) : null,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF2A1A08),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: OzTypography.ctaLabel(
                            color: enabled
                                ? const Color(0xFF2A1A08)
                                : OzColors.faint,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            trailingIcon,
                            size: 16,
                            color: enabled
                                ? const Color(0xFF2A1A08)
                                : OzColors.faint,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 작은 필(pill) 형태의 보조 골드 버튼(히어로 카드 CTA 등 컴팩트한 곳에 사용).
class OzPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const OzPillButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(OzTokens.radiusPill),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            gradient: OzColors.goldGradient,
            borderRadius: BorderRadius.circular(OzTokens.radiusPill),
            boxShadow: OzColors.goldGlow(alpha: 0.35, blur: 14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: OzTypography.ctaLabel(fontSize: 12.5)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  size: 14, color: Color(0xFF2A1A08)),
            ],
          ),
        ),
      ),
    );
  }
}
