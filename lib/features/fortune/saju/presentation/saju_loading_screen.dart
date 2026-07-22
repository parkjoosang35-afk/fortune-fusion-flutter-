import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../application/saju_provider.dart';

/// 03단계 §3.3 / 07단계 - SajuLoadingScreen (연출용 로딩, 브랜드 경험)
class SajuLoadingScreen extends StatefulWidget {
  const SajuLoadingScreen({super.key});

  @override
  State<SajuLoadingScreen> createState() => _SajuLoadingScreenState();
}

class _SajuLoadingScreenState extends State<SajuLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;

  static const _messages = [
    '사주 명식을 계산하고 있어요...',
    'AI가 오행의 균형을 분석하고 있어요...',
    '주제별 해석을 작성하고 있어요...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateOnResult(SajuProvider provider) {
    if (_navigated) return;
    if (provider.state.isSuccess) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(
          '/ai-fortune/saju/result',
          arguments: provider.state.data!.id,
        );
      });
    } else if (provider.state.isError) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/ai-fortune/saju/result', arguments: null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuProvider>();
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
                child: const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 72),
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
