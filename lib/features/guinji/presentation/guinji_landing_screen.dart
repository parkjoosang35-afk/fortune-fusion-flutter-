import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';
import '../widgets/guinji_char_pair.dart';
import '../widgets/guinji_ui_kit.dart';

/// L · Landing — `/guinji`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1176~1341줄 마크업을
/// 그대로 재현한다. 회원가입/로그인 없이 누구나 볼 수 있는 첫 진입
/// 페이지(SEO 대응 + 소셜 유입 랜딩)로, 예시 미리보기 지도와
/// "지도 만들기 · 무료" CTA만 노출한다. CTA를 누르면 I(Input) 화면으로
/// 이동하며, 로그인이 필요한 시점은 I 화면 진입 이후(지도 생성 시점)로
/// 미룬다 — 바이럴 원칙("게스트는 회원가입 없이 완전히 둘러볼 수 있어야
/// 한다")을 호스트 랜딩에도 동일하게 적용.
class GuinjiLandingScreen extends StatelessWidget {
  const GuinjiLandingScreen({super.key});

  static const routeName = '/guinji';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.4),
        bgOpacity: 0.14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Brand(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LandingTitle(),
                    const SizedBox(height: 6),
                    const Text(
                      '생년월일만 있으면 돼요. 신통방통이 관계의 결을 봐드립니다.',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontSize: 12,
                        height: 1.6,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const GuinjiCharPair(
                      leftAsset: 'assets/images/guinji/doryeong/greeting.png',
                      rightAsset: 'assets/images/guinji/seonnyeo/greeting.png',
                      duration: Duration(milliseconds: 3600),
                      imageSize: 108,
                      gap: 4,
                    ),
                    const SizedBox(height: 4),
                    const _CharacterNames(),
                    const SizedBox(height: 20),
                    const _LandingPreviewMap(),
                    const SizedBox(height: 16),
                    const GuinjiStatRow(
                      items: [
                        ('128,542', 'MAPS'),
                        ('3.2M', 'RELATIONS'),
                        ('98%', '추천'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GuinjiPrimaryButton(
              label: '지도 만들기 · 무료',
              onPressed: () {
                Navigator.of(context).pushNamed('/guinji-map/new');
              },
            ),
            const SizedBox(height: 12),
            const Text(
              '"재미·참고용" 콘텐츠 · 개인정보는 안전하게 보호됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 10,
                height: 1.5,
                color: GuinjiColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: GuinjiColors.lavender,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GuinjiColors.lavender.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '신통방통',
              style: TextStyle(
                fontFamily: GuinjiFonts.display,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GuinjiColors.textPrimary,
              ),
            ),
          ],
        ),
        const Text(
          'L · LANDING',
          style: TextStyle(
            fontFamily: GuinjiFonts.mono,
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 3,
            color: GuinjiColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LandingTitle extends StatelessWidget {
  const _LandingTitle();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: GuinjiFonts.display,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1.3,
          letterSpacing: -0.4,
          color: GuinjiColors.textPrimary,
        ),
        children: [
          TextSpan(text: '내 곁의\n'),
          TextSpan(text: '귀인', style: TextStyle(color: GuinjiColors.lavender)),
          TextSpan(text: '은 몇 명일까'),
        ],
      ),
    );
  }
}

class _CharacterNames extends StatelessWidget {
  const _CharacterNames();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '신통도령',
          style: TextStyle(
            fontFamily: GuinjiFonts.mono,
            fontSize: 9,
            letterSpacing: 2,
            color: GuinjiColors.lavender,
          ),
        ),
        SizedBox(width: 40),
        Text(
          '방통선녀',
          style: TextStyle(
            fontFamily: GuinjiFonts.mono,
            fontSize: 9,
            letterSpacing: 2,
            color: Color(0xFFF5C8D5),
          ),
        ),
      ],
    );
  }
}

/// `.landing-hero` + `.landing-preview-map` + `.preview-node`(6개) +
/// `.preview-center`.
class _LandingPreviewMap extends StatefulWidget {
  const _LandingPreviewMap();

  @override
  State<_LandingPreviewMap> createState() => _LandingPreviewMapState();
}

class _LandingPreviewMapState extends State<_LandingPreviewMap>
    with TickerProviderStateMixin {
  static const _nodes = [
    (hanja: '貴', color: GuinjiColors.relationCheonGwii, left: 0.30, top: 0.20, delayMs: 0),
    (hanja: '生', color: GuinjiColors.relationNaSalrida, left: 0.68, top: 0.25, delayMs: 400),
    (hanja: '助', color: GuinjiColors.relationJoryeok, left: 0.78, top: 0.55, delayMs: 800),
    (hanja: '刺', color: GuinjiColors.relationJageukje, left: 0.62, top: 0.80, delayMs: 1200),
    (hanja: '緣', color: GuinjiColors.relationKkeurida, left: 0.32, top: 0.78, delayMs: 1600),
    (hanja: '輝', color: GuinjiColors.relationGachiBich, left: 0.15, top: 0.50, delayMs: 2000),
  ];

  late final List<AnimationController> _controllers;
  late final List<Timer> _delayTimers;

  @override
  void initState() {
    super.initState();
    _delayTimers = [];
    _controllers = List.generate(_nodes.length, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000),
      );
      _delayTimers.add(
        Timer(Duration(milliseconds: _nodes[i].delayMs), () {
          if (mounted) controller.repeat();
        }),
      );
      return controller;
    });
  }

  @override
  void dispose() {
    for (final timer in _delayTimers) {
      timer.cancel();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            GuinjiColors.lavender.withValues(alpha: 0.22),
            GuinjiColors.backgroundDeep,
          ],
        ),
      ),
      // [렌더 크래시 수정 — Task 8 검증에서 발견] `LayoutBuilder`는 투명한
      // Builder가 아니라 자체 RenderObject를 삽입하는 위젯이라, 예전처럼
      // `Stack` → `LayoutBuilder` → `AnimatedBuilder` → `Positioned` 순서로
      // 감싸면 `Positioned`의 실제 렌더 부모가 `RenderStack`이 아니게 되어
      // "Incorrect use of ParentDataWidget" 크래시가 발생했다(L 화면 진입
      // 즉시 예외). `LayoutBuilder`를 `Stack` **밖으로** 한 번만 감싸
      // constraints를 얻고, `Stack`의 직계 자식은 `AnimatedBuilder`(투명한
      // StatelessWidget 서브클래스라 RenderObject를 삽입하지 않음) →
      // `Positioned`로 유지해 정상적인 ParentData 체인을 보장한다.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // landing-badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: GuinjiColors.gold.withValues(alpha: 0.2),
                    border: Border.all(
                      color: GuinjiColors.gold.withValues(alpha: 0.45),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '▸ 예시 미리보기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: GuinjiColors.gold,
                    ),
                  ),
                ),
              ),
              // preview-center
              const Center(
                child: _PreviewCenter(),
              ),
              // preview-node x6
              for (var i = 0; i < _nodes.length; i++)
                AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, _) {
                    final node = _nodes[i];
                    final t = _controllers[i].value;
                    final dy = t <= 0.5
                        ? -4 * (t / 0.5)
                        : -4 * (1 - (t - 0.5) / 0.5);
                    return Positioned(
                      left: node.left * constraints.maxWidth - 16,
                      top: node.top * constraints.maxHeight - 16 + dy,
                      child: _PreviewNode(hanja: node.hanja, color: node.color),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewCenter extends StatelessWidget {
  const _PreviewCenter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [
            GuinjiColors.lavender,
            GuinjiColors.lavender.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 30),
        ],
      ),
      child: const Text(
        '我',
        style: TextStyle(
          fontFamily: GuinjiFonts.display,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2A1A3A),
        ),
      ),
    );
  }
}

class _PreviewNode extends StatelessWidget {
  const _PreviewNode({required this.hanja, required this.color});

  final String hanja;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GuinjiColors.backgroundDeep,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
      ),
      child: Text(
        hanja,
        style: TextStyle(
          fontFamily: GuinjiFonts.display,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
