// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper 디자인 핸드오프]
// 원본: design_handoff_saju_result.zip flutter_starter/saju_tokens.dart
//
// [naming collision 회피] 기존 프로젝트에 이미 `HanjiColors`
// (jeontong_design/hanji_design_tokens.dart, 정통사주 결과 화면의 세부
// 상세 위젯 13개가 참조 중)가 존재하므로, 이 파일은 완전히 새 이름
// (`SajuDawn*`)으로 격리한다. 값 자체는 원본 saju_tokens.dart의
// SajuColors/SajuSpacing/SajuRadius/SajuText/SajuMotion과 100% 동일하되,
// 클래스 이름만 `SajuDawn` 접두어를 붙였다 — 원본 클래스명(`SajuColors`
// 등)을 그대로 쓰면 이후 프로젝트 다른 곳에서 `Saju` 접두 클래스가
// 추가될 때 충돌 위험이 있어 선제적으로 방지한다.
//
// [폰트] fontFamily 'NotoSerifKR'은 pubspec.yaml에 이미 등록되어 있다
// (Bold 700/Black 900 — 관상·손금 신통방통 리스킨에서 먼저 등록됨).
// 이 파일이 참조하는 weight(w700/w900)와 정확히 일치해 새 폰트 asset을
// 추가하지 않고 그대로 재사용한다.
// ============================================================

import 'package:flutter/material.dart';

/// Dawn Paper 팔레트 — 정통사주 결과 화면(壹~柒 챕터 구조) 전용.
class SajuDawnColors {
  SajuDawnColors._();

  // Backgrounds
  static const bg = Color(0xFFF5EDD8); // 크림 배경
  static const bg2 = Color(0xFFEFE4C9);
  static const paper = Color(0xFFFFFAEE); // 카드 배경
  static const paper2 = Color(0xFFFBF3DD);
  static const line = Color(0xFFE4D2AC); // 테두리
  static const line2 = Color(0xFFD4BC8E);

  // Text
  static const ink = Color(0xFF2A2118); // 본문
  static const ink2 = Color(0xFF5B4A36); // 서브
  static const ink3 = Color(0xFF8B7355); // 캡션
  static const ink4 = Color(0xFFB8A582); // 가장 흐린

  // Brand accents
  static const brown = Color(0xFF8B6F47); // 命 배지
  static const brownDeep = Color(0xFF5F4A2E);
  static const terracotta = Color(0xFFB85838); // 忌 · 경고
  static const gold = Color(0xFFB89968);
  static const goldDeep = Color(0xFF8B7040);

  // 오행(五行) — 고정
  static const wood = Color(0xFF4A8F5C);
  static const fire = Color(0xFFC4623E);
  static const earth = Color(0xFFB89968);
  static const metal = Color(0xFF8B857E);
  static const water = Color(0xFF3F6A8C);

  /// [재계산 금지 원칙] 기존 `saju_engine.dart`/`SajuProfile` 등이 이미
  /// 한글('목'/'화'/'토'/'금'/'수') 또는 한자('木'/'火'/'土'/'金'/'水')로
  /// 오행을 반환하므로, 이 팔레트에서도 문자열 → 색상 조회 함수를 함께
  /// 제공한다(HanjiColors.wuxingColor와 동일한 시그니처 — 새 enum 변환
  /// 계층을 추가하지 않고 기존 문자열 값을 그대로 조회).
  static Color wuxingColor(String? el) {
    switch (el) {
      case '목':
      case '木':
        return wood;
      case '화':
      case '火':
        return fire;
      case '토':
      case '土':
        return earth;
      case '금':
      case '金':
        return metal;
      case '수':
      case '水':
        return water;
      default:
        return earth;
    }
  }
}

/// 오행 enum — 순수 표시용 레이블 헬퍼(§ 재계산 금지, 데이터 소스가 아님).
enum SajuDawnElement { wood, fire, earth, metal, water }

extension SajuDawnElementX on SajuDawnElement {
  Color get color {
    switch (this) {
      case SajuDawnElement.wood:
        return SajuDawnColors.wood;
      case SajuDawnElement.fire:
        return SajuDawnColors.fire;
      case SajuDawnElement.earth:
        return SajuDawnColors.earth;
      case SajuDawnElement.metal:
        return SajuDawnColors.metal;
      case SajuDawnElement.water:
        return SajuDawnColors.water;
    }
  }

  String get hanja {
    switch (this) {
      case SajuDawnElement.wood:
        return '木';
      case SajuDawnElement.fire:
        return '火';
      case SajuDawnElement.earth:
        return '土';
      case SajuDawnElement.metal:
        return '金';
      case SajuDawnElement.water:
        return '水';
    }
  }

  String get hangul {
    switch (this) {
      case SajuDawnElement.wood:
        return '목';
      case SajuDawnElement.fire:
        return '화';
      case SajuDawnElement.earth:
        return '토';
      case SajuDawnElement.metal:
        return '금';
      case SajuDawnElement.water:
        return '수';
    }
  }
}

/// 폰트 패밀리 상수.
class SajuDawnFonts {
  SajuDawnFonts._();
  static const sans = 'Pretendard';
  static const serif = 'NotoSerifKR';
}

/// 스페이싱 스케일(dp).
class SajuDawnSpacing {
  SajuDawnSpacing._();
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const xl = 26.0;

  static const screenPadding = 22.0;
  static const cardPadding = 20.0;
  static const cardGap = 10.0;
}

/// Border Radius.
class SajuDawnRadius {
  SajuDawnRadius._();
  static const cell = 10.0;
  static const button = 14.0;
  static const small = 16.0;
  static const card = 18.0;
  static const large = 20.0;
  static const pill = 999.0;
}

/// 타이포 스타일.
class SajuDawnText {
  SajuDawnText._();

  static const heroTitle = TextStyle(
    fontFamily: SajuDawnFonts.serif,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -1.19,
    color: SajuDawnColors.ink,
  );

  static const chapterTitle = TextStyle(
    fontFamily: SajuDawnFonts.serif,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.34,
    color: SajuDawnColors.ink,
  );

  static const cardTitle = TextStyle(
    fontFamily: SajuDawnFonts.serif,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.15,
    color: SajuDawnColors.ink,
  );

  static const storyBody = TextStyle(
    fontFamily: SajuDawnFonts.sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.85,
    letterSpacing: -0.07,
    color: SajuDawnColors.ink2,
  );

  static const cardBody = TextStyle(
    fontFamily: SajuDawnFonts.sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.65,
    color: SajuDawnColors.ink2,
  );

  static const metaChip = TextStyle(
    fontFamily: SajuDawnFonts.sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.23,
    color: SajuDawnColors.ink2,
  );

  static const caption = TextStyle(
    fontFamily: SajuDawnFonts.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
    color: SajuDawnColors.ink3,
  );

  static const pillarHanja = TextStyle(
    fontFamily: SajuDawnFonts.serif,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1,
    color: SajuDawnColors.ink,
  );

  static const ilganHanja = TextStyle(
    fontFamily: SajuDawnFonts.serif,
    fontSize: 52,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: -1.04,
  );
}

/// 애니메이션 duration/easing.
class SajuDawnMotion {
  SajuDawnMotion._();

  static const brushInDuration = Duration(milliseconds: 900);
  static const brushInDelay = Duration(milliseconds: 300);
  static const cellRevealDuration = Duration(milliseconds: 500);
  static const cellStaggerGap = Duration(milliseconds: 80);
  static const barGrowDuration = Duration(milliseconds: 1100);
  static const barStartDelay = Duration(milliseconds: 100);
  static const barStaggerGap = Duration(milliseconds: 120);
  static const sectionRevealDuration = Duration(milliseconds: 600);
  static const topbarTransition = Duration(milliseconds: 300);
  static const tooltipAutoDismiss = Duration(milliseconds: 2400);

  /// cubic-bezier(.2, .7, .2, 1) 근사치.
  static const easeMain = Cubic(0.2, 0.7, 0.2, 1);
}
