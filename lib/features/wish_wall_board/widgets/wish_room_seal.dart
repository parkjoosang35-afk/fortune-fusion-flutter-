import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 도장/스탬프(Seal) 위젯.
///
/// `design_handoff/sigils.jsx`의 `Seal({text, color, size})`를 그대로
/// Flutter 위젯으로 재구현. 願(소원)/合(합격)/康(건강)/福(복)/緣(인연)/
/// 財(재물) 등 한자 글리프를 -6deg 회전한 정사각 스탬프 형태로 표시한다.
///
/// README: 36×36(피커), 44×44(리스트), accent 색 배경, Noto Serif KR 900
/// 흰 텍스트(55% 크기), radius 6, box-shadow `0 2px 8px {accent}88, inset 0
/// 0 4px rgba(0,0,0,0.2)`.
class WishRoomSeal extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final bool selected;

  const WishRoomSeal({
    super.key,
    this.text = '願',
    this.color = WishRoomColors.accent,
    this.size = 44,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * 3.1415926535 / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.53), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'NotoSerifKRWish',
            fontWeight: FontWeight.w900,
            fontSize: size * 0.55,
            color: const Color(0xFFFFF9E8),
            shadows: const [
              Shadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// README Compose 화면의 소원 도장 종류(願/合/康/福/緣/財)를 하나의 enum으로
/// 정의해, Compose 화면의 도장 선택기(seal picker)와 Detail/Feed 화면의
/// 도장 표시가 동일한 색/의미 매핑을 공유하도록 한다.
enum WishSeal { wish, pass, health, fortune, bond, wealth }

extension WishSealX on WishSeal {
  String get glyph {
    switch (this) {
      case WishSeal.wish:
        return '願';
      case WishSeal.pass:
        return '合';
      case WishSeal.health:
        return '康';
      case WishSeal.fortune:
        return '福';
      case WishSeal.bond:
        return '緣';
      case WishSeal.wealth:
        return '財';
    }
  }

  String get label {
    switch (this) {
      case WishSeal.wish:
        return '소원';
      case WishSeal.pass:
        return '합격';
      case WishSeal.health:
        return '건강';
      case WishSeal.fortune:
        return '복';
      case WishSeal.bond:
        return '인연';
      case WishSeal.wealth:
        return '재물';
    }
  }
}
