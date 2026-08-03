import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// 07단계(추가) §3.4 - 상담 유형(사주/타로/일반)별 시각 테마 정의.
/// ConsultationTypeScreen(카드 선택)과 ConsultationChatScreen(헤더/말풍선)에서
/// 동일한 색상/아이콘/그라디언트를 공유하기 위해 이 파일로 중앙화한다.
///
/// ▸ 사주(saju): 🔮 보라색 계열 + 골드 복주머니
/// ▸ 타로(tarot): 🃏 레드/블랙 계열
/// ▸ 일반(general): 💬 블루/그레이 계열
class ConsultationTypeStyle {
  final String type;
  final String emoji;
  final IconData icon;
  final String label;
  final String description;
  final Color primaryColor;
  final Color accentColor;
  final Color containerColor;
  final LinearGradient gradient;

  const ConsultationTypeStyle({
    required this.type,
    required this.emoji,
    required this.icon,
    required this.label,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
    required this.containerColor,
    required this.gradient,
  });

  static const saju = ConsultationTypeStyle(
    type: 'saju',
    emoji: '🔮',
    icon: Icons.auto_stories_rounded,
    label: '사주상담',
    description: 'AI가 나의 사주를 바탕으로 대화해드려요',
    primaryColor: AppColors.primary,
    accentColor: AppColors.secondary,
    containerColor: AppColors.primaryContainer,
    gradient: LinearGradient(
      colors: [AppColors.primary, AppColors.secondaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const tarot = ConsultationTypeStyle(
    type: 'tarot',
    emoji: '🃏',
    icon: Icons.style_rounded,
    label: '타로상담',
    description: '고민을 말하면 타로의 의미로 답해드려요',
    primaryColor: Color(0xFFD1355A),
    accentColor: Color(0xFF1E1A2B),
    containerColor: Color(0xFFFBE1E8),
    gradient: LinearGradient(
      colors: [Color(0xFFD1355A), Color(0xFF1E1A2B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const general = ConsultationTypeStyle(
    type: 'general',
    emoji: '💬',
    icon: Icons.chat_bubble_rounded,
    label: '고민상담',
    description: '오늘의 고민을 편하게 나눠보세요',
    primaryColor: AppColors.info,
    accentColor: AppColors.textSecondary,
    containerColor: Color(0xFFE3F0FF),
    gradient: LinearGradient(
      colors: [AppColors.info, AppColors.textSecondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const List<ConsultationTypeStyle> all = [saju, tarot, general];

  static ConsultationTypeStyle of(String type) {
    return all.firstWhere((e) => e.type == type, orElse: () => general);
  }
}
