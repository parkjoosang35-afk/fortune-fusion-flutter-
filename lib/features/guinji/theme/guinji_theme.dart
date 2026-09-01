import 'package:flutter/material.dart';

/// 귀인지도(Guinji Map) — 전용 디자인 토큰.
///
/// [신통방통_귀인지도_최종_개발계획서_v2.0.md §9 / design_handoff_home_redesign
/// (3).zip → assets/colors_and_type.css `[data-palette="crystal"]`] "Moonlit
/// Crystal(달빛 크리스탈)" 팔레트를 그대로 이식한다. 이 파일은 순수 디자인
/// 토큰(색상/타이포/spacing)만 다루며 어떤 화폐/잔액/포인트도 정의하지
/// 않는다(절대 원칙 — 재화는 항상 Wallet/PointHistory 경로로만 처리).
///
/// [팔레트 확장 여지] `ERROR_STATES_AND_MOTION.md`는 Crystal 외 Hanji(라이트)
/// / Midnight(이벤트) 2종을 추가로 정의하지만, Phase G-1(온보딩 1화면)에서는
/// Crystal 하나만 사용한다. 다크모드 자동전환·팔레트 선택 UI는 후속 Phase에서
/// ThemeExtension으로 확장한다.
class GuinjiColors {
  GuinjiColors._();

  // ── Moonlit Crystal 배경 그라디언트 (bg-1 → bg-2) ──
  static const backgroundSoft = Color(0xFF3D3568); // --bg-1
  static const backgroundDeep = Color(0xFF1E1A3A); // --bg-2
  static const backgroundDarker = Color(0xFF14102A); // 배너 하단(README 참고)

  // ── 텍스트 ──
  static const textPrimary = Color(0xFFF0EAFF); // --fg
  static const textSecondary = Color(0xA6DCD2F5); // --muted (65% 근사)
  static const paper = Color(0xFFF8F2E6); // 타이틀 전용(README 배너 title)

  // ── 액센트 ──
  static const lavender = Color(0xFFE8C8F5); // --glow / --sigil (CTA·강조)
  static const lavenderSoft = Color(0xFFF5E4FB);
  static const glowShadow = Color(0x59E8C8F5); // rgba(232,200,245,0.35)
  static const aqua = Color(0xFF7FB8D4); // --accent
  static const crystalAqua = Color(0xFFA8D5E3); // --crystal
  static const gold = Color(0xFFF5D97A); // 타이틀 그라디언트 시작·스파클
  static const ink = Color(0xFF1A0D2E); // CTA 텍스트(라벤더 배경 위)

  // ── 카드/구분선 ──
  static const surfaceCard = Color(0x14C8B4FF); // rgba(200,180,255,0.08)
  static const surfaceCardBorder = Color(0x26DCC8FF); // rgba(220,200,255,0.15)

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSoft, backgroundDeep, backgroundDarker],
  );

  /// 12라벨(貴人地圖 관계 라벨) 색상 — admin_web `src/app/g/[token]/page.tsx`의
  /// `RELATION_COLOR`(PRD "신통방통 · 귀인지도 섹션 PRD" v0.9 기준으로
  /// 전면 재작성됨)와 동일한 HEX 값을 그대로 이식한다. 기존 5색
  /// (relationGuin 등)은 [2026-09 12라벨 전환] 작업으로 완전히 대체되었다.
  static const relationCheonGwii = Color(0xFFF5D97A); // 천생귀인
  static const relationNaSalrida = Color(0xFFE8C8F5); // 나를 살리는 사람
  static const relationJoryeok = Color(0xFFA8D5E3); // 조력자
  static const relationGachiGa = Color(0xFFC8F5D5); // 같이 가야 좋은 길
  static const relationNaSaljinda = Color(0xFFF5C8D5); // 내가 살리는 사람
  static const relationChangGyim = Color(0xFFE8C890); // 내가 챙기는 사람
  static const relationGamjeong = Color(0xFFD5C8F5); // 감정 충전소
  static const relationDeungdeung = Color(0xFFA5B5E8); // 든든한 등받이
  static const relationKkeurida = Color(0xFFF5A8BD); // 끌리는 사람
  static const relationGachiBich = Color(0xFFF5D97A); // 같이 빛나는 사람
  static const relationJageukje = Color(0xFFF5B880); // 자극제
  static const relationGingjang = Color(0xFFB5A8E8); // 긴장 속 단짝

  /// 오행(五行) 5색 — `GUINJI_SCREENS.md` "오행 5색" 표.
  static const ohaengMok = Color(0xFF7FB8D4); // 木
  static const ohaengHwa = Color(0xFFE8A5B8); // 火
  static const ohaengTo = Color(0xFFE8C890); // 土
  static const ohaengGeum = Color(0xFFE8E0F5); // 金
  static const ohaengSu = Color(0xFFA8A5E8); // 水
}

/// 타이포 폰트 패밀리 — README/`colors_and_type.css` `--font-*` 변수를
/// pubspec.yaml에 이미 등록된 로컬 폰트 패밀리명으로 매핑한다.
/// (Wish Room이 `GowunBatangWish`/`IBMPlexMonoWish`로 이미 등록해 둔 자산을
/// 재사용 — 새 폰트 asset을 추가하지 않는다.)
class GuinjiFonts {
  GuinjiFonts._();

  static const display = 'NotoSerifKRWish'; // --font-display 대응 존재 시 사용
  static const body = 'GowunBatangWish'; // --font-body
  static const ui = 'Pretendard'; // --font-ui (앱 전역 기본 폰트)
  static const mono = 'IBMPlexMonoWish'; // --font-mono
}
