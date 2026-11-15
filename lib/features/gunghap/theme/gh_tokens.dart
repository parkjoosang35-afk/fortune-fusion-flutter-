// ═══════════════════════════════════════════════════════════════
// FILE: gh_tokens.dart
// [궁합지도 전면 리디자인 — 2026-11 2차 핸드오프] design_handoff_
// gunghap_map.zip `00_DEV_MAPPING.md` §2(디자인 토큰) 반영.
//
// 기존 "Celestial Navy"(네이비×골드) 팔레트를 핸드오프가 확정한
// "화이트×핑크/바이올렛" 팔레트로 전면 교체한다.
//
// 하위 호환 원칙: 기존 화면(아직 재작성 전)이 참조하는 토큰 "이름"
// (bg1/bg2/gold/ivory/gray 등)은 그대로 유지하고 **값만** 교체한다.
// 이렇게 하면 gh_button.dart/gh_screen.dart/star_map.dart 등 이번
// 세션에서 아직 재작성하지 않은 기존 화면도 코드 변경 없이 새
// 색상이 즉시 반영되어, "다크 배경 + 라이트 텍스트" → "화이트 배경
// + 다크 텍스트"로 일관되게 전환된다(개별 화면 재작성 전에도 글자가
// 보이지 않는 상태가 되지 않는다).
//
// 새 디자인 문서(§2)가 쓰는 이름(accent/fg/muted/line 등)은 앞으로
// 작성할 신규 위젯이 바로 쓸 수 있도록 **별도 상수로 추가**했다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

abstract final class GHColors {
  // ── §2-1 색상 (화이트 테마) — 기존 토큰 이름 유지, 값만 교체 ──
  static const bg2 = Color(0xFFFAF8FC); // 화면 베이스
  static const bg1 = Color(0xFFFFFFFF); // 상단 / 카드
  static const cardSolid = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const gold = Color(0xFFE0668A); // accent — 강조 글씨·선택 테두리·탭 활성·링크
  static const goldLight = Color(0xFFEC8AA6); // 보조 강조·하단바 점
  static const goldDark = Color(0xFFB76BD0); // 그라데이션 끝
  static const violet = Color(0xFF8B6FD8); // 보조 포인트
  static const violetText = Color(0xFF7A5FC8); // 보라 글씨
  static const violetTextLight = Color(0xFFE6DAFF); // violet 버튼 글씨 그라데이션 시작색
  static const ivory = Color(0xFF1E1730); // fg — 본문
  static const gray = Color(0xFF453D5C); // muted — 보조 글씨
  static const divider = Color(0xFFE6DDEB);
  static const lineSoft = Color(0x4D2A2140); // rgba(42,33,64,.30) — 기본 박스 테두리
  static const mint = Color(0xFF3FA884); // 긍정·강점·완료
  static const rose = Color(0xFFE05A6E); // 경고·살펴볼 부분·오류
  static const ink = Color(0xFFFFFFFF); // 포인트(그라데이션) 배경 위 글씨 — 흰색
  static const glowShadow = Color(0x52E0668A); // rgba(224,102,138,.32)
  static const kakao = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF191600);
  static const scrim = Color(0xB3080C1A); // rgba(8,12,26,.70) — 바텀시트 딤(= dim)

  // ── 신규 토큰(§2-1) ──
  static const line = Color(0x8CE0668A); // rgba(224,102,138,.55) — 강조 테두리
  static const fieldBg = Color(0xFFF3EDF8); // 세그먼트·보조 박스·아이콘 박스
  static const track = Color(0xFFEEE7F4); // 점수 원/막대 트랙
  static const dim = scrim; // 바텀시트 딤(이름만 스펙과 통일)
  static const meInk = Color(0xFFFF5C93); // 인연지도 「나」 전용
  static const introBorder = Color(0x73E0668A); // rgba(224,102,138,.45) — 「궁합지도」 버튼 테두리
  static const introText = Color(0xFFC2416E); // 「궁합지도」 버튼 글씨

  // ── §2 스펙 명칭 별칭(신규 위젯 작성 시 사용 권장) ──
  static const accent = gold;
  static const fg = ivory;
  static const muted = gray;

  // ── §2-2 오행 색 ──
  static const elementWood = Color(0xFF10B981); // 木
  static const elementFire = Color(0xFFF43F5E); // 火
  static const elementEarth = Color(0xFFF59E0B); // 土
  static const elementMetal = Color(0xFF64748B); // 金
  static const elementWater = Color(0xFF3B82F6); // 水

  // 오행 관계색 (RelationSheet) — 生 · 比 · 剋
  static const relGenerate = gold; // 生 #E0668A
  static const relSame = ivory; // 比 #1E1730
  static const relOvercome = violetText; // 剋 #7A5FC8
}

/// §2-4 대분류 8종 아이콘 색(c1, c2) — CatIcon · 대분류 카드 그라데이션 등에 사용.
abstract final class GHCatColors {
  static const Map<String, List<Color>> byKind = {
    'heart': [Color(0xFFFF4D8D), Color(0xFFFF9A8B)], // love
    'ring': [Color(0xFFF59E0B), Color(0xFFFB7185)], // marriage
    'linked': [Color(0xFFEC4899), Color(0xFF8B5CF6)], // intimacy
    'moons': [Color(0xFF6366F1), Color(0xFF22D3EE)], // persona
    'gem': [Color(0xFFF59E0B), Color(0xFFEAB308)], // wealth
    'rise': [Color(0xFF0EA5E9), Color(0xFF6366F1)], // business
    'friends': [Color(0xFF10B981), Color(0xFF22D3EE)], // friend
    'family': [Color(0xFFF97316), Color(0xFFEC4899)], // family
  };
  static List<Color> of(String kind) =>
      byKind[kind] ?? const [GHColors.gold, GHColors.violet];
}

abstract final class GHGradients {
  /// 135° #F07A9C → #E0668A → #B76BD0 — 주 버튼·프리미엄 배지·번호 배지
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF07A9C), Color(0xFFE0668A), Color(0xFFB76BD0)],
    stops: [0, .5, 1],
  );

  /// 180° #F4F0F8 → #FFFFFF — 바텀시트 배경
  static const sheet = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4F0F8), Color(0xFFFFFFFF)],
  );

  /// 135° #E0668A → #B76BD0 — 텍스트 전용(ShaderMask로 적용), 결과 세부명
  static const title = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0668A), Color(0xFFB76BD0)],
  );

  /// 145° #FFF0F5 → #F3ECFF — S01 「궁합지도」 버튼 배경
  static const intro = LinearGradient(
    begin: Alignment(-0.8, -1),
    end: Alignment(0.8, 1),
    colors: [Color(0xFFFFF0F5), Color(0xFFF3ECFF)],
  );

  /// 화면 상단 320px 배경 워시 — radial 핑크 10% + 라벤더 9% (gradBg)
  static const backdropPink = RadialGradient(
    center: Alignment(-0.4, -0.6),
    radius: 1.0,
    colors: [Color(0x1AEC8AA6), Color(0x00EC8AA6)],
  );
  static const backdropLavender = RadialGradient(
    center: Alignment(0.5, -0.8),
    radius: 1.0,
    colors: [Color(0x178B6FD8), Color(0x008B6FD8)],
  );
}

/// 기존 이름 유지(back-compat) — [GHGradients.primary]와 동일.
const ghGoldGradient = GHGradients.primary;

abstract final class GHSpace {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0;
  static const s8 = 32.0, s10 = 40.0;
  // §2-6 간격
  static const screenH = 20.0; // 화면 좌우
  static const sectionGap = 30.0; // 섹션 간 (28~34)
  static const cardGap = 10.0; // 카드 간
  static const cardPad = 16.0; // 카드 패딩 (14~18)
  static const fieldGap = 22.0; // 필드 간
  // §2-6 높이
  static const appBar = 56.0;
  static const statusBar = 47.0;
  static const inputHeight = 54.0;
  static const segmentHeight = 42.0;
  static const segmentHeightLg = 46.0;
  static const bottomNavTop = 8.0;
  static const bottomNavContent = 52.0;
  static const bottomNavBottom = 26.0;
  static const minTouch = 44.0;
}

abstract final class GHRadius {
  static const button = 16.0;
  static const input = 16.0;
  static const card = 20.0; // 카드 18~20
  static const cardSm = 18.0;
  static const imageCard = 18.0;
  static const hero = 24.0;
  static const sheet = 24.0; // 시트 상단
  static const segment = 16.0;
  static const segmentItem = 12.0;
  static const chip = 999.0;
  static const sealSquare = 8.0; // 분야 네모(CatIcon 카드)
  static const iconBtn = 20.0; // 40×40 원
}

abstract final class GHButtonSize {
  static const xl = 58.0, lg = 54.0, md = 48.0, sm = 40.0;
}

abstract final class GHMotion {
  // 기존 이름(back-compat)
  static const screen = Duration(milliseconds: 450); // screenIn
  static const sheet = Duration(milliseconds: 400); // sheetUp
  static const sheetCurve = Cubic(0.22, 1, 0.36, 1);
  static const press = Duration(milliseconds: 180);
  static const lineSegment = Duration(milliseconds: 550);
  static const lineStagger = Duration(milliseconds: 220);
  static const ringRevolution = Duration(seconds: 180);
  static const pulse = Duration(milliseconds: 2400); // loadPulse
  static const loadingTotal = Duration(milliseconds: 5100);

  // §2-7 신규
  static const cardIn = Duration(milliseconds: 500);
  static const cardInStagger = Duration(milliseconds: 50);
  static const ringIn = Duration(milliseconds: 900);
  static const ringInCurve = Cubic(.3, 1.4, .5, 1);
  static const sealIn = Duration(milliseconds: 600);
  static const sealInDelayBase = Duration(milliseconds: 600);
  static const sealInStagger = Duration(milliseconds: 70);
  static const flyIn = Duration(milliseconds: 900);
  static const flyInCurve = Cubic(.2, .9, .25, 1.15);
  static const flyInDelayBase = Duration(milliseconds: 1250);
  static const flyInStagger = Duration(milliseconds: 160);
  static const lineDraw = Duration(milliseconds: 700);
  static const haloCycle = Duration(milliseconds: 2400); // 2.2~2.6s
  static const moveTo = Duration(milliseconds: 1600);
  static const scoreCount = Duration(milliseconds: 1400);
  static const scoreCountDelay = Duration(milliseconds: 350);
  static const barIn = Duration(milliseconds: 1200);
  static const barInCurve = Cubic(.2, .8, .2, 1);
  static const barInDelayBase = Duration(milliseconds: 400);
  static const barInStagger = Duration(milliseconds: 150);
  static const kenBurns = Duration(seconds: 38);
  static const shineCycle = Duration(milliseconds: 3600);
  static const shineDelay = Duration(milliseconds: 2400);
  static const rippleCycle = Duration(seconds: 10);
  static const rippleLayers = 6;
  static const rippleStagger = Duration(milliseconds: 1670);
}

abstract final class GHShadow {
  // 기존 이름(back-compat)
  static const primary = [
    BoxShadow(color: Color(0x47E0668A), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const xl = [
    BoxShadow(color: Color(0x6BE0668A), blurRadius: 34, offset: Offset(0, 10)),
  ];
  static const selected = [
    BoxShadow(color: GHColors.gold, blurRadius: 0, spreadRadius: 1),
    BoxShadow(color: Color(0x38E0668A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // §2-1 신규 명칭
  static const card = [
    BoxShadow(color: Color(0x1F3C285A), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const cardSelected = selected;
  static const imageCard = [
    BoxShadow(color: Color(0x1F3C285A), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const primaryBtn = primary;
  static const scoreRing = [
    BoxShadow(color: Color(0x47E0668A), blurRadius: 28, offset: Offset(0, 10)),
  ];
  static const introBtn = [
    BoxShadow(color: Color(0x38E0668A), blurRadius: 16, offset: Offset(0, 6)),
  ];
}
