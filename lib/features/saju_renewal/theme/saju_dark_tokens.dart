import 'package:flutter/material.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프 적용]
/// `design_handoff_jeongtong_saju_v3/docs/01_디자인토큰.md` +
/// `design_files/saju/saju-tokens.css` + `colors_and_type.css`를
/// 1:1로 Flutter 토큰으로 옮긴 것.
///
/// [절대 원칙] 이 파일은 `saju_renewal` 피처 내부에서만 사용한다 — 앱
/// 전역 `UnifiedColors`/`UnifiedText`(라이트 테마)를 변경하지 않는다.
/// 오행(목·화·토·금·수) 색상은 디자인 문서의 경고대로 "임의 색 금지" —
/// 기존 앱에 전역 오행 색 토큰이 없으므로(검색 확인됨) 디자인 핸드오프의
/// 값을 오행 시각화 "유일한 기준값"으로 그대로 사용한다.

/// 잉크(배경) 톤.
class SajuInk {
  SajuInk._();
  static const Color i900 = Color(0xFF111111); // 기본 배경
  static const Color i850 = Color(0xFF17161B);
  static const Color i800 = Color(0xFF1D1C22);
}

/// 골드(강조/CTA/제목) 톤.
class SajuGold {
  SajuGold._();
  static const Color g100 = Color(0xFFFAF3E0); // CTA 텍스트/제목 하이라이트
  static const Color g300 = Color(0xFFE9D3A0); // 글로우/라인/강조
  static const Color g500 = Color(0xFFA88B5C); // 보더/모노 라벨
  static const Color glow = Color(0x52E9D3A0); // rgba(233,211,160,0.32)
}

/// 자수정 다크(카드 서피스) 톤.
class SajuViolet {
  SajuViolet._();
  static const Color v700 = Color(0xFF2A2640);
  static const Color v800 = Color(0xFF201D31);
  static const Color v900 = Color(0xFF17151F);
}

/// 오행(五行) 5색 — 시각화 전용 고정값("임의 색 금지" 원칙).
class SajuElementColor {
  SajuElementColor._();
  static const Color wood = Color(0xFF5E9E74);
  static const Color fire = Color(0xFFD2604A);
  static const Color earth = Color(0xFFC8A24E);
  static const Color metal = Color(0xFFD8D3C6);
  static const Color water = Color(0xFF4C7DB8);

  static Color of(String key) {
    switch (key) {
      case 'wood':
        return wood;
      case 'fire':
        return fire;
      case 'earth':
        return earth;
      case 'metal':
        return metal;
      case 'water':
        return water;
      default:
        return wood;
    }
  }

  static String hanjaOf(String key) {
    switch (key) {
      case 'wood':
        return '木';
      case 'fire':
        return '火';
      case 'earth':
        return '土';
      case 'metal':
        return '金';
      case 'water':
        return '水';
      default:
        return '';
    }
  }

  static String koreanOf(String key) {
    switch (key) {
      case 'wood':
        return '나무';
      case 'fire':
        return '불';
      case 'earth':
        return '흙';
      case 'metal':
        return '쇠';
      case 'water':
        return '물';
      default:
        return '';
    }
  }
}

/// 관계선(합/충) 색.
class SajuRelationColor {
  SajuRelationColor._();
  static const Color hap = SajuGold.g300; // 합 = 금선
  static const Color chung = Color(0xFFC94A3B); // 충/파 = 적선
}

/// 텍스트 색(투명도 포함) — rgba(250,243,224, a) 계열.
class SajuText {
  SajuText._();
  static const Color fg = SajuGold.g100; // 100%
  static const Color fg2 = Color(0xC7FAF3E0); // 78%
  static const Color muted = Color(0x8FFAF3E0); // 56%
  static const Color faint = Color(0x52FAF3E0); // 32%
  static const Color line = Color(0x1FFAF3E0); // 12%
  static const Color lineGold = Color(0x8CA88B5C); // 55%
  static const Color card = Color(0x0AFAF3E0); // 4%
}

/// 주제군 장면 조명(scene tint) 5종 — topic_id의 scene 값과 1:1 대응.
class SajuScene {
  const SajuScene({
    required this.nameKo,
    required this.nameEn,
    required this.glyph,
    required this.tint,
  });

  final String nameKo;
  final String nameEn;
  final String glyph;
  final Color tint;

  static const SajuScene money = SajuScene(
    nameKo: '재물',
    nameEn: 'MONEY',
    glyph: '◈',
    tint: Color(0xFFE9D3A0),
  );
  static const SajuScene talent = SajuScene(
    nameKo: '재능·직업',
    nameEn: 'TALENT',
    glyph: '✧',
    tint: Color(0xFFDCD8CC),
  );
  static const SajuScene love = SajuScene(
    nameKo: '연애·인연',
    nameEn: 'LOVE',
    glyph: '☾',
    tint: Color(0xFFE8B9A8),
  );
  static const SajuScene life = SajuScene(
    nameKo: '인생 흐름',
    nameEn: 'LIFE',
    glyph: '⟡',
    tint: Color(0xFFCFD6E0),
  );
  static const SajuScene guin = SajuScene(
    nameKo: '귀인',
    nameEn: 'RELATION',
    glyph: '✦',
    tint: Color(0xFFF5CF6A),
  );
}

/// 타이포그래피 — Noto Serif KR(제목/한자) · Gowun Batang(본문/CTA) ·
/// Pretendard(UI) · IBM Plex Mono(영문 모노 라벨). 전부 앱에 이미 등록된
/// family 이름을 그대로 재사용한다(신규 폰트 추가 없음).
class SajuType {
  SajuType._();

  static const String serif = 'NotoSerifKR';
  static const String body = 'GowunBatang';
  static const String ui = 'Pretendard';
  static const String mono = 'IBMPlexMono';

  /// T-hero — 01 메인 타이틀 "정통사주".
  static const TextStyle hero = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w900,
    fontSize: 40,
    height: 1.15,
    letterSpacing: -0.03 * 40,
    color: SajuGold.g100,
  );

  /// T-display2 — 페이지 타이틀(02/04 카피 등).
  static const TextStyle display2 = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.2,
    letterSpacing: -0.02 * 26,
    color: SajuGold.g100,
  );

  /// T-h1 — 섹션 헤더 / 05·08 타이틀 대형.
  static const TextStyle h1 = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w900,
    fontSize: 28,
    height: 1.32,
    letterSpacing: -0.03 * 28,
    color: SajuGold.g100,
  );

  /// T-h2 — 카드/서브 타이틀.
  static const TextStyle h2 = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.3,
    letterSpacing: -0.02 * 18,
    color: SajuGold.g100,
  );

  /// T-h3 — 07 블록 타이틀.
  static const TextStyle h3 = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.3,
    letterSpacing: -0.02 * 18,
    color: SajuGold.g100,
  );

  /// T-body — Gowun Batang 본문(이야기/카피).
  static const TextStyle body16 = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.8,
    color: SajuText.fg2,
  );

  static const TextStyle body14 = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.6,
    color: SajuText.muted,
  );

  /// T-ui — Pretendard UI 라벨/버튼.
  static const TextStyle ui16Bold = TextStyle(
    fontFamily: ui,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    letterSpacing: -0.01 * 16,
    color: SajuInk.i900,
  );

  static const TextStyle ui14 = TextStyle(
    fontFamily: ui,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: SajuText.muted,
  );

  static const TextStyle ui12 = TextStyle(
    fontFamily: ui,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    color: SajuText.muted,
  );

  /// T-mono — IBM Plex Mono, 영문 대문자 라벨(0.3em 트래킹).
  static const TextStyle mono10 = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    letterSpacing: 0.3 * 10,
    color: SajuGold.g500,
  );

  static const TextStyle mono9 = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w500,
    fontSize: 9.5,
    letterSpacing: 0.3 * 9.5,
    color: SajuGold.g500,
  );

  /// 한자(원국 글자) — 커다란 Serif Black.
  static TextStyle hanja(double size, {bool highlight = false}) => TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w900,
    fontSize: size,
    height: 1,
    color: SajuGold.g100,
    shadows: highlight
        ? [Shadow(color: SajuGold.g300.withValues(alpha: 0.6), blurRadius: 14)]
        : null,
  );
}

/// 모션(지속시간/이징) — docs/04_모션.md 기준.
class SajuMotion {
  SajuMotion._();
  static const Duration screen = Duration(milliseconds: 300);
  static const Duration card = Duration(milliseconds: 600);
  static const Duration step = Duration(milliseconds: 880); // 권고값
  static const Duration draw = Duration(milliseconds: 1200);
  static const Duration press = Duration(milliseconds: 150);

  /// cubic-bezier(0.22, 0.8, 0.24, 1) ease.sj 근사.
  static const Curve easeSj = Cubic(0.22, 0.8, 0.24, 1.0);
}

/// 간격/반경 — colors_and_type.css 스케일.
class SajuSpace {
  SajuSpace._();
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

class SajuRadius {
  SajuRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}
