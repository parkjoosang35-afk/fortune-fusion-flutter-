import 'dart:async';

import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../theme/guinji_map_theme.dart';

/// C · Calculating — `/guinji-map/calc` (호스트) / 게스트 참여 계산 화면.
///
/// [2026 디자인 핸드오프] "계산 중"(§05-1) — 진행 원(6초 1회전, 금색
/// 진행 아크) + 중앙 내 얼굴 + "{이름}님의 지도를 펼치고 있어요 · 사주
/// 여덟 글자를 읽는 중 N%". 응답이 오면 자동 전환(최소 2초). 실패하면
/// 다시 시도.
///
/// [컨텍스트별 문구 분기] 이 화면은 두 개의 서로 다른 흐름에서 재사용된다
/// — (1) 호스트가 자기 정보만 입력한 시점(I→C→M, "내 사주 계산"), (2)
/// 지인이 참여해 호스트와의 관계를 계산하는 시점(게스트 참여→C→Y, "두
/// 분의 관계 계산"). [title]/[subtitle]을 선택적으로 오버라이드할 수
/// 있게 해, 기본값(게스트 2인 관계 계산 문구)은 그대로 유지하면서
/// 호스트 라우트(`/guinji-map/calc`, app_router.dart)에서만 "내 사주"
/// 문구로 교체한다.
class GuinjiCalculatingScreen extends StatefulWidget {
  const GuinjiCalculatingScreen({
    super.key,
    this.autoAdvanceAfter = const Duration(seconds: 2),
    this.onComplete,
    this.title = '두 분의 관계를\n정성껏 살펴보고 있어요',
    this.subtitle = '사주 여덟 글자를 읽는 중',
  });

  static const routeName = '/guinji-map/calc';

  final Duration autoAdvanceAfter;
  final VoidCallback? onComplete;

  /// 로딩 화면 헤드라인. 기본값은 게스트 2인 관계 계산 문구(하위 호환).
  final String title;

  /// 로딩 화면 서브텍스트(진행률 N%가 뒤에 자동으로 붙는다).
  final String subtitle;

  @override
  State<GuinjiCalculatingScreen> createState() =>
      _GuinjiCalculatingScreenState();
}

class _GuinjiCalculatingScreenState extends State<GuinjiCalculatingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _advanceTimer;
  Timer? _progressTimer;
  late final AnimationController _ringController;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted) return;
      setState(() => _progress = (_progress + 4).clamp(0, 100));
      if (_progress >= 100) t.cancel();
    });
    _advanceTimer = Timer(widget.autoAdvanceAfter, () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _progressTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: _ProgressRingPainter(
                          progress: _progress,
                          rotation: _ringController.value,
                        ),
                      );
                    },
                  ),
                  ClipOval(
                    child: Image.asset(
                      const GuinjiCharacter('f30', '').face,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: GmColors.card,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GmText.display,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: GmColors.fg,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.subtitle} · $_progress%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GmText.ui,
                fontSize: 13.5,
                color: GmColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({required this.progress, required this.rotation});

  final int progress;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 92.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * 3.14159265);
    canvas.translate(-center.dx, -center.dy);

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, bgPaint);
    canvas.restore();

    final progressPaint = Paint()
      ..color = GmColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final sweep = (progress / 100) * 2 * 3.14159265;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265 / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.rotation != rotation;
}
