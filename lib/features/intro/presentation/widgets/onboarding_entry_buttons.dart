import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../intro_palette.dart';

/// [온보딩 전면 교체 2026-11 — design_handoff_onboarding_v2.zip 반영]
/// `Onboarding v2.html` `.btn-primary`/`.btn-ghost` 버튼 2종. README §4
/// "Actions" 표의 정확한 수치(높이/배경/그림자/애니메이션)를 그대로
/// 이식한다.
///
/// [기존 `onboarding_action_buttons.dart`와의 관계] 그 파일은 과거(v2
/// 리디자인, 2026-10-18) 버전의 Primary/Ghost 버튼으로 높이·배경·
/// 그림자 수치가 이번 디자인과 다르다(예: Primary 54px 단색, Ghost
/// 46px). 프로젝트 관례(구 코드 보존)에 따라 그 파일은 그대로 두고,
/// 이번 디자인 전용 버튼을 이 새 파일에 작성한다.
class OnboardingMoonPrimaryButton extends StatefulWidget {
  const OnboardingMoonPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.reduceMotion = false,
    this.enabled = true,
    this.height = 56,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool reduceMotion;
  final bool enabled;
  final double height;

  @override
  State<OnboardingMoonPrimaryButton> createState() =>
      _OnboardingMoonPrimaryButtonState();
}

class _OnboardingMoonPrimaryButtonState
    extends State<OnboardingMoonPrimaryButton> with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _shimmerController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    if (!widget.reduceMotion) {
      _glowController.repeat(reverse: true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _shimmerController.repeat();
      });
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'onboarding_primary_cta_button',
      button: true,
      child: GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowController, _shimmerController]),
          builder: (context, _) {
            // `@keyframes pulse{0%,100%{blur 18px alpha .28}50%{blur 32px
            // alpha .5}}`.
            final glowT = Curves.easeInOut.transform(_glowController.value);
            final blur = 18 + glowT * (32 - 18);
            // [온보딩 v3] README §2 "버튼" Primary pulse — alpha .28↔.5
            // (기존과 동일한 범위, 색만 골드로 교체).
            final alpha = 0.28 + glowT * (0.5 - 0.28);
            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                // [온보딩 v3] README §2 "버튼" Primary 배경 —
                // `linear-gradient(180deg, #f1da92, #e0c264)`.
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    IntroPalette.onboardingV3GlowLight,
                    IntroPalette.onboardingV3Glow,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: IntroPalette.onboardingV3Glow.withValues(
                      alpha: alpha,
                    ),
                    blurRadius: blur,
                  ),
                  const BoxShadow(
                    color: Color(0x8CFFFFFF),
                    blurRadius: 0,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.icon,
                          style: GoogleFonts.gowunBatang(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: IntroPalette.onboardingV3Ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: GoogleFonts.gowunBatang(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: IntroPalette.onboardingV3Ink,
                          ),
                        ),
                      ],
                    ),
                    if (!widget.reduceMotion) _buildShimmer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  /// `::after` — 110° 흰색 55% 띠가 -130%→130% 이동, 주기 앞 30%
  /// 구간에서만 보이고 나머지는 대기.
  Widget _buildShimmer() {
    final t = _shimmerController.value;
    if (t > 0.3) return const SizedBox.shrink();
    final pos = -1.3 + (t / 0.3) * 2.6;
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(pos, 0),
        child: Transform.rotate(
          angle: 0.2, // 110deg 근사(가로 대비 완만한 기울기).
          child: Container(
            width: double.infinity,
            height: widget.height * 1.6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-ghost` — 2열 그리드용 작은 버튼. [온보딩 v3] README §2 "버튼"
/// 보조 버튼 — 배경 `rgba(224,194,100,.06)`, 테두리
/// `1px solid rgba(224,194,100,.18)`, `backdrop-filter: blur(12px)`.
class OnboardingMoonGhostButton extends StatefulWidget {
  const OnboardingMoonGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    this.height = 50,
  });

  final String label;
  final VoidCallback onTap;

  /// 라벨 앞에 붙는 아이콘(예: ☾).
  final String? leadingIcon;

  /// 라벨 뒤에 붙는 아이콘(예: →).
  final String? trailingIcon;
  final double height;

  @override
  State<OnboardingMoonGhostButton> createState() =>
      _OnboardingMoonGhostButtonState();
}

class _OnboardingMoonGhostButtonState
    extends State<OnboardingMoonGhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: widget.leadingIcon != null
          ? 'onboarding_login_button'
          : 'onboarding_browse_guest_button',
      button: true,
      child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: IntroPalette.onboardingV3Card,
                border: Border.all(color: IntroPalette.onboardingV3Line),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leadingIcon != null) ...[
                    Text(
                      widget.leadingIcon!,
                      style: GoogleFonts.gowunBatang(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IntroPalette.onboardingV3Glow,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: GoogleFonts.gowunBatang(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: IntroPalette.onboardingV3Fg,
                    ),
                  ),
                  if (widget.trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.trailingIcon!,
                      style: GoogleFonts.gowunBatang(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IntroPalette.onboardingV3Glow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// 안내 링크 — "ⓘ 모든 풀이는 재미·참고용 이야기예요". Pretendard 11.5px,
/// faint 색, 가운데 정렬, ⓘ 배지(14×14 원).
class OnboardingNoticeLink extends StatelessWidget {
  const OnboardingNoticeLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'onboarding_notice_link',
      button: true,
      child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: IntroPalette.onboardingV3Line),
            ),
            child: Text(
              'i',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: IntroPalette.onboardingV3Glow,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '모든 풀이는 재미·참고용 이야기예요',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: IntroPalette.onboardingV3Faint,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
