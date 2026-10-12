import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import 'analysis_complete_screen.dart';
import 'birth_input_screen.dart';
import 'story_detail_screen.dart';
import 'story_preview_screen.dart';

/// [버그 수정 — saju-handoff-spec.pdf §6.4 R-D "추정 금지" 미이행 보완]
/// 서버(TK-6, admin_web topics/select·interpret route.ts)는 성별/출생정보가
/// 없으면 "성별을 입력해 주세요"(GENDER_REQUIRED) / "프로필을 먼저
/// 입력해주세요"(BIRTH_INFO_REQUIRED) 상태를 reason 코드로 명확히 내려준다.
/// 그런데 이 화면은 지금까지 이 reason을 전혀 구분하지 않고 모든 오류를
/// 동일하게 "다시 시도"(provider.retry() = 같은 요청 재실행) 버튼 하나로만
/// 처리했다 — 홈 화면의 `_isProfileComplete()` 사전 검사가 신규 흐름은
/// 대부분 막아주지만, 클라이언트 캐시 user.gender와 서버 DB 값이 어긋나는
/// 예외 상황(다른 기기 동기화 지연 등)에서는 서버가 실제로 이 reason을
/// 반환할 수 있다. 이 경우 "다시 시도"를 눌러도 서버 DB 상태(성별 없음)가
/// 그대로이므로 똑같은 실패가 반복되는 무한 루프가 되고, 사용자가 성별을
/// 고칠 수 있는 화면으로 안내하는 경로가 전혀 없었다. §6.4 R-D는 "성별을
/// 입력해 주세요 상태로 반환"하라고 명시하므로, 이 두 reason일 때만 버튼을
/// "출생정보 입력하기"로 바꿔 BirthInputScreen(수정 모드)으로 보내고,
/// 저장 후 돌아오면 자동으로 retry()를 호출해 사용자가 별도 조작 없이
/// 바로 이어서 진행되게 한다.
const Set<String> _kProfileFixReasons = {'GENDER_REQUIRED', 'BIRTH_INFO_REQUIRED'};

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
      } else if (provider.status == SajuRenewalFlowStatus.storyPreview) {
        // [전수검수 2026-10-12 D-3] 미리보기 오류의 재시도 성공은 05 직행 —
        // 기존엔 04(분석완료) 우회로 "이야기 열어 보기"를 한 번 더 눌러야 했다.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StoryPreviewScreen()),
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

  /// §6.4 R-D 대응 — 출생정보 입력(수정 모드)으로 보낸 뒤, 저장을 마치고
  /// 돌아오면 사용자가 다시 "다시 시도"를 누를 필요 없이 자동으로 재시도한다
  /// (BirthInputScreen은 isEditMode=true일 때 저장 성공 시 그냥 pop만 하므로,
  /// 이 화면이 돌아온 직후를 감지해 이어서 진행시켜야 한다).
  Future<void> _goFixProfileThenRetry(BuildContext context) async {
    setState(() => _retrying = true);
    final provider = context.read<SajuRenewalProvider>();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BirthInputScreen(isEditMode: true)));
    if (!mounted) return;
    await provider.retry();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    _maybeNavigateAfterRetry(provider);
    final message =
        provider.errorMessage ?? '일시적으로 결과를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
    // [§6.4 R-D] 성별/출생정보 누락은 "재시도"가 아니라 "입력 화면 이동"으로
    // 풀어야 한다 — 서버 DB 상태(성별 없음)가 그대로인 한 단순 재시도는
    // 똑같은 실패만 반복한다(추정 금지 원칙상 클라이언트가 임의로 기본값을
    // 채워 보낼 수도 없음).
    final needsProfileFix = _kProfileFixReasons.contains(provider.errorReason);

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
                    label: needsProfileFix ? '출생정보 입력하기' : '다시 시도',
                    loading: _retrying,
                    onTap: _retrying
                        ? null
                        : () async {
                            if (needsProfileFix) {
                              await _goFixProfileThenRetry(context);
                              return;
                            }
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
