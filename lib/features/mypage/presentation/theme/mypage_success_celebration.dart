import 'package:flutter/material.dart';
import 'mypage_minimal_theme.dart';

/// [마이페이지 리뉴얼] S02/S04 등 "보상/발급 성공" 바텀시트 공통 축하
/// 애니메이션 — 체크 아이콘 스케일-인 + 반짝임(sparkle) + 부드러운 fade.
/// 900ms 이내로 짧게 재생한다.
///
/// 원래 `coupang_pass_sheet.dart`(S02)에서 `_SuccessCelebration`이라는
/// 비공개 위젯으로 처음 구현했으나, `fortune_ad_watch_dialog.dart`(S04)도
/// README상 동일한 "짧은 성공 연출 후 자동 닫힘" 패턴을 쓰므로 중복 구현을
/// 피하기 위해 제목/부제를 매개변수로 받는 공용 위젯으로 추출했다.
class MyPageSuccessCelebration extends StatefulWidget {
  const MyPageSuccessCelebration({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<MyPageSuccessCelebration> createState() =>
      _MyPageSuccessCelebrationState();
}

class _MyPageSuccessCelebrationState extends State<MyPageSuccessCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _sparkles = [
    Offset(-42, -30),
    Offset(38, -34),
    Offset(-46, 22),
    Offset(44, 26),
    Offset(0, -48),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MyPageSpacing.sp8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ..._sparkles.map(
                  (offset) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = Curves.easeOut.transform(_controller.value);
                      return Positioned(
                        left: 48 + offset.dx * t - 7,
                        top: 48 + offset.dy * t - 7,
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: MyPageColors.gold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                ScaleTransition(
                  scale: scale,
                  child: FadeTransition(
                    opacity: fade,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: MyPageColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFFFBF1DE),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MyPageSpacing.sp4),
          FadeTransition(
            opacity: fade,
            child: Text(
              widget.title,
              style: const TextStyle(
                fontFamily: MyPageFonts.ui,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: MyPageColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: MyPageSpacing.sp1),
          FadeTransition(
            opacity: fade,
            child: Text(
              widget.subtitle,
              style: MyPageTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
