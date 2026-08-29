import 'package:flutter/material.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨] 공용 필터/토픽 칩. CSS 대응: .oz-chip / .oz-chip.active.
///
/// 화면02(THEME LIST)의 그룹 필터, 화면04(ASK)의 토픽 선택 등 여러
/// 화면에서 공유하는 알약형 칩.
class OzChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const OzChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(OzTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x26F5D98A) : OzColors.card,
          borderRadius: BorderRadius.circular(OzTokens.radiusPill),
          border: Border.all(
            color: selected
                ? OzColors.gold.withValues(alpha: 0.5)
                : OzColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: OzTypography.body(
            fontSize: 12.5,
            color: selected
                ? OzColors.gold
                : OzColors.fg.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}
