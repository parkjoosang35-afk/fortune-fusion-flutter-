import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/util/original_result_capture.dart';
import '../../../core/utils/load_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/result_card_stack.dart';
import '../application/compatibility_provider.dart';
import '../domain/compatibility_model.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../../pass/application/pass_provider.dart';

/// [궁합(C그룹) 신규 구현] CompatibilityResultScreen - 결과형 패턴.
///
/// 신규 결과 화면이지만 새 레이아웃을 만들지 않고, 기존
/// [ResultCardStack](오늘의 운세/사주/이름 운세 등이 공유하는 표준 결과
/// 스켈레톤)을 그대로 재사용한다. topicResults(애정/성격/미래 등)를 섹션
/// 목록으로 매핑한다.
///
/// [REQ-06 — 신통방통_저장기능_정상화_개발지시서_v1.0] 이 화면에는
/// 저장·공유 코드가 0건이었다(P-04). 사주·타로·관상·손금·귀인지도 5개
/// 결과 화면에는 모두 기기 저장이 있는데 궁합만 없어, 사용자 입장에서는
/// "궁합만 저장이 안 된다"로 보였다. [ResultCardStack]이 이미 지원하는
/// captureKey를 연결하고, 다른 결과 화면과 동일한 saveOriginalResult 공통
/// 유틸(REQ-03 — 저장 단일 진입점)을 그대로 재사용해 저장 CTA를 추가한다.
/// 파일명 규칙은 §6 REQ-06 지정대로 sintong_compat_{id}를 따른다.
class CompatibilityResultScreen extends StatefulWidget {
  const CompatibilityResultScreen({super.key});

  @override
  State<CompatibilityResultScreen> createState() =>
      _CompatibilityResultScreenState();
}

class _CompatibilityResultScreenState
    extends State<CompatibilityResultScreen> {
  final _originalResultKey = GlobalKey();

  Future<void> _retry(
    BuildContext context,
    CompatibilityProvider provider,
  ) async {
    if (provider.needsNewAccess) {
      final access = await showResultAccessGateSheet(
        context,
        contentType: 'compatibility',
        categoryKey: 'compatibility',
        contentTitle: '궁합 보기',
        returnRoute: '/compatibility/input',
        userInputForRestore: provider.inputForRestore,
      );
      if (!context.mounted || access == null) return;
      await provider.retry(access: access);
    } else {
      await provider.retry();
    }
    if (context.mounted) context.read<PassProvider>().load();
  }

  Future<void> _onSave(CompatibilityResultModel result) async {
    final saved = await saveOriginalResult(
      context,
      _originalResultKey,
      name: 'sintong_compat_${result.id}',
    );
    if (!mounted || !saved) return;
    // [REQ-09 토스트 규칙] 성공 토스트는 saveOriginalResult 내부에서 이미
    // 표시되므로(원래 결과 페이지를 갤러리에 저장했어요 / 파일 다운로드를
    // 요청했어요) 여기서 중복 토스트는 띄우지 않는다.
  }

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
            onRetry: () => _retry(context, provider),
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
      captureKey: _originalResultKey,
      heroCaption: '${result.nameA} × ${result.nameB} · $typeLabel',
      heroSummary: result.summary,
      heroChips: [_ScoreChip(score: result.score)],
      sectionTitle: '항목별 궁합',
      sections: [
        for (final entry in result.topicResults.entries)
          ResultSection(title: entry.key, body: entry.value),
      ],
      ctas: [
        // [REQ-06 / REQ-08 — 버튼 명칭 통일] 다른 5개 결과 화면과 동일한
        // "이미지로 저장" 단일 문구 + download_rounded 아이콘을 사용한다.
        ResultCta(
          label: '이미지로 저장',
          icon: Icons.download_rounded,
          onTap: () => _onSave(result),
        ),
        ResultCta(
          label: '다른 상대와 다시 보기',
          icon: Icons.refresh_rounded,
          onTap: () => Navigator.of(
            context,
          ).pushReplacementNamed('/compatibility/input'),
        ),
        // [엔진 통합 지시문 STEP 3 — 2탭 도달성] face_result_screen.dart와
        // 동일한 패턴으로 교차검증 화면 진입점을 추가한다.
        ResultCta(
          label: '다른 운세와 비교해보기',
          icon: Icons.compare_arrows_rounded,
          onTap: () => Navigator.of(context).pushNamed('/cross-check/result'),
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
