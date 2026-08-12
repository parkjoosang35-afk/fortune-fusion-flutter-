import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../domain/wish_wall_models.dart';

/// 인장(Seal) — 옛 "신통방통 소원방"(wish_room) 작성 화면의 핵심 모티프.
///
/// [디자인 히스토리] 옛 소원방은 소원을 두루마리에 적고 願/合/康/福/緣/財/成
/// 7종 인장 중 하나로 "봉인"하는 서사를 가졌다. 지금의 소원벽(유리병)은
/// 카테고리 체계가 다르지만(9개), 같은 인장 언어를 각 카테고리에 매핑해
/// 그 서사를 되살린다. 회전 -6도 + 도장 그림자는 원본과 동일하게 유지.
class WishWallSeal extends StatelessWidget {
  const WishWallSeal({
    super.key,
    this.text = '願',
    this.color = const Color(0xFFC94A3B),
    this.size = 44,
  });

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.53),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            fontWeight: FontWeight.w900,
            fontSize: size * 0.55,
            color: const Color(0xFFFFF9E8),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 9개 소원 카테고리 → 인장 한자 매핑(옛 소원방 7종 인장 어휘를 그대로 살려
/// 카테고리별로 매핑하고, 부족한 2종은 같은 한자 조어 방식으로 보충했다).
extension WishCategorySealX on WishCategory {
  String get sealChar {
    switch (this) {
      case WishCategory.exam:
        return '願'; // 바람
      case WishCategory.job:
        return '成'; // 성취
      case WishCategory.money:
        return '財'; // 재물
      case WishCategory.love:
        return '緣'; // 인연
      case WishCategory.family:
        return '合'; // 화합
      case WishCategory.health:
        return '康'; // 건강
      case WishCategory.travel:
        return '行'; // 여정
      case WishCategory.growth:
        return '勉'; // 정진
      case WishCategory.etc:
        return '福'; // 복
    }
  }

  String get sealName {
    switch (this) {
      case WishCategory.exam:
        return '바람';
      case WishCategory.job:
        return '성취';
      case WishCategory.money:
        return '재물';
      case WishCategory.love:
        return '인연';
      case WishCategory.family:
        return '화합';
      case WishCategory.health:
        return '건강';
      case WishCategory.travel:
        return '여정';
      case WishCategory.growth:
        return '정진';
      case WishCategory.etc:
        return '복';
    }
  }
}
