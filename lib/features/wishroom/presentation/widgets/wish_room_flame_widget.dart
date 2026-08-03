import 'package:flutter/material.dart';

/// [소원방 MVP §8 제단/촛불 비주얼 규칙] "촛불은 절대 꺼진 상태로 두지
/// 않는다. 항상 은은하게 타고 있어야 한다."
///
/// [intensity]는 0.0(은은한 기본 상태)~1.0(완료 상태의 활활 타오르는 성화)
/// 사이의 값이다. 호출하는 화면이 이 값 하나만 바꿔주면, 이 위젯은:
/// - 항상 은은한 좌우 흔들림(ambient sway)을 유지하고,
/// - intensity가 오르면 불꽃 크기/글로우/색온도가 부드럽게(AnimatedContainer
///   계열, 350ms easeOut) 커지고 따뜻해진다.
///
/// 커스텀 페인터 없이 비대칭 [BorderRadius]로 "꽃잎/불꽃" 실루엣을 만든
/// 이유는, 과한 3D/판타지 연출 없이(§3 금지 원칙) 가볍고 안정적으로 "말랑
/// 하지만 고급스러운" 느낌을 내기 위함이다.
class WishRoomFlameWidget extends StatefulWidget {
  const WishRoomFlameWidget({
    super.key,
    required this.intensity,
    this.size = 120,
  });

  /// 0.0(기본) ~ 1.0(완료/성화) 사이로 클램프된다.
  final double intensity;
  final double size;

  @override
  State<WishRoomFlameWidget> createState() => _WishRoomFlameWidgetState();
}

class _WishRoomFlameWidgetState extends State<WishRoomFlameWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swayController;
  late final Animation<double> _swayAngle;

  @override
  void initState() {
    super.initState();
    // 항상 켜져 있는 은은한 흔들림 — intensity와 무관하게 계속 반복한다.
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _swayAngle = Tween<double>(begin: -0.045, end: 0.045).animate(
      CurvedAnimation(parent: _swayController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _swayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intensity = widget.intensity.clamp(0.0, 1.0);
    final w = widget.size;

    return SizedBox(
      width: w,
      height: w * 1.35,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 제단 받침(연보라 은은한 번짐)
          Positioned(
            bottom: 0,
            child: Container(
              width: w * 0.9,
              height: w * 0.16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE7E2F7).withValues(alpha: 0.9),
                    const Color(0xFFE7E2F7).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // 초(캔들 바디)
          Positioned(
            bottom: w * 0.08,
            child: Container(
              width: w * 0.16,
              height: w * 0.42,
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F2),
                borderRadius: BorderRadius.circular(w * 0.05),
                border: Border.all(color: const Color(0xFFECECEF), width: 1),
              ),
            ),
          ),
          // 불꽃(항상 살아있는 흔들림 + intensity에 따라 부드럽게 커지는 글로우)
          Positioned(
            bottom: w * 0.08 + w * 0.42 - 2,
            child: AnimatedBuilder(
              animation: _swayAngle,
              builder: (context, child) => Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.rotationZ(_swayAngle.value),
                child: child,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: intensity, end: intensity),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => _FlameCore(size: w, intensity: value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlameCore extends StatelessWidget {
  const _FlameCore({required this.size, required this.intensity});

  final double size;
  final double intensity;

  /// 은은한 아이보리~연보라(기본) → 따뜻한 골드~오렌지(완료) 톤 보간.
  /// [주의] "지나치게 화려한 금색 표현 금지" 정책에 따라 채도를 낮춰
  /// intensity가 최대치여도 파스텔에 가까운 골드만 사용한다.
  Color _outerColor(double t) =>
      Color.lerp(const Color(0xFFEFE9FA), const Color(0xFFF3C988), t)!;
  Color _innerColor(double t) =>
      Color.lerp(const Color(0xFFFDFBF5), const Color(0xFFFFE1AE), t)!;

  @override
  Widget build(BuildContext context) {
    final flameW = size * (0.34 + intensity * 0.16);
    final flameH = size * (0.5 + intensity * 0.22);
    final glowSize = size * (0.7 + intensity * 0.55);

    return SizedBox(
      width: glowSize,
      height: glowSize * 1.1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 은은한 글로우 halo
          Positioned(
            bottom: flameH * 0.1,
            child: Container(
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _outerColor(intensity).withValues(
                      alpha: 0.30 + intensity * 0.22,
                    ),
                    _outerColor(intensity).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // 불꽃 외곽(둥근 윗부분 + 살짝 좁아지는 아랫부분 = 꽃잎/불꽃 실루엣)
          Positioned(
            bottom: 0,
            child: Container(
              width: flameW,
              height: flameH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(flameW * 0.5),
                  topRight: Radius.circular(flameW * 0.5),
                  bottomLeft: Radius.circular(flameW * 0.12),
                  bottomRight: Radius.circular(flameW * 0.12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_innerColor(intensity), _outerColor(intensity)],
                ),
              ),
            ),
          ),
          // 불꽃 안쪽 하이라이트(입체감)
          Positioned(
            bottom: flameH * 0.12,
            child: Container(
              width: flameW * 0.5,
              height: flameH * 0.55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(flameW * 0.3),
                  topRight: Radius.circular(flameW * 0.3),
                  bottomLeft: Radius.circular(flameW * 0.1),
                  bottomRight: Radius.circular(flameW * 0.1),
                ),
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
