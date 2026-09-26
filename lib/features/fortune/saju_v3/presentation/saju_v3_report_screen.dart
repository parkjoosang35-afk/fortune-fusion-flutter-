// 신통방통 정통사주 v3 — AI 장문 리포트 화면 (POST /saju/v3/report)
//
// [5차 지시서] AI 정통사주 해석 엔진 v1.0 — 9 PART 장문 개인 리포트.
// 흐름: 이 화면(질문 입력) → SajuV3Provider.loadReport(question) → 결과 렌더링.
// - source == "rule_fallback": 상단 안내 배너 + 계산값 나열(신규 문장 생성 없음).
// - source == "llm": LLM 종합 해석(현재 엔진 서버는 LLM 미연결이라 실사용 전까지는
//   rule_fallback만 관측됨 — 5차 지시서 §PHASE12).
// - source == "cache": 동일 질문 재요청 시 idempotency 캐시 응답.
// - 402(SajuV3ApiException.isFreePassRequired): 프리패스 안내.
// - 429(SajuV3ApiException.isRateLimited): rate limit 안내(네트워크 오류와 구분).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/saju_v3_provider.dart';
import '../domain/saju_report.dart';
import 'jeontong_v3_theme.dart';

class SajuV3ReportScreen extends StatefulWidget {
  const SajuV3ReportScreen({super.key});

  @override
  State<SajuV3ReportScreen> createState() => _SajuV3ReportScreenState();
}

class _SajuV3ReportScreenState extends State<SajuV3ReportScreen> {
  final TextEditingController _questionController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _questionController.text.trim();
    setState(() => _submitted = true);
    context.read<SajuV3Provider>().loadReport(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Jt3Colors.inkBlack,
      appBar: AppBar(
        backgroundColor: Jt3Colors.inkBlack,
        foregroundColor: Jt3Colors.royalGold,
        title: const Text(
          'AI 장문 리포트 (베타)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: _submitted ? _buildResult(context) : _buildQuestionForm(),
      ),
    );
  }

  Widget _buildQuestionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '9 PART 심층 리포트',
            style: TextStyle(
              color: Jt3Colors.royalGold,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '한눈에 보는 나 · 타고난 성향 · 숨겨진 성향 · 재능/직업 · 재물운 ·\n'
            '연애/인간관계 · 인생 흐름 · 현재 운 · 종합 분석 — 9개 파트로\n'
            '깊이 있게 풀어드립니다. (베타 · 현재 계산값 기반 룰 해석)',
            style: TextStyle(
              color: Jt3Colors.moonSilver.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '궁금한 점이 있다면 적어주세요 (선택)',
            style: TextStyle(
              color: Jt3Colors.moonSilver,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _questionController,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(color: Jt3Colors.starWhite),
            decoration: InputDecoration(
              hintText: '예: 올해 재물운이 궁금해요',
              hintStyle: TextStyle(
                color: Jt3Colors.moonSilver.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: Jt3Colors.charcoal,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Jt3Radii.chip),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Jt3Colors.royalGold,
                foregroundColor: Jt3Colors.inkBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Jt3Radii.button),
                ),
              ),
              child: const Text(
                '리포트 만들기',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    return Consumer<SajuV3Provider>(
      builder: (context, provider, _) {
        final question = provider.lastReportQuestion;
        final state = provider.reportStateOf(question);

        if (state.isLoading || state.isInitial) {
          return const Center(
            child: CircularProgressIndicator(color: Jt3Colors.royalGold),
          );
        }
        if (state.isError) {
          return _buildErrorView(context, state.errorMessage ?? '알 수 없는 오류');
        }
        final result = state.data!;
        return _ReportView(result: result);
      },
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    // 402/429/네트워크 오류를 문구로 구분해 안내한다(5차 지시서 img2 "주의" 항목).
    final isFreePass = message.contains('열림패스') || message.contains('프리패스');
    final isRateLimited =
        message.contains('너무 많습니다') || message.contains('rate');
    final title = isFreePass
        ? '열림패스가 필요해요'
        : isRateLimited
        ? '요청 한도를 초과했어요'
        : '리포트를 불러오지 못했어요';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFreePass
                  ? Icons.lock_outline
                  : isRateLimited
                  ? Icons.hourglass_empty
                  : Icons.error_outline,
              color: Jt3Colors.royalGold,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Jt3Colors.starWhite,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Jt3Colors.moonSilver),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () =>
                  context.read<SajuV3Provider>().retryReport(),
              child: const Text(
                '다시 시도',
                style: TextStyle(color: Jt3Colors.royalGold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  final SajuReportResult result;
  const _ReportView({required this.result});

  @override
  Widget build(BuildContext context) {
    final body = result.report;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (result.isFallback)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Jt3Colors.royalGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Jt3Colors.royalGold.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'AI 해석 준비 중입니다 — 검증된 룰 기반 해석으로 보여드려요.',
              style: TextStyle(
                color: Jt3Colors.royalGold.withValues(alpha: 0.95),
                fontSize: 13,
              ),
            ),
          ),
        if (result.isCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '이전에 만든 리포트를 다시 보여드려요.',
              style: TextStyle(
                color: Jt3Colors.moonSilver.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        for (final part in body.parts) _PartCard(part: part),
        if (body.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              body.summary,
              style: const TextStyle(
                color: Jt3Colors.starWhite,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (body.evidenceUsed.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: body.evidenceUsed
                .map(
                  (e) => Chip(
                    label: Text(
                      e,
                      style: const TextStyle(
                        color: Jt3Colors.moonSilver,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: Jt3Colors.charcoal,
                    padding: EdgeInsets.zero,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _PartCard extends StatelessWidget {
  final SajuReportPart part;
  const _PartCard({required this.part});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Jt3Colors.charcoal,
        borderRadius: BorderRadius.circular(Jt3Radii.card),
        border: Border.all(color: Jt3Colors.royalGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Jt3Colors.royalGold,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${part.no}',
                  style: const TextStyle(
                    color: Jt3Colors.inkBlack,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.title,
                  style: const TextStyle(
                    color: Jt3Colors.starWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...part.paras.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                p,
                style: TextStyle(
                  color: Jt3Colors.moonSilver.withValues(alpha: 0.95),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
