import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../data/models/topic_card.dart';
import '../state/saju_renewal_provider.dart';
import 'story_preview_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면⑧ 다른 사주 이야기 후보 목록.
///
/// [Flutter 임의선정 절대 금지] 이 화면은 Topic Engine이 이미 내려준
/// `topicsState.data!.candidates`를 그대로 노출만 한다 — 후보를 다시
/// 정렬/필터링/임의 추천하지 않는다(지시서 §흐름 요구사항). "이미 본
/// 이야기" 재노출 방지도 서버(Exposure History)가 최종 판단하며,
/// Flutter는 [SajuRenewalProvider.loadMoreTopics]를 통해 지금까지 상세까지
/// 완료한 topic_id만 `exclude_topic_ids`로 참고 전달한다.
class MoreStoriesScreen extends StatefulWidget {
  const MoreStoriesScreen({super.key});

  @override
  State<MoreStoriesScreen> createState() => _MoreStoriesScreenState();
}

class _MoreStoriesScreenState extends State<MoreStoriesScreen> {
  bool _selecting = false;

  Future<void> _selectCandidate(TopicCard candidate) async {
    if (_selecting) return; // [중복클릭 방어]
    setState(() => _selecting = true);
    final provider = context.read<SajuRenewalProvider>();

    await provider.loadPreview(candidate);
    if (!mounted) return;
    setState(() => _selecting = false);

    if (provider.status == SajuRenewalFlowStatus.storyPreview) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StoryPreviewScreen()));
    } else if (provider.status == SajuRenewalFlowStatus.error) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    }
  }

  Future<void> _loadMore() async {
    if (_selecting) return;
    final provider = context.read<SajuRenewalProvider>();
    await provider.loadMoreTopics();
    if (!mounted) return;
    if (provider.status == SajuRenewalFlowStatus.error) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    final topicsState = provider.topicsState;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('다른 사주 이야기', style: UnifiedText.title()),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (topicsState.isLoading || provider.isTopicsLoading) {
              return const Center(
                child: CircularProgressIndicator(color: UnifiedColors.black),
              );
            }
            if (topicsState.isError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        topicsState.errorMessage ?? '이야기를 불러오지 못했습니다.',
                        style: UnifiedText.body(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: UnifiedTokens.spaceLg),
                      ElevatedButton(
                        onPressed: _loadMore,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = topicsState.data;
            final candidates = data?.candidates ?? const <TopicCard>[];

            if (candidates.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '새로운 사주 이야기를 찾고 있어요.',
                        style: UnifiedText.body(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: UnifiedTokens.spaceLg),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loadMore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UnifiedColors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                UnifiedTokens.radiusPill,
                              ),
                            ),
                          ),
                          child: const Text(
                            '새로운 이야기 더 찾기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
              itemCount: candidates.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: UnifiedTokens.spaceLg),
              itemBuilder: (context, index) {
                if (index == candidates.length) {
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _selecting ? null : _loadMore,
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
                        '새로운 이야기 더 찾기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                final candidate = candidates[index];
                return _CandidateCard(
                  candidate: candidate,
                  enabled: !_selecting,
                  onTap: () => _selectCandidate(candidate),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.enabled,
    required this.onTap,
  });

  final TopicCard candidate;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UnifiedColors.cardSection,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  candidate.title,
                  style: UnifiedText.bodyStrong(
                    color: UnifiedColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: UnifiedColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
