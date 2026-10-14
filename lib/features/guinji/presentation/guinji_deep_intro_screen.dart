import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import 'guinji_deep_result_screen.dart';
import '../widgets/guinji_animated_graph.dart' show parseGuinjiBirthLabel;

/// 08-인트로 · Deep Intro — 핸드오프 `DeepIntro`(1276~1318줄) 1:1 이식.
///
/// [귀인지도 기능 정리] 관계 상세 화면에서 처음으로 스페셜 해설을 해금한
/// 순간에만 1회 재생되는 "풀이 준비" 애니메이션. 4단계 진행 문구가
/// 1100ms 간격으로 순차 완료 표시되고, 그 사이 木火土金水 다섯 글자가
/// 새겨진 원이 24초 주기로 천천히 회전한다. 전부 완료되면 "풀이 읽기"
/// CTA가 활성화되어 [GuinjiDeepResultScreen]으로 넘어간다. 이미 해금된
/// 관계를 "다시 보기"할 때는 이 인트로를 건너뛰고 곧바로 결과로 간다
/// (호출부 `guinji_map_relation_detail_screen.dart`에서 분기).
class GuinjiDeepIntroScreen extends StatefulWidget {
  const GuinjiDeepIntroScreen({
    super.key,
    required this.person,
    this.ownerName = '나',
    this.onShare,
  });

  final GuinjiPerson person;
  final String ownerName;
  final VoidCallback? onShare;

  @override
  State<GuinjiDeepIntroScreen> createState() => _GuinjiDeepIntroScreenState();
}

class _GuinjiDeepIntroScreenState extends State<GuinjiDeepIntroScreen>
    with TickerProviderStateMixin {
  // [핸드오프 `lines` 1:1 이식] 4단계 진행 문구.
  static const _lines = [
    '두 사람의 사주 여덟 글자를 펼치고 있어요',
    '일간과 일지의 흐름을 읽고 있어요',
    '오행의 균형과 보완을 살피고 있어요',
    '관계의 결을 글로 옮기고 있어요',
  ];

  int _step = 0;
  Timer? _timer;

  /// [핸드오프 `gjSpin 24s linear infinite`] 오행 원 회전.
  late final AnimationController _spinController;

  /// [핸드오프 `gjDraw 2.4s ease forwards`] 중앙 가로선이 그려지는 애니메이션.
  late final AnimationController _drawController;

  bool get _done => _step >= _lines.length;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
    // [핸드오프 `setInterval(..., 1100)`] 1100ms마다 한 단계씩 완료 표시.
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (!mounted) return;
      if (_step >= _lines.length) {
        timer.cancel();
        return;
      }
      setState(() => _step += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spinController.dispose();
    _drawController.dispose();
    super.dispose();
  }

  void _goToResult() {
    if (!_done) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GuinjiDeepResultScreen(
          person: widget.person,
          ownerName: widget.ownerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final meta = guinjiRelationMetaOf(person.relation);
    final color = meta.color;
    final birth = parseGuinjiBirthLabel(person.birth);
    final theirCharacter = birth == null
        ? null
        : GuinjiCharacter.of(birth: birth, stableKey: person.id);
    // [핸드오프 `GJ.charFor(me)`] "나"(소유자) 얼굴 — 이 화면 컨텍스트에는
    // 실제 소유자 생년월일이 전달되지 않으므로(엔진/모델 변경 금지 원칙),
    // 지도 그래프 중앙 노드와 동일한 데모 자산을 재사용한다
    // (`guinji_animated_graph.dart`의 `_loadFaceImage('...f30_face.jpg')`
    // 와 같은 폴백).
    const myFacePath = 'assets/images/guinji/chars/f30_face.jpg';

    return Scaffold(
      backgroundColor: GmColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // DEEP READING 라벨.
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Text(
                'DEEP READING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GmText.mono,
                  fontSize: 10.5,
                  letterSpacing: 3.5,
                  color: GmColors.dim,
                ),
              ),
            ),

            // 회전 오행 원 + 중앙 가로선 + 얼굴 2개 + 한자 배지.
            Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _spinController,
                    _drawController,
                  ]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _DeepIntroPainter(
                        color: color,
                        hanja: meta.hanja,
                        spin: _spinController.value,
                        draw: _drawController.value,
                      ),
                      child: Stack(
                        children: [
                          // 왼쪽 — "나" 얼굴.
                          Positioned(
                            left: 160 - 62 - 34,
                            top: 160 - 34,
                            child: _IntroFace(
                              facePath: myFacePath,
                              size: 68,
                              ringColor: Colors.white.withValues(alpha: 0.6),
                              fallbackColor: GmColors.gold,
                              fallbackText: widget.ownerName.isNotEmpty
                                  ? widget.ownerName.substring(0, 1)
                                  : '나',
                            ),
                          ),
                          // 오른쪽 — 상대 얼굴.
                          Positioned(
                            left: 160 + 62 - 34,
                            top: 160 - 34,
                            child: _IntroFace(
                              facePath: theirCharacter?.face,
                              size: 68,
                              ringColor: color,
                              glowColor: color,
                              fallbackColor: color,
                              fallbackText: person.name.isNotEmpty
                                  ? person.name.substring(0, 1)
                                  : '?',
                            ),
                          ),
                          // 중앙 한자 배지.
                          Positioned(
                            left: 160 - 15,
                            top: 160 - 15,
                            child: Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: GmColors.bg,
                                border: Border.all(color: color),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                meta.hanja,
                                style: TextStyle(
                                  fontFamily: GmText.display,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 타이틀 + 진행 문구 목록.
            Positioned(
              left: 28,
              right: 28,
              top: 476,
              child: Column(
                children: [
                  Text(
                    '${widget.ownerName}님과 ${person.name}님,\n두 사람의 이야기',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: GmText.display,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      letterSpacing: -0.4,
                      color: GmColors.fg,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        for (var i = 0; i < _lines.length; i++)
                          AnimatedOpacity(
                            opacity: i <= _step ? 1 : 0,
                            duration: const Duration(milliseconds: 600),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    child: Text(
                                      i < _step ? '✓' : '·',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: i < _step ? color : GmColors.dim,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _lines[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: i < _step
                                          ? GmColors.muted
                                          : GmColors.dim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 하단 CTA — 완료 전까지 비활성(투명도 35%).
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: AnimatedOpacity(
                opacity: _done ? 1 : 0.35,
                duration: const Duration(milliseconds: 600),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _done ? _goToResult : null,
                    style: gmPrimary(),
                    child: Text(_done ? '풀이 읽기' : '풀이를 준비하고 있어요'),
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

/// 얼굴 사진(있으면)을 원형으로 보여주고, 없으면 색상 원 + 이니셜 폴백.
class _IntroFace extends StatelessWidget {
  const _IntroFace({
    required this.facePath,
    required this.size,
    required this.ringColor,
    required this.fallbackColor,
    required this.fallbackText,
    this.glowColor,
  });

  final String? facePath;
  final double size;
  final Color ringColor;
  final Color? glowColor;
  final Color fallbackColor;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: 1.5),
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: facePath == null
          ? Container(
              color: fallbackColor.withValues(alpha: 0.2),
              alignment: Alignment.center,
              child: Text(
                fallbackText,
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.38,
                  color: fallbackColor,
                ),
              ),
            )
          : Image.asset(
              facePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: fallbackColor.withValues(alpha: 0.2),
                alignment: Alignment.center,
                child: Text(
                  fallbackText,
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.38,
                    color: fallbackColor,
                  ),
                ),
              ),
            ),
    );
  }
}

/// [핸드오프 svg 요소 1:1 이식] 고정 원(반경128, 7% 흰선) + 회전하는
/// 점선 원(반경108, 유형색 35%) + 五行 글자 5개 + 가운데서 그려지는
/// 가로선(draw-in).
class _DeepIntroPainter extends CustomPainter {
  _DeepIntroPainter({
    required this.color,
    required this.hanja,
    required this.spin,
    required this.draw,
  });

  final Color color;
  final String hanja;

  /// 0→1 무한 반복(24초 1주기).
  final double spin;

  /// 0(선 없음)→1(완전히 그려짐), 2.4초 1회성.
  final double draw;

  static const _ohaengChars = ['木', '火', '土', '金', '水'];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 고정 바깥 원(7% 흰색).
    canvas.drawCircle(
      Offset(cx, cy),
      128,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.07),
    );

    // 회전하는 점선 원 + 오행 글자(원과 함께 회전).
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(spin * math.pi * 2);
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.35);
    const step = 1 / 180 * math.pi;
    for (double a = 0; a < math.pi * 2; a += step * 8) {
      canvas.drawLine(
        Offset(math.cos(a) * 108, math.sin(a) * 108),
        Offset(math.cos(a + step) * 108, math.sin(a + step) * 108),
        dashPaint,
      );
    }
    for (var i = 0; i < _ohaengChars.length; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5;
      final tp = TextPainter(
        text: TextSpan(
          text: _ohaengChars[i],
          style: TextStyle(
            fontFamily: GmText.display,
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.38),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          math.cos(a) * 128 - tp.width / 2,
          math.sin(a) * 128 - tp.height / 2,
        ),
      );
    }
    canvas.restore();

    // 중앙 가로선(draw-in, 좌우 62px 길이, ease 없이 선형 근사).
    final lineProgress = Curves.easeOut.transform(draw.clamp(0.0, 1.0));
    final halfLen = 62.0 * lineProgress;
    canvas.drawLine(
      Offset(cx - halfLen, cy),
      Offset(cx + halfLen, cy),
      Paint()
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DeepIntroPainter oldDelegate) {
    return oldDelegate.spin != spin ||
        oldDelegate.draw != draw ||
        oldDelegate.color != color;
  }
}
