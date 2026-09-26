// 신통방통 정통사주 v3 — 69종 상세 화면의 "AI 해석(서사형)" 탭.
//
// [69종 AI 해석 전면 재설계] 기존 `jeontong69_interpretation_tab.dart`
// (4블록 카드형, /saju/v3/interpret)를 대체하지 않고 병행하는 새 탭이다.
// 서버(`/saju/v3/narrative`)가 카테고리 1개당 "하나의 줄글 이야기"만
// 돌려주므로, 이 탭도 섹션/카드로 나누지 않고 한 문단으로 이어지는
// 서사를 그대로 보여준다. 본문 속 전문 용어는 [NarrativeTermText]가
// 탭 가능한 하이라이트로 표시하고, 탭하면 바텀시트로 쉬운 설명을 띄운다
// (본문 자체를 고치지 않고 부가 설명만 UI로 제공 — 재계산/재작성 없음).
//
//  - loading: 중앙 스피너.
//  - result == null: 오류 안내 + onRetry 재시도 버튼.
//  - result.isFallback: 상단에 안내 배너(룰 기반 해석 표시).
//  - qaWarnings가 있어도(치명적 아님) 화면에는 노출하지 않는다(개발/운영
//    로그 용도 — 사용자에게는 결과 품질을 의심하게 만들 필요가 없다).
import 'package:flutter/material.dart';

import '../domain/narrative_result.dart';
import 'widgets/narrative_term_text.dart';

class Jeontong69NarrativeTab extends StatelessWidget {
  final NarrativeResult? result;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  const Jeontong69NarrativeTab({
    super.key,
    this.result,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error ?? '해석을 불러올 수 없어요.'),
            const SizedBox(height: 12),
            if (onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final r = result!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (r.isFallback)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'AI 해석 준비 중입니다 — 검증된 룰 기반 해석으로 보여드려요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.categoryName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                NarrativeTermText(text: r.text),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '밑줄 그어진 용어를 탭하면 쉬운 설명을 볼 수 있어요.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        if (r.evidenceUsed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: r.evidenceUsed
                .map(
                  (e) => Chip(
                    label:
                        Text(e, style: Theme.of(context).textTheme.labelSmall),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
