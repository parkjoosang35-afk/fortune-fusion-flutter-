import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../state/saju_renewal_provider.dart';
import 'analysis_complete_screen.dart';
import 'story_detail_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 공용 오류 화면.
///
/// [오류처리 요구사항] 서버오류("일시적으로 결과를 불러오지 못했습니다
/// ...")/네트워크오류(재시도 버튼)를 동일한 화면에서 처리한다. 서버가
/// 내려준 사용자 안내 문구를 그대로 보여주며(내부 코드/topic_id 등은
/// Provider가 이미 걸러냄), "재시도" 버튼은 [SajuRenewalProvider.retry]를
/// 호출해 직전 실패했던 단계부터 다시 시도한다. 재시도가 성공해
/// status가 error를 벗어나면 그 상태에 맞는 화면으로 자동 전환한다.
class ErrorScreen extends StatefulWidget {
  const ErrorScreen({super.key});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _retrying = false;
  bool _navigated = false;

  void _maybeNavigateAfterRetry(SajuRenewalProvider provider) {
    if (_navigated || provider.status == SajuRenewalFlowStatus.error) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (provider.status == SajuRenewalFlowStatus.storyDetail) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StoryDetailScreen()),
        );
      } else {
        // factsReady/storyPreview 등 — 분석완료 화면으로 복귀(그 화면이
        // 다시 적절한 다음 화면으로 안내).
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AnalysisCompleteScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    _maybeNavigateAfterRetry(provider);
    final message =
        provider.errorMessage ?? '일시적으로 결과를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: UnifiedColors.textCaption,
                ),
                const SizedBox(height: UnifiedTokens.spaceLg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: UnifiedText.body(color: UnifiedColors.textPrimary),
                ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _retrying
                        ? null
                        : () async {
                            setState(() => _retrying = true);
                            await context.read<SajuRenewalProvider>().retry();
                            if (mounted) setState(() => _retrying = false);
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
                    child: _retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            '다시 시도',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: UnifiedTokens.spaceSm),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text('처음으로 돌아가기', style: UnifiedText.caption()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
