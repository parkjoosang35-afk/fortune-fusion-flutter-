// ═══════════════════════════════════════════════════════════════
// FILE: sintong_story_hero.dart
// [신통방통 메인 매핑] C-04 · StoryHero — Handoff.html §06/§07
// "귀인지도" 소개용 5컷 × 6초 = 30초 무한 루프 스토리 슬라이드.
//
// 스펙(Handoff.html §07):
// - 5컷: hanbok(0-6s) / sky(6-12s) / saju(12-18s) / thread(18-24s) / map(24-30s)
// - 각 컷: 페이드 크로스디졸브 전환 + Ken Burns 슬로우 줌(1.08→1.00)
// - 별빛 반짝임 오버레이 5개, 3초 주기 opacity 0.35↔1.0
// - 하단좌측 진행 도트 5개(14×3), 현재 컷은 gold(#FFD6A0)로 6초에 걸쳐 채워짐
// - 캡션(Fraunces Italic 18/1.25)은 각 컷 진입 0~6%에 페이드인, 17~20%에 페이드아웃
// - Cut 1(한복, 세로 3:4)은 BoxFit.contain 중앙 배치 + 같은 이미지의 블러
//   버전(sigma 24, brightness 0.5)을 배경으로 깔아 좌우 여백을 채움
// - 우상단 "STORY" 배지, 하단 40%부터 그라디언트 어둡게 처리(캡션 가독성)
//
// [탭 인터랙션] 히어로 탭 시 귀인지도 생성 플로우(GuiinCta와 동일한
// 목적지)로 이동한다.
//
// 배터리 절약을 위해 화면이 비활성(dispose 시점)이면 타이머를 정지한다.
// ═══════════════════════════════════════════════════════════════
import 'dart:ui';
import 'package:flutter/material.dart';
import '../sintong_home_tokens.dart';

class _StoryCut {
  const _StoryCut({
    required this.asset,
    required this.captionLines,
    this.isPortrait = false,
  });

  final String asset;
  final List<InlineSpan> captionLines; // 강조어는 gold 컬러 TextSpan으로 섞음
  final bool isPortrait;
}

class SintongStoryHero extends StatefulWidget {
  const SintongStoryHero({super.key, required this.onTap});

  final VoidCallback onTap;

  static const Duration cutDuration = Duration(seconds: 6);
  static const int cutCount = 5;

  @override
  State<SintongStoryHero> createState() => _SintongStoryHeroState();
}

class _SintongStoryHeroState extends State<SintongStoryHero>
    with TickerProviderStateMixin {
  static const String _assetBase = 'assets/images/sintong_home';

  final List<_StoryCut> _cuts = const [
    _StoryCut(
      asset: '$_assetBase/story-0-hanbok.jpg',
      isPortrait: true,
      captionLines: [
        TextSpan(text: '귀인'),
        TextSpan(text: '이\n당신을 기다리고 있어요'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-1-sky.jpg',
      captionLines: [
        TextSpan(text: '밤하늘에는\n당신을 위한 '),
        TextSpan(text: '별'),
        TextSpan(text: '이 있어요'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-2-saju.jpg',
      captionLines: [
        TextSpan(text: '당신의 사주가\n'),
        TextSpan(text: '이야기'),
        TextSpan(text: '를 풀어줘요'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-4-thread.jpg',
      captionLines: [
        TextSpan(text: '붉은 실이 이어지는\n'),
        TextSpan(text: '인연의 방향'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-5-map.jpg',
      captionLines: [
        TextSpan(text: '나만의 '),
        TextSpan(text: '귀인지도'),
        TextSpan(text: '를\n만나보세요'),
      ],
    ),
  ];

  // 30초 총 루프를 통째로 도는 마스터 컨트롤러 하나로 모든 서브 애니메이션
  // (컷 전환/줌/캡션/도트)을 동기화한다 — Handoff §07 "Progress dots는
  // 컷을 진행시키는 동일 AnimationController로 구동해 완벽히 동기화" 요구
  // 그대로 반영.
  late final AnimationController _loopCtrl;
  // 반짝임(sparkle)은 3초 독립 주기라 별도 컨트롤러 사용.
  late final AnimationController _sparkleCtrl;

  @override
  void initState() {
    super.initState();
    final totalMs =
        SintongStoryHero.cutDuration.inMilliseconds * SintongStoryHero.cutCount;
    _loopCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..repeat();
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: 16 / 11,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SintongHomeRadii.xl),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF0E0820)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _loopCtrl,
                  builder: (context, _) {
                    final t = _loopCtrl.value; // 0..1 (30초 전체 진행률)
                    return Stack(
                      fit: StackFit.expand,
                      children: List.generate(_cuts.length, (i) {
                        final localT = _cutLocalProgress(t, i);
                        return _CutLayer(cut: _cuts[i], localT: localT);
                      }),
                    );
                  },
                ),
                // 하단 그라디언트 워시(캡션 가독성)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x260E0820),
                        Color(0x000E0820),
                        Color(0xB30E0820),
                      ],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                // 별빛 반짝임 오버레이
                AnimatedBuilder(
                  animation: _sparkleCtrl,
                  builder: (context, _) {
                    final opacity = 0.35 + _sparkleCtrl.value * 0.65;
                    return Opacity(
                      opacity: opacity,
                      child: const _SparkleOverlay(),
                    );
                  },
                ),
                // 우상단 STORY 배지
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(
                        SintongHomeRadii.pill,
                      ),
                    ),
                    child: Text(
                      'STORY',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: SintongHomeColors.ember,
                      ),
                    ),
                  ),
                ),
                // 캡션(컷별 페이드 인/아웃)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 26,
                  child: AnimatedBuilder(
                    animation: _loopCtrl,
                    builder: (context, _) {
                      final t = _loopCtrl.value;
                      return Stack(
                        children: List.generate(_cuts.length, (i) {
                          final localT = _cutLocalProgress(t, i);
                          return _CaptionLayer(cut: _cuts[i], localT: localT);
                        }),
                      );
                    },
                  ),
                ),
                // 하단좌측 진행 도트 5개
                Positioned(
                  left: 16,
                  bottom: 14,
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
                            child: _ProgressDot(fill: fill),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 전체 루프 진행률 [t](0..1, 30초 기준)에서 컷 [index]의 로컬 진행률을
  /// 계산한다. 자기 컷 구간이면 0..1, 그 외 구간이면 음수/1 초과로 반환해
  /// 하위 위젯이 "화면 밖" 상태로 처리하게 한다.
  double _cutLocalProgress(double t, int index) {
    final n = _cuts.length;
    final segment = 1 / n;
    final start = index * segment;
    return (t - start) / segment;
  }
}

/// 개별 컷 레이어 — Ken Burns 줌 + 페이드 크로스디졸브.
/// [localT] 0..1이 자기 표시 구간, 그 밖(음수/1 초과)은 완전히 숨김.
class _CutLayer extends StatelessWidget {
  const _CutLayer({required this.cut, required this.localT});

  final _StoryCut cut;
  final double localT;

  @override
  Widget build(BuildContext context) {
    // [버그 수정 — 스토리 슬라이드 끊김] CSS 원본 keyframe(cutSwap)의
    // 퍼센트(0%/4%/17%/20%)는 "30초 전체 루프" 기준값이다. 이 위젯이
    // 받는 [localT]는 "컷 하나(6초)를 0..1로 정규화한 로컬 진행률"이므로,
    // CSS % 그대로 0.04/0.17/0.20을 문턱값으로 쓰면 실제로는 6초 중
    // 앞의 1.2초(20%가 아니라 20%의 20%=1.2초)만 보이고 나머지 4.8초는
    // 완전히 사라져 "슬라이드가 끊기는" 것처럼 보이는 버그가 있었다.
    // 컷 하나 = 전체 루프의 1/5(=20%)이므로, CSS %를 로컬 스케일로
    // 되돌리려면 5를 곱해야 한다: 4%→0.20, 17%→0.85, 20%→1.00.
    // (0→0.20 페이드인, 0.20→0.85 유지, 0.85→1.00 페이드아웃 — 다음 컷과
    // 자연스러운 크로스디졸브를 위해 캡션 레이어와 동일한 곡선을 쓴다.)
    if (localT < -0.02 || localT > 1.02) {
      return const SizedBox.shrink();
    }
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

    // 줌: 컷 전체(0→1, 즉 6초 내내)에 걸쳐 1.08 → 1.00로 슬로우 줌.
    final scale = 1.08 - p * 0.08;

    Widget image;
    if (cut.isPortrait) {
      // Cut1 특수 처리 — 세로 이미지를 BoxFit.contain 중앙 배치하고
      // 좌우 여백은 같은 이미지의 블러(sigma24, brightness0.5) 버전으로 채움.
      image = Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.15,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.black38,
                  BlendMode.darken,
                ),
                child: Image.asset(cut.asset, fit: BoxFit.cover),
              ),
            ),
          ),
          Image.asset(cut.asset, fit: BoxFit.contain),
        ],
      );
    } else {
      image = Image.asset(cut.asset, fit: BoxFit.cover);
    }

    return Opacity(
      opacity: opacity,
      child: Transform.scale(scale: scale, child: image),
    );
  }
}

/// 캡션 레이어 — Handoff §07 capSwap 매핑(30초 전체 기준 0%→6%→17%→20%를
/// 컷 로컬(6초=1.0) 기준으로 5배 환산: 0→0.30→0.85→1.00).
///
/// [버그 수정 — 스토리 슬라이드 끊김] 위 [_CutLayer]와 동일한 원인으로
/// CSS % 원본값을 그대로 로컬 진행률 문턱값에 써서 캡션이 컷 시작
/// 직후(6초 중 0.36초)에 사라졌다 나머지 5.6초 동안 보이지 않던 버그.
class _CaptionLayer extends StatelessWidget {
  const _CaptionLayer({required this.cut, required this.localT});

  final _StoryCut cut;
  final double localT;

  @override
  Widget build(BuildContext context) {
    if (localT < -0.02 || localT > 1.02) return const SizedBox.shrink();
    final p = localT.clamp(0.0, 1.0);
    double opacity;
    double dy;
    if (p < 0.30) {
      final k = p / 0.30;
      opacity = k;
      dy = 8 * (1 - k);
    } else if (p < 0.85) {
      opacity = 1;
      dy = 0;
    } else {
      final k = (p - 0.85) / 0.15;
      opacity = 1 - k;
      dy = -4 * k;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0.001) return const SizedBox.shrink();

    final spans = cut.captionLines.map((span) {
      if (span is TextSpan && span.text != null) {
        return TextSpan(
          text: span.text,
          style: SintongHomeText.heroCaption(color: Colors.white).copyWith(
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 14,
                offset: Offset(0, 2),
              ),
            ],
          ),
        );
      }
      return span;
    }).toList();

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: RichText(
          text: TextSpan(
            style: SintongHomeText.heroCaption(color: Colors.white),
            children: spans,
          ),
        ),
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fill.clamp(0.0, 1.0),
          child: Container(color: SintongHomeColors.storyGold),
        ),
      ),
    );
  }
}

/// 별빛 반짝임 오버레이 — CSS radial-gradient 점 5개를 CustomPaint로 재현.
class _SparkleOverlay extends StatelessWidget {
  const _SparkleOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _SparkleDotsPainter(), size: Size.infinite),
    );
  }
}

class _SparkleDotsPainter extends CustomPainter {
  const _SparkleDotsPainter();

  static const _dots = [
    (0.20, 0.30, 1.5, Colors.white),
    (0.80, 0.20, 1.0, Color(0xFFFFD66A)),
    (0.60, 0.70, 1.5, Colors.white),
    (0.30, 0.80, 1.0, Color(0xFFFFD66A)),
    (0.90, 0.50, 1.0, Colors.white),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (dx, dy, r, color) in _dots) {
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(dx * size.width, dy * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleDotsPainter oldDelegate) => false;
}
