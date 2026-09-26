// 신통방통 정통사주 v3 — 69종 상세 화면의 "AI 해석" 탭.
//
// [Option 2 이식] 순수 StatelessWidget(riverpod/dio 의존 없음) - 원본 그대로 이식.
//
// [2026-09-25 3차 회신 반영] `/saju/v3/interpret` 서버 라우트가 구현되어 정상 계약이
// 확정됨에 따라, 이 탭은 다음 두 경로만 처리한다(그 외 임시 분기 없음):
//  - 200 + source == "rule_fallback" → 상단에 안내 배너(룰 기반 해석 표시)를 보여주고
//    기존 룰 해석기 내용을 동일 블록 구조로 렌더링한다(문구 추가 없음).
//  - 비-2xx(네트워크 실패·5xx·402·422) → 오류 안내 + onRetry 재시도 버튼.
//    (404를 별도 "준비 중"으로 취급하는 분기는 두지 않는다 — 이제 404는 배포 설정
//    오류를 의미하며, 일반 오류 경로로 자연스럽게 처리된다.)
//  - actions/closing이 비어 있으면 해당 블록은 숨긴다(폴백은 비어 있을 수 있음).
import 'package:flutter/material.dart';

import '../domain/interpretation_result.dart';

class Jeontong69InterpretationTab extends StatelessWidget {
  final InterpretationResult? result;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  const Jeontong69InterpretationTab({
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
              '해석 준비 중입니다 — 검증된 룰 기반 해석으로 보여드려요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              r.headline,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        ...r.sections.map(
          (s) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...s.body.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(b),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (r.hasActions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '실천 3가지',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...r.actions.map((a) => Text('· $a')),
                ],
              ),
            ),
          ),
        if (r.hasClosing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              r.closing,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Wrap(
          spacing: 6,
          children: r.evidenceUsed
              .map(
                (e) => Chip(
                  label: Text(e, style: Theme.of(context).textTheme.labelSmall),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
