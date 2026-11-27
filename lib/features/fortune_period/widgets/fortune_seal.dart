/// [기간별 운세 — Seal(인장) 포팅]
///
/// `sigils.jsx`의 `Seal` 컴포넌트(회전된 사각 도장, 한자 1글자)를 그대로
/// 포팅한다. `core/theme/legacy_wish_room/wish_room_seal.dart`의
/// `WishRoomSeal`과 구조가 같지만(둘 다 `text`/`color`/`size` 파라미터로
/// 자유로운 인장을 그림), feature 간 결합을 피하기 위해 `fortune_period`
/// 전용으로 별도 위젯을 둔다.
///
/// 사용되는 글자(seal text)는 서버 `FortunePayload.seal`로 결정되며
/// (예: 吉/平/新/改/神/週/月 등), 이 위젯은 글자 자체를 하드코딩하지
/// 않는다.
library;

import 'package:flutter/material.dart';
import '../theme/fortune_period_theme.dart';

class FortuneSeal extends StatelessWidget {
  const FortuneSeal({
    super.key,
    required this.text,
    this.color,
    this.size = 44,
  });

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? FortunePeriodColors.accent;
    return Transform.rotate(
      angle: -6 * 3.1415926535 / 180,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.53),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: FortunePeriodType.serif,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.55,
            color: const Color(0xFFFFF9E8),
            shadows: const [
              Shadow(
                color: Color(0x4D000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
