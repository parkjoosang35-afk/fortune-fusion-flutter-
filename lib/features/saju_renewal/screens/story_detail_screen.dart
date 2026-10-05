import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../data/models/interpret_result.dart';
import '../state/saju_renewal_provider.dart';
import 'more_stories_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면⑦ 상세 사주 이야기.
///
/// [내부 정보 비노출 — 절대 원칙] MONEY_002/LIFE_004 같은 topic_id,
/// FACT 키, score, 69종 코드, evaluator, "AI" 표현 등을 이 화면에 절대
/// 노출하지 않는다. 서버가 이미 `interpret-qa-check.ts`로 이런 표현을
/// 걸러내 보장하지만, 이 화면도 [InterpretDetailBlock.body] 텍스트만
/// 그대로 렌더링하고 별도의 내부 식별자를 화면에 추가하지 않는다.
class StoryDetailScreen extends StatelessWidget {
  const StoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    final detailState = provider.detailState;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('사주 이야기', style: UnifiedText.title()),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (detailState.isLoading || detailState.isInitial) {
              return const Center(
                child: CircularProgressIndicator(color: UnifiedColors.black),
              );
            }
            if (detailState.isError) {
              return Center(
                child: Text(
                  detailState.errorMessage ?? '이야기를 불러오지 못했습니다.',
                  style: UnifiedText.body(),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final detail = detailState.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.title, style: UnifiedText.titleLarge()),
                  const SizedBox(height: UnifiedTokens.spaceXl),
                  for (final block in detail.blocks) ...[
                    _DetailBlockView(block: block),
                    const SizedBox(height: UnifiedTokens.spaceLg),
                  ],
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        provider.showMoreTopics();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MoreStoriesScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UnifiedColors.black,
                        side: const BorderSide(color: UnifiedColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            UnifiedTokens.radiusPill,
                          ),
                        ),
                      ),
                      child: const Text(
                        '내 사주에 또 다른 이야기가 있어요',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailBlockView extends StatelessWidget {
  const _DetailBlockView({required this.block});

  final InterpretDetailBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      decoration: BoxDecoration(
        color: UnifiedColors.cardSection,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        block.body,
        style: UnifiedText.body(color: UnifiedColors.textPrimary),
      ),
    );
  }
}
