import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../state/saju_renewal_provider.dart';
import 'birth_input_screen.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면① 메인(진입) — "내 사주
/// 분석하기" 버튼 하나만 제공한다.
///
/// [절대 금지] 기존 69종 그리드(JeontongEightyScreen)와 동일한 UI/UX를
/// 만들지 않는다 — 사용자는 "내 사주를 계산했더니 이런 이야기가
/// 발견됐다"는 경험을 해야 한다(지시서 §최종 사용자 흐름).
class SajuRenewalHomeScreen extends StatelessWidget {
  const SajuRenewalHomeScreen({super.key});

  void _start(BuildContext context) {
    context.read<SajuRenewalProvider>().startNewAnalysis();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BirthInputScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('정통사주 이야기', style: UnifiedText.title()),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔮', style: TextStyle(fontSize: 56)),
                const SizedBox(height: UnifiedTokens.spaceLg),
                Text(
                  '내 사주 속에 숨어 있는\n이야기를 발견해보세요',
                  textAlign: TextAlign.center,
                  style: UnifiedText.title(),
                ),
                const SizedBox(height: UnifiedTokens.spaceSm),
                Text(
                  '생년월일을 입력하면, 사주를 계산해\n지금 당신에게 꼭 맞는 이야기를 찾아드려요',
                  textAlign: TextAlign.center,
                  style: UnifiedText.body(),
                ),
                const SizedBox(height: UnifiedTokens.spaceXl),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _start(context),
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
                      '내 사주 분석하기',
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
