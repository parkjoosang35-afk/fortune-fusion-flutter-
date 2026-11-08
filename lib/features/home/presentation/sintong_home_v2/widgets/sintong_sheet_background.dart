// ═══════════════════════════════════════════════════════════════
// FILE: sintong_sheet_background.dart
// [Midnight Navy 리뉴얼 — design_handoff_sintong_main(2).zip]
// "운세 엔진" 시트의 배경 데코레이션(README "운세 엔진 시트 > 컨테이너"
// 절 레이어 순서 그대로): ① 3단 세로 그라데이션 ② 좌상단 네이비 radial
// ③ 우하단 골드 radial ④ 별빛(흰 점 7개 + 금색 점 1개) ⑤ 회전하는
// "명리 원반"(destiny wheel) 장식 SVG.
//
// 순수 장식(pointer-events 없음)이라 이 위젯 전체를 IgnorePointer로
// 감싸 시트 내부 카드/버튼의 탭을 절대 가리지 않게 한다.
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sintong_home_v2_tokens.dart';

/// 시트 전체를 덮는 배경 레이어. 시트 컨테이너의 `Stack` 맨 아래에
/// `Positioned.fill`로 넣어 쓴다.
class SintongSheetBackground extends StatelessWidget {
  const SintongSheetBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: const [
          // ① 기본 3단 세로 그라데이션 — #0E1830 0% → #0B1326 40% → #070D1B 100%.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SHomeV2Colors.navyTop,
                  SHomeV2Colors.navy,
                  SHomeV2Colors.navy2,
                ],
                stops: [0, 0.4, 1.0],
              ),
            ),
          ),
          // ② 좌상단 네이비 radial — rgba(40,62,110,.55) at 15% 0%.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -1.0),
                radius: 1.1,
                colors: [Color(0x8C283E6E), Colors.transparent],
                stops: [0, 0.6],
              ),
            ),
          ),
          // ③ 우하단 골드 radial — rgba(212,175,55,.08) at 100% 100%.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1.0, 1.0),
                radius: 1.1,
                colors: [Color(0x14D4AF37), Colors.transparent],
                stops: [0, 0.6],
              ),
            ),
          ),
          // ④ 별빛.
          _StarField(),
          // ⑤ 회전하는 명리 원반 — 우상단 모서리에 걸쳐 배치.
          Positioned(top: -160, right: -170, child: _DestinyWheel()),
        ],
      ),
    );
  }
}

/// README "별빛" — 1px 흰 점 7개 + 1.4px 금색 점 1개, 전체 opacity .3.
/// 위치는 핸드오프 HTML `.stars`의 각 `radial-gradient` 좌표(%)를 그대로
/// 옮겼다.
class _StarField extends StatelessWidget {
  const _StarField();

  // (dx%, dy%, size, isGold)
  static const List<(double, double, double, bool)> _dots = [
    (0.12, 0.18, 1, false),
    (0.72, 0.09, 1, false),
    (0.88, 0.34, 1, false),
    (0.33, 0.62, 1, false),
    (0.58, 0.82, 1, false),
    (0.46, 0.28, 1.4, true),
    (0.08, 0.88, 1, false),
    (0.94, 0.72, 1, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 600.0;
          return Stack(
            children: [
              for (final (dx, dy, size, gold) in _dots)
                Positioned(
                  left: w * dx - size / 2,
                  top: h * dy - size / 2,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold ? SHomeV2Colors.goldHi : Colors.white,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// README "명리 원반(wheel)" — 380×380, 금색 0.6px 선, opacity .1,
/// 160초 1바퀴 linear 무한 회전(동심원 r=98/86/60/34 + 5° 간격 눈금
/// 72개(30°마다 긴 눈금) + 30° 방사선 12개, viewBox 200).
///
/// [저전력/모션 줄이기 — README "원반 회전" 동작 규칙] "160s linear
/// infinite. 저전력/모션 줄이기 설정 시 정지 권장." —
/// `MediaQuery.disableAnimations`(OS 접근성 "애니메이션 줄이기" 설정)를
/// 확인해 켜져 있으면 회전을 멈추고 정적 원반만 보여준다.
class _DestinyWheel extends StatefulWidget {
  const _DestinyWheel();

  @override
  State<_DestinyWheel> createState() => _DestinyWheelState();
}

class _DestinyWheelState extends State<_DestinyWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 160),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // [README "원반 회전" 동작 규칙] "저전력/모션 줄이기 설정 시 정지
    // 권장" — MediaQuery는 initState에서 안전하게 조회할 수 없으므로
    // (상위 InheritedWidget 조회는 트리 부착 이후인 여기서 해야 함)
    // didChangeDependencies에서 최초 1회만 애니메이션을 시작한다.
    if (!_started) {
      _started = true;
      if (!MediaQuery.of(context).disableAnimations) {
        _ctrl.repeat();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      height: 380,
      child: Opacity(
        opacity: 0.1,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: child,
            );
          },
          child: CustomPaint(painter: _DestinyWheelPainter()),
        ),
      ),
    );
  }
}

class _DestinyWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 0 0 200 200 → size(380,380) 스케일.
    final scale = size.width / 200;
    canvas.save();
    canvas.scale(scale, scale);
    const center = Offset(100, 100);
    final paint = Paint()
      ..color = SHomeV2Colors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (final r in [98.0, 86.0, 60.0, 34.0]) {
      canvas.drawCircle(center, r, paint);
    }

    // 5° 간격 눈금 72개(30°마다 긴 눈금 r2=98, 그 외 r2=92), r1=86 고정.
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180;
      final r1 = 86.0;
      final r2 = i % 6 == 0 ? 98.0 : 92.0;
      canvas.drawLine(
        Offset(100 + r1 * math.cos(a), 100 + r1 * math.sin(a)),
        Offset(100 + r2 * math.cos(a), 100 + r2 * math.sin(a)),
        paint,
      );
    }

    // 30° 방사선 12개, r 34→86.
    for (var i = 0; i < 12; i++) {
      final a = i * 30 * math.pi / 180;
      canvas.drawLine(
        Offset(100 + 34 * math.cos(a), 100 + 34 * math.sin(a)),
        Offset(100 + 86 * math.cos(a), 100 + 86 * math.sin(a)),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
