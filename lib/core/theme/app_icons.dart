import 'package:flutter/material.dart';

/// 03단계 §4 아이콘 시스템 — 도메인별 표준 아이콘 중앙 관리
/// 기본 스타일: Rounded. Outlined는 "비활성/미선택 상태" 전용으로만 예외 허용.
/// 신규 화면은 이 클래스의 상수를 우선 참조하고, 기존 화면은 점진 교체한다.
class AppIcons {
  AppIcons._();

  // ── 운세/AI 콘텐츠 ──
  static const IconData fortuneDaily = Icons.wb_twilight_rounded; // 운세(종합/일간)
  static const IconData saju = Icons.auto_stories_rounded; // 사주
  static const IconData tarot = Icons.style_rounded; // 타로
  static const IconData palm = Icons.back_hand_rounded; // 손금
  static const IconData face = Icons.face_retouching_natural_rounded; // 관상
  static const IconData aiConsultation = Icons.chat_bubble_rounded; // AI상담
  static const IconData aiHighlight = Icons.auto_awesome_rounded; // AI추천/마법 강조

  // ── 리워드 ──
  static const IconData luckyBag = Icons.card_giftcard_rounded; // 복주머니
  static const IconData giftcard = Icons.receipt_long_outlined; // 상품권
  static const IconData ranking = Icons.leaderboard_rounded; // 랭킹
  static const IconData attendance = Icons.calendar_month_rounded; // 출석체크
  static const IconData mission = Icons.checklist_rounded; // 미션
  static const IconData wallet = Icons.wallet_rounded; // 복주머니 지갑
  static const IconData event = Icons.celebration_rounded; // 이벤트(신규 표준)

  // ── 커뮤니티/기타 ──
  static const IconData community =
      Icons.chat_bubble_outline_rounded; // 커뮤니티/소원게시판(신규 표준)
  static const IconData notificationOff =
      Icons.notifications_none_rounded; // 알림(읽지않음 없음)
  static const IconData notificationOn =
      Icons.notifications_rounded; // 알림(읽지않음 있음)
  static const IconData profile = Icons.person_rounded; // 프로필
  static const IconData chevronRight = Icons.chevron_right_rounded; // 목록 이동 화살표
}
