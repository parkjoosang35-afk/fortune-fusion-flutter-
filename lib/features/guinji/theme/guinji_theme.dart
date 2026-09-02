import 'package:flutter/material.dart';

/// 귀인지도(Guinji Map) — 전용 디자인 토큰.
///
/// [2026-11 리스킨] 기존 "Moonlit Crystal(달빛 크리스탈)" 다크 팔레트를
/// 신규 디자인 핸드오프(`flutter (1).zip` → `lib/guiindo/theme/colors.dart`
/// `AppColors`)의 "아이보리 + 로즈골드" 라이트 팔레트로 전면 교체한다.
/// 색상 상수의 **이름**(backgroundSoft, lavender, textPrimary 등)은 8화면
/// (`guinji_landing_screen.dart` 등)과 공통 위젯 키트(`guinji_ui_kit.dart`)가
/// 이미 참조하고 있으므로 그대로 유지하고, **값**만 새 팔레트로 교체해
/// 화면/로직 코드를 건드리지 않고 리스킨한다(매핑 방식).
///
/// 매핑 기준(AppColors → GuinjiColors):
///  - bgCream/bgIvory      → backgroundSoft/backgroundDeep/backgroundDarker
///  - ink/inkSoft            → textPrimary/textSecondary
///  - rose500(Primary)       → lavender(기존 라벤더 액센트 슬롯을 그대로 사용)
///  - gold                   → gold/aqua
///  - 화이트 카드 + line 테두리 → surfaceCard/surfaceCardBorder
///
/// 이 파일은 순수 디자인 토큰(색상/타이포)만 다루며 어떤 화폐/잔액/포인트도
/// 정의하지 않는다(절대 원칙 — 재화는 항상 Wallet/PointHistory 경로로만
/// 처리).
class GuinjiColors {
  GuinjiColors._();

  // ── 배경 그라디언트(아이보리 + 크림) — 구 backgroundSoft→Deep→Darker 슬롯 ──
  static const backgroundSoft = Color(0xFFF5EBDC); // AppColors.bgCream
  static const backgroundDeep = Color(0xFFFBF7EF); // AppColors.bgIvory
  static const backgroundDarker = Color(0xFFFBF7EF); // Scaffold 배경(bgIvory)

  // ── 텍스트 ──
  static const textPrimary = Color(0xFF2A2438); // AppColors.ink
  static const textSecondary = Color(0xFF6E5A54); // AppColors.inkSoft
  static const paper = Color(0xFFFBF7EF); // AppColors.ivory(타이틀 전용)

  // ── 액센트(로즈골드) — 구 lavender 슬롯을 rose500으로 대체 ──
  static const lavender = Color(0xFFC99B7F); // AppColors.rose500 (Primary/CTA)
  static const lavenderSoft = Color(0xFFF5D9C9); // AppColors.rose100
  static const glowShadow = Color(0x40C99B7F); // rose500 25% 근사(그림자)
  static const aqua = Color(0xFFD4A574); // AppColors.gold
  static const crystalAqua = Color(0xFFE8CBA0); // AppColors.goldLight
  static const gold = Color(0xFFD4A574); // AppColors.gold
  static const ink = Color(0xFFFFFFFF); // CTA 텍스트(로즈 배경 위 화이트)

  // ── 카드/구분선(화이트 카드 + 라인 테두리) ──
  static const surfaceCard = Color(0xFFFFFFFF); // 카드 배경(불투명 화이트)
  static const surfaceCardBorder = Color(0xFFE8DDD0); // AppColors.line

  // 에러/경고 텍스트(아이보리 배경에서도 식별 가능한 진한 로즈레드)
  static const error = Color(0xFFC65D5D);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSoft, backgroundDeep, backgroundDarker],
  );

  /// 12라벨(貴人地圖 관계 라벨) 색상 — 로즈골드 아이보리 팔레트에 맞춰
  /// 파스텔 웜톤으로 재조정(기존 다크 배경용 네온 파스텔 → 라이트 배경용
  /// 저채도 톤). 관계 유형별 구분은 유지하면서 전체적으로 채도를 낮추고
  /// 배경(아이보리)과 대비가 확보되도록 톤을 조정했다.
  static const relationCheonGwii = Color(0xFFC99B7F); // 천생귀인 (rose500)
  static const relationNaSalrida = Color(0xFFD4A574); // 나를 살리는 사람 (gold)
  static const relationJoryeok = Color(0xFF8FA68C); // 조력자 (세이지그린)
  static const relationGachiGa = Color(0xFFA6795E); // 같이 가야 좋은 길 (rose700)
  static const relationNaSaljinda = Color(0xFFE8B4A5); // 내가 살리는 사람 (blush)
  static const relationChangGyim = Color(0xFFB58567); // 내가 챙기는 사람 (rose600)
  static const relationGamjeong = Color(0xFFC9A5C9); // 감정 충전소 (더스티 라일락)
  static const relationDeungdeung = Color(0xFF8B9DAE); // 든든한 등받이 (더스티 블루)
  static const relationKkeurida = Color(0xFFD69175); // 끌리는 사람 (rose400)
  static const relationGachiBich = Color(0xFFE8CBA0); // 같이 빛나는 사람 (goldLight)
  static const relationJageukje = Color(0xFFCC8B5C); // 자극제 (버뮤트 오렌지)
  static const relationGingjang = Color(0xFF9C8AA5); // 긴장 속 단짝 (더스티 퍼플)

  /// 오행(五行) 5색 — 로즈골드 아이보리 팔레트에 맞춘 저채도 톤.
  static const ohaengMok = Color(0xFF8FA68C); // 木 (세이지그린)
  static const ohaengHwa = Color(0xFFD69175); // 火 (rose400)
  static const ohaengTo = Color(0xFFD4A574); // 土 (gold)
  static const ohaengGeum = Color(0xFFE8DDD0); // 金 (line, 은은한 아이보리)
  static const ohaengSu = Color(0xFF8B9DAE); // 水 (더스티 블루)
}

/// 타이포 폰트 패밀리 — [2026-11 리스킨] 신규 디자인 핸드오프의
/// `AppFonts`(serif=NotoSerifKR, sans=Pretendard)에 맞춰 재매핑한다.
/// pubspec.yaml에 `NotoSerifKR`/`Pretendard`가 이미 등록되어 있으므로 별도
/// 폰트 asset 추가는 필요 없다. 기존 `GowunBatangWish`/`IBMPlexMonoWish`
/// 대신 본문·모노 슬롯도 새 팔레트 톤에 맞춰 `NotoSerifKR`/`Pretendard`로
/// 통일한다(로즈골드 디자인은 손글씨체 느낌의 GowunBatang을 사용하지 않음).
class GuinjiFonts {
  GuinjiFonts._();

  static const display = 'NotoSerifKR'; // --font-display (구 NotoSerifKRWish)
  static const body = 'Pretendard'; // --font-body (구 GowunBatangWish)
  static const ui = 'Pretendard'; // --font-ui (앱 전역 기본 폰트)
  static const mono = 'Pretendard'; // --font-mono (구 IBMPlexMonoWish)
}
