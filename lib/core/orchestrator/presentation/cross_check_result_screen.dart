import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/application/auth_provider.dart';
import '../../theme/app_unified_style.dart';
import '../../widgets/app_error_state.dart';
import '../cross_check_engine.dart';
import '../interpretation_narrator.dart';
import '../orchestrator_provider.dart';

/// [엔진 통합 지시문 STEP 3 §6 "2탭/3탭 도달성"] 교차검증 결과를 보여주는
/// 공용 화면. 각 운세 결과화면(사주/타로/관상/손금/궁합)에서 CTA 1번
/// 탭으로 이 화면에 도달한다(해당 결과화면이 이미 홈에서 1탭 또는 2탭
/// 거리이므로, 전체적으로 "홈→결과→교차검증" 2탭, "교차검증→근거 상세"
/// 3탭 도달성을 만족한다).
///
/// [narrator 주입] LLM 미연동 기본 구현인 [RuleOnlyNarrator]를 사용한다.
/// 이 화면은 [CrossCheckResult.verdict]를 직접 material 색상(초록/주황/
/// 빨강)으로도 보여줘, narrator 텍스트와 별개로 "판정 자체는 항상 눈에
/// 보이게" 한다 — 서술 문장이 바뀌어도 판정 결과 자체는 가려지지 않는다.
class CrossCheckResultScreen extends StatefulWidget {
  const CrossCheckResultScreen({super.key});

  @override
  State<CrossCheckResultScreen> createState() =>
      _CrossCheckResultScreenState();
}

class _CrossCheckResultScreenState extends State<CrossCheckResultScreen> {
  static const InterpretationNarrator _narrator = RuleOnlyNarrator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      context.read<OrchestratorProvider>().load(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orchestrator = context.watch<OrchestratorProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('교차 검증 결과', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: switch (orchestrator.status) {
          OrchestratorStatus.initial ||
          OrchestratorStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          OrchestratorStatus.error => AppErrorState(
            message: orchestrator.errorMessage ?? '불러오지 못했습니다.',
            onRetry: () => orchestrator.load(
              context.read<AuthProvider>().currentUser,
            ),
          ),
          OrchestratorStatus.loaded => _buildBody(context, orchestrator),
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, OrchestratorProvider orchestrator) {
    final judged = orchestrator.judged;
    final unjudged = orchestrator.unjudged;

    if (judged.isEmpty && unjudged.isEmpty) {
      return const AppErrorState(
        message: '아직 비교할 결과가 없어요. 사주/타로/관상/손금/궁합을 먼저 이용해보세요.',
      );
    }

    return ListView(
      padding: EdgeInsets.all(UnifiedTokens.spaceLg),
      children: [
        Text(
          '${orchestrator.profile.filledDoorCount}/5개 문 결과를 바탕으로 '
          '${judged.length}건을 비교했어요.',
          style: UnifiedText.caption(),
        ),
        SizedBox(height: UnifiedTokens.spaceMd),
        for (final result in judged) ...[
          _CrossCheckCard(result: result, narrator: _narrator),
          SizedBox(height: UnifiedTokens.spaceMd),
        ],
        if (unjudged.isNotEmpty) ...[
          Text('아직 비교할 수 없는 조합', style: UnifiedText.titleLarge()),
          SizedBox(height: UnifiedTokens.spaceSm),
          for (final u in unjudged) ...[
            _UnjudgedCard(unjudged: u, narrator: _narrator),
            SizedBox(height: UnifiedTokens.spaceSm),
          ],
        ],
      ],
    );
  }
}

class _CrossCheckCard extends StatelessWidget {
  const _CrossCheckCard({required this.result, required this.narrator});

  final CrossCheckResult result;
  final InterpretationNarrator narrator;

  Color get _verdictColor => switch (result.verdict) {
    CrossCheckVerdict.match => Colors.green,
    CrossCheckVerdict.complement => Colors.orange,
    CrossCheckVerdict.conflict => Colors.red,
  };

  String get _verdictLabel => switch (result.verdict) {
    CrossCheckVerdict.match => '일치',
    CrossCheckVerdict.complement => '보완',
    CrossCheckVerdict.conflict => '상충',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _verdictColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _verdictLabel,
                  style: UnifiedText.caption().copyWith(
                    color: _verdictColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${result.pair} · ${result.axis}',
                  style: UnifiedText.titleLarge(),
                ),
              ),
            ],
          ),
          SizedBox(height: UnifiedTokens.spaceSm),
          Text(narrator.narrate(result), style: UnifiedText.body()),
          SizedBox(height: UnifiedTokens.spaceSm),
          // [3탭 도달성] "근거 보기"를 탭하면(이 화면이 이미 2탭째이므로
          // 3탭째) evidence 원문 전체를 펼쳐 보여준다 — 추가 네트워크
          // 호출 없이 이미 받아온 데이터를 그대로 펼치는 것뿐이다.
          _EvidenceExpander(result: result),
        ],
      ),
    );
  }
}

class _EvidenceExpander extends StatefulWidget {
  const _EvidenceExpander({required this.result});
  final CrossCheckResult result;

  @override
  State<_EvidenceExpander> createState() => _EvidenceExpanderState();
}

class _EvidenceExpanderState extends State<_EvidenceExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            size: 18,
          ),
          label: Text(_expanded ? '근거 접기' : '근거 보기'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < result.evidence.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '[${result.sources[i]}] ${result.evidence[i]}',
                      style: UnifiedText.caption(),
                    ),
                  ),
                Text(
                  'scoreA=${result.scoreA.toStringAsFixed(2)}  '
                  'scoreB=${result.scoreB.toStringAsFixed(2)}  '
                  'delta=${result.delta.toStringAsFixed(2)}',
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UnjudgedCard extends StatelessWidget {
  const _UnjudgedCard({required this.unjudged, required this.narrator});

  final UnjudgedRule unjudged;
  final InterpretationNarrator narrator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(UnifiedTokens.spaceMd),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              narrator.narrateUnjudged(unjudged),
              style: UnifiedText.caption(),
            ),
          ),
        ],
      ),
    );
  }
}
