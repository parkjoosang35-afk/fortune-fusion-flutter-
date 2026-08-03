import 'dart:math' as math;
import 'package:flutter/material.dart';

/// [소원방 촛불 비주얼 재작업 지시] "기능 아이콘"이 아니라 소원방의
/// 심장처럼 보이는 촛불/제단 오브제.
///
/// 기존 [WishRoomFlameWidget](비대칭 BorderRadius 트릭)은 시안 비교용으로
/// 남겨두고, 이 위젯은 CustomPainter로 초 몸체/심지/불꽃(2겹: 코어+글로우)/
/// 바닥 반사광/제단 받침/빛 번짐(bloom)을 한 캔버스에 겹쳐 그린다.
///
/// [CandleStyle] 3가지는 "제단 존재감 · bloom 크기 · 빛 입자 유무"만 다르고,
/// 색 팔레트(화이트/라벤더 베이스 + 완료 시에만 저채도 골드)와 애니메이션
/// 로직은 동일하게 공유한다. 최종안이 정해지면 이 파일 하나로 소원방
/// 전역(제단 뷰/치성 화면)의 촛불을 교체한다.
enum CandleStyle {
  /// A안 — 가장 심플하고 미니멀한 촛불. 제단 받침 없이 초+불꽃만 정갈하게.
  minimal,

  /// B안 — 제단 감성이 살아 있는 촛불. 2단 받침 위에 놓인 중심 오브제.
  altar,

  /// C안 — 빛 표현이 풍부한 촛불. 받침 + 겹겹의 bloom + 아주 은은한 빛 입자.
  radiant,
}

class WishRoomCandleWidget extends StatefulWidget {
  const WishRoomCandleWidget({
    super.key,
    required this.intensity,
    this.style = CandleStyle.altar,
    this.size = 128,
    this.completionPulseTrigger = 0,
  });

  /// 0.0(은은한 기본) ~ 1.0(치성 완료, 성스럽게 밝아진 상태).
  final double intensity;
  final CandleStyle style;
  final double size;

  /// 이 값이 바뀔 때마다(예: 완료 시 +1) 제단 주변에 은은한 빛 확산 링을
  /// 한 번 재생한다. 파티클 폭발이 아니라 "번짐" 한 번임에 유의.
  final int completionPulseTrigger;

  @override
  State<WishRoomCandleWidget> createState() => _WishRoomCandleWidgetState();
}

class _WishRoomCandleWidgetState extends State<WishRoomCandleWidget>
    with TickerProviderStateMixin {
  // 항상 켜져 있는 "숨 쉬는" 흔들림(단순 좌우 반복이 아니라, 서로 다른
  // 주기의 사인파 2개를 합쳐 기계적이지 않은 유기적 흔들림을 만든다).
  late final AnimationController _flicker;
  // 완료 시 1회 재생되는 빛 확산 펄스(파티클 없음, 링 하나만 은은하게).
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _flicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void didUpdateWidget(covariant WishRoomCandleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completionPulseTrigger != oldWidget.completionPulseTrigger) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = widget.intensity.clamp(0.0, 1.0);
    final s = widget.size;
    final canvasSize = Size(s * 1.55, s * 1.7);

    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: TweenAnimationBuilder<double>(
        // 밝기/크기 변화는 opacity 단발이 아니라 값 하나(intensity)를
        // 350~500ms로 부드럽게 보간해, glow/불꽃 크기/색온도가 함께
        // 자연스럽게 따라오게 한다("숨 쉬는 촛불").
        tween: Tween(begin: intensity, end: intensity),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOut,
        builder: (context, liveIntensity, _) {
          return AnimatedBuilder(
            animation: Listenable.merge([_flicker, _pulse]),
            builder: (context, __) {
              final t = _flicker.value * 2 * math.pi;
              // 아주 미세한 좌우 기울임(이전보다 절반 이하 진폭) +
              // 서로 다른 위상의 두 번째 사인파를 더해 규칙적이지 않게.
              final sway = math.sin(t) * 0.016 + math.sin(t * 1.65 + 1.3) * 0.007;
              // 크기 "숨쉬기"(breathing) — opacity가 아니라 스케일로 살아있는
              // 느낌을 준다.
              final breathe = 1.0 +
                  math.sin(t * 0.82) * 0.018 +
                  math.sin(t * 2.15 + 0.6) * 0.010;
              final moteT = _flicker.value; // 0..1 loop, 입자 위상용

              return CustomPaint(
                size: canvasSize,
                painter: _CandlePainter(
                  style: widget.style,
                  intensity: liveIntensity,
                  sway: sway,
                  breathe: breathe,
                  moteT: moteT,
                  pulse: _pulse.value,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.style,
    required this.intensity,
    required this.sway,
    required this.breathe,
    required this.moteT,
    required this.pulse,
  });

  final CandleStyle style;
  final double intensity;
  final double sway;
  final double breathe;
  final double moteT;
  final double pulse;

  // 저채도 팔레트: 기본은 화이트/라벤더, intensity가 올라가도 파스텔
  // 골드에서 멈춘다(형광·고채도 주황 금지 — 소원방 촛불 재작업 지시 §5).
  static const _base = Color(0xFFF6F3FC); // 라벤더 화이트
  static const _baseCore = Color(0xFFFFFFFF);
  static const _warmOuter = Color(0xFFF4D9A6); // 저채도 소프트 골드
  static const _warmCore = Color(0xFFFFEFCB);

  Color get _outerColor => Color.lerp(_base, _warmOuter, intensity)!;
  Color get _coreColor => Color.lerp(_baseCore, _warmCore, intensity)!;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final floorY = size.height * 0.88;

    _paintBloom(canvas, cx, floorY);
    _paintPedestal(canvas, cx, floorY);
    _paintFloorGlow(canvas, cx, floorY);
    final candleTopY = _paintCandleBody(canvas, cx, floorY);
    _paintFlame(canvas, cx, candleTopY);
    if (style == CandleStyle.radiant) _paintDustMotes(canvas, cx, floorY);
    _paintCompletionPulse(canvas, cx, floorY);
  }

  /// 빛 번짐(bloom) — 진짜 가우시안 블러(MaskFilter)로 "은은한 빛 확산"을
  /// 표현한다. RadialGradient만 쓰는 것보다 부드럽고 사진 같은 느낌.
  void _paintBloom(Canvas canvas, double cx, double floorY) {
    final layers = style == CandleStyle.radiant ? 2 : 1;
    final baseRadius = switch (style) {
      CandleStyle.minimal => size0(cx) * 0.62,
      CandleStyle.altar => size0(cx) * 0.78,
      CandleStyle.radiant => size0(cx) * 0.92,
    };
    for (var i = 0; i < layers; i++) {
      final radius = baseRadius * (1 + i * 0.55) * (0.92 + intensity * 0.28);
      final alpha = (0.16 + intensity * 0.16) * (i == 0 ? 1.0 : 0.6);
      final paint = Paint()
        ..color = _outerColor.withValues(alpha: alpha.clamp(0.0, 0.42))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.34);
      canvas.drawCircle(
        Offset(cx, floorY - radius * 0.52),
        radius * 0.5,
        paint,
      );
    }
  }

  double size0(double cx) => cx; // 편의용(캔버스 절반 폭을 스케일 기준으로).

  /// 제단 받침 — minimal은 아주 얇은 흔적만, altar/radiant는 2단 받침을
  /// 또렷하게 그려 "제단 위에 놓인 중심 오브제" 느낌을 준다.
  void _paintPedestal(Canvas canvas, double cx, double floorY) {
    if (style == CandleStyle.minimal) return;

    final w = size0(cx);
    final tierBottomW = w * 0.92;
    final tierTopW = w * 0.5;
    final tierH = w * 0.10;
    final baseTopW = w * 0.62;
    final baseBottomW = w * 0.82;
    final baseH = w * 0.075;

    // 하단 넓은 단(그림자감 있는 라벤더 톤)
    final lowerRect = Rect.fromCenter(
      center: Offset(cx, floorY + tierH * 0.05),
      width: tierBottomW,
      height: tierH,
    );
    final lowerPath = _trapezoidPath(lowerRect, tierTopW);
    canvas.drawPath(
      lowerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFEFEBF9), const Color(0xFFE1DCF1)],
        ).createShader(lowerRect),
    );

    // 상단 좁은 단(살짝 밝은 하이라이트 에지)
    final upperRect = Rect.fromCenter(
      center: Offset(cx, floorY - baseH * 0.55),
      width: baseBottomW * 0.62,
      height: baseH,
    );
    final upperPath = _trapezoidPath(upperRect, baseTopW * 0.55);
    canvas.drawPath(
      upperPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFAF8FF), const Color(0xFFEDE8F8)],
        ).createShader(upperRect),
    );
    canvas.drawPath(
      Path()
        ..moveTo(upperRect.left, upperRect.top)
        ..lineTo(upperRect.right, upperRect.top),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  Path _trapezoidPath(Rect rect, double topWidth) {
    final halfTop = topWidth / 2;
    return Path()
      ..moveTo(rect.center.dx - halfTop, rect.top)
      ..lineTo(rect.center.dx + halfTop, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  /// 초 바로 아래 은은한 바닥 반사광(모든 스타일 공통, 아주 옅게).
  void _paintFloorGlow(Canvas canvas, double cx, double floorY) {
    final w = size0(cx) * (style == CandleStyle.minimal ? 0.5 : 0.62);
    final paint = Paint()
      ..color = _outerColor.withValues(alpha: 0.20 + intensity * 0.10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.22);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, floorY - 2), width: w, height: w * 0.24),
      paint,
    );
  }

  /// 초 몸체 — 위쪽은 완전히 둥글게(캡), 아래는 살짝만 둥글게 처리해
  /// "단정한 원기둥 초" 인상을 준다. 아이보리 그라디언트 + 얇은 외곽선.
  double _paintCandleBody(Canvas canvas, double cx, double floorY) {
    final w = size0(cx);
    final bodyW = w * 0.20;
    final bodyH = w * 0.46;
    final bodyBottom = floorY - w * 0.02;
    final bodyTop = bodyBottom - bodyH;
    final rect = Rect.fromLTRB(
      cx - bodyW / 2,
      bodyTop,
      cx + bodyW / 2,
      bodyBottom,
    );
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(bodyW / 2),
      topRight: Radius.circular(bodyW / 2),
      bottomLeft: Radius.circular(bodyW * 0.12),
      bottomRight: Radius.circular(bodyW * 0.12),
    );

    // 살짝 따뜻한 그림자감(과하지 않게) — 좌측은 밝고 우측은 아주 살짝 그늘.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFFFDFBF6), Color(0xFFEFEAE0)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE7E1D3).withValues(alpha: 0.9),
    );

    // 심지(진한 브라운/차콜, 아주 작게)
    final wickRect = Rect.fromCenter(
      center: Offset(cx, bodyTop - w * 0.012),
      width: w * 0.012,
      height: w * 0.045,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wickRect, Radius.circular(w * 0.006)),
      Paint()..color = const Color(0xFF4B4550),
    );

    return bodyTop - w * 0.03; // 불꽃이 시작될 y 좌표
  }

  /// 불꽃 — 2겹 구조(바깥 소프트 글로우 실루엣 + 안쪽 밝은 코어). 노란
  /// 물방울이 아니라 "빛이 있는 불꽃"으로 보이도록 코어를 확실히 밝게 둔다.
  void _paintFlame(Canvas canvas, double cx, double baseY) {
    final w = size0(cx);
    final flameH = w * (0.34 + intensity * 0.16) * breathe;
    final flameW = w * (0.13 + intensity * 0.05) * breathe;

    canvas.save();
    canvas.translate(cx, baseY);
    canvas.rotate(sway);
    canvas.translate(-cx, -baseY);

    final outerRect = Rect.fromLTRB(
      cx - flameW,
      baseY - flameH,
      cx + flameW,
      baseY,
    );
    final outerPath = _flamePath(outerRect, lean: sway * 2.2);

    // 바깥 글로우 실루엣(블러로 부드럽게 퍼짐)
    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_coreColor.withValues(alpha: 0.9), _outerColor],
        ).createShader(outerRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, flameW * 0.22),
    );
    // 실루엣을 한 번 더 선명하게(블러 없이) 덧그려 형태감 유지.
    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_coreColor, _outerColor.withValues(alpha: 0.92)],
        ).createShader(outerRect),
    );

    // 안쪽 코어(더 작고, 더 밝고, 살짝 위로 치우침 — "빛의 심장")
    final coreRect = Rect.fromLTRB(
      cx - flameW * 0.48,
      baseY - flameH * 0.78,
      cx + flameW * 0.48,
      baseY - flameH * 0.06,
    );
    final corePath = _flamePath(coreRect, lean: sway * 1.4);
    canvas.drawPath(
      corePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.68 + intensity * 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, flameW * 0.10),
    );

    canvas.restore();
  }

  /// 자연스러운 불꽃 실루엣(테두리가 각지지 않도록 3차 베지어로 좌우
  /// 비대칭 곡선을 만든다). lean이 붙으면 끝이 살짝 기운다.
  Path _flamePath(Rect r, {double lean = 0}) {
    final w = r.width;
    final h = r.height;
    final bottom = Offset(r.center.dx, r.bottom);
    final tip = Offset(r.center.dx + lean * w * 0.6, r.top);
    final path = Path()..moveTo(bottom.dx, bottom.dy);
    path.cubicTo(
      r.left + w * 0.02,
      r.top + h * 0.70,
      r.left + w * 0.10,
      r.top + h * 0.26,
      tip.dx,
      tip.dy,
    );
    path.cubicTo(
      r.left + w * 0.90,
      r.top + h * 0.24,
      r.right - w * 0.02,
      r.top + h * 0.68,
      bottom.dx,
      bottom.dy,
    );
    path.close();
    return path;
  }

  /// C안 전용 — 아주 은은하고 느리게 떠오르는 빛 입자(스파클 아님).
  /// 반짝이지 않고, 블러된 작은 원이 천천히 위로 떠오르며 옅게 사라진다.
  void _paintDustMotes(Canvas canvas, double cx, double floorY) {
    final w = size0(cx);
    const count = 3;
    for (var i = 0; i < count; i++) {
      final phase = (moteT + i / count) % 1.0;
      final dx = math.sin((moteT + i) * 2 * math.pi * 0.5) * w * 0.18;
      final dy = floorY - w * 0.35 - phase * w * 0.55;
      final alpha = (math.sin(phase * math.pi) * 0.16) * (0.5 + intensity * 0.5);
      final paint = Paint()
        ..color = _outerColor.withValues(alpha: alpha.clamp(0.0, 0.18))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
      canvas.drawCircle(Offset(cx + dx, dy), 2.6, paint);
    }
  }

  /// 치성 완료 시 1회 재생되는 은은한 빛 확산 링(파티클 폭발 금지).
  void _paintCompletionPulse(Canvas canvas, double cx, double floorY) {
    if (pulse <= 0 || pulse >= 1) return;
    final w = size0(cx);
    final radius = w * (0.28 + pulse * 0.62);
    final alpha = (1 - pulse) * 0.32;
    canvas.drawCircle(
      Offset(cx, floorY - w * 0.32),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _warmOuter.withValues(alpha: alpha.clamp(0.0, 0.32)),
    );
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.sway != sway ||
        oldDelegate.breathe != breathe ||
        oldDelegate.moteT != moteT ||
        oldDelegate.pulse != pulse ||
        oldDelegate.style != style;
  }
}
