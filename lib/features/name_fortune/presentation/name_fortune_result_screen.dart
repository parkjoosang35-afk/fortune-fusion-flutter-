import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/result_card_stack.dart';
import '../application/name_fortune_provider.dart';
import '../domain/name_fortune_model.dart';

/// [운세 카테고리 확장] NameFortuneResultScreen - 결과형 패턴.
///
/// 신규 결과 화면이지만 새 레이아웃을 만들지 않고, 기존
/// [ResultCardStack](오늘의 운세/사주/궁합 등이 공유하는 표준 결과 스켈레톤)을
/// 그대로 재사용한다. 이름 운세는 토픽 분기/섹션 목록이 없는 단일 텍스트
/// 생성형 카테고리이므로 heroSummary 하나로 표현하고, sections는 비운다.
class NameFortuneResultScreen extends StatelessWidget {
  const NameFortuneResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NameFortuneProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('이름 운세 결과', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: switch (state.status) {
          LoadStatus.loading => const _NameFortuneLoading(),
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

  Widget _buildResult(BuildContext context, NameFortuneResultModel result) {
    final captionParts = <String>[
      result.name,
      if (result.hanja != null && result.hanja!.isNotEmpty) '(${result.hanja})',
    ];
    return ResultCardStack(
      heroCaption: captionParts.join(' '),
      heroSummary: result.resultText,
      sectionTitle: '세부 리포트',
      sections: const [],
      ctas: [
        ResultCta(
          label: '다른 이름으로 다시 보기',
          icon: Icons.refresh_rounded,
          onTap: () => Navigator.of(
            context,
          ).pushReplacementNamed('/ai-fortune/name/input'),
        ),
      ],
    );
  }
}

class _NameFortuneLoading extends StatelessWidget {
  const _NameFortuneLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.badge_outlined,
            color: UnifiedColors.textSecondary,
            size: 48,
          ),
          SizedBox(height: UnifiedTokens.spaceLg),
          Text('이름에 담긴 기운을 풀이하고 있어요...', style: UnifiedText.body()),
        ],
      ),
    );
  }
}
