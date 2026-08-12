import 'package:flutter/material.dart';

/// 한지 두루마리(Scroll) — 옛 "신통방통 소원방"(wish_room) 작성 화면에서
/// 소원 본문을 적던 컨테이너.
///
/// [디자인 히스토리] "마음속 바람을 두루마리에 적어요"라는 옛 소원방의
/// 작성 서사를 그대로 이식한다. 한지색 그라디언트는 다크 톤 전환과 무관하게
/// 고정값을 유지한다(두루마리 자체가 밝은 종이 질감이어야 자연스럽다).
class WishWallScroll extends StatelessWidget {
  const WishWallScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5C3), Color(0xFFE8D5A3)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: 'GowunBatangWish',
          color: Color(0xFF3A2515),
        ),
        child: child,
      ),
    );
  }
}
