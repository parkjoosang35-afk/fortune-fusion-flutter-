// [S1 재구축 — 소원 작성 2026-11] app3/flows.jsx `Light3({app})` 1:1 포팅.
// 소원 작성 제출 성공 직후 보여주는 "촛불 켜기" 연출. 기존 SealedDoneScreen
// (봉인 완료 두루마리 연출)과는 다른 신규 화면이다 — SealedDoneScreen은
// capsule_screen.dart(REWISH 타임캡슐 플로우)에서도 재사용 중이므로 그대로
// 유지하고, 이 화면은 compose 제출 경로에서만 쓴다.
//
// 원본 타임라인(flows.jsx Light3):
//   ph0(0~1.3s)  소원 글자들이 촛불(fx=204,fy=330)로 날아듦(fly-to)
//   ph1(1.3~1.9s) 금빛 버스트 26개
//   ph2(1.9~3.3s) 꽃잎비 + 갈래 인장 stamp
//   ph3(3.3s~)    암전 그라데이션 + "당신의 소원이\n이곳에 머물기 시작했어요" +
//                 "이제 두 손 모아, 첫 기도를 올려볼까요" + CTA "🙏 첫 기도 올리러 가기"
// 원본은 Room(배경)을 그대로 쓰지만, 이 화면은 글자 비행 연출에 집중하기 위해
// 방 배경 이미지(room-empty.jpg) 위에 FX만 얹는 단순화된 버전으로 구현한다
// (RoomScene 풀 렌더는 바로 다음 화면인 소원방 홈에서 이미 보여준다).
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_canvas.dart';
import '../../data/wr_catalog.dart';

class WishLightScreen extends StatefulWidget {
  const WishLightScreen({
    super.key,
    required this.text,
    required this.wishColor,
    required this.onGo,
  });
  final String text;
  final String wishColor;
  final VoidCallback onGo;

  @override
  State<WishLightScreen> createState() => _WishLightScreenState();
}

class _WishLightScreenState extends State<WishLightScreen> {
  int _ph = 0; // 0~3, flows.jsx Light3 ph state 1:1

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _ph = 1);
    });
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _ph = 2);
    });
    Future.delayed(const Duration(milliseconds: 3300), () {
      if (mounted) setState(() => _ph = 3);
    });
  }

  // fx 좌표 — flows.jsx `const fx = 204, fy = 330;`
  static const double _fx = 204, _fy = 330;

  List<_FlyChar> get _chars {
    final s = widget.text.characters.take(30).toList();
    return [
      for (var i = 0; i < s.length; i++)
        _FlyChar(
          c: s[i],
          x: 60.0 + (i % 15) * 18,
          y: 560.0 + (i ~/ 15) * 30,
          delay: i * .03,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    final w = cat.wishColors.firstWhere(
      (e) => e['id'] == widget.wishColor,
      orElse: () => cat.wishColors.first,
    );
    final deep = _hex(w['deep'] as String);
    final hanja = w['hanja'] as String;
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 방 배경(흐릿하게) — ph에 따라 밝아짐.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 900),
              opacity: _ph >= 2 ? 1 : (_ph >= 1 ? .55 : .25),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Image.asset(
                  'assets/wishroom/room-empty.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(color: const Color(0x80100610)),
            WrCanvasScaler(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ph0: 글자들이 촛불로 날아듦
                  if (_ph < 1)
                    for (final g in _chars)
                      _FlyingGlyph(key: ValueKey('fly_${g.x}_${g.y}'), spec: g, targetX: _fx, targetY: _fy),
                  // ph1: 금빛 버스트
                  if (_ph >= 1)
                    const WrBurst(
                      x: _fx,
                      y: _fy,
                      n: 26,
                      spread: 170,
                      color: Color(0xFFFFE08A),
                      dur: 1600,
                    ),
                  // ph2: 꽃잎비
                  if (_ph >= 2) const WrPetalRain(n: 16),
                  // ph2: 갈래 인장 stamp
                  if (_ph >= 2)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 96,
                      child: Center(
                        child: _StampSeal(hanja: hanja, color: deep),
                      ),
                    ),
                ],
              ),
            ),
            // ph3: 암전 + 문구 + CTA
            if (_ph >= 3)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE10C040A)],
                    stops: [0.5, 1],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _FadeInUp(
                          delayMs: 0,
                          child: Text(
                            '당신의 소원이\n이곳에 머물기 시작했어요',
                            textAlign: TextAlign.center,
                            style: WrF.display(26, height: 1.35),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _FadeInUp(
                          delayMs: 300,
                          child: Text(
                            '이제 두 손 모아, 첫 기도를 올려볼까요',
                            textAlign: TextAlign.center,
                            style: WrF.body(14, color: WrC.muted),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _FadeInUp(
                          delayMs: 600,
                          child: GestureDetector(
                            onTap: widget.onGo,
                            child: Container(
                              width: double.infinity,
                              height: WrSize.btnH,
                              alignment: Alignment.center,
                              decoration: WrDeco.btnGold,
                              child: Text(
                                '🙏 첫 기도 올리러 가기',
                                style: WrF.body(
                                  WrSize.btnFont,
                                  w: FontWeight.w700,
                                  color: const Color(0xFF4A2A10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlyChar {
  final String c;
  final double x, y, delay;
  _FlyChar({required this.c, required this.x, required this.y, required this.delay});
}

/// 'fly-to' 키프레임 근사: 1.2s cubic(.5,0,.6,1)로 시작 위치→목표 위치 이동 + 축소 + 페이드아웃.
class _FlyingGlyph extends StatefulWidget {
  const _FlyingGlyph({super.key, required this.spec, required this.targetX, required this.targetY});
  final _FlyChar spec;
  final double targetX, targetY;
  @override
  State<_FlyingGlyph> createState() => _FlyingGlyphState();
}

class _FlyingGlyphState extends State<_FlyingGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: (widget.spec.delay * 1000).round()), () {
      if (mounted) _c.forward();
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
      builder: (_, __) {
        final t = const Cubic(.5, 0, .6, 1).transform(_c.value);
        final x = widget.spec.x + (widget.targetX - widget.spec.x) * t;
        final y = widget.spec.y + (widget.targetY - widget.spec.y) * t;
        final scale = 1.0 - t * .7;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Text(
                widget.spec.c,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 20,
                  color: Color(0xFFFFE6C0),
                  shadows: [Shadow(color: Color(0xFFFFB070), blurRadius: 10)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 'stamp' 키프레임 근사: cubic(.34,1.56,.64,1) 바운스 확대.
class _StampSeal extends StatefulWidget {
  const _StampSeal({required this.hanja, required this.color});
  final String hanja;
  final Color color;
  @override
  State<_StampSeal> createState() => _StampSealState();
}

class _StampSealState extends State<_StampSeal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = const Cubic(.34, 1.56, .64, 1).transform(_c.value);
        return Transform.scale(
          scale: t,
          child: Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: widget.color.withValues(alpha: .6), blurRadius: 16),
              ],
            ),
            child: Text(
              widget.hanja,
              style: const TextStyle(
                fontFamily: 'NotoSerifKR',
                fontWeight: FontWeight.w900,
                fontSize: 32,
                color: Color(0xFFFFF4E0),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FadeInUp extends StatefulWidget {
  const _FadeInUp({required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;
  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
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
      builder: (_, __) {
        final t = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: widget.child,
          ),
        );
      },
    );
  }
}

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
