// 신통방통 정통사주 v3 — 화면 바인딩용 디자인 토큰
// 출처: 엔진 킷 flutter_integration/design_system.md (먹·금·자수정 팔레트, 오행 색)
// 앱 테마(Dawn Hanji)와 병행 사용 — 이 파일은 v3 신규 화면 전용 로컬 토큰.
// [Option 2 이식] 원본과 동일 - riverpod/dio 의존 없는 순수 Material 토큰이라
// 변경 없이 그대로 복사했다.

import 'package:flutter/material.dart';

class Jt3Colors {
  static const inkBlack = Color(0xFF0A0A0F);
  static const deepNight = Color(0xFF12121A);
  static const charcoal = Color(0xFF1E1E28);
  static const royalGold = Color(0xFFD4AF37);
  static const antiqueGold = Color(0xFFB8860B);
  static const softGold = Color(0xFFF5DEB3);
  static const amethyst = Color(0xFF6B4E9E);
  static const starWhite = Color(0xFFF8F5E6);
  static const moonSilver = Color(0xFFC0C0C8);

  static const elementColors = <String, Color>{
    '목': Color(0xFF2E7D32),
    '화': Color(0xFFC62828),
    '토': Color(0xFF8D6E1E),
    '금': Color(0xFFBFA76A),
    '수': Color(0xFF1565C0),
  };

  static Color element(String el) => elementColors[el] ?? moonSilver;
}

class Jt3Radii {
  static const card = 16.0;
  static const chip = 999.0;
  static const button = 12.0;
}
