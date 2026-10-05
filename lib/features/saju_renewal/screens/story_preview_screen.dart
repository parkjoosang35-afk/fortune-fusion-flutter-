import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../state/saju_renewal_provider.dart';
import 'story_detail_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면⑤ 첫 이야기 미리보기
/// (제목/요약 + "자세히보기" 버튼). "다른 사주 이야기" 선택 후에도
/// 동일한 화면을 재사용한다.
///
/// [Access Gate — 절대 신규 위젯 금지] "자세히보기"를 누르면 기존
/// [showResultAccessGateSheet]를 그대로 재사용한다(Wallet/복주머니/
/// AdMob/FreePass/ResultAccessGate 전부 재사용, 신규 생성 금지 —
/// 지시서 §Access Gate 요구사항). contentType은 saju 69종(`'saju'`)과
/// 혼동되지 않도록 `'saju_renewal'`로 분리한다.
class StoryPreviewScreen extends StatefulWidget {
  const StoryPreviewScreen({super.key});

  @override
  State<StoryPreviewScreen> createState() => _StoryPreviewScreenState();
}

class _StoryPreviewScreenState extends State<StoryPreviewScreen> {
  bool _gateOpening = false;

  Future<void> _openAccessGate() async {
    if (_gateOpening) return; // [중복클릭 방어]
    setState(() => _gateOpening = true);
    final provider = context.read<SajuRenewalProvider>();
    final topic = provider.currentTopic;

    final beginResult = await showResultAccessGateSheet(
      context,
      contentType: 'saju_renewal',
      categoryKey: 'saju_renewal',
      contentId: topic?.topicId,
      contentTitle: topic?.title ?? '사주 이야기',
      returnRoute: '/saju-renewal',
    );

    if (!mounted) return;
    setState(() => _gateOpening = false);
    if (beginResult == null) return; // 사용자가 취소함

    provider.requestAccess();
    await provider.onAccessGranted();
    if (!mounted) return;

    if (provider.status == SajuRenewalFlowStatus.storyDetail) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const StoryDetailScreen()));
    } else if (provider.status == SajuRenewalFlowStatus.error) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    final previewState = provider.previewState;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('이야기 미리보기', style: UnifiedText.title()),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (previewState.isLoading || previewState.isInitial) {
              return const Center(
                child: CircularProgressIndicator(color: UnifiedColors.black),
              );
            }
            if (previewState.isError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        previewState.errorMessage ?? '이야기를 불러오지 못했습니다.',
                        style: UnifiedText.body(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: UnifiedTokens.spaceLg),
                      ElevatedButton(
                        onPressed: () {
                          final topic = provider.currentTopic;
                          if (topic != null) provider.loadPreview(topic);
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final summary = previewState.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.title, style: UnifiedText.titleLarge()),
                  const SizedBox(height: UnifiedTokens.spaceLg),
                  Text(summary.summary, style: UnifiedText.body()),
                  const SizedBox(height: UnifiedTokens.spaceXl),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _gateOpening ? null : _openAccessGate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UnifiedColors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            UnifiedTokens.radiusPill,
                          ),
                        ),
                      ),
                      child: _gateOpening
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              '자세히보기',
                              style: TextStyle(
                                fontSize: 16,
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
