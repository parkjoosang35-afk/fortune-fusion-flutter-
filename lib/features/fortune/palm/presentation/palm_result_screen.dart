import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/utils/load_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/result_card_stack.dart';
import '../application/palm_provider.dart';
import '../domain/palm_model.dart';

/// [서브 디자인 통일 확산 프롬프트] 결과 페이지 표준 스켈레톤([ResultCardStack])을
/// 재사용해 오늘의 운세/사주/궁합/관상 결과와 동일한 "카드 스택형 리포트" 톤을
/// 적용한다. 손금선별 색상 구분/그림자·호버 효과/이모지는 모두 제거하고,
/// 손금선 특징 + 주제별 해석을 하나의 세부 리포트 카드 스택으로 통일한다.
class PalmResultScreen extends StatefulWidget {
  final String? resultId;
  const PalmResultScreen({super.key, this.resultId});

  @override
  State<PalmResultScreen> createState() => _PalmResultScreenState();
}

/// 주제별 라인 아이콘 매핑(이모지 대체)
const Map<String, IconData> _topicIcons = {
  '재물': Icons.payments_outlined,
  '애정': Icons.favorite_outline_rounded,
  '직업': Icons.work_outline_rounded,
  '건강': Icons.health_and_safety_outlined,
};

class _PalmResultScreenState extends State<PalmResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.resultId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PalmProvider>().selectFromHistory(widget.resultId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PalmProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('손금 결과', style: UnifiedText.titleLarge()),
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

  Widget _buildResult(BuildContext context, PalmResultModel result) {
    final topicEntries = result.topicResults.entries
        .where((e) => e.key != '종합')
        .toList();

    return ResultCardStack(
      heroCaption: '종합 손금 해석',
      heroSummary: result.summary,
      sectionTitle: '세부 리포트',
      sections: [
        ...result.lines.entries.map(
          (e) => ResultSection(title: e.key, body: e.value),
        ),
        ...topicEntries.map(
          (e) => ResultSection(
            title: e.key,
            body: e.value,
            trailing: Icon(
              _topicIcons[e.key] ?? Icons.auto_awesome_outlined,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textSecondary,
            ),
          ),
        ),
      ],
      ctas: [
        ResultCta(
          label: '다시 분석하기',
          icon: Icons.refresh_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed('/ai-fortune/palm/capture'),
        ),
        ResultCta(
          label: '히스토리 보기',
          icon: Icons.history_rounded,
          onTap: () =>
              Navigator.of(context).pushNamed('/ai-fortune/palm/history'),
        ),
      ],
    );
  }
}
