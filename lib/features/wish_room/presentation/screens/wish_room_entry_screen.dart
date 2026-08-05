import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_screen.dart';

/// [소원방 Riverpod 실험판] 입장 화면.
/// 페이드+스케일 전환 연출 후 메인 화면으로 자동/탭 전환된다.
class WishRoomEntryScreen extends StatefulWidget {
  const WishRoomEntryScreen({super.key});

  @override
  State<WishRoomEntryScreen> createState() => _WishRoomEntryScreenState();
}

class _WishRoomEntryScreenState extends State<WishRoomEntryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1400), _enterMainScreen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enterMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const WishRoomScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: GestureDetector(
        onTap: _enterMainScreen,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: WishRoomColors.backgroundGradient,
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('당신의 소원이 머무는 방', style: WishRoomTextStyles.titleXl),
                    const SizedBox(height: WishRoomSpacing.md),
                    Text('조용히 문을 엽니다…', style: WishRoomTextStyles.bodySm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
