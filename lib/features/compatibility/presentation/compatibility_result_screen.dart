import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/result_card_stack.dart';
import '../../wallet/presentation/widgets/send_bok_sheet.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';

/// 07단계 결과형 패턴 - CompatibilityResultScreen
///
/// [서브 디자인 통일 확산 프롬프트] 결과 페이지 표준 스켈레톤([ResultCardStack])을
/// 재사용해 오늘의 운세/사주 결과와 동일한 톤을 적용한다. 궁합 점수 원형
/// 게이지 + 복 나누기 버튼은 히어로 카드 하단 [heroExtra]에 유지한다.
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
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: Icon(
                state.data!.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: state.data!.isSaved
                    ? UnifiedColors.black
                    : UnifiedColors.textSecondary,
              ),
              onPressed: () async {
                final saved = await provider.toggleSave(state.data!.id);
                if (context.mounted) {
                  AppToast.show(
                    context,
                    saved ? '보관함에 저장되었습니다.' : '보관함에서 제거되었습니다.',
                  );
                }
              },
            ),
          if (state.isSuccess)
            IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: UnifiedColors.textPrimary,
              ),
              onPressed: () async {
                final url = await provider.generateShareLink(state.data!.id);
                if (context.mounted) {
                  AppToast.show(
                    context,
                    url != null ? '공유 링크가 생성되었습니다: $url' : '공유 링크 생성에 실패했습니다.',
                    isError: url == null,
                  );
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const _CompatLoading(),
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
    return ResultCardStack(
      heroCaption:
          '${result.nameA} \u2764 ${result.nameB} \u00b7 ${result.type.label}',
      heroSummary: result.summary,
      heroExtra: _ScoreExtra(result: result),
      sectionTitle: '주제별 분석',
      sections: result.topicResults.entries
          .map((e) => ResultSection(title: e.key, body: e.value))
          .toList(),
      ctas: [
        ResultCta(
          label: '다시 분석하기',
          icon: Icons.refresh_rounded,
          onTap: () => Navigator.of(
            context,
          ).pushNamed('/ai-fortune/compatibility/input'),
        ),
        ResultCta(
          label: '보관함 보기',
          icon: Icons.bookmark_outline_rounded,
          onTap: () => Navigator.of(
            context,
          ).pushNamed('/ai-fortune/compatibility/history'),
        ),
      ],
    );
  }
}

class _CompatLoading extends StatelessWidget {
  const _CompatLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            color: UnifiedColors.textSecondary,
            size: 48,
          ),
          const SizedBox(height: UnifiedTokens.spaceLg),
          Text('두 사람의 인연을 분석하고 있어요...', style: UnifiedText.body()),
        ],
      ),
    );
  }
}

/// 히어로 카드 하단 - 궁합 점수 원형 게이지 + 복 나누기 버튼을 그대로 유지한다.
/// [주의] 포인트 컬러(네온)는 원형 CTA 전용이므로, 데이터 시각화인 이 점수
/// 게이지에는 사용하지 않고 중립 톤(블랙)으로 표시한다.
class _ScoreExtra extends StatelessWidget {
  final CompatibilityResultModel result;
  const _ScoreExtra({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: result.score / 100,
                strokeWidth: 7,
                backgroundColor: UnifiedColors.chipInactiveBg,
                color: UnifiedColors.black,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${result.score}', style: UnifiedText.titleLarge()),
                Text('점', style: UnifiedText.caption()),
              ],
            ),
          ],
        ),
        const SizedBox(height: UnifiedTokens.spaceLg),
        SizedBox(
          width: double.infinity,
          child: PremiumButton.secondary(
            label: '${result.nameB}님에게 복 나누기',
            icon: Icons.volunteer_activism_outlined,
            onPressed: () =>
                showSendBokSheet(context, recipientNickname: result.nameB),
          ),
        ),
      ],
    );
  }
}
