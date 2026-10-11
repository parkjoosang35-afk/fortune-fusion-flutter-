import 'package:flutter/material.dart';

import '../intro_palette.dart';
import '../intro_text_styles.dart';

/// [온보딩 화면 교체 2026-10-11 — 신규] `Onboarding.html` `.sheet`
/// ("재미·참고용 콘텐츠 안내" 바텀시트). 기존에는 이 카피가 별도
/// 페이지(`/policy/notice`, [PolicyNoticeScreen])로 이동해 보여줬지만,
/// 이번 디자인 교체 지시서(README §1-4, 개발지시서 §06)는 이를 온보딩
/// 화면 안에서 바로 열리는 바텀시트로 바꾼다. [PolicyNoticeScreen]과
/// `/policy/notice` 라우트 자체는 다른 화면이 참조할 가능성에 대비해
/// 삭제하지 않고 그대로 보존한다(이 화면만 바텀시트로 전환).
///
/// 핸드오프 수치:
/// - 딤: 전체화면, `rgba(10,8,25,.55)` + blur(4px), opacity 전환 0.6s
/// - 시트: 하단고정, radius `22px 22px 0 0`,
///   `linear-gradient(180deg, #3a3264, #241f45)`, 전환 0.7s
///   `cubic-bezier(.2,.8,.2,1)` (translateY 105%→0)
/// - 본문: 전통 명리 기반 "재미·참고용" 안내 + 「알겠어요」 버튼
///
/// `showModalBottomSheet`의 기본 slide-up 전환이 핸드오프의
/// cubic-bezier(.2,.8,.2,1) 근사와 충분히 유사하므로, 별도
/// PageRouteBuilder 없이 `transitionAnimationController` 커브만
/// 지정해 디자인 의도를 살린다.
Future<void> showOnboardingNoticeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C0A0819), // rgba(10,8,25,.55) 근사.
    builder: (context) => const _OnboardingNoticeSheet(),
  );
}

class _OnboardingNoticeSheet extends StatelessWidget {
  const _OnboardingNoticeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [IntroPalette.sheetTop, IntroPalette.sheetBottom],
          ),
          border: Border(
            top: BorderSide(color: IntroPalette.cardBorder),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 손잡이(grab) — 38×4.
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: IntroPalette.cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              '재미·참고용 콘텐츠 안내',
              textAlign: TextAlign.center,
              style: IntroTextStyles.title(fontSize: 19),
            ),
            const SizedBox(height: 12),
            Text(
              '신통방통의 사주·운세 풀이는 전통 명리 이론을 바탕으로 한\n'
              '재미와 참고를 위한 이야기예요.\n'
              '중요한 결정은 당신의 마음과 함께 내려주세요.',
              textAlign: TextAlign.center,
              style: IntroTextStyles.sub(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: IntroPalette.primary,
                  foregroundColor: IntroPalette.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ).copyWith(
                  backgroundColor: const WidgetStatePropertyAll(
                    IntroPalette.glowLight,
                  ),
                ),
                child: Text(
                  '알겠어요',
                  style: IntroTextStyles.btnPrimary().copyWith(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
