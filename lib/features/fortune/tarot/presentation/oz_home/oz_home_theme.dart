// ============================================================
//  oz_home_theme.dart
//
//  신통방통 타로 · 오즈 스타일 "홈 화면" 전용 디자인 토큰
//  - 컬러 팔레트 (딥 퍼플 + 골드 + 로즈)
//  - 타이포그래피 (Noto Serif KR* + Gowun Batang + IBM Plex Mono)
//
//  [handoff-home 이식 주의사항]
//  이 파일은 handoff-home.zip의 02_oz_home_theme.dart를 이식한 것으로,
//  기존 `presentation/oz/oz_theme.dart`(다른 6개 화면: 허브/카테고리상세/
//  질문/카드선택/로딩/결과가 사용 중)와 클래스명(OzColors/OzTypography)이
//  동일하다. 이 파일은 오직 `oz_home/` 하위 화면(OzTarotHomeScreen)에서만
//  import하여 사용하고, 기존 `oz/` 하위 6개 화면 파일에는 절대 import하지
//  않는다(파일 단위 import이므로 Dart 네임스페이스 충돌 없음. 동일 파일
//  내에서 두 클래스를 동시에 import할 경우에만 `as` prefix가 필요함).
//
//  * `google_fonts: 6.2.1`(이 프로젝트 고정 버전)에는 notoSerifKr이 없어
//    (기존 오즈 리스킨 6화면과 동일한 이유로) notoSansKr(굵은 세리프 톤)
//    weight 900/700으로 대체했다. 값 자체(사이즈/트래킹/그림자)는 원본
//    handoff 그대로.
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────────────
class OzHomeColors {
  OzHomeColors._();

  // 배경 (그라디언트용 3단)
  static const bgTop = Color(0xFF2D1B5C); // 상단 밝은 보라
  static const bgMid = Color(0xFF1A0F3D); // 중간 진한 보라
  static const bgDeep = Color(0xFF0A0620); // 하단 딥 인디고

  // 텍스트
  static const fg = Color(0xFFFFF8DD); // 크림 화이트 (본문)
  static const muted = Color(0xBFE8DCF5); // 75% alpha 라벤더 (서브 텍스트)
  static const line = Color(0x29F5D98A); // 16% alpha 골드 (경계선)
  static const card = Color(0x2E8B6EC8); // 18% alpha 퍼플 (카드 배경)

  // 액센트
  static const gold = Color(0xFFF5D97A); // 촛불 골드 (강조/CTA)
  static const goldDeep = Color(0xFFC9982A); // 딥 골드 (그라디언트 하단)
  static const rose = Color(0xFFE87A91); // 로즈 (NEW 배지/하트)
  static const roseDeep = Color(0xFFC94A6B); // 딥 로즈
  static const teal = Color(0xFF8DBFD6); // 티일 (쿨 세컨더리)
}

// ─────────────────────────────────────────────────────
//  Typography
//  - Display: Noto Sans KR 900 (히어로 타이틀, notoSerifKr 대체)
//  - Body:    Gowun Batang 400/700 (시적 본문)
//  - Mono:    IBM Plex Mono 500 (모노 라벨 · 대문자 · 넓은 트래킹)
// ─────────────────────────────────────────────────────
class OzHomeTypography {
  OzHomeTypography._();

  /// 히어로 타이틀 · (Noto Serif KR 대체) Noto Sans KR 900 · 22px
  /// 예) "오늘, 카드가\n건네는 한마디"
  static TextStyle heroTitle({double size = 22, Color? color}) =>
      GoogleFonts.notoSansKr(
        fontWeight: FontWeight.w900,
        fontSize: size,
        height: 1.2,
        letterSpacing: size * -0.03,
        color: color ?? Colors.white,
        shadows: const [
          Shadow(color: Color(0xB3000000), offset: Offset(0, 2), blurRadius: 8),
        ],
      );

  /// 배너 강조 텍스트 (아래줄) · Gowun Batang 700 이탤릭 · 20px
  /// 예) "**보는 카테고리**" (골드/로즈 이탤릭)
  static TextStyle bannerAccent({double size = 20, required Color color}) =>
      GoogleFonts.gowunBatang(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        fontSize: size,
        height: 1.2,
        letterSpacing: size * -0.03,
        color: color,
        shadows: const [
          Shadow(color: Color(0xB3000000), offset: Offset(0, 2), blurRadius: 8),
        ],
      );

  /// 섹션 타이틀 · Gowun Batang 700 · 14px
  /// 예) "✦ 테마별로 둘러보기"
  static TextStyle sectionTitle() => GoogleFonts.gowunBatang(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    letterSpacing: -0.14,
    color: OzHomeColors.fg,
  );

  /// 카드 이름 · Gowun Batang 700
  static TextStyle cardName({double size = 15, Color? color}) =>
      GoogleFonts.gowunBatang(
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: size * -0.013,
        color: color ?? OzHomeColors.fg,
      );

  /// 본문 · Gowun Batang 400 · 13px
  static TextStyle body({double size = 13, Color? color}) =>
      GoogleFonts.gowunBatang(
        fontSize: size,
        height: 1.7,
        color: color ?? OzHomeColors.muted,
      );

  /// 모노 라벨 · IBM Plex Mono 500 · 대문자 + 넓은 트래킹
  /// 예) "MOST · LOVED", "FRESH · TAROT"
  static TextStyle monoLabel({
    double size = 10,
    double trackingEm = 0.3,
    Color? color,
  }) => GoogleFonts.ibmPlexMono(
    fontWeight: FontWeight.w500,
    fontSize: size,
    letterSpacing: size * trackingEm,
    color: color ?? OzHomeColors.gold.withValues(alpha: 0.85),
  );

  /// 카운트 pill 안의 큰 숫자
  static TextStyle countNumber({required Color color}) => GoogleFonts.notoSansKr(
    fontWeight: FontWeight.w900,
    fontSize: 14,
    letterSpacing: -0.28,
    color: color,
  );

  /// 카운트 pill 안의 라벨 ("개 카테고리")
  static TextStyle countLabel({required Color color}) => GoogleFonts.gowunBatang(
    fontSize: 10.5,
    letterSpacing: -0.05,
    color: color,
  );

  /// 상단바 앱 타이틀 · (Noto Serif KR 대체) Noto Sans KR 700 · 20px
  static TextStyle topbarTitle() => GoogleFonts.notoSansKr(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    letterSpacing: -0.3,
    color: OzHomeColors.fg,
  );
}

// ─────────────────────────────────────────────────────
//  Radii & Spacing (4pt scale)
// ─────────────────────────────────────────────────────
class OzHomeRadii {
  OzHomeRadii._();
  static const chip = 12.0;
  static const card = 14.0;
  static const banner = 20.0;
  static const hero = 22.0;
  static const pill = 999.0;
}

class OzHomeSpacing {
  OzHomeSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}
