// lib/features/guinji_map/theme/guinji_map_theme.dart
// [2026 디자인 핸드오프 v5 — "심야의 신전(Midnight Temple)" 전면 교체]
// `design_handoff_guinji_map_v5/design_files/guinji-temple.jsx`의 `TP` 전역
// 색상 상수를 1:1 이식한다. 기존 GmColors/GmText 상수만 교체하면 전 화면에
// 즉시 반영된다. guinji_theme.dart 의 GuinjiColors 도 같은 값으로 맞출 것.
import 'package:flutter/material.dart';

class GmColors {
  // ── 배경: 보라빛 "심야의 신전" 그라데이션(위→아래) ──
  // 단색 배경이 필요한 곳(Scaffold.backgroundColor 등)은 bg(중간톤 근사치)를
  // 쓰고, 지도 메인처럼 그라데이션 전체를 보여줘야 하는 화면은 [bgGradient]를
  // 사용한다.
  static const bgTop = Color(0xFF1A0D2E); // TP.bg1
  static const bgBottom = Color(0xFF0A0716); // TP.bg2
  static const bg = Color(0xFF120A1F); // 단색 폴백(= bgTop/bgBottom 중간)
  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );
  static const card = Color(0xFF1C1230); // TP.cardS — 캐릭터 카드 · 카드
  static const sheet = Color(0xFF170E29); // TP.sheet — 바텀시트 (결제 · 공유)
  static const tabBar = Color(0xFF0D0819); // 하단 탭바
  static const fg = Color(0xFFF8F2E6); // TP.fg — 본문 · 밝은 글자
  static const onFg = Color(0xFF1A0D2E); // TP.ink — 금색 버튼 위 글자
  static const muted = Color(0x9EE8DCC8); // TP.mut 62%
  static const dim = Color(0x66E8DCC8); // TP.dim 40%
  static const line = Color(0x24FFEBC8); // TP.line 14%
  static const hair = Color(0x14FFEBC8); // TP.hair 8%
  static const gold = Color(0xFFF5CF6A); // TP.gold — 강조(랭킹·마일스톤·인장)
  static const goldTop = Color(0xFFFCE7B0); // 그라데이션 상단(밝은 금)
  static const goldShadow = Color(0x59F5CF6A); // TP.goldSh 35%
  static const mapLine = Color(0x38FFEBC8); // 지도 방사선
  static const mapWeb = Color(0x1AFFEBC8); // 같은 유형 이웃선
  static const danger = Color(0xFFEF7A55); // 삭제 · 공유 중단(= 충돌극복 색과 동일 계열)
  static const red = Color(0xFFC94A3B); // TP.red — 초대장 박스 포인트

  // ── [2026 디자인 핸드오프 v5 — SPEC.md §2] ──────────────────────────
  // ★ 모든 주요 CTA(Primary 버튼)는 이 카카오 노랑 하나만 사용한다.
  // 기존 `gjPrimary`/`gjOnPrimary`(0곳 참조)를 SPEC 명칭으로 교체했다 —
  // QA_CHECKLIST.md §1 "로즈골드·금색·흰색 버튼 0곳" 요구에 따라
  // [GmPrimaryButton]/[GmRoseButton]/[gmPrimary]가 전부 이 색으로
  // 통일된다(흰 알약·금 그라데이션 버튼은 전부 폐기).
  static const primary = Color(0xFFFEE500);
  static const onPrimary = Color(0xFF191600);
  static const primaryShadow = Color(0x47FEE500); // rgba(254,229,0,.28)
  static const disabledBg = Color(0x14FFEBC8); // rgba(255,235,200,.08) — 버튼 비활성
  static const sheetDim = Color(0xAD06030E); // rgba(6,3,14,.68) — 바텀시트 딤

  /// SPEC §2 `card` 원본값(반투명 하이라이트) — 배경 그라데이션 위에 얹는
  /// "떠 있는" 카드용. 기존 [card](불투명 #1C1230)는 다이얼로그·바텀시트
  /// 내부처럼 또렷한 표면이 필요한 26곳에서 이미 쓰이고 있어 그대로 두고,
  /// 화면별 SPEC 재작업(H4/H6 등) 시 이 값을 새로 쓴다.
  static const cardTint = Color(0x0DFFEBC8); // rgba(255,235,200,.05)

  // [2026-12 버그수정 — 귀인지도 공유 화면 공유옵션 대비 문제]
  // `fg`/`muted`는 다크 배경(`bg`/`card`/`sheet`) 전용 글자색으로 설계됐다.
  // 공유 화면의 "문자(SMS)로 공유"/"더보기" 버튼은 카카오 버튼과 레이아웃을
  // 맞추려고 컨테이너 배경을 `Colors.white`(흰색)로 하드코딩했는데, 글자색은
  // 그대로 `fg`(#F2F0EC, 거의 흰색)/`muted`(#F2F0EC 52%)를 썼다 — 흰 배경 위에
  // 거의 흰 글자라 실측 대비 1.34~3.20:1로 WCAG AA(4.5:1) 미달, 사용자가
  // "글씨가 안 보인다"고 리포트. 흰(라이트) 배경 전용 글자색을 별도로 정의해
  // 이런 라이트 카드에서만 사용한다(다크 배경 쪽 `fg`/`muted`는 그대로 유지).
  static const fgOnLight = Color(0xFF2A2438); // 라이트 카드 제목 — 대비 ~13.6:1
  static const mutedOnLight = Color(0xFF6E5A54); // 라이트 카드 설명 — 대비 ~5.2:1
}

class GmText {
  // ── [2026 디자인 핸드오프 v5 — SPEC.md §1] ──────────────────────────
  // SPEC은 "귀인지도 통합 폰트 1종"을 요구한다 — 위계는 글꼴을 바꾸는 게
  // 아니라 굵기(FontWeight)/자간(letterSpacing)만으로 구현한다. SPEC의
  // placeholder family명은 `kGjFont = 'GuinjiUnified'`(실제 적용할
  // family가 아직 미정)이고, 프로젝트 전역에서 이미 Pretendard를 기본
  // 폰트로 쓰고 있어(6개 굵기 전부 pubspec.yaml에 등록됨) 통합 폰트로
  // Pretendard를 채택한다. display/body/ui/mono 4개 이름은 호출부
  // 20여 곳이 그대로 참조하므로 이름은 유지하고 값만 전부 통일한다.
  static const display = 'Pretendard'; // 타이틀 · 이름(카드) · 점수 숫자 · 한자
  static const body = 'Pretendard';
  static const ui = 'Pretendard'; // 버튼 · 라벨 · 노드 이름
  static const mono = 'Pretendard'; // S1~S5 배지 · 영문 메타 (대문자, 자간 0.3em — gjMeta)

  static const mapTitle = TextStyle(
    fontFamily: display,
    fontSize: 30,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    color: GmColors.fg,
  );
  static const mapSub = TextStyle(
    fontFamily: ui,
    fontSize: 13.5,
    color: GmColors.muted,
  );
  static const nodeName = TextStyle(
    fontFamily: ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: Color(0xC7F2F0EC),
  ); // 11명+: 11.5
  static const nodeType = TextStyle(
    fontFamily: ui,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  ); // 유형색 · 11명+: 10.5
  static const cardName = TextStyle(
    fontFamily: display,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: GmColors.fg,
  );
  static const cardScore = TextStyle(
    fontFamily: display,
    fontSize: 34,
    fontWeight: FontWeight.w600,
  );
  static const typeBig = TextStyle(
    fontFamily: display,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );
  static const deepTitle = TextStyle(
    fontFamily: display,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.75,
    height: 1.3,
  );
  static const chapter = TextStyle(
    fontFamily: display,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.35,
  );
  static const deepBody = TextStyle(
    fontFamily: body,
    fontSize: 16,
    height: 1.85,
    color: Color(0xDBF2F0EC),
  );
  static const button = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: GmColors.onPrimary, // SPEC §2 — Primary 버튼은 카카오 노랑 위 잉크색
  );
  static const caption = TextStyle(
    fontFamily: ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: GmColors.dim,
  );
}

/// ── [2026 디자인 핸드오프 v5 — SPEC.md §2 "라운드"] ──────────────────────
/// SPEC 표: 인장 4~6 · 칩 10~12 · 입력·버튼 14 · 카드 16~18 · 시트 상단 24 ·
/// 아바타 원형. 기존 멤버명(pill/card/sheet/box/phoneSafeBottom)은
/// `guinji_node_sheet.dart`(sheet 1곳)만 참조 중이라 이름은 그대로 두고
/// 값만 SPEC 기준으로 갱신하며, SPEC 명칭(seal/chip/input/button)도
/// 신규로 함께 추가해 앞으로의 화면별 작업에서 바로 쓸 수 있게 한다.
class GmRadius {
  static const seal = 5.0; // 인장(4~6 평균)
  static const chip = 11.0; // 칩(10~12 평균)
  static const input = 14.0; // 입력창
  static const button = 14.0; // 버튼(Primary/Ghost/Rose 공통)
  static const card = 17.0; // 일반 카드(16~18 평균) — 캐릭터 카드도 동일 적용
  static const sheet = 24.0; // 바텀시트 상단

  // ── 구 멤버명(호환 유지, 값은 SPEC 기준 재매핑) ──
  static const pill = button; // 기존 "완전 알약" 버튼 모양은 폐기 → button(14)
  static const box = card; // 일반 카드 · 링크 행
  static const phoneSafeBottom = 24.0;
}

/// SPEC §2 초대장 박스 그라데이션(135°, #B8402F → #8A2A22(55%) → #5E1A1E),
/// 테두리는 별도로 `rgba(245,207,106,.45)`(= GmColors.gold 45% 근사)를 쓴다.
const gmInviteBoxGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFB8402F), Color(0xFF8A2A22), Color(0xFF5E1A1E)],
  stops: [0, 0.55, 1],
);

/// 공통 버튼: 높이 54 · SPEC §2 Primary(카카오 노랑 단색) / Ghost(테두리)
/// [2026 디자인 핸드오프 v5] 기존 "흰 알약(StadiumBorder)"은 QA_CHECKLIST.md
/// §1 "로즈골드 · 금색 · 흰색 버튼 0곳" 요구에 따라 폐기하고, 라운드
/// 14(GmRadius.button) + 카카오 노랑(GmColors.primary) 단색으로 교체한다.
ButtonStyle gmPrimary() => ElevatedButton.styleFrom(
  backgroundColor: GmColors.primary,
  foregroundColor: GmColors.onPrimary,
  disabledBackgroundColor: GmColors.disabledBg,
  disabledForegroundColor: GmColors.dim,
  elevation: 0,
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(GmRadius.button),
  ),
  textStyle: GmText.button,
);
ButtonStyle gmGhost() => OutlinedButton.styleFrom(
  foregroundColor: GmColors.fg,
  side: const BorderSide(color: GmColors.line),
  minimumSize: const Size.fromHeight(54),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(GmRadius.button),
  ),
  textStyle: GmText.button,
);
