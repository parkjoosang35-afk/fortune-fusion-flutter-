import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../application/palm_provider.dart';

class PalmAnalyzingScreen extends StatefulWidget {
  const PalmAnalyzingScreen({super.key});

  @override
  State<PalmAnalyzingScreen> createState() => _PalmAnalyzingScreenState();
}

class _PalmAnalyzingScreenState extends State<PalmAnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;

  static const _messages = [
    '손금의 선을 인식하고 있어요...',
    'AI가 주요 손금 라인을 분석하고 있어요...',
    '해석을 작성하고 있어요...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateOnResult(PalmProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/palm/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PalmProvider>();
    _navigateOnResult(provider);

    final msgIndex = (DateTime.now().second ~/ 2) % _messages.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mysticGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _controller,
                child: const Icon(
                  Icons.back_hand_rounded,
                  color: AppColors.secondary,
                  size: 72,
                ),
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
