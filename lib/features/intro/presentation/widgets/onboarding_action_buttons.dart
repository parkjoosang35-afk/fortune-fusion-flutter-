import 'package:flutter/material.dart';

import '../intro_palette.dart';
import '../intro_text_styles.dart';

/// [온보딩 v2 리디자인 2026-10-18] `온보딩 v2.html` `.btn-primary`.
///
/// [v1→v2 변경] v1은 glow pulse(3.2s 무한반복) + 광택 스윕(::after 4.5s)
/// + 회전하는 ✧ 아이콘까지 있는 "살아있는" 버튼이었지만, v2 CSS에는 이
/// 세 앰비언트 애니메이션이 전부 빠지고 정적 shadow만 남았다(README
/// "Press 상태: scale 0.96 ... 색 반전이나 스프링 바운스는 쓰지 않습니다"
/// 외에 상시 모션 언급 없음 — README §등장 모션 표에도 Primary 버튼
/// 자체의 반복 애니메이션 행이 없다). 대신 끝에 `→`(trailing arrow,
/// opacity .6, Pretendard)가 추가됐다. 기존 [enablePulse] 파라미터는
/// 호환을 위해 남겨두되 기본값을 false로 바꿔 v2 기본 동작(정적)을
/// 기본값으로 삼는다.
class OnboardingPrimaryButton extends StatefulWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.enablePulse = false,
    this.reduceMotion = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final String? icon;

  /// v2 전용 — 라벨 뒤 보조 아이콘(예: `→`). opacity 0.6, 비굵은 폰트.
  final String? trailingIcon;
  final bool enablePulse;
  final bool reduceMotion;
  final bool enabled;

  @override
  State<OnboardingPrimaryButton> createState() =>
      _OnboardingPrimaryButtonState();
}

class _OnboardingPrimaryButtonState extends State<OnboardingPrimaryButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final AnimationController _sparkController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.enablePulse && !widget.reduceMotion) {
      _pulseController.repeat(reverse: true);
      _sparkController.repeat();
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) _shimmerController.repeat();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _shimmerController]),
          builder: (context, _) {
            final pulseT = widget.enablePulse ? _pulseController.value : 0.0;
            // v2 정적 shadow: `0 4px 22px rgba(232,200,245,.35)`. pulse가
            // 비활성(v2 기본)이면 blur/alpha는 이 고정값 그대로 유지된다.
            final blur = widget.enablePulse ? 18 + pulseT * (30 - 18) : 22.0;
            final alpha = _pressed
                ? 0.6
                : (widget.enablePulse ? 0.28 + pulseT * (0.5 - 0.28) : 0.35);
            return Container(
              height: 54, // v2: 56→54.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                // v2: 그라디언트 대신 단색 `background: var(--glow)`.
                color: IntroPalette.primary,
                boxShadow: [
                  BoxShadow(
                    color: IntroPalette.primary.withValues(alpha: alpha),
                    blurRadius: blur,
                    offset: _pressed ? Offset.zero : const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 0,
                    offset: const Offset(0, 1),
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
                        if (widget.icon != null) ...[
                          RotationTransition(
                            turns: _sparkController,
                            child: Text(
                              widget.icon!,
                              style: IntroTextStyles.btnPrimary(),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(widget.label, style: IntroTextStyles.btnPrimary()),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          Opacity(
                            opacity: 0.6,
                            child: Text(
                              widget.trailingIcon!,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                                color: IntroPalette.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.enablePulse) _buildShimmer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    final t = _shimmerController.value;
    final pos = -1.3 + t * 2.6;
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(pos, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.55),
                Colors.transparent,
              ],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-ghost` — v2는 2열 그리드 배치(`.row{grid-template-columns:1fr
/// 1fr}`)에서 쓰이는 작은 버튼으로 바뀌었다. 높이 56→**46**, 폰트
/// 15→**13px**, 배경 `var(--card)`(8% 알파)→`rgba(200,180,255,.06)`로
/// 더 옅어졌다. 단독 전체폭으로도 쓸 수 있도록 [fullWidthFontSize] 등
/// 기존 API는 유지한다.
class OnboardingGhostButton extends StatefulWidget {
  const OnboardingGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 46,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback onTap;

  /// v2에서는 아이콘이 라벨 "뒤"에 옅게(opacity .7, 11px) 붙는다(예:
  /// "둘러보기 ☾"). null이면 아이콘 없이 라벨만 표시.
  final String? icon;
  final double height;
  final double fontSize;

  @override
  State<OnboardingGhostButton> createState() => _OnboardingGhostButtonState();
}

class _OnboardingGhostButtonState extends State<OnboardingGhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // v2: `rgba(200,180,255,.06)`(기존 primaryLight #14보다 더 옅음).
            color: const Color(0x0FC8B4FF),
            border: Border.all(color: IntroPalette.cardBorder),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: IntroTextStyles.btnGhost(
                  color: IntroPalette.textPrimary,
                ).copyWith(fontSize: widget.fontSize),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 6),
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    widget.icon!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: IntroPalette.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
