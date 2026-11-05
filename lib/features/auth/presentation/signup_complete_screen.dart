import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../fortune_period/domain/fortune_saju_profile.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../application/auth_provider.dart';
import 'widgets/auth_primary_button.dart';

/// [회원가입 통합 사주정보 — 디자인 핸드오프 05 "가입 완료" 화면]
///
/// `design_handoff_review/README.md` §05 스펙의 "Moonlit Crystal" 팔레트
/// (`IntroPalette`/`IntroTextStyles`)를 그대로 재현한다. 02(로그인)/03(가입)
/// 화면과 동일한 디자인 시스템을 사용해 가입 플로우 전체의 시각적 일관성을
/// 유지한다.
///
/// [2026-xx 리스킨] 이전 구현은 전혀 무관한 다른 피처("정통사주 리뉴얼")의
/// 다크 골드/블랙 톤 디자인 시스템(`SajuDarkBase`/`SajuGold`/`SajuType`)을
/// 잘못 재사용하고 있었다. 02/03과 톤이 어긋나 있던 것을 바로잡아
/// `IntroPalette`/`IntroTextStyles` 기반으로 전면 재작성한다. `_goHome()`의
/// 비로그인 결과보기 복귀 로직은 100% 그대로 보존했다.
///
/// [진입 경로] `BirthInputScreen(isSignupFlow: true)`가 저장(= 서버
/// `updateProfile` 성공)에 성공한 직후에만 `pushReplacement`로 연결된다.
/// 이 화면에서 "홈으로 가기"를 누르면 가입 플로우 전체 스택을 정리하고
/// `/home`으로 이동한다(뒤로가기로 사주 입력 화면이나 가입 화면으로
/// 되돌아갈 수 없다 — 가입이 이미 완료됐으므로).
class SignupCompleteScreen extends StatelessWidget {
  const SignupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final summary = user != null ? formatFortuneSajuSummary(user) : '';

    return PopScope(
      // [dev-spec.md §Interactions] 가입 완료 화면에서 시스템 뒤로가기로
      // 사주 입력 화면으로 돌아가는 것은 의미가 없다(이미 저장 완료) —
      // 바로 홈으로 보낸다.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      IntroPalette.backgroundTop,
                      IntroPalette.backgroundBottom,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIGN UP · 完',
                            style: IntroTextStyles.formEyebrow(
                              color: IntroPalette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF1DCFA),
                                    Color(0xFFD2B2F0),
                                    Color(0xFFB9D9EA),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: IntroPalette.glowShadow,
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                '命',
                                style: TextStyle(
                                  fontFamily:
                                      IntroTextStyles.title().fontFamily,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 30,
                                  color: IntroPalette.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '${user?.nickname ?? ''}님,\n가입이 완료되었어요',
                              textAlign: TextAlign.center,
                              style: IntroTextStyles.formTitle(
                                color: IntroPalette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '저장한 사주정보는 모든 운세 메뉴에서\n'
                              '다시 입력하지 않아도 함께 사용돼요.',
                              textAlign: TextAlign.center,
                              style: IntroTextStyles.formSubtitle(),
                            ),
                            const SizedBox(height: 28),
                            if (user != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 18,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: IntroPalette.cardBorder,
                                  ),
                                  color: IntroPalette.primaryLight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '◈ MY SAJU',
                                      style: IntroTextStyles.formEyebrow(
                                        color: IntroPalette.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      summary,
                                      style:
                                          const TextStyle(
                                            fontFamily: 'Pretendard',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ).copyWith(
                                            color: IntroPalette.textPrimary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    AuthPrimaryButton(
                      label: '☾ 홈으로 가기',
                      onPressed: () => _goHome(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [비로그인 결과보기 복귀 지시서 R2 — 기능 유지] 과거 로그인/가입
  /// 직후 확인하던 "결과보기 시트 복귀" pending 상태를, 이제 사주정보
  /// 입력까지 모두 마친 이 시점으로 옮겨서 그대로 확인한다. 저장된
  /// 복귀 대상이 있으면 원래 화면 + 결과보기 시트로 돌아가고, 없으면
  /// 기존과 동일하게 '/home'으로 이동한다 — 기능 삭제 없음.
  Future<void> _goHome(BuildContext context) async {
    final restored = await restorePendingResultAccessAfterLogin(context);
    if (!context.mounted || restored) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
