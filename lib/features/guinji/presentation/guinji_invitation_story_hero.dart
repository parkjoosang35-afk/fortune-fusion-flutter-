// lib/features/guinji/presentation/guinji_invitation_story_hero.dart
// [귀인지도 초대장 리디자인 — design_handoff_guiin_invitation.zip]
// [A] StoryHero 변형 — 홈의 `SintongStoryHero`(sintong_story_hero.dart)와
// 동일한 5컷×6초=30초 무한 루프 타이밍 수학을 재사용하되, README "StoryHero
// (초대장 변형)" 표에 명시된 시각 차이를 적용한다:
//   - 풀블리드 폭 × 높이 430, 라운드 0 (홈은 16:11 aspect, 라운드 18)
//   - Ken Burns 1.12 → 1.00 (홈은 1.08 → 1.00)
//   - 캡션 Gowun Batang 700 21px lh1.45, 강조색 glow + glow shadow
//   - 캡션 등장에 blur 4→0 추가(홈은 fade+Y만)
//   - 회전 마법진(sigil) SVG 레이어 + 금가루(gold dust) 파티클 레이어 추가
//   - STORY 버튼이 우상단이 아니라 하단 우측, 진행 도트와 같은 줄
//
// 이미지 자산은 홈과 완전히 동일한 5장(`assets/images/sintong_home/
// story-N-*.jpg`)을 재사용한다(핸드오프 README "모두 1376×768 AI 생성
// 일러스트" — 이미 프로젝트에 존재하는 파일과 동일).
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'guinji_invitation_theme.dart';

class _InviteCut {
  const _InviteCut({required this.asset, required this.captionLines});

  final String asset;
  final List<InlineSpan> captionLines;
}

class GuinjiInvitationStoryHero extends StatefulWidget {
  const GuinjiInvitationStoryHero({super.key});

  static const Duration cutDuration = Duration(seconds: 6);
  static const int cutCount = 5;
  static const double height = 430;

  @override
  State<GuinjiInvitationStoryHero> createState() =>
      _GuinjiInvitationStoryHeroState();
}

class _GuinjiInvitationStoryHeroState extends State<GuinjiInvitationStoryHero>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _assetBase = 'assets/images/sintong_home';

  final List<_InviteCut> _cuts = const [
    _InviteCut(
      asset: '$_assetBase/story-0-hanbok.jpg',
      captionLines: [
        TextSpan(text: '귀인', style: TextStyle(color: GiColors.glow)),
        TextSpan(text: '이\n당신을 기다리고 있어요'),
      ],
    ),
    _InviteCut(
      asset: '$_assetBase/story-1-forest.jpg',
      captionLines: [
        TextSpan(text: '밤길에도\n당신을 이끄는 '),
        TextSpan(text: '발걸음', style: TextStyle(color: GiColors.glow)),
      ],
    ),
    _InviteCut(
      asset: '$_assetBase/story-2-tower.jpg',
      captionLines: [
        TextSpan(text: '먼 곳에서도\n'),
        TextSpan(text: '인연', style: TextStyle(color: GiColors.glow)),
        TextSpan(text: '은 이어져요'),
      ],
    ),
    _InviteCut(
      asset: '$_assetBase/story-3-apothecary.jpg',
      captionLines: [
        TextSpan(text: '당신의 사주가\n'),
        TextSpan(text: '이야기', style: TextStyle(color: GiColors.glow)),
        TextSpan(text: '를 풀어줘요'),
      ],
    ),
    _InviteCut(
      asset: '$_assetBase/story-4-village.jpg',
      captionLines: [
        TextSpan(text: '두 사람의 '),
        TextSpan(text: '귀인지도', style: TextStyle(color: GiColors.glow)),
        TextSpan(text: '가\n펼쳐질 시간이에요'),
      ],
    ),
  ];

  late final AnimationController _loopCtrl;
  late final AnimationController _sigilCtrl;
  bool _storyBtnPressed = false;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final totalMs =
        GuinjiInvitationStoryHero.cutDuration.inMilliseconds *
        GuinjiInvitationStoryHero.cutCount;
    _loopCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..repeat();
    // 마법진 120초에 1회전(linear).
    _sigilCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final cut in _cuts) {
        precacheImage(AssetImage(cut.asset), context);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _loopCtrl.stop();
      _sigilCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _loopCtrl.repeat();
      _sigilCtrl.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loopCtrl.dispose();
    _sigilCtrl.dispose();
    super.dispose();
  }

  void _restartStory() {
    _loopCtrl
      ..reset()
      ..repeat();
  }

  double _cutLocalProgress(double t, int index) {
    final n = _cuts.length;
    final segment = 1 / n;
    final start = index * segment;
    return (t - start) / segment;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: GuinjiInvitationStoryHero.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF0E0820)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1) 컷 이미지 5장 — Ken Burns 1.12 → 1.00
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _loopCtrl,
                builder: (context, _) {
                  final t = _loopCtrl.value;
                  return Stack(
                    fit: StackFit.expand,
                    children: List.generate(_cuts.length, (i) {
                      final localT = _cutLocalProgress(t, i);
                      return _InviteCutLayer(cut: _cuts[i], localT: localT);
                    }),
                  );
                },
              ),
            ),
            // 2) 마법진 SVG 레이어 — 중앙(top 46%), 120초 1회전, opacity .22
            Positioned(
              left: 0,
              right: 0,
              top: GuinjiInvitationStoryHero.height * 0.46 - 150,
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.22,
                    child: AnimatedBuilder(
                      animation: _sigilCtrl,
                      builder: (context, _) {
                        return Transform.rotate(
                          angle: _sigilCtrl.value * 2 * math.pi,
                          child: const SizedBox(
                            width: 300,
                            height: 300,
                            child: CustomPaint(painter: _SigilPainter()),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // 3) 그라디언트 워시 — 하단이 배경색(bg1)으로 자연스럽게 녹아듦
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      GiColors.wash1,
                      GiColors.wash2,
                      GiColors.wash2,
                      GiColors.wash3,
                      GiColors.bg1,
                    ],
                    stops: [0, 0.24, 0.48, 0.82, 1],
                  ),
                ),
              ),
            ),
            // 4) 금가루 파티클 — 14개, 하단에서 위로 420px 상승
            const Positioned.fill(child: IgnorePointer(child: _GoldDustLayer())),
            // 5) 캡션
            Positioned(
              left: 24,
              right: 24,
              bottom: 112,
              child: IgnorePointer(
                child: SizedBox(
                  height: 70,
                  child: AnimatedBuilder(
                    animation: _loopCtrl,
                    builder: (context, _) {
                      final t = _loopCtrl.value;
                      return Stack(
                        children: List.generate(_cuts.length, (i) {
                          final localT = _cutLocalProgress(t, i);
                          return _InviteCaptionLayer(
                            cut: _cuts[i],
                            localT: localT,
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
            // 6) 메타 행 — 진행 도트 + STORY 버튼 (같은 줄, 하단 우측)
            Positioned(
              left: 24,
              right: 24,
              bottom: 86,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _loopCtrl,
                      builder: (context, _) {
                        final t = _loopCtrl.value;
                        return Row(
                          children: List.generate(_cuts.length, (i) {
                            final localT = _cutLocalProgress(t, i);
                            final fill = localT.clamp(0.0, 1.0);
                            return Padding(
                              padding: EdgeInsets.only(
                                right: i == _cuts.length - 1 ? 0 : 5,
                              ),
                              child: _InviteProgressDot(fill: fill),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _storyBtnPressed = true),
                    onTapCancel: () =>
                        setState(() => _storyBtnPressed = false),
                    onTapUp: (_) => setState(() => _storyBtnPressed = false),
                    onTap: _restartStory,
                    child: AnimatedScale(
                      scale: _storyBtnPressed ? 0.96 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(GiRadius.pill),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                            decoration: BoxDecoration(
                              color: const Color(0x800A0716),
                              borderRadius: BorderRadius.circular(
                                GiRadius.pill,
                              ),
                              border: Border.all(
                                color: const Color(0x59F5CF6A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '⟲',
                                  style: TextStyle(
                                    fontFamily: GiFonts.mono,
                                    fontSize: 10,
                                    color: GiColors.glow,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'STORY',
                                  style: TextStyle(
                                    fontFamily: GiFonts.mono,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 9.5 * 0.28,
                                    color: GiColors.glow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCutLayer extends StatelessWidget {
  const _InviteCutLayer({required this.cut, required this.localT});

  final _InviteCut cut;
  final double localT;

  @override
  Widget build(BuildContext context) {
    if (localT < -0.02 || localT > 1.02) return const SizedBox.shrink();
    final p = localT.clamp(0.0, 1.0);
    double opacity;
    if (p < 0.20) {
      opacity = p / 0.20;
    } else if (p < 0.85) {
      opacity = 1;
    } else {
      opacity = 1 - (p - 0.85) / 0.15;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0.001) return const SizedBox.shrink();

    // Ken Burns: 1.12 → 1.00
    final scale = 1.12 - p * 0.12;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(cut.asset, fit: BoxFit.cover),
      ),
    );
  }
}

class _InviteCaptionLayer extends StatelessWidget {
  const _InviteCaptionLayer({required this.cut, required this.localT});

  final _InviteCut cut;
  final double localT;

  @override
  Widget build(BuildContext context) {
    if (localT < -0.02 || localT > 1.02) return const SizedBox.shrink();
    final p = localT.clamp(0.0, 1.0);
    double opacity;
    double dy;
    double blur;
    if (p < 0.30) {
      final k = p / 0.30;
      opacity = k;
      dy = 10 * (1 - k);
      blur = 4 * (1 - k);
    } else if (p < 0.85) {
      opacity = 1;
      dy = 0;
      blur = 0;
    } else {
      final k = (p - 0.85) / 0.15;
      opacity = 1 - k;
      dy = -6 * k;
      blur = 0;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0.001) return const SizedBox.shrink();

    final text = RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: GiFonts.body,
          fontWeight: FontWeight.w700,
          fontSize: 21,
          height: 1.45,
          letterSpacing: -0.21,
          color: GiColors.fg,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 2)),
          ],
        ),
        children: cut.captionLines,
      ),
    );

    final content = blur > 0.01
        ? ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: text,
          )
        : text;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(offset: Offset(0, dy), child: content),
      ),
    );
  }
}

class _InviteProgressDot extends StatelessWidget {
  const _InviteProgressDot({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 2,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fill.clamp(0.0, 1.0),
          child: Container(color: GiColors.glow),
        ),
      ),
    );
  }
}

/// 마법진 — SVG viewBox 0..200 좌표를 그대로 사용(스케일 1.5로 300×300에 맞춤).
/// 원 r96 · 점선 원 r84(dash 2 5) · 원 r58 · 정사각형 82×82 두 개(0°, 45°).
class _SigilPainter extends CustomPainter {
  const _SigilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 200);
    const center = Offset(100, 100);
    final paint = Paint()
      ..color = GiColors.glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(center, 96, paint);
    canvas.drawCircle(center, 58, paint);
    _drawDashedCircle(canvas, center, 84, paint, dash: 2, gap: 5);

    final rect = Rect.fromCenter(center: center, width: 82, height: 82);
    canvas.drawRect(rect, paint);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(45 * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawRect(rect, paint);
    canvas.restore();

    canvas.restore();
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final circumference = 2 * math.pi * radius;
    final step = dash + gap;
    final count = (circumference / step).floor();
    final dashAngle = dash / radius;
    final gapAngle = gap / radius;
    var angle = -math.pi / 2;
    for (var i = 0; i < count; i++) {
      final path = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: radius),
          angle,
          dashAngle,
        );
      canvas.drawPath(path, paint);
      angle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SigilPainter oldDelegate) => false;
}

class _DustParticle {
  _DustParticle({
    required this.left,
    required this.phase0,
    required this.durationSeconds,
    required this.size,
  });

  final double left; // 0..1
  final double phase0; // 0..1 초기 위상(음수 delay 근사)
  final double durationSeconds;
  final double size;
}

/// 금가루 파티클 레이어 — 14개, 7~11초 랜덤 주기로 420px 상승.
/// 각 파티클은 자체 [AnimationController](고유 주기)로 구동하고, 전체는
/// [Listenable.merge]로 한 번에 재빌드해 상위 트리 리빌드를 막는다.
class _GoldDustLayer extends StatefulWidget {
  const _GoldDustLayer();

  @override
  State<_GoldDustLayer> createState() => _GoldDustLayerState();
}

class _GoldDustLayerState extends State<_GoldDustLayer>
    with TickerProviderStateMixin {
  late final List<_DustParticle> _particles;
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    final rand = math.Random(7);
    _particles = List.generate(14, (_) {
      return _DustParticle(
        left: rand.nextDouble(),
        phase0: rand.nextDouble(),
        durationSeconds: 7 + rand.nextDouble() * 4,
        size: 1.5 + rand.nextDouble() * 2.5,
      );
    });
    _controllers = _particles.map((particle) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: (particle.durationSeconds * 1000).round(),
        ),
      );
      c.value = particle.phase0;
      c.repeat();
      return c;
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge(_controllers),
          builder: (context, _) {
            return Stack(
              children: List.generate(_particles.length, (i) {
                final particle = _particles[i];
                final phase = _controllers[i].value;
                double opacity;
                if (phase < 0.15) {
                  opacity = (phase / 0.15) * 0.9;
                } else if (phase < 0.85) {
                  final k = (phase - 0.15) / 0.70;
                  opacity = 0.9 - k * 0.3;
                } else {
                  final k = (phase - 0.85) / 0.15;
                  opacity = 0.6 * (1 - k);
                }
                final dy = -420 * phase;
                return Positioned(
                  left: particle.left * constraints.maxWidth - particle.size / 2,
                  bottom: -10,
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Container(
                        width: particle.size,
                        height: particle.size,
                        decoration: BoxDecoration(
                          color: GiColors.glow,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: GiColors.glow,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}
