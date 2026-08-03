import 'package:flutter/material.dart';
import '../../theme/app_unified_style.dart';
import '../premium_card.dart';

/// 재사용 위젯 ① HeroSummaryCard — 결과 화면 섹션 1(히어로 요약 카드).
///
/// 배경 #F0EEFB(cardMain), radius16, padding16.
/// 상단: 이름 + 오늘 날짜(Caption12) + 상태뱃지(보통/상승/주의) /
/// 중앙: 점수(TitleLarge17)+"/100" / 한줄 총평(Body14 SemiBold) /
/// 보조 설명 1문장(Body14) / 오늘의 키워드 chip 2~3개(Label12 SemiBold).
///
/// 무료 노출 섹션이라 잠금 표기가 없다. 데이터 부족 시에는 [notice]에
/// "정보를 다시 확인해주세요" 안내 문구를 넘겨 담백하게 표시한다(§7 상태처리).
class HeroSummaryCard extends StatelessWidget {
  const HeroSummaryCard({
    super.key,
    required this.name,
    required this.date,
    required this.score,
    required this.headline,
    this.maxScore = 100,
    this.notice,
    this.statusLabel,
    this.keywords = const [],
    this.subDescription,
  });

  final String name;
  final DateTime date;
  final int score;
  final int maxScore;
  final String headline;
  final String? notice;
  final String? statusLabel;
  final List<String> keywords;
  final String? subDescription;

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${date.month}월 ${date.day}일';
    return PremiumCard(
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$name · $dateLabel', style: UnifiedText.caption()),
              ),
              if (statusLabel != null) _StatusChip(label: statusLabel!),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$score', style: UnifiedText.titleLarge()),
              const SizedBox(width: 2),
              Text('/$maxScore', style: UnifiedText.body()),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(headline, style: UnifiedText.bodyStrong()),
          if (subDescription != null) ...[
            const SizedBox(height: 4),
            Text(subDescription!, style: UnifiedText.body()),
          ],
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: UnifiedTokens.spaceSm),
            Wrap(
              spacing: UnifiedTokens.spaceSm,
              runSpacing: UnifiedTokens.spaceXs,
              children: keywords.map((k) => _KeywordChip(label: k)).toList(),
            ),
          ],
          if (notice != null) ...[
            const SizedBox(height: UnifiedTokens.spaceSm),
            Text(notice!, style: UnifiedText.caption()),
          ],
        ],
      ),
    );
  }
}

/// 상단 우측 상태뱃지 — "보통/상승/주의" 담백한 한 단어 표시.
/// 검정 텍스트 + 옅은 배경만 사용하고, 별도의 신규 색상은 추가하지 않는다.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Text(label, style: UnifiedText.chipLabel()),
    );
  }
}

/// 오늘의 키워드 chip — Label/Chip 12 SemiBold, 옅은 배경의 낮은 채도 스타일.
class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        border: Border.all(color: UnifiedColors.border, width: 1),
      ),
      child: Text('#$label', style: UnifiedText.chipLabel()),
    );
  }
}
