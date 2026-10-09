// lib/features/guinji_map/theme/guinji_map_theme.dart
// 최종(v2) 토큰 — 기존 GmColors/GmText 상수만 교체하면 전 화면 반영 (명세서 §8)
// guinji_theme.dart 의 GuinjiColors 도 같은 값으로 맞출 것
import 'package:flutter/material.dart';

class GmColors {
  static const bg      = Color(0xFF0B0B0D); // 전 화면 배경 (단색 · 그라데이션/별 없음)
  static const card    = Color(0xFF161618); // 캐릭터 카드 · 카드
  static const sheet   = Color(0xFF111113); // 바텀시트 (결제 · 공유)
  static const tabBar  = Color(0xFF18181B);
  static const fg      = Color(0xFFF2F0EC); // 본문 · 흰 알약 버튼 배경
  static const onFg    = Color(0xFF0B0B0D); // 흰 버튼 위 글자
  static const muted   = Color(0x85F2F0EC); // 52%
  static const dim     = Color(0x52F2F0EC); // 32%
  static const line    = Color(0x29FFFFFF); // 16% 테두리
  static const hair    = Color(0x14FFFFFF); // 8% 헤어라인
  static const gold    = Color(0xFFE9C46A); // 강조 (랭킹 1위 · 마일스톤 · 인트로 CTA · 프리패스)
  static const goldTop = Color(0xFFF7E4AE); // 인트로 CTA 그라데이션 위
  static const mapLine = Color(0x38FFFFFF); // 지도 방사선 22%
  static const mapWeb  = Color(0x1AFFFFFF); // 같은 유형 이웃선 10%
  static const danger  = Color(0xFFEF7A55); // 삭제 · 공유 중단
}

class GmText {
  static const display = 'NotoSerifKR';  // 타이틀 · 이름(카드) · 점수 숫자 · 한자
  static const body    = 'GowunBatang';  // 장문 풀이 본문 16/1.85
  static const ui      = 'Pretendard';   // 버튼 · 라벨 · 노드 이름
  static const mono    = 'IBMPlexMono';  // S1~S5 배지 · 영문 메타 (대문자, 자간 0.3em)

  static const mapTitle   = TextStyle(fontFamily: display, fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.6, color: GmColors.fg);
  static const mapSub     = TextStyle(fontFamily: ui, fontSize: 13.5, color: GmColors.muted);
  static const nodeName   = TextStyle(fontFamily: ui, fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xC7F2F0EC)); // 11명+: 11.5
  static const nodeType   = TextStyle(fontFamily: ui, fontSize: 11, fontWeight: FontWeight.w500);                           // 유형색 · 11명+: 10.5
  static const cardName   = TextStyle(fontFamily: display, fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: GmColors.fg);
  static const cardScore  = TextStyle(fontFamily: display, fontSize: 34, fontWeight: FontWeight.w600);
  static const typeBig    = TextStyle(fontFamily: display, fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.6);
  static const deepTitle  = TextStyle(fontFamily: display, fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.75, height: 1.3);
  static const chapter    = TextStyle(fontFamily: display, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, height: 1.35);
  static const deepBody   = TextStyle(fontFamily: body, fontSize: 16, height: 1.85, color: Color(0xDBF2F0EC));
  static const button     = TextStyle(fontFamily: ui, fontSize: 15, fontWeight: FontWeight.w600, color: GmColors.onFg);
  static const caption    = TextStyle(fontFamily: ui, fontSize: 12.5, fontWeight: FontWeight.w500, color: GmColors.dim);
}

class GmRadius {
  static const pill = 999.0;   // 모든 버튼 · 칩
  static const card = 34.0;    // 인물 캐릭터 카드
  static const sheet = 28.0;   // 바텀시트 상단
  static const box = 16.0;     // 일반 카드 · 링크 행
  static const phoneSafeBottom = 34.0;
}

/// 공통 버튼: 높이 52~54 · 흰 알약(primary) / 테두리(ghost)
ButtonStyle gmPrimary() => ElevatedButton.styleFrom(
  backgroundColor: GmColors.fg, foregroundColor: GmColors.onFg, elevation: 0,
  minimumSize: const Size.fromHeight(54), shape: const StadiumBorder(), textStyle: GmText.button);
ButtonStyle gmGhost() => OutlinedButton.styleFrom(
  foregroundColor: GmColors.fg, side: const BorderSide(color: GmColors.line),
  minimumSize: const Size.fromHeight(54), shape: const StadiumBorder(), textStyle: GmText.button);
