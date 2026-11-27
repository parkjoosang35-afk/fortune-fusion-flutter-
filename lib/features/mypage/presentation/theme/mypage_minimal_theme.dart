import 'package:flutter/material.dart';

/// 마이페이지 · 미니멀 트렌드(Variant B) 디자인 토큰.
///
/// 출처: `design_handoff_mypage_minimal.zip`의 `tokens.css` (87 lines).
/// 한지 크림 배경(#f7eedc) + 부적 주홍(#8b2c1f) 톤의 라이트 테마로,
/// 앱 전역에서 쓰이는 다크 테마 `UnifiedColors`/`UnifiedText`
/// (lib/core/theme/app_unified_style.dart)와는 완전히 분리된
/// 마이페이지 전용 토큰이다 — shrine_v3의 `ShrineV3Colors`/
/// `ShrineV3TextStyles` (lib/features/shrine_v3/presentation/theme/
/// shrine_v3_theme.dart) 패턴을 그대로 따른다.
///
/// 값은 tokens.css의 원본 주석/변수명을 그대로 보존해 추적 가능하게 했다.
/// (CSS 커스텀 프로퍼티 1px = Flutter 1 논리픽셀로 그대로 매핑)
class MyPageColors {
  MyPageColors._();

  // ---------- Color · Surface ----------
  /// --mp-paper: 화면 배경 (한지)
  static const paper = Color(0xFFF7EEDC);
  /// --mp-paper-2
  static const paper2 = Color(0xFFEFE2C6);
  /// --mp-surface: 카드/리스트 배경
  static const surface = Color(0xFFFFFAF0);
  /// --mp-nav-bg: 하단 탭 배경 (blur 20px와 함께 사용)
  static const navBg = Color(0xE6FAF3E4); // rgba(250,243,228,.90)

  // ---------- Color · Ink (B 전용: 진하고 선명) ----------
  /// --mp-ink: 본문/제목
  static const ink = Color(0xFF140C06);
  /// --mp-ink-2: 보조 텍스트  rgba(20,12,6,.82)
  static const ink2 = Color(0xD1140C06);
  /// --mp-ink-3: 캡션/비활성/chevron  rgba(20,12,6,.60)
  static const ink3 = Color(0x99140C06);
  /// --mp-hair: 1px 구분선  rgba(40,25,12,.16)
  static const hair = Color(0x29281909);
  /// --mp-row-div: 리스트 행 구분선  rgba(60,45,30,.07)
  static const rowDiv = Color(0x123C2D1E);

  // ---------- Color · Brand ----------
  /// --mp-red: Primary (부적 주홍)
  static const red = Color(0xFF8B2C1F);
  /// --mp-red-2: 알림 dot, 위험 텍스트
  static const red2 = Color(0xFFB4472F);
  /// --mp-red-deep
  static const redDeep = Color(0xFF5E1A12);
  /// --mp-red-soft: Soft 버튼 배경  rgba(139,44,31,.08)
  static const redSoft = Color(0x148B2C1F);
  /// --mp-gold
  static const gold = Color(0xFFE9B949);
  /// --mp-gold-2: +3 숫자, 무료 배지
  static const gold2 = Color(0xFFF6D77C);
  /// --mp-attend-from: 출석 배너 gradient 시작
  static const attendFrom = Color(0xFFF3D27A);
  /// --mp-attend-to: 출석 배너 gradient 끝
  static const attendTo = Color(0xFFEBB84A);
  /// --mp-bronze: 등급 뱃지 '銅'
  static const bronze = Color(0xFFB07A4A);

  // ---------- 메뉴 아이콘 타일 4톤 ----------
  /// 사주 · 궁합
  static const tile1Bg = Color(0xFFF4DCD2);
  static const tile1Fg = Color(0xFF8B2C1F);
  /// 타로 · 소원방
  static const tile2Bg = Color(0xFFEFE0BD);
  static const tile2Fg = Color(0xFF8A5A14);
  /// 관상 · 보관한 풀이
  static const tile3Bg = Color(0xFFE3E5D2);
  static const tile3Fg = Color(0xFF55663A);
  /// 손금 · 운세 기록
  static const tile4Bg = Color(0xFFE8DCCD);
  static const tile4Fg = Color(0xFF6B4A2B);

  /// 4톤 타일 팔레트를 순서대로 묶은 리스트 (index % 4 로 순환 사용).
  static const List<Color> tileBg = [tile1Bg, tile2Bg, tile3Bg, tile4Bg];
  static const List<Color> tileFg = [tile1Fg, tile2Fg, tile3Fg, tile4Fg];
}

/// --mp-font-* 패밀리 이름.
class MyPageFonts {
  MyPageFonts._();

  /// --mp-font-ui: 모든 UI 텍스트
  static const ui = 'Pretendard';
  /// --mp-font-hanja: 한자 글리프(四 塔 福 印 …) 전용
  static const hanja = 'NotoSerifKR';
  /// --mp-font-mono: 날짜 라벨 2026 · 11 · 05
  static const mono = 'IBMPlexMono';
}

/// tokens.css의 `--mp-t-*` 조합 타이포 스타일.
/// (CSS shorthand: weight size/line-height family, letter-spacing은
/// 주석에 em 단위로 명시된 값을 해당 size 기준 px로 환산해 적용)
class MyPageTextStyles {
  MyPageTextStyles._();

  /// --mp-t-page: 800 30px/1.2 — '마이' 페이지 타이틀, -0.03em
  static const page = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 30,
    height: 1.2,
    letterSpacing: -0.9,
    color: MyPageColors.ink,
  );

  /// --mp-t-display: 800 26px/1.25 — 서브화면 히어로(2줄)
  static const display = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 26,
    height: 1.25,
    color: MyPageColors.ink,
  );

  /// --mp-t-name: 800 20px/1.3 — 프로필 이름
  static const name = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 20,
    height: 1.3,
    color: MyPageColors.ink,
  );

  /// --mp-t-section: 800 18px/1.3 — 섹션 헤더
  static const section = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 18,
    height: 1.3,
    color: MyPageColors.ink,
  );

  /// --mp-t-header: 800 17px/1.2 — 서브 상단바 타이틀
  static const header = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 17,
    height: 1.2,
    color: MyPageColors.ink,
  );

  /// --mp-t-card-t: 800 17px/1.3 — 강조 카드 제목
  static const cardTitle = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 17,
    height: 1.3,
    color: MyPageColors.ink,
  );

  /// --mp-t-row: 600 15px/1.4 — 리스트 행
  static const row = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.4,
    color: MyPageColors.ink,
  );

  /// --mp-t-body: 500 14px/1.65 — 리드 문단
  static const body = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.65,
    color: MyPageColors.ink2,
  );

  /// --mp-t-btn: 800 14px/1
  static const btn = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 14,
    height: 1,
    color: MyPageColors.ink,
  );

  /// --mp-t-caption: 600 12px/1.5
  static const caption = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 1.5,
    color: MyPageColors.ink3,
  );

  /// --mp-t-tab: 700 11px/1
  static const tab = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    height: 1,
    color: MyPageColors.ink3,
  );

  /// --mp-t-num-xl: 900 76px/1 — 지갑 잔액, -0.04em
  static const numXl = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w900,
    fontSize: 76,
    height: 1,
    letterSpacing: -3.04,
    color: MyPageColors.ink,
  );

  /// --mp-t-num-l: 800 30px/1 — 마이 지갑 숫자, tabular-nums
  static const numL = TextStyle(
    fontFamily: MyPageFonts.ui,
    fontWeight: FontWeight.w800,
    fontSize: 30,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
    color: MyPageColors.ink,
  );

  /// 한자 글리프(四 塔 福 印 …) 전용 스타일 — README 실사용 스펙 상
  /// NotoSerifKR weight 900만 실제로 쓰인다 (pubspec.yaml에 700/900만
  /// 번들되어 있고 600은 미번들 — tokens.css의 @import가 600;900을
  /// 요청하지만 실사용은 900뿐이라 비차단 사항).
  static const hanjaGlyph = TextStyle(
    fontFamily: MyPageFonts.hanja,
    fontWeight: FontWeight.w900,
    color: MyPageColors.ink,
  );

  /// --mp-font-mono 날짜 라벨(2026 · 11 · 05) 등에 사용하는 기본 모노 스타일.
  static const mono = TextStyle(
    fontFamily: MyPageFonts.mono,
    fontWeight: FontWeight.w500,
    color: MyPageColors.ink2,
  );
}

/// --mp-sp-*, --mp-screen-x, --mp-sub-x (4pt spacing scale)
class MyPageSpacing {
  MyPageSpacing._();

  static const sp1 = 4.0;
  static const sp2 = 8.0;
  static const sp3 = 12.0;
  static const sp4 = 16.0;
  static const sp5 = 20.0;
  static const sp6 = 24.0;
  static const sp8 = 32.0;

  /// --mp-screen-x: 마이 메인 좌우 패딩
  static const screenX = 20.0;
  /// --mp-sub-x: 서브화면 좌우 패딩
  static const subX = 22.0;
}

/// --mp-r-*
class MyPageRadius {
  MyPageRadius._();

  /// --mp-r-tile: 메뉴 아이콘 타일 54×54
  static const tile = 18.0;
  /// --mp-r-btn: 지갑 내부 버튼
  static const btn = 18.0;
  /// --mp-r-list: 설정 리스트 카드
  static const list = 22.0;
  /// --mp-r-card: 지갑 카드
  static const card = 24.0;
  /// --mp-r-avatar: 60×60 squircle
  static const avatar = 22.0;
  static const cta = 16.0;
  /// --mp-r-sheet: 바텀시트 상단
  static const sheet = 30.0;
  static const pill = 999.0;
}

/// --mp-sh-* (Elevation). CSS의 inset 하이라이트는 Flutter BoxShadow로
/// 표현할 수 없어 outer shadow 성분만 포팅한다 — inset 효과가 꼭 필요한
/// 곳은 위젯 트리에서 반투명 Border/Gradient로 별도 근사한다.
class MyPageShadows {
  MyPageShadows._();

  /// --mp-sh-card: 0 8px 30px rgba(120,80,40,.08)
  static const card = [
    BoxShadow(
      color: Color(0x14785028),
      offset: Offset(0, 8),
      blurRadius: 30,
    ),
  ];

  /// --mp-sh-list: 0 8px 30px rgba(120,80,40,.06)
  static const list = [
    BoxShadow(
      color: Color(0x0F785028),
      offset: Offset(0, 8),
      blurRadius: 30,
    ),
  ];

  /// --mp-sh-cta: 0 6px 20px rgba(139,44,31,.28)
  static const cta = [
    BoxShadow(
      color: Color(0x478B2C1F),
      offset: Offset(0, 6),
      blurRadius: 20,
    ),
  ];

  /// --mp-sh-earn: 0 12px 28px rgba(139,44,31,.38) — 광고 보상 강조용
  static const earn = [
    BoxShadow(
      color: Color(0x618B2C1F),
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  /// --mp-sh-coupon: 4px 4px 0 #140c06 (하드 섀도우, 쿠폰 카드)
  /// 눌림 시 1px 1px 0 + translate(3px,3px)로 애니메이션 — 위젯에서
  /// AnimatedContainer로 별도 구현.
  static const coupon = [
    BoxShadow(
      color: MyPageColors.ink,
      offset: Offset(4, 4),
      blurRadius: 0,
    ),
  ];

  static const couponPressed = [
    BoxShadow(
      color: MyPageColors.ink,
      offset: Offset(1, 1),
      blurRadius: 0,
    ),
  ];
}

/// --mp-ease, --mp-dur-*, --mp-press-scale
class MyPageMotion {
  MyPageMotion._();

  /// --mp-ease: cubic-bezier(.2,.8,.2,1)
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1.0);

  /// --mp-dur-push: 서브화면 push/pop, 시트
  static const push = Duration(milliseconds: 550);
  /// --mp-dur-fade: 토글, 칩, 세그먼트
  static const fade = Duration(milliseconds: 400);
  /// --mp-press-scale
  static const pressScale = 0.96;
}
