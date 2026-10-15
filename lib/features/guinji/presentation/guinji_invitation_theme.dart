// lib/features/guinji/presentation/guinji_invitation_theme.dart
// [귀인지도 초대장 리디자인 — design_handoff_guiin_invitation.zip]
// "심야의 신전(Midnight Temple)" 팔레트 — 이 화면(GuinjiMapGuestJoinScreen)
// 전용으로 격리된 디자인 토큰이다.
//
// [기존 테마와의 관계] 이 화면은 기존 `GmColors`/`GmText`(아이보리+로즈골드,
// `guinji_map_theme.dart`)를 사용하지 않는다. 핸드오프
// `colors_and_type.css`의 기본(`:root`) 팔레트가 Midnight Temple이며, 이는
// `intro_palette.dart`의 `IntroPalette`("달빛 크리스탈" — CSS의
// `.palette-crystal` 변형)와도 다른, 완전히 별개의 색 체계다. 프로젝트의
// "화면별 토큰 격리" 관례(`sintong_home_tokens.dart`, `intro_palette.dart`
// 등)를 그대로 따라 이 화면 전용 파일로 새로 만든다 — 전역 테마 파일은
// 건드리지 않는다.
//
// 폰트 패밀리는 기존에 이미 등록된 family 이름(`NotoSerifKR`/`GowunBatang`/
// `IBMPlexMono`, `pubspec.yaml` 참고)을 그대로 재사용한다(새 폰트 자산
// 추가 불필요). UI 칩/입력칸 라벨은 기존 전역 Pretendard를 사용한다.
import 'package:flutter/material.dart';

/// Design Tokens (Midnight Temple) — `colors_and_type.css` 기본 `:root` 값 그대로.
class GiColors {
  GiColors._();

  static const bg1 = Color(0xFF1A0D2E); // 상단 배경
  static const bg2 = Color(0xFF0A0716); // 하단 배경
  static const fg = Color(0xFFF8F2E6); // 본문
  static const muted = Color(0x9EE8DCC8); // rgba(232,220,200,.62)
  static const mutedFaint = Color(0x6BE8DCC8); // rgba(232,220,200,.42) 힌트
  static const mutedFaintest = Color(0x52E8DCC8); // rgba(232,220,200,.32) placeholder
  static const glow = Color(0xFFF5CF6A); // 촛불 금색 — 강조·CTA·선택
  static const glowShadow = Color(0x59F5CF6A); // rgba(245,207,106,.35)
  static const glowShadowSoft = Color(0x24F5CF6A); // rgba(245,207,106,.14) 보더
  static const crystal = Color(0xFF8DBFD6);
  static const accent = Color(0xFFC94A3B); // 인장 빨강
  static const card = Color(0x0DFFEBC8); // rgba(255,235,200,.05)
  static const line = Color(0x1FFFEBC8); // rgba(255,235,200,.12)
  static const hanjiInk = Color(0xFF2A1F14); // 편지 본문
  static const hanjiAccent = Color(0xFF8B3A2B); // 편지 강조("귀인지도")
  static const hanjiMuted = Color(0xB83C2D1E); // rgba(60,45,30,.72) 친구 메시지
  static const hanjiMeta = Color(0x8C3C2D1E); // rgba(60,45,30,.55) 태그/서명

  /// 오버레이 1 — 좌상단 보라빛
  static const overlayTopLeft = Color(0x38785084); // rgba(120,80,200,.22) 근사
  /// 오버레이 2 — 우하단 인장 빨강빛
  static const overlayBottomRight = Color(0x1FC94A3B); // rgba(201,74,59,.12)

  static const wash1 = Color(0x8C0A0716); // rgba(10,7,22,.55)
  static const wash2 = Color(0x001A0D2E); // transparent
  static const wash3 = Color(0xD91A0D2E); // rgba(26,13,46,.85)
}

/// 폰트 패밀리 — 기존 등록된 family 재사용.
class GiFonts {
  GiFonts._();
  static const display = 'NotoSerifKR'; // 제목 · 인장 · CTA
  static const body = 'GowunBatang'; // 캡션 · 편지 본문 · 인용구
  static const ui = 'Pretendard'; // 입력 · 라벨 · 칩
  static const mono = 'IBMPlexMono'; // 메타 라벨(대문자 · 넓은 자간)
}

/// 라운드 — README "라운드" 섹션 그대로.
class GiRadius {
  GiRadius._();
  static const seal = 6.0;
  static const letter = 6.0;
  static const checkbox = 6.0;
  static const field = 14.0;
  static const consentCard = 16.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}
