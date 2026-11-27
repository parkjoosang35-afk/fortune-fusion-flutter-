import 'package:flutter/material.dart';

import '../oz_theme.dart';

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 3분할 툴바 버튼
/// (카드 섞기 / 다시 뽑기 / 되돌리기). CSS 대응: `<ToolButton>`(TarotApp.jsx).
class OzToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  const OzToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(OzTokens.radiusPill),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: disabled
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(OzTokens.radiusPill),
            border: Border.all(
              color: OzColors.goldDeep.withValues(alpha: disabled ? 0.25 : 0.55),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: disabled
                    ? OzColors.faint
                    : OzColors.gold,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: disabled ? OzColors.faint : OzColors.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
