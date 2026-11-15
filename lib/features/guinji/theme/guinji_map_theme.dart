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
  // 신규: 카카오/주요 CTA 버튼(TpBtn kind='gold') — 금색과는 별개 토큰
  static const gjPrimary = Color(0xFFFEE500);
  static const gjOnPrimary = Color(0xFF191600);
  static const mapLine = Color(0x38FFEBC8); // 지도 방사선
  static const mapWeb = Color(0x1AFFEBC8); // 같은 유형 이웃선
  static const danger = Color(0xFFEF7A55); // 삭제 · 공유 중단(= 충돌극복 색과 동일 계열)
  static const red = Color(0xFFC94A3B); // TP.red — 초대장 박스 포인트

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
  static const display = 'NotoSerifKR'; // 타이틀 · 이름(카드) · 점수 숫자 · 한자
  // [폰트 전환 — 2026-11] GowunBatang -> Pretendard. 장문 풀이 본문 16/1.85
  static const body = 'Pretendard';
  static const ui = 'Pretendard'; // 버튼 · 라벨 · 노드 이름
  static const mono = 'IBMPlexMono'; // S1~S5 배지 · 영문 메타 (대문자, 자간 0.3em)

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
    color: GmColors.onFg,
  );
  static const caption = TextStyle(
    fontFamily: ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: GmColors.dim,
  );
}

class GmRadius {
  static const pill = 999.0; // 모든 버튼 · 칩
  static const card = 34.0; // 인물 캐릭터 카드
  static const sheet = 28.0; // 바텀시트 상단
  static const box = 16.0; // 일반 카드 · 링크 행
  static const phoneSafeBottom = 34.0;
}

/// 공통 버튼: 높이 52~54 · 흰 알약(primary) / 테두리(ghost)
ButtonStyle gmPrimary() => ElevatedButton.styleFrom(
  backgroundColor: GmColors.fg,
  foregroundColor: GmColors.onFg,
  elevation: 0,
  minimumSize: const Size.fromHeight(54),
  shape: const StadiumBorder(),
  textStyle: GmText.button,
);
ButtonStyle gmGhost() => OutlinedButton.styleFrom(
  foregroundColor: GmColors.fg,
  side: const BorderSide(color: GmColors.line),
  minimumSize: const Size.fromHeight(54),
  shape: const StadiumBorder(),
  textStyle: GmText.button,
);
