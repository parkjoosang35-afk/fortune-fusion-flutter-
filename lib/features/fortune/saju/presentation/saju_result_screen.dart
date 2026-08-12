import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/result_card_stack.dart';
import '../application/saju_provider.dart';
import '../domain/saju_model.dart';

/// 07단계 §6.1 SajuResultScreen
///
/// [서브 디자인 통일 확산 프롬프트] 결과 페이지 표준 스켈레톤([ResultCardStack])을
/// 그대로 재사용해 오늘의 운세와 동일한 "카드 스택형 리포트" 톤을 적용한다.
/// 기존 TabBar(종합/재물/애정/직업/건강) 구성은 표준 플로우의 세부 리포트
/// 섹션 목록(카드 스택)으로 대체하고, 사주 명식/오행 분포는 히어로 카드
/// 하단 [heroExtra]에 그대로 유지한다.
class SajuResultScreen extends StatefulWidget {
  final String? resultId;
  const SajuResultScreen({super.key, this.resultId});

  @override
  State<SajuResultScreen> createState() => _SajuResultScreenState();
}

class _SajuResultScreenState extends State<SajuResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SajuProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('사주 결과', style: UnifiedText.titleLarge()),
        actions: [
          if (state.isSuccess)
            IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: UnifiedColors.textPrimary,
              ),
              onPressed: () => AppToast.show(context, '공유 링크가 복사되었습니다.'),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
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

  Widget _buildResult(BuildContext context, SajuResultModel result) {
    final topics = result.topicResults.keys.toList();

    // [사주정보 이름 필드 보완] 입력 화면에서 받은 이름을 결과 히어로 캡션에
    // 반영해 "OOO님의 사주 명식"처럼 개인화한다.
    final heroCaption = result.name.trim().isEmpty
        ? '나의 사주 명식'
        : '${result.name}님의 사주 명식';
    return ResultCardStack(
      heroCaption: heroCaption,
      heroSummary: result.summary,
      heroExtra: _SajuChartExtra(result: result),
      sectionTitle: '세부 리포트',
      sections: topics
          .map(
            (t) => ResultSection(title: t, body: result.topicResults[t] ?? ''),
          )
          .toList(),
      ctas: [
        ResultCta(
          label: '다시 분석하기',
          icon: Icons.refresh_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed('/ai-fortune/saju/input'),
        ),
        ResultCta(
          label: '히스토리 보기',
          icon: Icons.history_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed('/ai-fortune/saju/history'),
        ),
      ],
    );
  }
}

/// 히어로 카드 하단 - 사주 명식(년/월/일/시주) + 오행 분포를 그대로 유지한다.
class _SajuChartExtra extends StatelessWidget {
  final SajuResultModel result;
  const _SajuChartExtra({required this.result});

  @override
  Widget build(BuildContext context) {
    final p = result.pillars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _pillarBox('년주', p.year),
            _pillarBox('월주', p.month),
            _pillarBox('일주', p.day),
            _pillarBox('시주', p.hour ?? '-'),
          ],
        ),
        const SizedBox(height: UnifiedTokens.spaceLg),
        Text('오행 분포', style: UnifiedText.caption()),
        const SizedBox(height: UnifiedTokens.spaceSm),
        Wrap(
          spacing: UnifiedTokens.spaceSm,
          runSpacing: UnifiedTokens.spaceSm,
          children: result.fiveElements.entries
              .map(
                (e) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceMd,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: UnifiedColors.bg,
                    borderRadius: BorderRadius.circular(
                      UnifiedTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    '${e.key} ${e.value}',
                    style: UnifiedText.chipLabel(),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _pillarBox(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: UnifiedTokens.spaceSm),
        decoration: BoxDecoration(
          color: UnifiedColors.bg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
        ),
        child: Column(
          children: [
            Text(label, style: UnifiedText.caption()),
            const SizedBox(height: 2),
            Text(value, style: UnifiedText.bodyStrong()),
          ],
        ),
      ),
    );
  }
}
