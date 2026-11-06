/// [기간별 운세(오늘/주간/월간) — 신규 기능 전용 디자인 토큰]
///
/// 디자인 핸드오프 `design_handoff_fortune_v4/design_files/`의
/// `colors_and_type.css` + `fortune.css` `[data-palette="white"]`(백자)
/// 블록 + 가독성 강화(11/4) 보정값을 그대로 포팅한 Flutter 상수 모음.
///
/// 기존 `saju_dark_tokens.dart`(정통사주 리뉴얼, 다크 톤)와 동일한
/// "클래스 기반 static const" 패턴을 따르되, 색상 자체는 완전히 다른
/// 백자(흰 바탕 + 보랏빛 먹 강조) 팔레트를 쓴다 — `UnifiedColors`(다크
/// #0B0B0D)도 `WishRoomColors`(크리스탈/라벤더)도 이 팔레트와 맞지
/// 않으므로 신규 토큰 파일로 분리한다.
///
/// 폰트 패밀리(`NotoSerifKR`/`GowunBatang`/`Pretendard`/`IBMPlexMono`)는
/// 이미 `pubspec.yaml`에 등록되어 있다 — 새로 추가하지 않는다.
library;

import 'package:flutter/material.dart';

/// 백자(White Porcelain) 팔레트 — fortune.css `[data-palette="white"]`
/// + 가독성 강화 보정(11/4 커밋: glow #5b3fc4→#4a2fb0, accent #d0503f→
/// #c03e2d, fg #1a1228→#140d22)을 반영한 최종 값.
class FortunePeriodColors {
  const FortunePeriodColors._();

  static const Color bg1 = Color(0xFFFDFCFA);
  static const Color bg2 = Color(0xFFF5F2EE);
  static const Color fg = Color(0xFF140D22); // 가독성 강화 보정값
  static const Color muted = Color(0xFF4A4058);
  static const Color glow = Color(0xFF4A2FB0); // 가독성 강화 보정값
  static const Color glowShadow = Color(0x384A2FB0); // rgba(74,47,176,0.22)
  static const Color crystal = Color(0xFF3F9BBF);
  static const Color accent = Color(0xFFC03E2D); // 가독성 강화 보정값
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0x1A3C2864); // rgba(60,40,100,0.10)
  static const Color sigil = Color(0xFFC9A24A); // 금빛 마법진
  static const Color onGlow = Color(0xFFFFFFFF);

  // 분야별 포인트 컬러 (fields: wealth/love/work, 참고용 people/health)
  static const Color cWealth = Color(0xFFC98A12);
  static const Color cLove = Color(0xFFD65B7A);
  static const Color cWork = Color(0xFF4A2FB0); // 가독성 강화 보정값
  static const Color cPeople = Color(0xFF2F93B8);
  static const Color cHealth = Color(0xFF3F9A74);

  // 주의사항 섹션 배경/테두리 (accent 기반 tint)
  static const Color cautionBg = Color(0xFFFFF6F3);
  static const Color cautionBorder = Color(0xFFF4D3CC);

  // 요약(v2-summary)/아카이브·스탬프 카드 배경(그라데이션 보조색)
  static const Color summaryGradStart = Color(0xFFF3ECFF);
  static const Color summaryGradMid = Color(0xFFFFF6EC);
  static const Color summaryGradEnd = Color(0xFFEEF8FB);

  /// 분야 id(`wealth`/`money`/`love`/`work`) → 포인트 컬러.
  static Color fieldColor(String id) {
    switch (id) {
      case 'wealth':
      case 'money':
        return cWealth;
      case 'love':
        return cLove;
      case 'work':
        return cWork;
      case 'people':
        return cPeople;
      case 'health':
        return cHealth;
      default:
        return glow;
    }
  }
}

/// 타이포그래피 — colors_and_type.css 폰트 패밀리 + fortune.css `.v2-*`
/// 클래스의 크기/자간/굵기를 그대로 포팅.
class FortunePeriodType {
  const FortunePeriodType._();

  static const String serif = 'NotoSerifKR'; // --font-display
  static const String body = 'GowunBatang'; // --font-body
  static const String ui = 'Pretendard'; // --font-ui
  static const String mono = 'IBMPlexMono'; // --font-mono

  /// `.v2-mono` — 기간 라벨/섹션 메타 (TODAY · THIS WEEK 등).
  static const TextStyle mono10 = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    letterSpacing: 3.0, // 0.3em
    fontWeight: FontWeight.w600,
    color: FortunePeriodColors.muted,
  );

  /// `.v2-period-main`
  // [폰트 중앙화 — 2026-11] '타이틀' 규칙(800)에 맞춰 700 -> 800 상향.
  static const TextStyle periodMain = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w800,
    fontSize: 21,
    letterSpacing: -0.4,
    height: 1.25,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-period-sub`
  static const TextStyle periodSub = TextStyle(
    fontFamily: body,
    fontSize: 13,
    color: FortunePeriodColors.muted,
  );

  /// `.v2-summary-title` (총평 2줄 타이틀, 2번째 줄은 glow 컬러로 별도 적용)
  static const TextStyle summaryTitle = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w900,
    fontSize: 27,
    height: 1.3,
    letterSpacing: -0.6,
    color: FortunePeriodColors.fg,
  );

  static const TextStyle summaryTitleGlow = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w900,
    fontSize: 27,
    height: 1.3,
    letterSpacing: -0.6,
    color: FortunePeriodColors.glow,
  );

  /// `.v2-summary-body` (가독성 강화: 16.5px)
  static const TextStyle summaryBody = TextStyle(
    fontFamily: body,
    fontSize: 16.5,
    height: 1.9,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-h` (섹션 소제목)
  // [폰트 중앙화] '타이틀' 규칙(800)에 맞춰 700 -> 800 상향.
  static const TextStyle sectionHead = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w800,
    fontSize: 17,
    letterSpacing: -0.3,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-flow-name`
  static const TextStyle flowName = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: FortunePeriodColors.glow,
  );

  /// `.v2-flow-t`
  static const TextStyle flowTime = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: FortunePeriodColors.muted,
  );

  /// `.v2-flow-text`
  static const TextStyle flowText = TextStyle(
    fontFamily: body,
    fontSize: 15,
    height: 1.75,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-field-name`
  static const TextStyle fieldName = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-field-text` (가독성 강화: 14.5px, opacity 1)
  static const TextStyle fieldText = TextStyle(
    fontFamily: body,
    fontSize: 14.5,
    height: 1.7,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-caution li` (가독성 강화: 15px)
  static const TextStyle caution = TextStyle(
    fontFamily: body,
    fontSize: 15,
    height: 1.6,
    color: FortunePeriodColors.fg,
  );

  /// `.pstamp`
  static const TextStyle stamp = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    color: FortunePeriodColors.fg,
  );

  /// `.archive-when`
  static const TextStyle archiveWhen = TextStyle(
    fontFamily: mono,
    fontSize: 10,
    letterSpacing: 0.8,
    fontWeight: FontWeight.w600,
    color: FortunePeriodColors.muted,
  );

  /// `.archive-title`
  static const TextStyle archiveTitle = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 13.5,
    color: FortunePeriodColors.fg,
  );

  /// `.archive-go`
  static const TextStyle archiveGo = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    color: FortunePeriodColors.glow,
  );

  /// `.dlg-title`
  static const TextStyle dialogTitle = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w900,
    fontSize: 22,
    height: 1.35,
    letterSpacing: -0.4,
    color: FortunePeriodColors.fg,
  );

  /// `.dlg-body`
  static const TextStyle dialogBody = TextStyle(
    fontFamily: body,
    fontSize: 13.5,
    height: 1.7,
    color: FortunePeriodColors.fg,
  );

  /// `.v2-share-note` / `.my-note`
  // [폰트 중앙화] mono 규칙(500)에 맞춰 기본값(400) -> 500 명시.
  static const TextStyle noteMono = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w500,
    fontSize: 9,
    letterSpacing: 1.6,
    height: 1.7,
    color: FortunePeriodColors.muted,
  );

  /// `.btn-primary` 글자
  static const TextStyle btnPrimary = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: FortunePeriodColors.onGlow,
  );

  /// `.btn-ghost` 글자
  static const TextStyle btnGhost = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: FortunePeriodColors.muted,
  );

  /// `.btn-secondary` 글자
  static const TextStyle btnSecondary = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: FortunePeriodColors.fg,
  );

  /// `.my-saju dt`
  static const TextStyle dt = TextStyle(
    fontFamily: body,
    fontSize: 13.5,
    color: FortunePeriodColors.muted,
  );

  /// `.my-saju dd`
  static const TextStyle dd = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: FortunePeriodColors.fg,
  );

  /// `.past-banner`
  static const TextStyle pastBanner = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    color: FortunePeriodColors.fg,
  );
}

/// 4pt 기반 간격 스케일 — `colors_and_type.css` `--sp-*`.
class FortunePeriodSpace {
  const FortunePeriodSpace._();
  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 20;
  static const double sp6 = 24;
  static const double sp8 = 32;
  static const double sp10 = 40;
  static const double sp12 = 48;
}

/// 모서리 반경 — `colors_and_type.css` `--r-*`.
class FortunePeriodRadius {
  const FortunePeriodRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}
