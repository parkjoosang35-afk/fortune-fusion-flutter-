import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/result_card_stack.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';

/// [궁합(C그룹) 신규 구현] CompatibilityResultScreen - 결과형 패턴.
///
/// 신규 결과 화면이지만 새 레이아웃을 만들지 않고, 기존
/// [ResultCardStack](오늘의 운세/사주/이름 운세 등이 공유하는 표준 결과
/// 스켈레톤)을 그대로 재사용한다. topicResults(애정/성격/미래 등)를 섹션
/// 목록으로 매핑한다.
class CompatibilityResultScreen extends StatelessWidget {
  const CompatibilityResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompatibilityProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('궁합 결과', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const _CompatibilityLoading(),
          LoadStatus.error => AppErrorState(
            message: state.errorMessage ?? '분석에 실패했습니다.',
            onRetry: () => provider.retry(),
          ),
          LoadStatus.success => _buildResult(context, state.data!),
          LoadStatus.initial => const AppErrorState(message: '입력 정보가 없습니다.'),
        },
      ),
    );
  }

  Widget _buildResult(BuildContext context, CompatibilityResultModel result) {
    final typeLabel = CompatibilityType.values
        .firstWhere(
          (t) => t.apiValue == result.type,
          orElse: () => CompatibilityType.love,
        )
        .label;

    return ResultCardStack(
      heroCaption: '${result.nameA} × ${result.nameB} · $typeLabel',
      heroSummary: result.summary,
      heroChips: [
        _ScoreChip(score: result.score),
      ],
      sectionTitle: '항목별 궁합',
      sections: [
        for (final entry in result.topicResults.entries)
          ResultSection(title: entry.key, body: entry.value),
      ],
      ctas: [
        ResultCta(
          label: '다른 상대와 다시 보기',
          icon: Icons.refresh_rounded,
          onTap: () => Navigator.of(
            context,
          ).pushReplacementNamed('/compatibility/input'),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Column(
        children: [
          Text('$score점', style: UnifiedText.titleLarge()),
          const SizedBox(height: 2),
          Text('궁합 점수', style: UnifiedText.caption()),
        ],
      ),
    );
  }
}

class _CompatibilityLoading extends StatelessWidget {
  const _CompatibilityLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            color: UnifiedColors.textSecondary,
            size: 48,
          ),
          SizedBox(height: UnifiedTokens.spaceLg),
          Text('두 분의 인연을 풀이하고 있어요...', style: UnifiedText.body()),
        ],
      ),
    );
  }
}
