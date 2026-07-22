import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../application/tarot_provider.dart';

/// 03단계 §3.3 / 07단계 - TarotLoadingScreen (연출용 로딩)
class TarotLoadingScreen extends StatefulWidget {
  const TarotLoadingScreen({super.key});

  @override
  State<TarotLoadingScreen> createState() => _TarotLoadingScreenState();
}

class _TarotLoadingScreenState extends State<TarotLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;

  static const _messages = [
    '카드를 섞고 있어요...',
    'AI가 카드의 의미를 해석하고 있어요...',
    '당신을 위한 메시지를 준비하고 있어요...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateOnResult(TarotProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/tarot/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TarotProvider>();
    _navigateOnResult(provider);

    final msgIndex = (DateTime.now().second ~/ 2) % _messages.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(_controller),
                child: const Icon(Icons.style_rounded, color: AppColors.secondary, size: 72),
              ),
              const SizedBox(height: 32),
              Text(
                _messages[msgIndex],
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
