// lib/features/guinji/widgets/guinji_intro_cinematic.dart
// [2026 디자인 핸드오프 — 신규] 01 인트로 시네마틱 (§05-1).
// 검정 배경 + 별 46개 → 나(84px) 등장 → 오행 원 그리기 → 인연 6명이
// 유성처럼 도착(충격파·얼굴 팝·한자 인장·유형명·연결선) → 빛 폭발 →
// 타이틀 글자별 등장 + 인원 카운터 → 금색 CTA "내 지도 만들기". 13.5초
// 루프, 2회차부터 타이틀/CTA 고정, 우상단 "건너뛰기"(완성 상태로 점프).
//
// 타이밍 상수는 `guinji_animation_spec.dart`의 [IntroTiming]을 그대로
// 사용한다(핸드오프 JS `IntroCinematic`의 ARRIVE0=2200/GAP=620/DONE=6420/
// TITLE=6720/CTA=7220/LOOP=13500과 1:1 동일).
//
// 엔진/데이터 비관여: 이 화면에 등장하는 6명의 인연은 아직 실제 지도가
// 없는 방문자에게 "곧 보게 될 모습"을 보여주는 순수 데모 비주얼이다 —
// 실제 [GuinjiPerson]/[GuinjiProvider] 데이터를 전혀 읽지 않는다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../character/guinji_character.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import 'guinji_animation_spec.dart';

class GuinjiIntroCinematic extends StatefulWidget {
  const GuinjiIntroCinematic({super.key, required this.onStart});

  /// CTA 탭 → 워프 전환(1.1초) 완료 후 호출(정보입력 화면으로 이동).
  final VoidCallback onStart;

  @override
  State<GuinjiIntroCinematic> createState() => _GuinjiIntroCinematicState();
}

class _DemoArrival {
  const _DemoArrival(this.typeCode, this.charId);
  final String typeCode;
  final String charId;
}

// 6종 유형 순서(귀인/인연/상생/동반/조율/극복) 대로 다양한 데모 캐릭터를 배치.
const _demoArrivals = [
  _DemoArrival('CHEON_GWII', 'f20a'),
  _DemoArrival('HAP', 'm30b'),
  _DemoArrival('SANG_SAENG', 'f40'),
  _DemoArrival('BI_HWA', 'm10b'),
  _DemoArrival('SANG_GEUK', 'f60'),
  _DemoArrival('CHUNG', 'm20a'),
];
const _demoOwnerCharId = 'f30';

class _GuinjiIntroCinematicState extends State<GuinjiIntroCinematic>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsedAtLoopStart = Duration.zero;
  int _tMs = 0; // 이번 루프 시작 이후 경과(ms)
  int _loop = 0;
  double _offsetMs = 0; // 건너뛰기 오프셋(첫 루프에만 적용)
  bool _warping = false;
  int _counter = 12841;

  late final AnimationController _ctaBreath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final AnimationController _ctaSheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  Timer? _counterTimer;

  static const _arrive0 = 2200;
  static const _gap = 620;
  static const _done = _arrive0 + _gap * 6 + 500; // 6420
  static const _titleAt = _done + 300; // 6720
  static const _loopMs = 13500;

  bool get _firstLoop => _loop == 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _counterTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _counter += 1 + math.Random().nextInt(3));
    });
  }

  void _onTick(Duration elapsed) {
    final sinceLoop = (elapsed - _elapsedAtLoopStart).inMilliseconds;
    if (sinceLoop + _offsetMs >= _loopMs) {
      _elapsedAtLoopStart = elapsed;
      _offsetMs = 0;
      setState(() => _loop++);
      return;
    }
    if (!mounted) return;
    setState(() => _tMs = sinceLoop);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ctaBreath.dispose();
    _ctaSheen.dispose();
    _counterTimer?.cancel();
    super.dispose();
  }

  int get _tt => _tMs + (_firstLoop ? _offsetMs.round() : 0);

  void _skip() {
    if (!_firstLoop) return;
    setState(() => _offsetMs = (_done + 1 - _tMs).toDouble());
  }

  void _go() {
    if (_warping) return;
    setState(() => _warping = true);
    Timer(IntroTiming.warp, () {
      if (mounted) widget.onStart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final scale = w / 390.0;
    final cx = w * 0.5;
    final cy = h * 0.391;
    final tt = _tt;

    return Scaffold(
      backgroundColor: GmColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 별 필드
          _StarsField(width: w, height: h),

          // 중심 광량 + 워프 트랜스폼 레이어
          Transform(
            alignment: Alignment.center,
            transform: _warping
                ? (Matrix4.identity()
                  ..translateByDouble(cx, cy, 0, 1)
                  ..scaleByDouble(
                    1.0 + (tt / 1100).clamp(0.0, 1.0) * 5.0,
                    1.0 + (tt / 1100).clamp(0.0, 1.0) * 5.0,
                    1.0,
                    1.0,
                  )
                  ..translateByDouble(-cx, -cy, 0, 1))
                : Matrix4.identity(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: cx - 200 * scale,
                  top: cy - 200 * scale,
                  width: 400 * scale,
                  height: 400 * scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          GmColors.gold.withValues(
                            alpha: math.min(
                              0.28,
                              0.05 + math.max(0, tt - _arrive0) / 18000,
                            ),
                          ),
                          GmColors.gold.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.62],
                      ),
                    ),
                  ),
                ),

                // 오행 원
                if (tt > 700)
                  _WuxingCircle(cx: cx, cy: cy, scale: scale, tt: tt, done: _done),

                // 연결선
                CustomPaint(
                  size: Size(w, h),
                  painter: _LinesPainter(
                    cx: cx,
                    cy: cy,
                    scale: scale,
                    tt: tt,
                    arrive0: _arrive0,
                    gap: _gap,
                  ),
                ),

                // 유성 · 충격파 · 얼굴 · 인장 · 유형명
                for (var i = 0; i < _demoArrivals.length; i++)
                  _ArrivalWidget(
                    index: i,
                    cx: cx,
                    cy: cy,
                    scale: scale,
                    tt: tt,
                    arriveAt: _arrive0 + i * _gap,
                  ),

                // 완성 — 빛 폭발 + 스트릭
                if (tt >= _done && tt < _done + 1400)
                  _BurstEffect(cx: cx, cy: cy, scale: scale, tt: tt, done: _done),

                // 나
                Positioned(
                  left: cx - 42 * scale,
                  top: cy - 42 * scale,
                  width: 84 * scale,
                  height: 84 * scale,
                  child: AnimatedOpacity(
                    opacity: tt > 200 ? 1 : 0,
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(
                            const GuinjiCharacter(_demoOwnerCharId, '').face,
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.85),
                            spreadRadius: 0,
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: GmColors.gold.withValues(alpha: 0.55),
                            blurRadius:
                                40 +
                                math.min(40, math.max(0, tt - _arrive0) / 120),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: cx - 20 * scale,
                  top: cy + 50 * scale,
                  width: 40 * scale,
                  child: AnimatedOpacity(
                    opacity: tt > 900 ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: const Text(
                      '나',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xBFF2F0EC),
                      ),
                    ),
                  ),
                ),

                // 금빛 먼지
                if (tt > _done) _GoldDust(cx: cx, cy: cy, scale: scale),
              ],
            ),
          ),

          // 상단 캡션
          Positioned(
            top: 74 * scale,
            left: 0,
            right: 0,
            child: const Text(
              'SINTONG · 貴人之圖',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GmText.mono,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.2,
                color: Color(0xCCE9C46A),
              ),
            ),
          ),
          if (_firstLoop && tt < _done)
            Positioned(
              top: 100 * scale,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  tt < _arrive0
                      ? '어둠 속에 당신이라는 별 하나'
                      : '하나둘, 인연이 당신에게 닿고 있어요',
                  key: ValueKey(tt < _arrive0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GmText.body,
                    fontSize: 15,
                    color: Color(0xB8F2F0EC),
                  ),
                ),
              ),
            ),

          // 타이틀
          Positioned(
            left: 28,
            right: 28,
            top: 556 * scale,
            child: Opacity(
              opacity: (tt > _titleAt || !_firstLoop) ? 1 : 0,
              child: _IntroTitle(
                tt: tt,
                firstLoop: _firstLoop,
                counter: _counter,
              ),
            ),
          ),

          // CTA
          Positioned(
            left: 24,
            right: 24,
            bottom: 40 * scale,
            child: AnimatedOpacity(
              opacity: (tt > _titleAt + 500 || !_firstLoop) ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: AnimatedSlide(
                offset: (tt > _titleAt + 500 || !_firstLoop)
                    ? Offset.zero
                    : const Offset(0, 0.08),
                duration: const Duration(milliseconds: 600),
                child: _IntroCta(
                  breath: _ctaBreath,
                  sheen: _ctaSheen,
                  onTap: _go,
                ),
              ),
            ),
          ),

          // 건너뛰기
          if (_firstLoop && tt < _done)
            Positioned(
              right: 16,
              top: 66 * scale,
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0x8CF2F0EC),
                    ),
                  ),
                ),
              ),
            ),

          // 워프 화이트아웃
          if (_warping)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: (tt / 1100).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 50),
                child: Container(color: const Color(0xFFFFF6DC)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StarsField extends StatefulWidget {
  const _StarsField({required this.width, required this.height});
  final double width;
  final double height;

  @override
  State<_StarsField> createState() => _StarsFieldState();
}

class _StarsFieldState extends State<_StarsField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _StarsPainter(_c.value),
        );
      },
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 46; i++) {
      final left = (i * 83) % 390 / 390.0 * size.width;
      final top = (60 + (i * 137) % 560) / 844.0 * size.height;
      final r = i % 7 == 0 ? 1.25 : 0.75;
      final localPhase = (phase * 6 + (i % 9) * 0.3) % (2 + (i % 5) * 0.7);
      final period = 2 + (i % 5) * 0.7;
      final t = (localPhase / period) * 2 * math.pi;
      final opacity = 0.525 + 0.375 * math.sin(t); // giTw: .15~.9
      final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(left, top), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => true;
}

class _WuxingCircle extends StatelessWidget {
  const _WuxingCircle({
    required this.cx,
    required this.cy,
    required this.scale,
    required this.tt,
    required this.done,
  });
  final double cx, cy, scale;
  final int tt, done;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WuxingPainter(cx: cx, cy: cy, scale: scale, tt: tt, done: done),
    );
  }
}

class _WuxingPainter extends CustomPainter {
  _WuxingPainter({
    required this.cx,
    required this.cy,
    required this.scale,
    required this.tt,
    required this.done,
  });
  final double cx, cy, scale;
  final int tt, done;

  static const _elements = ['木', '火', '土', '金', '水'];

  @override
  void paint(Canvas canvas, Size size) {
    final r = 170.0 * scale;
    final ringPaint = Paint()
      ..color = GmColors.gold.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale;
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    // 눈금 60개
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * math.pi * 2;
      final len = i % 5 == 0 ? 8.0 * scale : 3.0 * scale;
      final opacity = tt > 1500 ? 0.4 : 0.0;
      final p1 = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
      final p2 = Offset(cx + math.cos(a) * (r - len), cy + math.sin(a) * (r - len));
      final tickPaint = Paint()
        ..color = GmColors.gold.withValues(alpha: opacity)
        ..strokeWidth = 1;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 五行 글자
    for (var i = 0; i < _elements.length; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5;
      final opacity = tt > 1300 + i * 120 ? 0.75 : 0.0;
      if (opacity <= 0) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: _elements[i],
          style: TextStyle(
            fontFamily: GmText.display,
            fontSize: 16 * scale,
            color: GmColors.gold.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(
        cx + math.cos(a) * 188 * scale - tp.width / 2,
        cy + math.sin(a) * 188 * scale - tp.height / 2,
      );
      tp.paint(canvas, pos);
    }

    // 역회전 육각 점선 + 완성 다각형
    final hexOpacity = tt > done ? 0.25 : 0.0;
    if (hexOpacity > 0) {
      final hexPaint = Paint()
        ..color = GmColors.gold.withValues(alpha: hexOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final pt = Offset(cx + math.cos(a) * 128 * scale, cy + math.sin(a) * 128 * scale);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, hexPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WuxingPainter oldDelegate) => true;
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({
    required this.cx,
    required this.cy,
    required this.scale,
    required this.tt,
    required this.arrive0,
    required this.gap,
  });
  final double cx, cy, scale;
  final int tt, arrive0, gap;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _demoArrivals.length; i++) {
      final at = arrive0 + i * gap + 520;
      if (tt < at) continue;
      final a = -math.pi / 2 + i * math.pi / 3;
      final x = cx + math.cos(a) * 128 * scale;
      final y = cy + math.sin(a) * 128 * scale;
      final color = guinjiTypeOf(_demoArrivals[i].typeCode).color;

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 5 * scale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(Offset(x, y), Offset(cx, cy), glowPaint);

      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 1.4 * scale;
      canvas.drawLine(Offset(x, y), Offset(cx, cy), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter oldDelegate) => true;
}

class _ArrivalWidget extends StatelessWidget {
  const _ArrivalWidget({
    required this.index,
    required this.cx,
    required this.cy,
    required this.scale,
    required this.tt,
    required this.arriveAt,
  });
  final int index;
  final double cx, cy, scale;
  final int tt, arriveAt;

  @override
  Widget build(BuildContext context) {
    final e = tt - arriveAt;
    if (e < -500) return const SizedBox.shrink();
    final arrival = _demoArrivals[index];
    final typeSpec = guinjiTypeOf(arrival.typeCode);
    final a = -math.pi / 2 + index * math.pi / 3;
    final x = cx + math.cos(a) * 128 * scale;
    final y = cy + math.sin(a) * 128 * scale;
    final leftSide = x < cx;

    final children = <Widget>[];

    // 유성 꼬리(도착 직전, e∈(-500,20)) — JSX `giComet` offset-path 애니메이션.
    if (e > -500 && e < 20) {
      children.add(
        _CometTrail(
          cx: cx,
          cy: cy,
          scale: scale,
          targetX: x,
          targetY: y,
          angle: a,
          leftSide: leftSide,
          index: index,
          localMs: e + 500,
          color: typeSpec.color,
        ),
      );
    }

    // 충격파 2겹
    if (e >= 0 && e < 1200) {
      for (final d in [0, 160]) {
        final local = e - d;
        if (local < 0 || local > 900) continue;
        final prog = local / 900;
        final ringScale = (3 + (d == 160 ? 1.5 : 0)) * prog;
        final opacity = (1 - prog).clamp(0.0, 1.0);
        children.add(
          Positioned(
            left: x - 22 * scale * ringScale,
            top: y - 22 * scale * ringScale,
            width: 44 * scale * ringScale,
            height: 44 * scale * ringScale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: typeSpec.color.withValues(alpha: opacity),
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
      }
    }

    // 얼굴 팝
    if (e >= 0) {
      final popProg = (e / 520).clamp(0.0, 1.0);
      final faceScale = popProg < 1.0
          ? Curves.easeOutBack.transform(popProg)
          : 1.0;
      children.add(
        Positioned(
          left: x - 22 * scale,
          top: y - 22 * scale,
          width: 44 * scale,
          height: 44 * scale,
          child: Transform.scale(
            scale: 0.3 + faceScale * 0.7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage(
                    GuinjiCharacter(arrival.charId, '').face,
                  ),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(color: typeSpec.color, blurRadius: 18),
                ],
                border: Border.all(color: typeSpec.color, width: 1.5),
              ),
            ),
          ),
        ),
      );
    }

    // 한자 인장
    if (e >= 260) {
      final stampProg = ((e - 260) / 480).clamp(0.0, 1.0);
      final stampScale = 3.2 - 2.2 * Curves.easeOut.transform(stampProg);
      children.add(
        Positioned(
          left: x + (leftSide ? -30 : 30) * scale - 14 * scale,
          top: y + (leftSide ? -24 : 26) * scale - 14 * scale,
          width: 28 * scale,
          height: 28 * scale,
          child: Transform.scale(
            scale: stampScale,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: typeSpec.color,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(color: typeSpec.color, blurRadius: 16),
                ],
                border: Border.all(color: GmColors.bg, width: 2),
              ),
              child: Text(
                typeSpec.hanja,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: GmColors.onFg,
                ),
              ),
            ),
          ),
        ),
      );
      children.add(
        Positioned(
          left: x + (leftSide ? -30 : 30) * scale - 40,
          top: y + (leftSide ? -50 : 48) * scale,
          width: 80,
          child: Opacity(
            opacity: stampProg,
            child: Text(
              typeSpec.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GmText.ui,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: typeSpec.color,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: children);
  }
}

/// 유성 꼬리 — JSX `giComet`(offset-path 곡선 이동) 재현.
/// 화면 바깥(leftSide 쪽이면 -60, 아니면 450)에서 2차 베지어 곡선을 따라
/// 도착 지점까지 날아오는 4개의 점(머리는 흰색, 꼬리 3개는 유형색).
class _CometTrail extends StatelessWidget {
  const _CometTrail({
    required this.cx,
    required this.cy,
    required this.scale,
    required this.targetX,
    required this.targetY,
    required this.angle,
    required this.leftSide,
    required this.index,
    required this.localMs,
    required this.color,
  });
  final double cx, cy, scale, targetX, targetY, angle;
  final bool leftSide;
  final int index, localMs;
  final Color color;

  static const _cometCurve = Cubic(0.5, 0, 0.8, 0.4);

  @override
  Widget build(BuildContext context) {
    final sx = (leftSide ? -60.0 : 450.0) * scale;
    final sy = (-40.0 - (index % 3) * 40.0) * scale;
    final ctrlX = (sx + targetX) / 2;
    final ctrlY = math.min(sy, targetY) - 50 * scale;

    final dots = <Widget>[];
    for (var k = 0; k < 4; k++) {
      final delay = k * 25;
      final raw = ((localMs - delay) / 500).clamp(0.0, 1.0);
      if (localMs < delay) continue;
      final te = _cometCurve.transform(raw);
      final px = (1 - te) * (1 - te) * sx +
          2 * (1 - te) * te * ctrlX +
          te * te * targetX;
      final py = (1 - te) * (1 - te) * sy +
          2 * (1 - te) * te * ctrlY +
          te * te * targetY;
      final opacity = (te < 0.1 ? te / 0.1 : 1.0) * (1 - k * 0.2);
      final dotSize = (8 - k * 1.5) * scale;
      final dotColor = k == 0 ? Colors.white : color;
      dots.add(
        Positioned(
          left: px - dotSize / 2,
          top: py - dotSize / 2,
          width: dotSize,
          height: dotSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: opacity), blurRadius: 14),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(children: dots);
  }
}

class _BurstEffect extends StatelessWidget {
  const _BurstEffect({
    required this.cx,
    required this.cy,
    required this.scale,
    required this.tt,
    required this.done,
  });
  final double cx, cy, scale;
  final int tt, done;

  @override
  Widget build(BuildContext context) {
    final e = tt - done;
    final flashOpacity = (1 - e / 1000).clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  (cx / (MediaQuery.of(context).size.width)) * 2 - 1,
                  (cy / (MediaQuery.of(context).size.height)) * 2 - 1,
                ),
                colors: [
                  Color.fromRGBO(255, 240, 200, 0.9 * flashOpacity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45],
              ),
            ),
          ),
        ),
        for (final d in [0, 200, 420])
          if (e - d >= 0 && e - d < 1200)
            Builder(
              builder: (context) {
                final prog = ((e - d) / 1200).clamp(0.0, 1.0);
                final ringScale = (4 + ([0, 200, 420].indexOf(d)) * 1.5) * prog;
                return Positioned(
                  left: cx - 45 * scale * ringScale,
                  top: cy - 45 * scale * ringScale,
                  width: 90 * scale * ringScale,
                  height: 90 * scale * ringScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GmColors.gold.withValues(
                          alpha: (1 - prog).clamp(0.0, 1.0),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
        for (var k = 0; k < 18; k++)
          if (e - k * 15 >= 0 && e - k * 15 < 900)
            Builder(
              builder: (context) {
                final prog = ((e - k * 15) / 900).clamp(0.0, 1.0);
                final angle = k * 20 * math.pi / 180;
                final len = 60 * scale * prog;
                return Positioned(
                  left: cx,
                  top: cy,
                  child: Transform.rotate(
                    angle: angle,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: len,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFFFFF3C8).withValues(
                              alpha: (1 - prog).clamp(0.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}

class _GoldDust extends StatelessWidget {
  const _GoldDust({required this.cx, required this.cy, required this.scale});
  final double cx, cy, scale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < 20; i++)
            Positioned(
              left: (60 + (i * 47) % 270) * scale,
              top: cy + (60 + (i * 31) % 120) * scale,
              child: _DustDot(delay: (i % 10) * 300, size: 2.0 + (i % 2)),
            ),
        ],
      ),
    );
  }
}

class _DustDot extends StatefulWidget {
  const _DustDot({required this.delay, required this.size});
  final int delay;
  final double size;

  @override
  State<_DustDot> createState() => _DustDotState();
}

class _DustDotState extends State<_DustDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.8;
        return Transform.translate(
          offset: Offset(0, -t * 60),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GmColors.gold.withValues(alpha: opacity),
              boxShadow: [BoxShadow(color: GmColors.gold.withValues(alpha: opacity), blurRadius: 6)],
            ),
          ),
        );
      },
    );
  }
}

class _IntroTitle extends StatelessWidget {
  const _IntroTitle({
    required this.tt,
    required this.firstLoop,
    required this.counter,
  });
  final int tt;
  final bool firstLoop;
  final int counter;

  static const _line1 = '내 곁의 귀인을';
  static const _line2 = '한 장의 지도로';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            for (var i = 0; i < _line1.length; i++)
              _AnimatedChar(
                ch: _line1[i],
                delayMs: i * 45,
                active: tt > 0 || !firstLoop,
                firstLoop: firstLoop,
                color: const Color(0xFFF6F1E6),
              ),
            const SizedBox(width: double.infinity, height: 0, child: Text('')),
          ],
        ),
        Wrap(
          children: [
            for (var i = 0; i < _line2.length; i++)
              _AnimatedChar(
                ch: _line2[i],
                delayMs: 300 + i * 45,
                active: tt > 0 || !firstLoop,
                firstLoop: firstLoop,
                color: (i == 5 || i == 6)
                    ? GmColors.gold
                    : const Color(0xFFF6F1E6),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: GmText.ui,
              fontSize: 15,
              color: Color(0x99F2F0EC),
            ),
            children: [
              const TextSpan(text: '생년월일로 읽는 여섯 가지 인연 · 지금 '),
              TextSpan(
                text: '${_formatCounter(counter)}명',
                style: const TextStyle(
                  color: GmColors.fg,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const TextSpan(text: '이 지도를 만들었어요'),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatCounter(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _AnimatedChar extends StatelessWidget {
  const _AnimatedChar({
    required this.ch,
    required this.delayMs,
    required this.active,
    required this.firstLoop,
    required this.color,
  });
  final String ch;
  final int delayMs;
  final bool active;
  final bool firstLoop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!firstLoop) {
      return Text(
        ch,
        style: TextStyle(
          fontFamily: GmText.display,
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.03,
          height: 1.22,
          color: color,
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 10),
            child: child,
          ),
        );
      },
      child: Text(
        ch,
        style: TextStyle(
          fontFamily: GmText.display,
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.03,
          height: 1.22,
          color: color,
        ),
      ),
    );
  }
}

class _IntroCta extends StatelessWidget {
  const _IntroCta({
    required this.breath,
    required this.sheen,
    required this.onTap,
  });
  final AnimationController breath;
  final AnimationController sheen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: breath,
          builder: (context, child) {
            final s = 1.0 + breath.value * 0.015;
            return Transform.scale(scale: s, child: child);
          },
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [GmColors.goldTop, GmColors.gold],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: sheen,
                      builder: (context, _) {
                        return Positioned(
                          left: -60 + sheen.value * 500,
                          top: 0,
                          bottom: 0,
                          width: 60,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Text(
                      '내 지도 만들기',
                      style: TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1206),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '30초면 충분해요 · 무료',
          style: TextStyle(
            fontFamily: GmText.ui,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0x73F2F0EC),
          ),
        ),
      ],
    );
  }
}
