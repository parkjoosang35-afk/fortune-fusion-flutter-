import 'package:flutter/material.dart';

/// 신당(THE SHRINE) v3 디자인 토큰 — README.md §9 공식 hex 값을 그대로 사용한다.
/// (주의: prototype/colors_and_type.css는 더 오래된 소원방 팔레트라 이 값과
/// 다르다 — shrine_v3는 이 파일만을 기준으로 한다.)
class ShrineV3Colors {
  ShrineV3Colors._();

  static const paper = Color(0xFFFAF3E0);
  static const paperDark = Color(0xFFEFE4C8);
  static const ink = Color(0xFF1F150C);
  static const ink2 = Color(0xFF4A3A2A);
  static const ink3 = Color(0xFF7A6852);
  static const seal = Color(0xFF8B2F22);
  static const jade = Color(0xFF2F7A5A);
  static const line = Color(0xFFE3D7BC);
  static const card = Color(0xFFFFFCF4);
  static const gold = Color(0xFFE9C27A);
  static const goldDeep = Color(0xFFD6AA64);
}

class ShrineV3TextStyles {
  ShrineV3TextStyles._();

  static const title = TextStyle(
    fontFamily: 'NotoSerifKR',
    fontWeight: FontWeight.w900,
    color: ShrineV3Colors.ink,
  );

  static const body = TextStyle(
    fontFamily: 'GowunBatang',
    fontWeight: FontWeight.w700,
    color: ShrineV3Colors.ink2,
  );

  static const ui = TextStyle(
    fontFamily: 'Pretendard',
    fontWeight: FontWeight.w600,
    color: ShrineV3Colors.ink2,
  );

  static const mono = TextStyle(
    fontFamily: 'IBMPlexMono',
    fontWeight: FontWeight.w600,
    color: ShrineV3Colors.ink3,
    letterSpacing: 0.5,
  );
}

/// 9개 카테고리별 포인트 컬러(프로토타입 `.k-xxx` 클래스가 쓰는 색감을
/// Material 근사치로 옮긴 값 — 카드 틴트/강조선 등에 사용).
const Map<String, Color> kShrineCategoryTints = {
  'wealth': Color(0xFFD9A441),
  'biz': Color(0xFF5A7FB8),
  'love': Color(0xFFD8607D),
  'harmony': Color(0xFF6FA86B),
  'exam': Color(0xFF7A6CC2),
  'suneung': Color(0xFF7A6CC2),
  'health': Color(0xFF4FA8A0),
  'ward': Color(0xFF8B2F22),
  'wish': Color(0xFFD6AA64),
};

const Map<String, String> kShrineCategoryLabels = {
  'wealth': '재물',
  'biz': '사업 · 일',
  'love': '인연 · 사랑',
  'harmony': '화합 · 가정',
  'exam': '학업 · 목표',
  'suneung': '수능 · 합격',
  'health': '건강 · 평안',
  'ward': '액막이 · 수호',
  'wish': '소원 · 개운',
};

/// README §4-1 소망 최대 길이.
const int kShrineWishMaxLength = 40;

/// §6 唯一 수명/향 올리기 상수(화면단 표시 용도 — 실제 계산은 전부 서버가
/// 담당하고, 서버 응답의 daysRemaining/expiresDateKey를 그대로 표시한다).
const int kShrineLifeDays = 49;
const int kShrineIncenseBonusDays = 3;
