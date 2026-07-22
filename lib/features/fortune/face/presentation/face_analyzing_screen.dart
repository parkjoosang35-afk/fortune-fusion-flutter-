import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../application/face_provider.dart';

/// 03단계 §3.3 / 07단계 - FaceAnalyzingScreen (연출용 로딩)
class FaceAnalyzingScreen extends StatefulWidget {
  const FaceAnalyzingScreen({super.key});

  @override
  State<FaceAnalyzingScreen> createState() => _FaceAnalyzingScreenState();
}

class _FaceAnalyzingScreenState extends State<FaceAnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;

  static const _messages = [
    '얼굴의 윤곽을 분석하고 있어요...',
    'AI가 부위별 특징을 읽고 있어요...',
    '관상 해석을 작성하고 있어요...',
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

  void _navigateOnResult(FaceProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess || provider.state.isError) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/face/result',
          arguments: provider.state.data?.id,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaceProvider>();
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
                  Icons.face_retouching_natural_rounded,
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
