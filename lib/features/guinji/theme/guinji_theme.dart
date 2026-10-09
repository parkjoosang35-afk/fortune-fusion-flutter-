import 'package:flutter/material.dart';

import 'guinji_map_theme.dart';

/// 귀인지도(Guinji Map) — 전용 디자인 토큰.
///
/// [2027-02 귀인지도 v2 리스킨 — 핸드오프 최종본] 핸드오프
/// `귀인지도_최종_핸드오프.html` §01(변경 파일 총괄)의 지시
/// "guinji_theme.dart(GuinjiColors)는 GmColors와 같은 값으로 맞출 것"에
/// 따라, 검정(#0B0B0D) 최종 토큰(`guinji_map_theme.dart`의 `GmColors`)과
/// 동일한 값으로 전면 교체한다. 이전 "아이보리 + 로즈골드" 라이트
/// 팔레트는 완전히 폐기한다.
///
/// 색상 상수의 **이름**(backgroundSoft, lavender, textPrimary 등)은 기존
/// `/guinji/*`(구버전, 유지) 화면들이 참조하므로 그대로 유지하고, **값**만
/// `GmColors`와 동일하게 맞춰 화면/로직 코드를 건드리지 않고 리스킨한다.
///
/// 매핑 기준(GmColors → GuinjiColors):
///  - bg(#0B0B0D)              → backgroundSoft/backgroundDeep/backgroundDarker (단색)
///  - fg(#F2F0EC)/muted/dim    → textPrimary/textSecondary
///  - gold(#E9C46A)            → lavender/aqua/gold (강조 전용 액센트)
///  - card(#161618)            → surfaceCard
///  - line(16% white)          → surfaceCardBorder
///
/// 이 파일은 순수 디자인 토큰(색상/타이포)만 다루며 어떤 화폐/잔액/포인트도
/// 정의하지 않는다(절대 원칙 — 재화는 항상 Wallet/PointHistory 경로로만
/// 처리).
class GuinjiColors {
  GuinjiColors._();

  // ── 배경(검정 단색) — 구 backgroundSoft→Deep→Darker 슬롯, 전부 동일값 ──
  static const backgroundSoft = GmColors.bg; // #0B0B0D
  static const backgroundDeep = GmColors.bg; // #0B0B0D
  static const backgroundDarker = GmColors.bg; // #0B0B0D (Scaffold 배경)

  // ── 텍스트 ──
  static const textPrimary = GmColors.fg; // #F2F0EC
  static const textSecondary = GmColors.muted; // 52% fg
  static const paper = GmColors.fg; // 타이틀 전용(밝은 글자)

  // ── 액센트(금색) — 구 lavender 슬롯을 gold로 대체 ──
  static const lavender = GmColors.gold; // #E9C46A (Primary/CTA 강조 전용)
  static const lavenderSoft = GmColors.goldTop; // #F7E4AE (그라데이션 상단)
  static const glowShadow = Color(0x40E9C46A); // gold 25% 근사(그림자)
  static const aqua = GmColors.gold; // #E9C46A
  static const crystalAqua = GmColors.goldTop; // #F7E4AE
  static const gold = GmColors.gold; // #E9C46A
  static const ink = GmColors.onFg; // 흰 버튼 위 글자(#0B0B0D)

  // ── 카드/구분선 ──
  static const surfaceCard = GmColors.card; // #161618
  static const surfaceCardBorder = GmColors.line; // 16% white

  // 에러/경고(삭제·공유 중단)
  static const error = GmColors.danger; // #EF7A55

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSoft, backgroundDeep, backgroundDarker],
  );

  /// 관계유형 6종(CHEON_GWII/HAP/SANG_SAENG/SANG_GEUK/BI_HWA/CHUNG) 색상.
  /// 핸드오프 §03과 동일한 값(`guinji_type_spec.dart`의 GuinjiTypeSpec과
  /// 1:1 대응) — 화면 교체 전 기존 참조처(guinji_relation_meta.dart 등)와의
  /// 호환을 위해 이 이름으로도 노출한다.
  static const relationCheonGwii = Color(0xFFF5CF6A); // 천생귀인 貴
  static const relationHap = Color(0xFFF08AA6); // 인연합 緣
  static const relationSangSaeng = Color(0xFF6FD3A0); // 상생동행 生
  static const relationSangGeuk = Color(0xFFB59CF0); // 상극조율 調
  static const relationBiHwa = Color(0xFF8DBFD6); // 동류동반 同
  static const relationChung = Color(0xFFEF7A55); // 충돌극복 衝

  /// 오행(五行) 5색 — 검정 배경에 맞춘 톤(참고용, 핸드오프에 별도 명시 없음).
  static const ohaengMok = Color(0xFF6FD3A0); // 木
  static const ohaengHwa = Color(0xFFEF7A55); // 火
  static const ohaengTo = Color(0xFFE9C46A); // 土
  static const ohaengGeum = Color(0xFFF2F0EC); // 金
  static const ohaengSu = Color(0xFF8DBFD6); // 水
}

/// 타이포 폰트 패밀리 — [귀인지도 v2 리스킨] 핸드오프 `GmText`의
/// display=NotoSerifKR / body=GowunBatang / ui=Pretendard / mono=IBMPlexMono
/// 4체계에 맞춰 재매핑한다(§02 디자인 토큰).
class GuinjiFonts {
  GuinjiFonts._();

  static const display = GmText.display; // 'NotoSerifKR' — 타이틀·이름·점수·한자
  static const body = GmText.body; // 'GowunBatang' — 장문 풀이 본문
  static const ui = GmText.ui; // 'Pretendard' — 버튼·라벨·노드 이름
  static const mono = GmText.mono; // 'IBMPlexMono' — S1~S5 배지·영문 메타
}
