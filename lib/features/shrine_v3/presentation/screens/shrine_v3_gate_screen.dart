import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/application/auth_provider.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/shrine_asset_path.dart';
import 'shrine_v3_main_screen.dart';

/// 신당(THE SHRINE) v3 — 02 입장 연출.
///
/// [사용자 버그 리포트 — 디자인 핸드오프 불일치 #2] "입장 연출도 핸드오픈대로
/// 안하고" — 프로토타입(신당 v3.html) `Gate` 컴포넌트의 CSS(`.gate .lf/.rt`
/// 문짝 질감·3D 회전, `.seam` 금빛 이음새 글로우, `Petals` 낙하 꽃잎,
/// `.in` 배경 줌+세피아 전환, `.wash` 화면 전환 덮임)를 전부 요소별로
/// 대조한 결과, 기존 Dart 구현은 타이밍(0.4/1.5/4.0/4.8s)만 맞고 시각
/// 요소는 검정 패널이 단순 슬라이드만 하는 수준으로 축소돼 있었다.
/// README §1 "02 입장 연출" 한 줄 요약(단청 붉은 문이 열리고 금빛이
/// 새어 나오며 안으로 들어감)도 이 누락을 뒷받침한다 — 이번에 문짝
/// 질감(단청 색 테두리+격자+손잡이)·3D 경첩 회전·이음새 글로우·꽃잎·
/// 배경 줌/세피아·wash 전환을 모두 재현한다. 타이밍 자체(단계 전환
/// 0.4s/1.5s/4.0s, 4.8s 후 자동 03 메인 이동, 탭하면 즉시 건너뛰기)는
/// 원본 핸드오프와 동일하게 유지한다.
class ShrineV3GateScreen extends StatefulWidget {
  const ShrineV3GateScreen({super.key});

  @override
  State<ShrineV3GateScreen> createState() => _ShrineV3GateScreenState();
}

class _ShrineV3GateScreenState extends State<ShrineV3GateScreen>
    with SingleTickerProviderStateMixin {
  int _phase = 0;
  final List<Timer> _timers = [];
  bool _navigated = false;

  /// 꽃잎(Petals) 낙하 애니메이션 전용 상시 루프 컨트롤러. HTML
  /// `@keyframes pt`(top:-12px → translateY(860px), 회전 500deg)를
  /// 그대로 따르되, 화면 높이에 맞춰 낙하 거리를 스케일한다.
  late final AnimationController _petalCtrl;

  /// HTML `Petals({n:12})`와 동일한 시드 — 각 꽃잎의 가로 위치(%)/주기(s)/
  /// 지연(s)/가로 드리프트(px)를 결정론적으로 생성한다.
  static final List<_PetalSeed> _petals = List.generate(12, (i) {
    return _PetalSeed(
      leftPct: (i * 37) % 100 / 100,
      durationMs: (6 + (i % 4) * 1.5) * 1000,
      delayMs: -i * 700.0,
      driftX: -30.0 - (i * 13) % 80,
    );
  });

  @override
  void initState() {
    super.initState();
    _petalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _timers.addAll([
      Timer(const Duration(milliseconds: 400), () => _setPhase(1)),
      Timer(const Duration(milliseconds: 1500), () => _setPhase(2)),
      Timer(const Duration(milliseconds: 4000), () => _setPhase(3)),
      Timer(const Duration(milliseconds: 4800), _goMain),
    ]);
  }

  void _setPhase(int p) {
    if (!mounted) return;
    setState(() => _phase = p);
  }

  void _goMain() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShrineV3MainScreen()),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _petalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nickname = context.read<AuthProvider>().currentUser?.nickname;
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: _goMain,
      child: Scaffold(
        backgroundColor: ShrineV3Colors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // [HTML `.gate .in`] 배경이 확대·저채도 상태(scale 1.3,
            // brightness .6 sepia .2)로 시작해 정상(scale 1, brightness
            // 1.05 sepia .1)으로 3.4s에 걸쳐 풀린다 — "문이 열리며 눈이
            // 서서히 안쪽 풍경에 적응하는" 느낌.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.3, end: _phase >= 1 ? 1.0 : 1.3),
              duration: const Duration(milliseconds: 3400),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Image.asset(
                shrineSceneImage('hall'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: ShrineV3Colors.ink),
              ),
            ),
            // 세피아/저채도 → 정상 전환 근사(갈색 틴트 오버레이 페이드아웃).
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.55, end: _phase >= 1 ? 0.12 : 0.55),
              duration: const Duration(milliseconds: 2400),
              curve: Curves.easeOut,
              builder: (context, v, _) =>
                  IgnorePointer(child: Container(color: const Color(0xFF3A2410).withValues(alpha: v))),
            ),
            // [HTML `.gate .lf/.rt`] 단청 문짝 — 크림 바탕 + 붉은/금색
            // 이중 테두리 + 격자 + 금색 손잡이, 3D 경첩 회전으로 열림.
            _DoorPanel(
              side: _DoorSide.left,
              openAngleDeg: _phase >= 2 ? 78 : 0,
              screenWidth: size.width,
            ),
            _DoorPanel(
              side: _DoorSide.right,
              openAngleDeg: _phase >= 2 ? -78 : 0,
              screenWidth: size.width,
            ),
            // [HTML `.gate .seam`] 문 틈으로 새어 나오는 금빛 — gl 단계에서
            // 번쩍 켜졌다가(opacity 1) op 단계에서 폭이 넓어지며 사라진다.
            Align(
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 3,
                  end: _phase >= 2 ? size.width * 1.1 : 3,
                ),
                duration: const Duration(milliseconds: 2600),
                curve: Curves.easeInOut,
                builder: (context, width, _) {
                  final opacity = _phase >= 2
                      ? 0.0
                      : (_phase >= 1 ? 1.0 : 0.0);
                  return AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 800),
                    child: Container(
                      width: width,
                      height: size.height,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8D8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xE6FFECAA),
                            blurRadius: 18,
                            spreadRadius: 6,
                          ),
                          BoxShadow(
                            color: Color(0x80FFDC8C),
                            blurRadius: 80,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // [HTML `Petals`] 낙하 꽃잎 — DOM 순서상 `.lf/.rt/.seam` 뒤에
            // 와서 문짝/이음새보다 위에 그려진다(최초 구현에서 Stack 순서를
            // 반대로 둬 문짝에 완전히 가려지는 버그가 있었음 — 수정).
            // 의식 내내 상시 재생.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _petalCtrl,
                builder: (context, _) => Stack(
                  children: [
                    for (final seed in _petals)
                      _PetalDot(
                        seed: seed,
                        globalT: _petalCtrl.lastElapsedDuration?.inMilliseconds
                                .toDouble() ??
                            0,
                        screenWidth: size.width,
                        screenHeight: size.height,
                      ),
                  ],
                ),
              ),
            ),
            // [HTML `.gate .cap`] 캡션.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '神堂 · 門',
                      style: ShrineV3TextStyles.mono.copyWith(
                        color: ShrineV3Colors.seal,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _phase < 2
                            ? '방울 소리와 함께 문이 열립니다'
                            : '어서 오십시오${nickname != null ? ', $nickname님' : ''}',
                        key: ValueKey(_phase < 2),
                        style: ShrineV3TextStyles.body.copyWith(
                          color: ShrineV3Colors.paper,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // [HTML `.gate.out .wash`] out 단계 진입 시 종이색으로 화면을
            // 덮으며 03 메인으로 자연스럽게 전환(컷 없이 디졸브).
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _phase >= 3 ? 1 : 0,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeIn,
                child: Container(color: ShrineV3Colors.paper),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetalSeed {
  const _PetalSeed({
    required this.leftPct,
    required this.durationMs,
    required this.delayMs,
    required this.driftX,
  });

  final double leftPct;
  final double durationMs;
  final double delayMs;
  final double driftX;
}

/// 단일 낙하 꽃잎. HTML `@keyframes pt`: 10%에서 opacity .9로 나타나고,
/// 100%(= `top:-12px`에서 `translate(x,860px) rotate(500deg)`까지)에
/// opacity 0으로 사라진다. `screenHeight`에 맞춰 860px 낙하거리를
/// 스케일한다.
class _PetalDot extends StatelessWidget {
  const _PetalDot({
    required this.seed,
    required this.globalT,
    required this.screenWidth,
    required this.screenHeight,
  });

  final _PetalSeed seed;
  final double globalT;
  final double screenWidth;
  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    final raw = (globalT + seed.delayMs) % seed.durationMs;
    final t = raw < 0 ? raw + seed.durationMs : raw;
    final tt = t / seed.durationMs;
    final fallDistance = screenHeight + 40;
    final dy = -12 + tt * fallDistance;
    final dx = tt * seed.driftX;
    final opacity = tt < 0.1 ? (tt / 0.1) * 0.9 : (0.9 * (1 - tt));
    return Positioned(
      left: seed.leftPct * screenWidth,
      top: dy,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Transform.rotate(
          angle: tt * 500 * math.pi / 180,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: 7,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFD9A35A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DoorSide { left, right }

/// [HTML `.gate .lf/.rt`] 단청 문짝 — 크림 바탕(`#efe1bf`) + 붉은
/// (`#8b2f22`)/금색(`#c9a368`) 이중 인셋 테두리 + 격자 패턴 + 손잡이
/// 원(금색+붉은 테두리), `perspective(800px) rotateY(±78deg)` 3D
/// 경첩 회전으로 열린다(transform-origin: 바깥쪽 모서리).
class _DoorPanel extends StatelessWidget {
  const _DoorPanel({
    required this.side,
    required this.openAngleDeg,
    required this.screenWidth,
  });

  final _DoorSide side;
  final double openAngleDeg;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    final isLeft = side == _DoorSide.left;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: openAngleDeg),
      duration: const Duration(milliseconds: 2600),
      curve: const Cubic(0.55, 0, 0.25, 1),
      builder: (context, angleDeg, child) {
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateY(angleDeg * math.pi / 180);
        return Positioned(
          left: isLeft ? 0 : null,
          right: isLeft ? null : 0,
          top: 0,
          bottom: 0,
          width: screenWidth / 2,
          child: Transform(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            transform: matrix,
            child: child,
          ),
        );
      },
      child: _DoorFace(isLeft: isLeft),
    );
  }
}

class _DoorFace extends StatelessWidget {
  const _DoorFace({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ShrineV3Colors.seal, // 바깥 붉은 테 10px
      padding: const EdgeInsets.all(10),
      child: Container(
        color: ShrineV3Colors.goldDeep, // 안쪽 금색 테 3px
        padding: const EdgeInsets.all(3),
        child: Container(
          color: ShrineV3Colors.paperDark, // 문 본판 크림색
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _DoorGridPainter()),
              Positioned(
                top: 0,
                bottom: 0,
                right: isLeft ? 14 : null,
                left: isLeft ? null : 14,
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ShrineV3Colors.goldDeep,
                      border: Border.all(
                        color: ShrineV3Colors.seal,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [HTML `.gate .lf::before/.rt::before`] 격자 무늬(단청 문살) 근사 —
/// 붉은색 반투명 가로/세로 선을 28px 간격으로 그린다.
class _DoorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ShrineV3Colors.seal.withValues(alpha: 0.18)
      ..strokeWidth = 2;
    const margin = 24.0;
    const step = 28.0;
    for (double y = margin; y < size.height - margin; y += step) {
      canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paint);
    }
    for (double x = margin; x < size.width - margin; x += step) {
      canvas.drawLine(Offset(x, margin), Offset(x, size.height - margin), paint);
    }
    final border = Paint()
      ..color = ShrineV3Colors.seal.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(
        margin,
        margin,
        size.width - margin * 2,
        size.height - margin * 2,
      ),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
