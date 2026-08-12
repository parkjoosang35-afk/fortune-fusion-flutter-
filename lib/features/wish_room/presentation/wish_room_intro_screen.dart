import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_room_provider.dart';
import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';
import '../widgets/wish_room_sigils.dart';
import '../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_guide_modal.dart';
import 'wish_room_shell.dart';

/// 신통방통 소원방 · 인트로(앱 최초 진입) 화면
/// 출처: `handoff/IntroScreen.jsx`
///
/// 라우트: `/wish-room` (기본 소원방 진입점, `/` 대신 별도 경로 사용 —
/// 기존 앱의 스플래시/인트로 흐름과 충돌하지 않도록 물리적으로 분리)
class WishRoomIntroScreen extends StatefulWidget {
  const WishRoomIntroScreen({super.key});

  @override
  State<WishRoomIntroScreen> createState() => _WishRoomIntroScreenState();
}

class _WishRoomIntroScreenState extends State<WishRoomIntroScreen> with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _haloCtrl;
  late final AnimationController _orbit1;
  late final AnimationController _orbit2;
  late final AnimationController _orbit3;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _haloCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _orbit1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..repeat(reverse: true);
    _orbit2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 6400))..repeat(reverse: true);
    _orbit3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 4400))..repeat(reverse: true);
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

    // Hive 기반 상태 초기화(최초 1회) — 이후 온보딩 여부에 따라 홈으로 스킵 가능.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<WishRoomProvider>();
      await provider.init();
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _haloCtrl.dispose();
    _orbit1.dispose();
    _orbit2.dispose();
    _orbit3.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _enterWishRoom() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WishRoomShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;

    return Scaffold(
      backgroundColor: palette.bg2,
      body: Stack(
        children: [
          // Atmospheric radial background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.1,
                  colors: [
                    palette.glow.withValues(alpha: 0.32),
                    palette.bg1,
                    palette.bg2,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // Big sigils
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: WishRoomSigil(size: 340, color: palette.glow, opacity: 0.42),
            ),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: WishRoomSigil(size: 230, color: palette.fg, opacity: 0.22),
            ),
          ),
          // Dust particles
          Positioned.fill(child: WishRoomDust(count: 14, color: palette.glow)),
          // Star sparkles
          ..._buildSparkles(palette),
          // Foreground content
          SafeArea(
            child: FadeTransition(
              opacity: _entrance,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '神通萬通 · SINTONG',
                      style: WishRoomText.monoSm(palette.muted.withValues(alpha: 0.85)).copyWith(
                        letterSpacing: 0.4 * 10,
                      ),
                    ),
                    _buildCenter(palette),
                    _buildCtas(palette),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenter(WishRoomPaletteTokens palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _haloCtrl,
                builder: (context, _) {
                  final t = _haloCtrl.value;
                  return Opacity(
                    opacity: 0.7 + 0.3 * t,
                    child: Transform.scale(
                      scale: 1.0 + 0.08 * t,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [palette.glowShadow, palette.glowShadow.withValues(alpha: 0)],
                            stops: const [0.0, 0.65],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _floatCtrl,
                builder: (context, _) => Transform.translate(
                  offset: Offset(0, -6 * _floatCtrl.value),
                  child: const WishRoomPouch(size: 140),
                ),
              ),
              AnimatedBuilder(
                animation: _orbit1,
                builder: (context, _) => Positioned(
                  top: 4,
                  left: -14,
                  child: Transform.translate(
                    offset: Offset(-3 * _orbit1.value, -8 * _orbit1.value),
                    child: Transform.rotate(
                      angle: 15 * math.pi / 180 * _orbit1.value,
                      child: const WishRoomShard(size: 18),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _orbit2,
                builder: (context, _) => Positioned(
                  top: 44,
                  right: -18,
                  child: Transform.translate(
                    offset: Offset(3 * _orbit2.value, -5 * _orbit2.value),
                    child: Transform.rotate(
                      angle: -12 * math.pi / 180 * _orbit2.value,
                      child: const WishRoomShard(size: 14),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _orbit3,
                builder: (context, _) => Positioned(
                  top: -14,
                  right: 14,
                  child: Transform.translate(
                    offset: Offset(0, -4 * _orbit3.value),
                    child: Transform.rotate(
                      angle: 10 * math.pi / 180 * _orbit3.value,
                      child: const WishRoomShard(size: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '마음속 바람을\n담을 그릇',
          textAlign: TextAlign.center,
          style: WishRoomText.display1(palette.fg).copyWith(
            shadows: [Shadow(color: palette.glowShadow, blurRadius: 30)],
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            '촛불로 켜두고, 마법진으로 봉인하고,\n이루어질 때까지 함께 밝힙니다.',
            textAlign: TextAlign.center,
            style: WishRoomText.body(palette.muted.withValues(alpha: 0.9)).copyWith(height: 1.75),
          ),
        ),
      ],
    );
  }

  Widget _buildCtas(WishRoomPaletteTokens palette) {
    return Column(
      children: [
        WishRoomPouchButton(
          label: '소원방 들어가기',
          primary: true,
          palette: palette,
          expand: true,
          onPressed: _enterWishRoom,
        ),
        const SizedBox(height: 10),
        WishRoomPouchButton(
          label: '❖  소원방 사용 설명',
          primary: false,
          palette: palette,
          expand: true,
          onPressed: () => showWishRoomGuideModal(context, onFinished: _enterWishRoom),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _enterWishRoom,
          child: Text('이미 계정이 있어요', style: WishRoomText.body(palette.muted.withValues(alpha: 0.7)).copyWith(fontSize: 12)),
        ),
      ],
    );
  }

  List<Widget> _buildSparkles(WishRoomPaletteTokens palette) {
    const specs = [
      (top: 0.18, left: 0.20, right: null, size: 3.0, delayMs: 0),
      (top: 0.24, left: null, right: 0.18, size: 2.0, delayMs: 1200),
      (top: 0.42, left: 0.12, right: null, size: 2.0, delayMs: 2400),
      (top: 0.38, left: null, right: 0.14, size: 3.0, delayMs: 800),
      (top: 0.58, left: 0.78, right: null, size: 2.0, delayMs: 1600),
    ];
    return specs.map((s) {
      return _Sparkle(
        top: s.top,
        left: s.left,
        right: s.right,
        size: s.size,
        delayMs: s.delayMs,
        color: palette.glow,
        glowShadow: palette.glowShadow,
      );
    }).toList();
  }
}

class _Sparkle extends StatefulWidget {
  const _Sparkle({
    required this.top,
    required this.left,
    required this.right,
    required this.size,
    required this.delayMs,
    required this.color,
    required this.glowShadow,
  });

  final double top;
  final double? left;
  final double? right;
  final double size;
  final int delayMs;
  final Color color;
  final Color glowShadow;

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * widget.top,
      left: widget.left != null ? MediaQuery.of(context).size.width * widget.left! : null,
      right: widget.right != null ? MediaQuery.of(context).size.width * widget.right! : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = (math.sin(_ctrl.value * math.pi * 2) + 1) / 2;
          return Opacity(
            opacity: 0.3 + 0.7 * t,
            child: Transform.scale(
              scale: 0.8 + 0.4 * t,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(color: widget.color, blurRadius: 8),
                    BoxShadow(color: widget.glowShadow, blurRadius: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
