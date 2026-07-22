import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../application/face_provider.dart';

/// 03단계 §3.3 / 07단계 - FaceCaptureScreen (촬영/업로드 안내형 패턴)
/// 10단계(A안) Mock: 실제 카메라 연동 없이 촬영 가이드 + 분석 시작 버튼으로 구성
/// (09단계 §7 개인정보보호 원칙: 이미지는 분석 즉시 파기되며 서버에 저장되지 않음을 안내)
class FaceCaptureScreen extends StatelessWidget {
  const FaceCaptureScreen({super.key});

  void _startAnalysis(BuildContext context) {
    context.read<FaceProvider>().analyze();
    Navigator.of(context).pushNamed('/ai-fortune/face/analyzing');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 관상')),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          color: AppColors.primaryContainer,
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 96,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '정면을 바라보고\n밝은 곳에서 촬영해주세요',
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
