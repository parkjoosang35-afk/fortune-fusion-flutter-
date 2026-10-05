import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../state/saju_renewal_provider.dart';
import 'story_preview_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면④ 분석 완료 — "첫 번째
/// 사주 이야기 발견".
///
/// [절대 금지] 내부 TopicID(예: MONEY_002)를 절대 노출하지 않는다 —
/// [TopicCard.title]만 보여준다. scene/evidence_fact_keys 등도 이 화면
/// UI에는 표시하지 않는다(내부 판단 근거는 사용자에게 설명하지 않음).
class AnalysisCompleteScreen extends StatefulWidget {
  const AnalysisCompleteScreen({super.key});

  @override
  State<AnalysisCompleteScreen> createState() => _AnalysisCompleteScreenState();
}

class _AnalysisCompleteScreenState extends State<AnalysisCompleteScreen> {
  bool _navigated = false;

  void _maybeNavigateOnError(SajuRenewalProvider provider) {
    if (_navigated || provider.status != SajuRenewalFlowStatus.error) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ErrorScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    _maybeNavigateOnError(provider);
    final topic = provider.currentTopic;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 48)),
                const SizedBox(height: UnifiedTokens.spaceLg),
                Text(
                  '사주 계산이 끝났어요',
                  style: UnifiedText.titleLarge(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: UnifiedTokens.spaceSm),
                Text(
                  '당신의 사주 속에서\n첫 번째 이야기를 발견했어요',
                  style: UnifiedText.body(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                if (topic == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: UnifiedColors.black,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
                    decoration: BoxDecoration(
                      color: UnifiedColors.cardMain,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      topic.title,
                      style: UnifiedText.titleLarge(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: topic == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StoryPreviewScreen(),
                              ),
                            );
                          },
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
                      '이야기 보기',
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
        ),
      ),
    );
  }
}
