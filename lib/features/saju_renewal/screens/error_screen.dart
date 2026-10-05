import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import 'analysis_complete_screen.dart';
import 'story_detail_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 공용 오류 화면.
///
/// [디자인 출처] `design_handoff_jeongtong_saju_v3`에는 전용 오류 화면
/// JSX가 없다(화면00-09 어디에도 에러 상태 컴포넌트가 정의되어 있지
/// 않음 — 검색 확인됨). 따라서 다른 화면(04/05/07/08)에서 이미 확립된
/// 다크 토큰·공용 위젯(`SajuDarkBase`/`SajuButton`/`SajuType`)을 그대로
/// 재사용해 톤을 통일한다 — 새로운 색상/컴포넌트를 임의로 만들지 않는다.
///
/// [오류처리 요구사항 — 변경 없음] 서버오류("일시적으로 결과를 불러오지
/// 못했습니다...")/네트워크오류(재시도 버튼)를 동일한 화면에서 처리한다.
/// 서버가 내려준 사용자 안내 문구를 그대로 보여주며(내부 코드/topic_id
/// 등은 Provider가 이미 걸러냄), "재시도" 버튼은
/// [SajuRenewalProvider.retry]를 호출해 직전 실패했던 단계부터 다시
/// 시도한다. 재시도가 성공해 status가 error를 벗어나면 그 상태에 맞는
/// 화면으로 자동 전환한다.
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
      body: SajuDarkBase(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 봉인 메달리온 톤의 원형 글리프 — 사주 카드와 동일한
                  // 금선/먹색 팔레트로 "깨진 인장" 느낌을 표현.
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SajuText.card,
                      border: Border.all(color: SajuText.lineGold, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: SajuGold.glow,
                          blurRadius: 28,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Text(
                      '✦',
                      style: TextStyle(
                        fontSize: 30,
                        color: SajuGold.g300.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '잠시 흐름이 끊겼어요',
                    textAlign: TextAlign.center,
                    style: SajuType.h2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: SajuType.body14,
                  ),
                  const SizedBox(height: 32),
                  SajuButton(
                    label: '다시 시도',
                    loading: _retrying,
                    onTap: _retrying
                        ? null
                        : () async {
                            setState(() => _retrying = true);
                            await context.read<SajuRenewalProvider>().retry();
                            if (mounted) setState(() => _retrying = false);
                          },
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: Text(
                      '처음으로 돌아가기',
                      style: TextStyle(
                        fontFamily: SajuType.ui,
                        fontSize: 13,
                        color: SajuText.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
