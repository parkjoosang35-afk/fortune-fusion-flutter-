import 'package:flutter/material.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 두루마리(Scroll paper) 위젯.
///
/// `design_handoff/sigils.jsx`의 `Scroll({children, style})`을 Flutter로
/// 재구현. README `3. Compose Wish` 화면의 소원 작성 종이 배경으로 쓰인다.
///
/// 원본 스펙:
/// - background: linear-gradient(180deg, #f3e5c3 0%, #e8d5a3 100%)
/// - color(잉크): #3a2515 (WishRoomTextStyles.wishBodyPaper와 동일)
/// - padding: 24px 20px, borderRadius 4
/// - boxShadow: 0 4px 16px rgba(0,0,0,0.3), inset 0 0 40px rgba(139,90,43,0.15)
/// - 위/아래 나무 롤 가장자리(높이 12px, 그라디언트 #8b5a2b↔#4a2f15)
class WishRoomScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WishRoomScroll({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 위/아래 나무 롤이 종이 바깥으로 6px씩 삐져나오므로 형제 위젯과의
      // 충돌을 막기 위한 여유 공간.
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3E5C3), Color(0xFFE8D5A3)],
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: DecoratedBox(
              // inset 0 0 40px rgba(139,90,43,0.15) 근사 — 안쪽 가장자리를
              // 살짝 어둡게 해 종이 질감의 깊이감을 낸다.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x268B5A2B),
                    blurRadius: 40,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: child,
            ),
          ),
          // top scroll edge
          Positioned(
            top: -6,
            left: -8,
            right: -8,
            height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8B5A2B), Color(0xFF4A2F15)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // bottom scroll edge
          Positioned(
            bottom: -6,
            left: -8,
            right: -8,
            height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4A2F15), Color(0xFF8B5A2B)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
