// ============================================================
// [부적게이트 · TalismanGate] — "정통사주" 섹션 진입 게이트 화면
//
// mode="tapToEnter": 부적을 [JeontongGateSession.tapsRequired]번(5번) 탭하면
// [JeontongGateSession.revealDelayMs] 뒤 onEnter가 발화되어 정통사주 69종
// 목록([JeontongEightyMatrix.browseRoute])으로 이동한다. 카운트다운/자동
// 진입 로직은 쓰지 않는다 — 오직 탭 횟수로만 진입한다.
//
// 이 게이트는 categoryId를 전혀 알지 못하며(아직 사용자가 카테고리를 고르기
// 전 시점), 종료 후에는 항상 목록 화면([browseRoute])으로만 이동한다.
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/jeontong_eighty_matrix.dart';
import '../domain/jeontong_gate_session.dart';

/// 부적게이트 전용 격리 팔레트 — README 시각 스펙 그대로.
class _GatePalette {
  _GatePalette._();

  // 배경 (먹색)
  static const Color bgOuter = Color(0xFF2A1B2E);
  static const Color bgMid = Color(0xFF14091A);
  static const Color bgInner = Color(0xFF08040E);

  // 부적 (홍색)
  static const Color talismanTop = Color(0xFFD0271F);
  static const Color talismanMid = Color(0xFFB01818);
  static const Color talismanBottom = Color(0xFF8E1010);

  // 글로우/텍스트 (금색)
  static const Color goldDeep = Color(0xFFD4A24C);
  static const Color gold = Color(0xFFE8C368);
  static const Color goldPale = Color(0xFFF5E6B8);
}

/// 팔괘(八卦) — 배경 장식용 회전 한자.
const List<String> _kBaguaGlyphs = ['乾', '兌', '離', '震', '巽', '坎', '艮', '坤'];

class JeontongTalismanGateScreen extends StatefulWidget {
  const JeontongTalismanGateScreen({super.key});

  @override
  State<JeontongTalismanGateScreen> createState() =>
      _JeontongTalismanGateScreenState();
}

class _JeontongTalismanGateScreenState extends State<JeontongTalismanGateScreen>
    with TickerProviderStateMixin {
  static const Size _talismanSize = Size(220, 300);

  late final AnimationController _baguaCtrl;
  late final math.Random _random;

  int _tapCount = 0;
  String? _currentBlessing;
  Timer? _blessingTimer;
  Timer? _revealTimer;
  final List<String> _recentBlessings = [];

  double _tiltX = 0; // -1..1
  double _tiltY = 0; // -1..1

  final List<_ParticleBurst> _bursts = [];

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _random = math.Random();

    // 팔괘 회전 배경 — 장식용 연속 회전.
    _baguaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  void _onTapTalisman(TapUpDetails details, Size localSize) {
    if (_navigated) return;
    final nextCount = _tapCount + 1;
    setState(() => _tapCount = nextCount);

    final blessing = _pickBlessing();
    _showBlessing(blessing);
    _spawnBurst(details.localPosition, localSize);

    // [tapToEnter] tapsRequired번 모두 탭하면 revealDelayMs 뒤 진입.
    if (nextCount >= JeontongGateSession.tapsRequired) {
      _revealTimer?.cancel();
      _revealTimer = Timer(
        const Duration(milliseconds: JeontongGateSession.revealDelayMs),
        _finish,
      );
    }
  }

  String _pickBlessing() {
    final pool = kJeontongGateBlessings
        .where((b) => !_recentBlessings.contains(b))
        .toList();
    final source = pool.isNotEmpty ? pool : kJeontongGateBlessings;
    final picked = source[_random.nextInt(source.length)];
    _recentBlessings.add(picked);
    if (_recentBlessings.length > 4) {
      _recentBlessings.removeAt(0);
    }
    return picked;
  }

  void _showBlessing(String text) {
    _blessingTimer?.cancel();
    setState(() => _currentBlessing = text);
    _blessingTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _currentBlessing = null);
    });
  }

  void _spawnBurst(Offset origin, Size localSize) {
    final specs = List.generate(24, (i) {
      final angle = (2 * math.pi / 24) * i + _random.nextDouble() * 0.3;
      final distance = 40.0 + _random.nextDouble() * 60.0;
      final isCoin = i.isEven;
      return _ParticleSpec(angle: angle, distance: distance, isCoin: isCoin);
    });
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    final burst = _ParticleBurst(
      origin: origin,
      specs: specs,
      controller: controller,
    );
    setState(() => _bursts.add(burst));
    controller.forward().whenCompleteOrCancel(() {
      controller.dispose();
      if (!mounted) return;
      setState(() => _bursts.remove(burst));
    });
  }

  void _finish() {
    if (_navigated) return;
    _navigated = true;
    // [화면 전환] 0.6초 정도의 짧은 페이드 후 정통사주 69종 목록 화면으로
    // 교체 이동(뒤로가기 시 게이트를 다시 보지 않도록 pushReplacementNamed).
    setState(() {});
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(JeontongEightyMatrix.browseRoute);
    });
  }

  @override
  void dispose() {
    _blessingTimer?.cancel();
    _revealTimer?.cancel();
    _baguaCtrl.dispose();
    for (final b in _bursts) {
      b.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tapsRequired = JeontongGateSession.tapsRequired;
    final progress = (_tapCount / tapsRequired).clamp(0.0, 1.0);
    final reachedGoal = _tapCount >= tapsRequired;

    return Scaffold(
      backgroundColor: _GatePalette.bgInner,
      body: AnimatedOpacity(
        opacity: _navigated ? 0 : 1,
        duration: const Duration(milliseconds: 600),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 배경 (먹색 방사 그라데이션)
            const _GateBackground(),
            // 2. 팔괘 회전 배경 (탭 진행도에 비례해 살짝 더 회전)
            AnimatedBuilder(
              animation: _baguaCtrl,
              builder: (context, _) =>
                  _BaguaRing(rotationTurns: _baguaCtrl.value + progress * 0.5),
            ),
            // 3. 본문
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    '今 日 之 運',
                    style: _monoStyle(color: _GatePalette.goldDeep, size: 11),
                  ),
                  const SizedBox(height: 6),
                  const _GateHintText(),
                  const Spacer(),
                  Listener(
                    onPointerMove: (event) =>
                        _onPointerMove(event.localPosition, _talismanSize),
                    child: GestureDetector(
                      onTapUp: (details) =>
                          _onTapTalisman(details, _talismanSize),
                      child: SizedBox(
                        width: _talismanSize.width,
                        height: _talismanSize.height,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _Talisman(tiltX: _tiltX, tiltY: _tiltY),
                            for (final burst in _bursts)
                              AnimatedBuilder(
                                animation: burst.controller,
                                builder: (context, _) => CustomPaint(
                                  size: _talismanSize,
                                  painter: _ParticlePainter(
                                    origin: burst.origin,
                                    specs: burst.specs,
                                    t: burst.controller.value,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _currentBlessing == null
                        ? const SizedBox(height: 28, key: ValueKey('empty'))
                        : _BlessingBadge(
                            key: ValueKey(_currentBlessing),
                            text: _currentBlessing!,
                          ),
                  ),
                  const Spacer(),
                  // [tapToEnter] 카운트다운 대신 안내문 + 탭 진행 도트.
                  _GateFooter(
                    tapCount: _tapCount,
                    tapsRequired: tapsRequired,
                    reachedGoal: reachedGoal,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPointerMove(Offset localPos, Size size) {
    final dx = (localPos.dx / size.width) * 2 - 1;
    final dy = (localPos.dy / size.height) * 2 - 1;
    setState(() {
      _tiltX = dx.clamp(-1.0, 1.0);
      _tiltY = dy.clamp(-1.0, 1.0);
    });
  }
}

TextStyle _monoStyle({required Color color, required double size}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Courier'],
    fontSize: size,
    letterSpacing: 3.0,
    fontWeight: FontWeight.w500,
    color: color,
  );
}

// ─── 배경 ────────────────────────────────────────────────
class _GateBackground extends StatelessWidget {
  const _GateBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [
            _GatePalette.bgOuter,
            _GatePalette.bgMid,
            _GatePalette.bgInner,
          ],
          stops: [0, 0.55, 1],
        ),
      ),
    );
  }
}

// ─── 팔괘 회전 링 ────────────────────────────────────────
class _BaguaRing extends StatelessWidget {
  const _BaguaRing({required this.rotationTurns});
  final double rotationTurns;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: rotationTurns * 2 * math.pi,
          child: SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              children: [
                for (int i = 0; i < _kBaguaGlyphs.length; i++) _bagatGlyphAt(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bagatGlyphAt(int i) {
    final angle = (2 * math.pi / _kBaguaGlyphs.length) * i;
    const radius = 150.0;
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    return Positioned(
      left: 160 + dx - 12,
      top: 160 + dy - 12,
      child: Opacity(
        opacity: 0.14,
        child: Text(
          _kBaguaGlyphs[i],
          style: const TextStyle(
            fontSize: 22,
            color: _GatePalette.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── 부적 본체 ───────────────────────────────────────────
class _Talisman extends StatelessWidget {
  const _Talisman({required this.tiltX, required this.tiltY});
  final double tiltX;
  final double tiltY;

  @override
  Widget build(BuildContext context) {
    // README 스펙 — 마우스/터치 이동에 반응하는 3D 틸트(±15°).
    final rotX = tiltY * (15 * math.pi / 180);
    final rotY = -tiltX * (15 * math.pi / 180);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(rotX)
        ..rotateY(rotY),
      child: Container(
        width: 180,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _GatePalette.talismanTop,
              _GatePalette.talismanMid,
              _GatePalette.talismanBottom,
            ],
          ),
          border: Border.all(
            color: _GatePalette.goldDeep.withValues(alpha: 0.6),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: _GatePalette.goldDeep.withValues(alpha: 0.45),
              blurRadius: 34,
              spreadRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '神通',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: _GatePalette.goldPale,
                shadows: [
                  Shadow(
                    color: _GatePalette.gold.withValues(alpha: 0.8),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 118,
              height: 150,
              child: CustomPaint(painter: _TalismanSymbolPainter()),
            ),
            const SizedBox(height: 10),
            Text(
              '萬事亨通',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: _GatePalette.goldDeep.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 힌트 문구 — README/원본 JSX 스펙: "부적을 만지면 좋은 일이 생깁니다"
/// ("좋은 일" 부분만 금색으로 강조).
class _GateHintText extends StatelessWidget {
  const _GateHintText();

  static const String _full = '부적을 만지면 좋은 일이 생깁니다';
  static const String _highlight = '좋은 일';

  @override
  Widget build(BuildContext context) {
    final idx = _full.indexOf(_highlight);
    final before = idx >= 0 ? _full.substring(0, idx) : _full;
    final after = idx >= 0 ? _full.substring(idx + _highlight.length) : '';
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 16,
          letterSpacing: 1,
          fontWeight: FontWeight.w400,
          color: _GatePalette.goldPale,
        ),
        children: [
          TextSpan(text: before),
          if (idx >= 0)
            TextSpan(
              text: _highlight,
              style: TextStyle(
                color: _GatePalette.gold,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (idx >= 0) TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// 부적 중앙 라인아트 심볼 — 원본 JSX의 SVG(viewBox 0 0 140 180)를 그대로
/// CustomPainter로 재현. 획 색상은 goldPale(#F5E6B8), 둥근 캡.
class _TalismanSymbolPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 140;
    final sy = size.height / 180;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final stroke = Paint()
      ..color = _GatePalette.goldPale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = _GatePalette.goldPale
      ..style = PaintingStyle.fill;

    void line(double x1, double y1, double x2, double y2, double w) {
      stroke.strokeWidth = w * ((sx + sy) / 2);
      canvas.drawLine(p(x1, y1), p(x2, y2), stroke);
    }

    // M70 5 L70 60
    line(70, 5, 70, 60, 4);
    // circle cx70 cy40 r7 filled
    canvas.drawCircle(p(70, 40), 7 * ((sx + sy) / 2), fill);
    // M35 55 L105 55
    line(35, 55, 105, 55, 3);
    // M30 65 L110 65
    line(30, 65, 110, 65, 2);
    // M70 55 L70 170
    line(70, 55, 70, 170, 4);
    // M45 85 L95 85
    line(45, 85, 95, 85, 2.5);
    // M45 85 Q45 105 55 110  &  M95 85 Q95 105 85 110
    stroke.strokeWidth = 2 * ((sx + sy) / 2);
    final path1 = Path()
      ..moveTo(p(45, 85).dx, p(45, 85).dy)
      ..quadraticBezierTo(
        p(45, 105).dx,
        p(45, 105).dy,
        p(55, 110).dx,
        p(55, 110).dy,
      );
    canvas.drawPath(path1, stroke);
    final path2 = Path()
      ..moveTo(p(95, 85).dx, p(95, 85).dy)
      ..quadraticBezierTo(
        p(95, 105).dx,
        p(95, 105).dy,
        p(85, 110).dx,
        p(85, 110).dy,
      );
    canvas.drawPath(path2, stroke);
    // M55 110 L85 110
    line(55, 110, 85, 110, 2);
    // M50 130 L90 130
    line(50, 130, 90, 130, 2);
    // M50 130 L50 160 & M90 130 L90 160
    line(50, 130, 50, 160, 2);
    line(90, 130, 90, 160, 2);
    // M50 160 L90 160
    line(50, 160, 90, 160, 2);
    // circle cx70 cy145 r4 filled
    canvas.drawCircle(p(70, 145), 4 * ((sx + sy) / 2), fill);
  }

  @override
  bool shouldRepaint(covariant _TalismanSymbolPainter oldDelegate) => false;
}

// ─── 축복 명패 ───────────────────────────────────────────
class _BlessingBadge extends StatelessWidget {
  const _BlessingBadge({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _GatePalette.bgOuter.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _GatePalette.goldDeep.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _GatePalette.goldPale,
        ),
      ),
    );
  }
}

// ─── 하단 UI (안내문 + 탭 진행 도트, tapToEnter 전용) ────────
class _GateFooter extends StatelessWidget {
  const _GateFooter({
    required this.tapCount,
    required this.tapsRequired,
    required this.reachedGoal,
  });

  final int tapCount;
  final int tapsRequired;
  final bool reachedGoal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          reachedGoal ? '정통사주 목록으로 이동합니다' : '부적을 탭하면 좋은 기운이 찾아와요 ✨',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _GatePalette.goldPale.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 14),
        // 진행 도트 N/tapsRequired
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(tapsRequired, (i) {
            final active = i < tapCount;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 9 : 7,
              height: active ? 9 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? _GatePalette.gold : Colors.transparent,
                border: active
                    ? null
                    : Border.all(
                        color: _GatePalette.goldDeep.withValues(alpha: 0.4),
                      ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _GatePalette.gold.withValues(alpha: 0.9),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        if (tapCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '福 · 축복 $tapCount회 받음',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _GatePalette.gold,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 파티클 ──────────────────────────────────────────────
class _ParticleSpec {
  const _ParticleSpec({
    required this.angle,
    required this.distance,
    required this.isCoin,
  });

  final double angle;
  final double distance;
  final bool isCoin;
}

class _ParticleBurst {
  _ParticleBurst({
    required this.origin,
    required this.specs,
    required this.controller,
  });

  final Offset origin;
  final List<_ParticleSpec> specs;
  final AnimationController controller;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.origin,
    required this.specs,
    required this.t,
  });

  final Offset origin;
  final List<_ParticleSpec> specs;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t).clamp(0.0, 1.0);
    for (final spec in specs) {
      final dist = spec.distance * t;
      final dx = origin.dx + math.cos(spec.angle) * dist;
      final dy = origin.dy + math.sin(spec.angle) * dist - (t * t * 30);
      final paint = Paint()
        ..color = (spec.isCoin ? _GatePalette.gold : _GatePalette.goldPale)
            .withValues(alpha: fade);
      final radius = spec.isCoin ? 3.2 : 1.6;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
