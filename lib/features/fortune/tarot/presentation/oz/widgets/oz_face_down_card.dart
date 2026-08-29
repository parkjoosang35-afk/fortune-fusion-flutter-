import 'package:flutter/material.dart';
import '../oz_category_illustrations.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨] 카드 뒷면(셔플/드로우 화면 공용). CSS 대응:
/// .oz-fan-card / .oz-fan-card.selected.
///
/// 실제 카드 정체는 이 위젯에서 절대 다루지 않는다(§10 설계 원칙 유지) -
/// 오직 [OzCategoryIllustrations.cardBack] 이미지 한 장만 보여준다.
/// [selected]가 true면 골드 글로우 테두리가 켜진다.
class OzFaceDownCard extends StatelessWidget {
  final double width;
  final double height;
  final bool selected;
  const OzFaceDownCard({
    super.key,
    this.width = 76,
    this.height = 118,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? OzColors.gold.withValues(alpha: 0.85)
              : OzColors.borderStrong,
          width: selected ? 1.6 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: OzColors.gold.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: OzColors.gold.withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ]
            : OzColors.cardElevation(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          OzCategoryIllustrations.cardBack,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A3378), Color(0xFF1A0F3D)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '✨',
              style: TextStyle(fontSize: width * 0.28, color: OzColors.gold),
            ),
          ),
        ),
      ),
    );
  }
}
