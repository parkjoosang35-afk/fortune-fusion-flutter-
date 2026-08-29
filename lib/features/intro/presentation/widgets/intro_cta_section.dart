import 'package:flutter/material.dart';
import 'intro_character.dart';
import 'intro_eyebrow_label.dart';
import 'intro_title_text.dart';
import 'intro_progress_dots.dart';
import '../intro_palette.dart';
import '../intro_text_styles.dart';

/// [인트로 전면 개편] 4단계 시작화면 - 타이틀/서브카피 + 메인버튼(회원가입)/
/// 보조버튼(로그인)/안내 링크 + (게스트모드 유지 결정에 따른) 비회원 시작 링크.
///
/// [UX 금지사항 준수] 강제 모달 없음, 긴 약관 없음, 유료/포인트/구독 느낌의
/// 문구 없음 — 오직 사용자가 지정한 정확한 카피만 노출한다.
///
/// [2026 디자인 핸드오프 콘텐츠 전면 반영] 이전 버전은 "바로시작하기(게스트)/
/// 가입하고복주머니받기/로그인" 3단 구조로 핸드오프와 무관한 문구였다.
/// `screens/01_Intro.html` 페이지4 `.ctas` 블록을 그대로 이식한다:
///   - Primary `✧ 시작하기` → 회원가입(onSignup)
///   - Secondary `☾ 이미 계정이 있어요` → 로그인(onLogin)
///   - Link `"재미·참고용" 콘텐츠 안내` → /policy/notice(onDisclaimerTap)
/// [기존 결정사항과의 절충] "바로 시작하기(게스트모드) 유지"는 이전 세션에서
/// 사용자가 명시적으로 확정한 사항이라 완전히 제거하지 않고, 핸드오프에 없는
/// 4번째 요소로 링크 버튼 밑에 작은 텍스트 링크로 추가했다(기존
/// `showGuestHint` on/off 설정을 그대로 재사용).
class IntroCTASection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String signupRewardText;
  final bool showGuestHint;
  final VoidCallback onStartAsGuest;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onDisclaimer;

  const IntroCTASection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.signupRewardText,
    required this.showGuestHint,
    required this.onStartAsGuest,
    required this.onSignup,
    required this.onLogin,
    required this.onDisclaimer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const IntroEyebrowLabel('READY · TO · BEGIN'),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // [핸드오프 반영] 신통도령 celebrating - halo + 스파클 3개 + float
                SizedBox(
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const IntroCharacter(
                        asset: 'assets/images/home/doryeong/celebrating.png',
                        size: 200,
                        haloSize: 260,
                      ),
                      const Positioned(
                        top: 8,
                        left: 24,
                        child: _Sparkle(color: IntroPalette.gold, size: 18),
                      ),
                      const Positioned(
                        top: 0,
                        right: 30,
                        child: _Sparkle(color: IntroPalette.primary, size: 14),
                      ),
                      const Positioned(
                        top: 56,
                        right: 8,
                        child: _Sparkle(color: IntroPalette.gold, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                IntroTitleText(
                  title,
                  style: IntroTextStyles.title(fontSize: 30),
                  highlight: '신통방통',
                  highlightColors: const [
                    IntroPalette.gold,
                    IntroPalette.primary,
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: IntroTextStyles.sub(),
                ),
              ],
            ),
          ),
        ),
        const IntroProgressDots(activeIndex: 3),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary — ✧ 시작하기 (회원가입)
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IntroPalette.primary,
                  foregroundColor: IntroPalette.onPrimary,
                  elevation: 0,
                  shadowColor: IntroPalette.glowShadow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✧', style: IntroTextStyles.btnPrimary()),
                    const SizedBox(width: 8),
                    Text('시작하기', style: IntroTextStyles.btnPrimary()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Secondary — ☾ 이미 계정이 있어요 (로그인)
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onLogin,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0x14C8B4FF),
                  side: const BorderSide(color: Color(0x40DCC8FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '☾',
                      style: IntroTextStyles.btnGhost().copyWith(
                        color: IntroPalette.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('이미 계정이 있어요', style: IntroTextStyles.btnGhost()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Link — "재미·참고용" 콘텐츠 안내
            TextButton(
              onPressed: onDisclaimer,
              child: Text(
                '"재미·참고용" 콘텐츠 안내',
                style: IntroTextStyles.linkButton(),
              ),
            ),
            // [기존 결정사항 유지] 바로 시작하기(게스트모드) — 핸드오프에는
            // 없는 요소지만 사용자가 별도로 확정한 "게스트 모드 유지" 결정을
            // 반영해 가장 눈에 덜 띄는 링크 형태로 하단에 추가했다.
            if (showGuestHint)
              TextButton(
                onPressed: onStartAsGuest,
                child: Text(
                  '회원가입 없이 둘러보기',
                  style: IntroTextStyles.linkButton().copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0x8CDCD2F5),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Sparkle extends StatefulWidget {
  final Color color;
  final double size;

  const _Sparkle({required this.color, required this.size});

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 0.6 + 0.4 * (0.5 - (t - 0.5).abs()) * 2;
        final opacity = 0.4 + 0.6 * (0.5 - (t - 0.5).abs()) * 2;
        return Opacity(
          opacity: opacity.clamp(0.4, 1.0),
          child: Transform.scale(scale: scale.clamp(0.6, 1.0), child: child),
        );
      },
      child: Icon(Icons.auto_awesome, color: widget.color, size: widget.size),
    );
  }
}
