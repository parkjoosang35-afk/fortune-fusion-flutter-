import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'intro_palette.dart';

/// [핸드오프 콘텐츠 반영 - 인트로 전용 타이포그래피]
/// `design_handoff_onboarding_flow/tokens/colors_and_type.css` 및
/// `screens/01_Intro.html`의 `.eyebrow`/`.title`/`.sub`/`.btn-primary`/
/// `.btn-ghost`/`.link-btn`/`.feature-title`/`.feature-desc` 규칙을
/// Flutter TextStyle로 1:1 이식한 것.
///
/// [폰트 매핑 - 대체 근거] 핸드오프는 4개 웹폰트를 지정한다:
/// - `Noto Serif KR`(900) → google_fonts 6.2.1에 해당 패밀리가 없어(한국어
///   Noto Serif 계열 미탑재) 같은 "한글 명조체 + 굵은 획" 인상을 주는
///   `GoogleFonts.nanumMyeongjo`(최대 weight 800)로 대체한다. 프로젝트 내
///   다른 화면(jeontong_design/hanji_design_tokens.dart)이 이미
///   `notoSansKr`/`gowunBatang`/`ibmPlexMono` 조합을 쓰고 있어 같은 계열의
///   대체 전략이다.
/// - `Gowun Batang` → `GoogleFonts.gowunBatang` (그대로 존재, weight 400/700).
/// - `IBM Plex Mono` → `GoogleFonts.ibmPlexMono` (그대로 존재).
/// - `Pretendard` → 이 3화면에는 별도 UI 라벨 요구가 없어 미사용.
///
/// [범위 격리 원칙] 이 파일은 인트로(스플래시/페이저/CTA) 3개 화면 전용이며
/// `core/theme/app_unified_style.dart`의 `UnifiedText`는 건드리지 않는다.
class IntroTextStyles {
  IntroTextStyles._();

  /// `.eyebrow` — mono 10px, letter-spacing 0.4em, uppercase, muted 라벤더.
  /// 핸드오프 표기는 이미 대문자(SINTONG, CHAPTER, READY 등)이므로 별도
  /// `.toUpperCase()` 변환 없이 원문 그대로 렌더링한다.
  static TextStyle eyebrow({Color? color}) => GoogleFonts.ibmPlexMono(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 4.0, // 0.4em ≈ fontSize(10) * 0.4
    color: color ?? IntroPalette.textSecondary,
    height: 1.0,
  );

  /// `.skip-btn` — mono 11px, letter-spacing 0.2em, uppercase.
  static TextStyle skipButton({Color? color}) => GoogleFonts.ibmPlexMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.2, // 0.2em * 11
    color: color ?? IntroPalette.textSecondary,
    height: 1.0,
  );

  /// `.title` — 900 30px, letter-spacing -0.03em, Noto Serif KR 대체(NanumMyeongjo).
  /// 페이지별로 fontSize가 다르므로(스플래시 42px/기본 30px/페이지3 26px)
  /// 호출부에서 `.copyWith(fontSize: ...)`로 오버라이드한다.
  static TextStyle title({Color? color, double fontSize = 30}) =>
      GoogleFonts.nanumMyeongjo(
        fontSize: fontSize,
        fontWeight: FontWeight.w800, // 핸드오프 900 요청, 폰트 최대치인 800으로 근사
        letterSpacing: fontSize * -0.03,
        height: 1.2,
        color: color ?? IntroPalette.textPrimary,
        shadows: [
          Shadow(color: IntroPalette.glowShadow, blurRadius: 30),
        ],
      );

  /// `.sub` — Gowun Batang 400 14px/1.75, muted 라벤더 화이트.
  static TextStyle sub({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.75,
    color: color ?? const Color(0xD1DCD2F5), // rgba(220,210,245,0.82)
  );

  /// `.btn-primary` 텍스트 — Gowun Batang 700 15px, 어두운 남보라(onPrimary).
  static TextStyle btnPrimary({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color ?? IntroPalette.onPrimary,
  );

  /// `.btn-ghost` 텍스트 — Gowun Batang 700 13px, fg(밝은 라벤더 화이트).
  static TextStyle btnGhost({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: color ?? IntroPalette.textPrimary,
  );

  /// `.link-btn` — Gowun Batang 500 12px, 옅은 회보라.
  static TextStyle linkButton({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? const Color(0x8CDCD2F5), // rgba(220,210,245,0.55)
  );

  /// `.feature-title` — Gowun Batang 700 13px/1.3.
  static TextStyle featureTitle({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: color ?? IntroPalette.textPrimary,
  );

  /// `.feature-desc` — Gowun Batang 400 11px/1.5, muted.
  static TextStyle featureDesc({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? const Color(0xA6DCD2F5), // rgba(220,210,245,0.65)
  );

  /// `.feature-ico` 한자 아이콘(貴/緣/符) — Noto Serif KR 대체 900 15px.
  static TextStyle featureIcon({Color? color}) => GoogleFonts.nanumMyeongjo(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: color ?? IntroPalette.primary,
    height: 1.0,
  );

  // ───────────────────────── [Phase B - 02_SignUp_Login.html 반영] ─────────────────────────
  // 02번 핸드오프 문서에서 처음 요구되는 `Pretendard`(필드 라벨/힌트) 스타일들.
  // 앱 전역에 이미 `Pretendard` 폰트 패밀리가 pubspec.yaml에 등록되어 있어
  // (core/theme/app_theme.dart 기본 폰트) google_fonts 대체 없이 `fontFamily:
  // 'Pretendard'`로 직접 지정한다.

  /// `.form-eyebrow` — 로그인/회원가입 폼 상단 라벨. eyebrow()와 폰트/톤은
  /// 동일하나 letter-spacing이 0.3em(핸드오프 값)으로 살짝 좁다.
  static TextStyle formEyebrow({Color? color}) => GoogleFonts.ibmPlexMono(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 3.0, // 0.3em * 10
    color: color ?? IntroPalette.textSecondary,
    height: 1.0,
  );

  /// `.form-title` — 폼 제목(22px), title()의 축소 버전.
  static TextStyle formTitle({Color? color}) => title(color: color, fontSize: 22);

  /// `.form-subtitle` — Gowun Batang 400 12px/1.55, muted.
  static TextStyle formSubtitle({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color ?? IntroPalette.textSecondary,
  );

  /// `.field-label` — Pretendard 500 11px, fg.
  static TextStyle fieldLabel({Color? color}) => const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.11,
    height: 1.0,
  ).copyWith(color: color ?? IntroPalette.textPrimary);

  /// `.field-hint` — Pretendard 400 10.5px/1.4, muted(기본)/danger/crystal 가변.
  static TextStyle fieldHint({Color? color}) => const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
  ).copyWith(color: color ?? IntroPalette.textSecondary);

  /// `.terms-view` — Pretendard 500 11px, muted, 밑줄은 위젯에서 적용.
  static TextStyle termsView({Color? color}) => const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 11,
    fontWeight: FontWeight.w500,
  ).copyWith(color: color ?? IntroPalette.textSecondary);

  /// `.terms-label` — Gowun Batang, 일반 12px/전체동의 13px(700)로 가변.
  static TextStyle termsLabel({
    Color? color,
    double fontSize = 12,
    FontWeight weight = FontWeight.w500,
  }) => GoogleFonts.gowunBatang(
    fontSize: fontSize,
    fontWeight: weight,
    height: 1.4,
    color: color ?? IntroPalette.textPrimary,
  );

  /// `.field-input` — 입력 텍스트, Gowun Batang 400 14px.
  static TextStyle fieldInput({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.14,
    color: color ?? IntroPalette.textPrimary,
  );

  /// `.field-input::placeholder` — rgba(220,210,245,0.35).
  static TextStyle fieldPlaceholder() => GoogleFonts.gowunBatang(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: const Color(0x59DCD2F5),
  );

  /// `.bottom-link` / 로그인상태유지·비밀번호찾기 — Gowun Batang 500 12px.
  static TextStyle bottomLink({Color? color}) => GoogleFonts.gowunBatang(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? IntroPalette.textSecondary,
  );
}
