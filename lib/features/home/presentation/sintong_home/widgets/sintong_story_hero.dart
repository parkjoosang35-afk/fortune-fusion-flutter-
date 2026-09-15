// ═══════════════════════════════════════════════════════════════
// FILE: sintong_story_hero.dart
// [신통방통 메인 매핑] C-04 · StoryHero — design_handoff_story_hero.zip
// "귀인지도" 소개용 5컷 × 6초 = 30초 무한 루프 스토리 슬라이드.
//
// 스펙(README.md + story_hero_prototype.html — 소스 오브 트루스):
// - 5컷: hanbok(0-6s) / forest(6-12s) / tower(12-18s) / apothecary(18-24s)
//   / village(24-30s) — 전부 16:9 이미지, 세로 특수처리 불필요
// - 컨테이너: aspect 16:11, radius 18, bg #0E0820,
//   shadow 0 8px 24px -12px rgba(0,0,0,0.35)
// - 각 컷: Ken Burns 슬로우 줌(1.08→1.00) + 페이드 크로스디졸브
//   CSS keyframe(cutSwap, 30s 기준): 0%→4%→17%→20% 페이드인/유지/페이드아웃.
//   이 위젯의 localT는 "컷 1개(6초)=0..1" 로컬 스케일이므로, 컷 1개가
//   전체 루프의 1/5(20%)인 점을 이용해 5배 스케일링해서 사용한다:
//   4%→0.20, 17%→0.85, 20%→1.00.
// - 캡션(capSwap, 30s 기준 0%→6%→17%→20%)도 동일 원리로 5배 스케일링:
//   6%→0.30, 17%→0.85, 20%→1.00. Y축 8px→0→-4px.
// - 별빛 반짝임 오버레이 5개, 3초 주기 opacity 0.35↔1.0
// - 하단좌측 진행 도트 5개(14×3), 현재 컷은 gold(#FFD6A0)로 6초 linear 채움
// - 우상단 "⟳ STORY" pill 버튼 — 탭 시 애니메이션 완전 리셋 후 Cut 1부터
//   재생 + 프레스 피드백(scale 0.94, 150ms)
// - 배너 배경(캡션/도트/스파클 제외) 탭 → 귀인지도 생성 플로우 이동
// - 앱이 백그라운드로 가면 애니메이션 일시정지, 포그라운드 복귀 시 재개
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../sintong_home_tokens.dart';

class _StoryCut {
  const _StoryCut({required this.asset, required this.captionLines});

  final String asset;
  final List<InlineSpan> captionLines; // 강조어는 gold 컬러 TextSpan으로 섞음
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _assetBase = 'assets/images/sintong_home';

  final List<_StoryCut> _cuts = const [
    _StoryCut(
      asset: '$_assetBase/story-0-hanbok.jpg',
      captionLines: [
        TextSpan(text: '귀인'),
        TextSpan(text: '이\n당신을 기다리고 있어요'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-1-forest.jpg',
      captionLines: [
        TextSpan(text: '밤길에도\n당신을 이끄는 '),
        TextSpan(text: '발걸음'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-2-tower.jpg',
      captionLines: [
        TextSpan(text: '먼 곳에서도\n'),
        TextSpan(text: '인연'),
        TextSpan(text: '은 이어져요'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-3-apothecary.jpg',
      captionLines: [
        TextSpan(text: '당신의 사주가\n'),
        TextSpan(text: '이야기'),
        TextSpan(text: '를 풀어줘요'),
      ],
    ),
    _StoryCut(
      asset: '$_assetBase/story-4-village.jpg',
      captionLines: [
        TextSpan(text: '나만의 '),
        TextSpan(text: '귀인지도'),
        TextSpan(text: '를\n만나보세요'),
      ],
    ),
  ];

  // 30초 총 루프를 통째로 도는 마스터 컨트롤러 하나로 모든 서브 애니메이션
  // (컷 전환/줌/캡션/도트)을 동기화한다.
  late final AnimationController _loopCtrl;
  // 반짝임(sparkle)은 3초 독립 주기라 별도 컨트롤러 사용.
  late final AnimationController _sparkleCtrl;
  bool _storyBtnPressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 배터리 절약: 앱이 백그라운드로 가면 애니메이션 일시정지, 복귀 시 재개.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _loopCtrl.stop();
      _sparkleCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _loopCtrl.repeat();
      _sparkleCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loopCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  void _restartStory() {
    _loopCtrl
      ..reset()
      ..repeat();
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

  int _currentCutIndex(double t) {
    final idx = (t * _cuts.length).floor();
    return idx.clamp(0, _cuts.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopCtrl,
      builder: (context, _) {
        final t = _loopCtrl.value;
        final currentCut = _currentCutIndex(t);
        return Semantics(
          label: '귀인지도 스토리, 슬라이드 ${currentCut + 1}/${_cuts.length}, 탭하여 열기',
          button: true,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AspectRatio(
              aspectRatio: 16 / 11,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SintongHomeRadii.xl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                      spreadRadius: -12,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SintongHomeRadii.xl),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFF0E0820)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1) 배경 이미지 5장
                        Stack(
                          fit: StackFit.expand,
                          children: List.generate(_cuts.length, (i) {
                            final localT = _cutLocalProgress(t, i);
                            return _CutLayer(cut: _cuts[i], localT: localT);
                          }),
                        ),
                        // 2) 하단 그라디언트 워시(캡션 가독성)
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
                        // 3) 별빛 반짝임 오버레이
                        AnimatedBuilder(
                          animation: _sparkleCtrl,
                          builder: (context, _) {
                            final opacity = 0.35 + _sparkleCtrl.value * 0.65;
                            return IgnorePointer(
                              child: Opacity(
                                opacity: opacity,
                                child: const _SparkleOverlay(),
                              ),
                            );
                          },
                        ),
                        // 4) 우상단 "⟳ STORY" 버튼 — 실제 재시작 기능
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) =>
                                setState(() => _storyBtnPressed = true),
                            onTapCancel: () =>
                                setState(() => _storyBtnPressed = false),
                            onTapUp: (_) =>
                                setState(() => _storyBtnPressed = false),
                            onTap: _restartStory,
                            child: AnimatedScale(
                              scale: _storyBtnPressed ? 0.94 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.replay,
                                      size: 11,
                                      color: SintongHomeColors.ember,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'STORY',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                        color: SintongHomeColors.ember,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 5) 캡션(컷별 페이드 인/아웃) — left/right 16, bottom 68
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 68,
                          child: IgnorePointer(
                            child: Stack(
                              children: List.generate(_cuts.length, (i) {
                                final localT = _cutLocalProgress(t, i);
                                return _CaptionLayer(
                                  cut: _cuts[i],
                                  localT: localT,
                                );
                              }),
                            ),
                          ),
                        ),
                        // 6) 하단좌측 진행 도트 5개
                        Positioned(
                          left: 16,
                          bottom: 14,
                          child: IgnorePointer(
                            child: Row(
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
    if (localT < -0.02 || localT > 1.02) {
      return const SizedBox.shrink();
    }
    final p = localT.clamp(0.0, 1.0);
    // CSS cutSwap(30s 기준 4%/17%/20%)을 컷 로컬 스케일(x5)로 환산:
    // 0→0.20 페이드인, 0.20→0.85 유지, 0.85→1.00 페이드아웃.
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

    // Ken Burns: 컷 전체(0→1, 6초 내내)에 걸쳐 1.08 → 1.00로 슬로우 줌.
    final scale = 1.08 - p * 0.08;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(cut.asset, fit: BoxFit.cover),
      ),
    );
  }
}

/// 캡션 레이어 — capSwap 매핑(30초 전체 기준 0%→6%→17%→20%를 컷 로컬(6초
/// =1.0) 기준으로 5배 환산: 0→0.30→0.85→1.00). Y축 8px→0→-4px.
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
    return const CustomPaint(
      painter: _SparkleDotsPainter(),
      size: Size.infinite,
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
