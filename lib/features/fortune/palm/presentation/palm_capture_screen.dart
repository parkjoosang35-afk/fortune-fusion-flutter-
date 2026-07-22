import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../application/palm_provider.dart';

/// 03단계 §3.3 / 07단계 - PalmCaptureScreen (촬영/업로드 안내형 패턴)
class PalmCaptureScreen extends StatelessWidget {
  const PalmCaptureScreen({super.key});

  void _startAnalysis(BuildContext context) {
    context.read<PalmProvider>().analyze();
    Navigator.of(context).pushNamed('/ai-fortune/palm/analyzing');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 손금')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryContainer,
                        ),
                        child: const Icon(
                          Icons.back_hand_rounded,
                          size: 96,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '손바닥을 펴고\n밝은 곳에서 촬영해주세요',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '촬영한 사진은 분석 즉시 파기되며 저장되지 않습니다',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _startAnalysis(context),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('앨범에서 선택'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startAnalysis(context),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('촬영하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
