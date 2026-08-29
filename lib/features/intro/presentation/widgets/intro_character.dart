import 'package:flutter/material.dart';
import '../intro_palette.dart';

/// [핸드오프 콘텐츠 반영] `.character` — halo(후광) + 신통도령 이미지.
/// 핸드오프의 `char-float`(4s, 상하 8px 부유) 애니메이션을 재현한다.
class IntroCharacter extends StatefulWidget {
  final String asset;
  final double size;
  final double haloSize;

  const IntroCharacter({
    super.key,
    required this.asset,
    required this.size,
    double? haloSize,
  }) : haloSize = haloSize ?? size * 1.35;

  @override
  State<IntroCharacter> createState() => _IntroCharacterState();
}

class _IntroCharacterState extends State<IntroCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _float = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.haloSize,
      height: widget.haloSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.haloSize,
            height: widget.haloSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  IntroPalette.primary.withValues(alpha: 0.35),
                  IntroPalette.primary.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, _float.value), child: child),
            child: Image.asset(
              widget.asset,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
