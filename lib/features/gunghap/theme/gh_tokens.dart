// ═══════════════════════════════════════════════════════════════
// FILE: gh_tokens.dart
// [궁합지도 전면 리디자인 v4] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §2(디자인 토큰) + `flutter_starter/lib/gunghap/
// theme/gh_tokens.dart`(v3 참고 구현, 2026-11-15 최종) 완전 포팅.
//
// [네이밍 전략] v4 참고 코드가 쓰는 새 이름(accent/fg/muted/line/card/
// onAccent/violetText/GHElement/GHCategory/GHBand/GHBorder 등)을
// "정본"으로 채택한다. 동시에 이번 턴 이전까지 이 프로젝트가 써 온
// 구버전 호환 이름(gold/ivory/gray/divider/ink/violetTextLight/
// cardSolid 등 — 18개 이상의 기존 파일이 참조)은 **별칭(const 재참조)**
// 으로 계속 제공해, 이번 턴에 아직 손대지 않은 화면도 컴파일이 깨지지
// 않고 동일한 색상을 그대로 보여준다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

abstract final class GHColors {
  // ── 베이스 ──
  static const bg2 = Color(0xFFFAF8FC); // 화면 베이스
  static const bg1 = Color(0xFFFFFFFF); // 상단 / 카드
  static const card = Color(0xFFFFFFFF);
  static const fieldBg = Color(0xFFF3EDF8); // 세그먼트 · 보조 박스
  static const track = Color(0xFFEEE7F4); // 점수 원/막대 트랙

  // ── 텍스트(§2 정본 명칭) ──
  static const fg = Color(0xFF1E1730); // 본문
  static const muted = Color(0xFF453D5C); // 보조 글씨

  // ── 강조(§2 정본 명칭) ──
  static const accent = Color(0xFFE0668A); // 강조 · 선택 · 탭 활성 · 링크
  static const accentLight = Color(0xFFEC8AA6); // 보조 강조 · 하단바 점
  static const accentDeep = Color(0xFFB76BD0); // 그라데이션 끝
  static const violet = Color(0xFF8B6FD8); // 보조 포인트
  static const violetText = Color(0xFF7A5FC8); // 보라 글씨
  static const mint = Color(0xFF3FA884); // 긍정 · 강점 · 완료
  static const rose = Color(0xFFE05A6E); // 경고 · 살펴볼 부분 · 오류
  static const meInk = Color(0xFFFF5C93); // 인연지도 「나」 전용
  static const introText = Color(0xFFC2416E); // 「궁합지도」 버튼 글씨

  // ── 선 ──
  static const line = Color(0x8CE0668A); // rgba(224,102,138,.55) — 강조 테두리
  static const lineSoft = Color(0x4D2A2140); // rgba(42,33,64,.30) — 기본 테두리
  static const navTop = Color(0x38E0668A); // 22% — 하단바 상단 보더

  // ── 기타 ──
  static const glowShadow = Color(0x47E0668A); // 28%
  static const scrim = Color(0xB3080C1A); // 70% — 바텀시트 딤
  static const kakao = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF191600);
  static const onAccent = Colors.white; // 포인트(그라데이션) 배경 위 글씨

  // ── §2 구버전 호환 별칭(기존 화면 — 값만 교체되어 보이도록 유지) ──
  // 이번 턴에 재작성하지 않은 화면도 그대로 컴파일 · 동일한 색으로
  // 표시된다. 신규 작성 코드는 위 §2 정본 이름을 사용할 것.
  static const cardSolid = card;
  static const gold = accent;
  static const goldLight = accentLight;
  static const goldDark = accentDeep;
  static const violetTextLight = Color(0xFFE6DAFF); // violet 버튼 글씨(구 버전 전용)
  static const ivory = fg;
  static const gray = muted;
  static const divider = Color(0xFFE6DDEB);
  static const ink = onAccent;
  static const dim = scrim;
  static const introBorder = Color(0x73E0668A);
}

/// 오행(일간) 색 — [GHColors.relGenerate] 등 관계색은 여기서 참조.
abstract final class GHElement {
  static const wood = Color(0xFF10B981); // 木
  static const fire = Color(0xFFF43F5E); // 火
  static const earth = Color(0xFFF59E0B); // 土
  static const metal = Color(0xFF64748B); // 金
  static const water = Color(0xFF3B82F6); // 水
  static Color of(String hanja) =>
      const {'木': wood, '火': fire, '土': earth, '金': metal, '水': water}[hanja] ??
      earth;
  // 오행 관계색 (RelationSheet) — 生 · 比 · 剋
  static const relGen = GHColors.accent; // 生
  static const relSame = GHColors.fg; // 比
  static const relKe = GHColors.violetText; // 剋
}

/// 대분류 8종 색(c1, c2) — [CatIcon] · 대분류 카드 그라데이션 등에 사용.
abstract final class GHCategory {
  static const colors = <String, (Color, Color)>{
    'love': (Color(0xFFFF4D8D), Color(0xFFFF9A8B)),
    'marriage': (Color(0xFFF59E0B), Color(0xFFFB7185)),
    'intimacy': (Color(0xFFEC4899), Color(0xFF8B5CF6)),
    'persona': (Color(0xFF6366F1), Color(0xFF22D3EE)),
    'wealth': (Color(0xFFF59E0B), Color(0xFFEAB308)),
    'business': (Color(0xFF0EA5E9), Color(0xFF6366F1)),
    'friend': (Color(0xFF10B981), Color(0xFF22D3EE)),
    'family': (Color(0xFFF97316), Color(0xFFEC4899)),
  };
  static const order = [
    'love', 'marriage', 'intimacy', 'persona', 'wealth', 'business', 'friend', 'family', //
  ];
}

/// §2 구버전 호환 — [GHCategory.colors]를 `kind` 문자열(CatIcon용)로
/// 조회하던 기존 코드를 위한 별칭.
abstract final class GHCatColors {
  static List<Color> of(String kind) {
    final c = GHCategory.colors[kind];
    return c == null ? const [GHColors.accent, GHColors.violet] : [c.$1, c.$2];
  }
}

/// 점수 밴드 5단계 — 전 화면 공통.
class GHBand {
  final int min;
  final String label;
  final Color c1;
  final Color c2;
  const GHBand(this.min, this.label, this.c1, this.c2);
  static const all = [
    GHBand(90, '천생연분', Color(0xFFFF4D8D), Color(0xFFB76BD0)),
    GHBand(80, '아주 잘 맞아요', Color(0xFFF0628F), Color(0xFF9F6FE0)),
    GHBand(70, '잘 맞아요', Color(0xFFF59E0B), Color(0xFFF0628F)),
    GHBand(55, '맞춰 가는 사이', Color(0xFF3B82F6), Color(0xFF8B6FD8)),
    GHBand(0, '노력이 필요해요', Color(0xFF64748B), Color(0xFF8B6FD8)),
  ];
  static GHBand of(int score) => all.firstWhere((b) => score >= b.min);
  LinearGradient get gradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]);
}

abstract final class GHGradients {
  /// 135° #F07A9C → #E0668A → #B76BD0 — 주 버튼 · 프리미엄 배지 · 번호 배지
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

  /// 135° #E0668A → #B76BD0 — 텍스트 전용(ShaderMask), 결과 세부명
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

  /// 화면 상단 320px 배경 워시 — radial 핑크/라벤더.
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

/// §2 구버전 호환 — [GHGradients.primary]와 동일.
abstract final class GHGradient {
  static const primary = GHGradients.primary;
  static const sheet = GHGradients.sheet;
  static const title = GHGradients.title;
  static const intro = GHGradients.intro;
}

/// 기존 이름 유지(back-compat) — [GHGradients.primary]와 동일.
const ghGoldGradient = GHGradients.primary;

abstract final class GHSpace {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0;
  static const s8 = 32.0, s10 = 40.0;
  static const screenH = 20.0; // 화면 좌우
  static const section = 32.0;
  static const sectionGap = 30.0; // 섹션 간 (28~34)
  static const cardGap = 10.0; // 카드 간
  static const cardPad = 16.0; // 카드 패딩 (14~18)
  static const fieldGap = 22.0; // 필드 간
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
  static const seal = 8.0; // 분야 네모(CatIcon 카드)
  static const sealSquare = 8.0;
  static const tier = 8.0;
  static const iconBtn = 20.0; // 40×40 원
}

/// §2 정본 — 카드 · 입력 · 박스 · 점선 박스 공통 테두리 두께.
abstract final class GHBorder {
  static const width = 1.5;
}

abstract final class GHButtonSize {
  static const xl = 58.0, lg = 54.0, md = 48.0, sm = 40.0;
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
    BoxShadow(color: GHColors.accent, blurRadius: 0, spreadRadius: 1),
    BoxShadow(color: Color(0x38E0668A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // §2 정본 명칭
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

abstract final class GHMotion {
  // 기존 이름(back-compat)
  static const screen = Duration(milliseconds: 450);
  static const sheet = Duration(milliseconds: 400);
  static const sheetCurve = Cubic(0.22, 1, 0.36, 1);
  static const press = Duration(milliseconds: 180);
  static const lineSegment = Duration(milliseconds: 550);
  static const lineStagger = Duration(milliseconds: 220);
  static const ringRevolution = Duration(seconds: 180);
  static const pulse = Duration(milliseconds: 2400);
  static const loadingTotal = Duration(milliseconds: 5100);

  // §2 정본 명칭(v4)
  static const cardIn = Duration(milliseconds: 500);
  static const cardInStagger = Duration(milliseconds: 50);
  static const cardStagger = cardInStagger;
  static const ringIn = Duration(milliseconds: 900);
  static const ringInCurve = Cubic(.3, 1.4, .5, 1);
  static const sealIn = Duration(milliseconds: 600);
  static const sealInDelayBase = Duration(milliseconds: 600);
  static const sealInStagger = Duration(milliseconds: 70);
  static const flyIn = Duration(milliseconds: 900);
  static const flyInCurve = Cubic(.2, .9, .25, 1.15);
  static const flyCurve = flyInCurve;
  static const flyInStart = Duration(milliseconds: 1250);
  static const flyInDelayBase = flyInStart;
  static const flyInStagger = Duration(milliseconds: 160);
  static const lineDraw = Duration(milliseconds: 700);
  static const haloCycle = Duration(milliseconds: 2400);
  static const moveTo = Duration(milliseconds: 1600);
  static const scoreCount = Duration(milliseconds: 1400);
  static const scoreDelay = Duration(milliseconds: 350);
  static const scoreCountDelay = scoreDelay;
  static const barIn = Duration(milliseconds: 1200);
  static const barInCurve = Cubic(.2, .8, .2, 1);
  static const barInDelayBase = Duration(milliseconds: 400);
  static const barInStagger = Duration(milliseconds: 150);
  static const kenBurns = Duration(seconds: 38);
  static const shine = Duration(milliseconds: 3600);
  static const shineCycle = shine;
  static const shineDelay = Duration(milliseconds: 2400);
  static const majorAutoNext = Duration(milliseconds: 260);
  /// 10초 1주기, 6겹(파동) — [DestinyBurst] 성운/파동 애니메이션.
  static const ripple = Duration(seconds: 10);
  static const rippleCycle = ripple;
  static const rippleLayers = 6;
  static const rippleStagger = Duration(milliseconds: 1670);
}
