// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper 디자인 핸드오프]
// 원본: design_handoff_saju_result.zip flutter_starter/ilgan_theme.dart
//
// 일간(日干) 10천간 각각의 컬러 테마(오행 5색 기반)를 단일 소스로
// 관리한다. 값은 원본과 100% 동일 — 이 프로젝트에 이미 존재하는
// `IlganType` 같은 이름이 없어(사전 grep 확인 완료) 이름 변경 없이
// 그대로 가져왔다.
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_tokens.dart';

/// 10천간(甲乙丙丁戊己庚辛壬癸).
enum IlganType { gap, eul, byeong, jeong, mu, gi, gyeong, sin, im, gye }

class IlganTheme {
  final IlganType type;
  final String hanja;
  final String hangul; // "갑목" 등
  final SajuDawnElement element;
  final String elementEn; // WOOD/FIRE/...
  final String symbolName; // "큰 나무의 사람"
  final Color main;
  final Color soft;
  final Color line;

  const IlganTheme({
    required this.type,
    required this.hanja,
    required this.hangul,
    required this.element,
    required this.elementEn,
    required this.symbolName,
    required this.main,
    required this.soft,
    required this.line,
  });

  static const map = <IlganType, IlganTheme>{
    IlganType.gap: IlganTheme(
      type: IlganType.gap,
      hanja: '甲',
      hangul: '갑목',
      element: SajuDawnElement.wood,
      elementEn: 'WOOD',
      symbolName: '큰 나무의 사람',
      main: Color(0xFF3E7A4C),
      soft: Color(0xFFE4EFD9),
      line: Color(0xFFA9C89B),
    ),
    IlganType.eul: IlganTheme(
      type: IlganType.eul,
      hanja: '乙',
      hangul: '을목',
      element: SajuDawnElement.wood,
      elementEn: 'WOOD',
      symbolName: '유연한 넝쿨의 사람',
      main: Color(0xFF6FB584),
      soft: Color(0xFFEEF7E5),
      line: Color(0xFFC4DDB4),
    ),
    IlganType.byeong: IlganTheme(
      type: IlganType.byeong,
      hanja: '丙',
      hangul: '병화',
      element: SajuDawnElement.fire,
      elementEn: 'FIRE',
      symbolName: '태양의 사람',
      main: Color(0xFFC4623E),
      soft: Color(0xFFFBE3D7),
      line: Color(0xFFE8A98A),
    ),
    IlganType.jeong: IlganTheme(
      type: IlganType.jeong,
      hanja: '丁',
      hangul: '정화',
      element: SajuDawnElement.fire,
      elementEn: 'FIRE',
      symbolName: '촛불의 사람',
      main: Color(0xFFD97B5A),
      soft: Color(0xFFFDECE3),
      line: Color(0xFFF0BFA5),
    ),
    IlganType.mu: IlganTheme(
      type: IlganType.mu,
      hanja: '戊',
      hangul: '무토',
      element: SajuDawnElement.earth,
      elementEn: 'EARTH',
      symbolName: '큰 산의 사람',
      main: Color(0xFF8B7040),
      soft: Color(0xFFF2E8D2),
      line: Color(0xFFD4BC8E),
    ),
    IlganType.gi: IlganTheme(
      type: IlganType.gi,
      hanja: '己',
      hangul: '기토',
      element: SajuDawnElement.earth,
      elementEn: 'EARTH',
      symbolName: '기름진 밭의 사람',
      main: Color(0xFFB89968),
      soft: Color(0xFFF7EFD9),
      line: Color(0xFFDFCA9F),
    ),
    IlganType.gyeong: IlganTheme(
      type: IlganType.gyeong,
      hanja: '庚',
      hangul: '경금',
      element: SajuDawnElement.metal,
      elementEn: 'METAL',
      symbolName: '강철 도끼의 사람',
      main: Color(0xFF6E6A62),
      soft: Color(0xFFEAE7E1),
      line: Color(0xFFBEBAAF),
    ),
    IlganType.sin: IlganTheme(
      type: IlganType.sin,
      hanja: '辛',
      hangul: '신금',
      element: SajuDawnElement.metal,
      elementEn: 'METAL',
      symbolName: '다듬어진 보석의 사람',
      main: Color(0xFF9B9086),
      soft: Color(0xFFF0EDE8),
      line: Color(0xFFCDC7BE),
    ),
    IlganType.im: IlganTheme(
      type: IlganType.im,
      hanja: '壬',
      hangul: '임수',
      element: SajuDawnElement.water,
      elementEn: 'WATER',
      symbolName: '큰 강의 사람',
      main: Color(0xFF3F6A8C),
      soft: Color(0xFFDDE8F0),
      line: Color(0xFF98B3C7),
    ),
    IlganType.gye: IlganTheme(
      type: IlganType.gye,
      hanja: '癸',
      hangul: '계수',
      element: SajuDawnElement.water,
      elementEn: 'WATER',
      symbolName: '이슬비의 사람',
      main: Color(0xFF618BAB),
      soft: Color(0xFFE7EFF5),
      line: Color(0xFFB0C6D3),
    ),
  };

  static IlganTheme of(IlganType type) => map[type]!;

  /// [실계산 연동 헬퍼] 기존 `saju_engine.dart`의 일간 한자 문자열
  /// ('甲'~'癸')을 그대로 받아 [IlganTheme]을 조회한다. 새 계산 없음 —
  /// 문자열 → enum 매핑 테이블 조회만 한다.
  static IlganTheme? ofHanja(String hanja) {
    for (final theme in map.values) {
      if (theme.hanja == hanja) return theme;
    }
    return null;
  }
}
