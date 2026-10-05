import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../state/saju_renewal_provider.dart';
import 'analysis_complete_screen.dart';
import 'error_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면③ 계산중.
///
/// [절대 금지] 단순 타이머로 N초 후 다음 화면으로 넘어가지 않는다 —
/// 반드시 실제 Birth Profile → SAJU FACTS → FACT Cache → Topic Selection
/// 완료(서버 응답)를 기다린 뒤에만 다음 화면으로 전환한다(지시서
/// §화면③ 요구사항). 이 화면은 [SajuRenewalProvider.status]를 watch해
/// factsReady/storyPreview가 되면 자동으로 다음 화면으로 넘어가고,
/// error가 되면 오류 화면으로 전환한다 — 화면 자신은 타이머를 두지
/// 않는다.
class CalculatingScreen extends StatefulWidget {
  const CalculatingScreen({super.key});

  @override
  State<CalculatingScreen> createState() => _CalculatingScreenState();
}

class _CalculatingScreenState extends State<CalculatingScreen> {
  bool _navigated = false;

  void _maybeNavigate(SajuRenewalProvider provider) {
    if (_navigated) return;
    // factsReady 이후 Provider가 내부적으로 곧바로 summary interpret까지
    // 이어서 호출하므로(startCalculating→_loadTopics→loadPreview),
    // storyPreview 상태가 되었을 때 분석완료 화면으로 넘어간다 — 그래야
    // 화면④(분석완료)가 즉시 화면⑤ 제목/요약을 보여줄 수 있다.
    if (provider.status == SajuRenewalFlowStatus.storyPreview ||
        provider.status == SajuRenewalFlowStatus.factsReady) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnalysisCompleteScreen()),
        );
      });
    } else if (provider.status == SajuRenewalFlowStatus.error) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ErrorScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    _maybeNavigate(provider);

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: UnifiedColors.black,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                Text(
                  '사주를 정성껏\n살펴보고 있어요',
                  textAlign: TextAlign.center,
                  style: UnifiedText.titleLarge(),
                ),
                const SizedBox(height: UnifiedTokens.spaceSm),
                Text(
                  '명식을 계산하고\n지금 꼭 필요한 이야기를 찾는 중입니다',
                  textAlign: TextAlign.center,
                  style: UnifiedText.body(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
