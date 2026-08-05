import 'package:flutter/material.dart';
import '../domain/tarot_model.dart';
import '../domain/tarot_reading_extras.dart';
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_mystic_background.dart';

/// [타로 섹션 전면 개편 §2 정보구조 §11 P4] 심화해석 화면.
///
/// 결과화면(⑦)의 히어로 카드 1장을 "마음의 관점 / 현실의 관점 / 흐름의
/// 관점" 3가지로 다시 풀어보는 화면. 신규 서버 API나 문장 풀을 추가하지
/// 않고, 이미 검증된 [TarotTextEngine.generateCardInterpretation]을 결과
/// id 기반의 다른 시드 3개로 호출한 [TarotReadingExtras.deepDivePerspectives]를
/// 그대로 사용한다(§1-3 신규 자산 최소화).
class TarotDeepDiveScreen extends StatelessWidget {
  final TarotResultModel result;
  const TarotDeepDiveScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final heroCard = result.positions.first.card;
    final perspectives = TarotReadingExtras.deepDivePerspectives(
      heroCard,
      result.topic,
      result.id,
    );
    final caution = TarotReadingExtras.caution(result.id, result.topic);

    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('심화해석', style: TarotTextStyles.screenTitle),
        ),
        body: Stack(
          children: [
            TarotMysticBackground(
              intensity: TarotPerfConfig.backgroundIntensity(0.5),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TarotTokens.spaceLg,
                  TarotTokens.spaceMd,
                  TarotTokens.spaceLg,
                  TarotTokens.spaceXxl,
                ),
                children: [
                  _HeroChip(card: heroCard),
                  const SizedBox(height: TarotTokens.spaceXl),
                  Text('같은 카드, 세 가지 결', style: TarotTextStyles.sectionHeader),
                  const SizedBox(height: 4),
                  Text(
                    '하나의 카드를 서로 다른 시선으로 다시 풀어봤어요',
                    style: TarotTextStyles.caption,
                  ),
                  const SizedBox(height: TarotTokens.spaceLg),
                  for (final p in perspectives) ...[
                    _PerspectiveCard(label: p.label, text: p.text),
                    const SizedBox(height: TarotTokens.spaceMd),
                  ],
                  const SizedBox(height: TarotTokens.spaceSm),
                  _CautionCard(text: caution),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final TarotCard card;
  const _HeroChip({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        gradient: TarotColors.nightGradient,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderGlow),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              card.thumbAssetPath,
              width: 48,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Text(card.icon, style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: TarotTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('심화해석 대상 카드', style: TarotTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  '${card.nameKr}${card.isReversed ? " (역방향)" : ""}',
                  style: TarotTextStyles.bodyStrong,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PerspectiveCard extends StatelessWidget {
  final String label;
  final String text;
  const _PerspectiveCard({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCard,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(color: TarotColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TarotTextStyles.caption.copyWith(
                  color: TarotColors.moonSilver,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: TarotTokens.spaceSm),
          Text(text, style: TarotTextStyles.body),
        ],
      ),
    );
  }
}

class _CautionCard extends StatelessWidget {
  final String text;
  const _CautionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TarotTokens.spaceLg),
      decoration: BoxDecoration(
        color: TarotColors.surfaceCardStrong,
        borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
        border: Border.all(
          color: TarotColors.starlightGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: TarotTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주의할 점',
                  style: TarotTextStyles.caption.copyWith(
                    color: TarotColors.starlightGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(text, style: TarotTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
