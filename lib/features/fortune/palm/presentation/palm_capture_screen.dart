import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_toast.dart';
import '../application/palm_provider.dart';

/// 03단계 §3.3 / 07단계 - PalmCaptureScreen (촬영/업로드 안내형 패턴)
///
/// 07단계(추가) §3.3 - 기존에는 버튼 클릭 시 바로 분석을 시작했으나,
/// "카메라로 촬영" / "갤러리에서 선택" 두 옵션으로 이미지를 먼저 선택하고,
/// 선택된 이미지를 미리보기(Image.memory)로 확인한 뒤 "분석 시작" 버튼으로
/// 넘어가는 2단계 플로우로 개편한다.
///
/// 07단계(추가, 수정2) §3.3 - camera 패키지(getUserMedia 기반 실시간 미리보기) 대신
/// image_picker의 ImageSource.camera(OS 네이티브 카메라 앱 호출)를 사용한다.
/// 이 방식은 모바일 브라우저(Chrome/삼성인터넷 등)에서 `<input capture>` 로 폴백되어
/// 훨씬 안정적으로 동작한다. 또한 dart:io File은 Flutter Web에서 지원되지 않으므로
/// [Uint8List] 기반으로 이미지를 다룬다.
class PalmCaptureScreen extends StatefulWidget {
  const PalmCaptureScreen({super.key});

  @override
  State<PalmCaptureScreen> createState() => _PalmCaptureScreenState();
}

class _PalmCaptureScreenState extends State<PalmCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      // 07단계(추가, 수정3) §3.3 - 일부 모바일 브라우저(안드로이드 WebView 계열)는
      // 파일 선택 취소(cancel) 이벤트가 제대로 발생하지 않아 Future가 영원히
      // 대기 상태로 멈추는 경우가 있다. 30초 타임아웃으로 버튼이 무한 로딩되는
      // 현상(사용자에게는 "아무 반응 없음"으로 보임)을 방지한다.
      final XFile? picked = await _picker
          .pickImage(source: source, imageQuality: 90, maxWidth: 1600)
          .timeout(const Duration(seconds: 30));
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      context.read<PalmProvider>().setSelectedImage(bytes);
    } catch (e) {
      if (!mounted) return;
      final isCamera = source == ImageSource.camera;
      // 07단계(추가, 수정3) §3.3 - 원인 파악을 위해 실제 예외 내용을 함께 노출한다.
      AppToast.show(
        context,
        isCamera
            ? '카메라를 사용할 수 없습니다 ($e)\n브라우저 앱의 카메라 권한을 확인하거나 갤러리에서 선택해주세요.'
            : '사진을 불러오지 못했습니다 ($e)',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _startAnalysis(BuildContext context) {
    context.read<PalmProvider>().analyze();
    Navigator.of(context).pushNamed('/ai-fortune/palm/analyzing');
  }

  @override
  Widget build(BuildContext context) {
    final selectedImageBytes = context.watch<PalmProvider>().selectedImageBytes;
    final hasImage = selectedImageBytes != null;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('AI 손금', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(UnifiedTokens.screenPadding),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              UnifiedTokens.radiusMd,
                            ),
                            child: Image.memory(
                              selectedImageBytes,
                              width: 220,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: UnifiedColors.cardAllMenu,
                            ),
                            child: Icon(
                              Icons.back_hand_rounded,
                              size: 96,
                              color: UnifiedColors.textPrimary,
                            ),
                          ),
                        SizedBox(height: UnifiedTokens.spaceXl),
                        Text(
                          hasImage
                              ? '이 사진으로 분석을 시작할까요?'
                              : '손바닥을 펴고\n밝은 곳에서 촬영해주세요',
                          style: UnifiedText.title(),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: UnifiedTokens.spaceSm),
                        if (!hasImage)
                          Text(
                            '사진을 선택해주세요',
                            style: UnifiedText.bodyStrong(
                              color: UnifiedColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        SizedBox(height: UnifiedTokens.spaceXs),
                        Text(
                          '촬영한 사진은 분석 즉시 파기되며 저장되지 않습니다',
                          style: UnifiedText.caption(
                            color: UnifiedColors.textCaption,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (hasImage) ...[
                          SizedBox(height: UnifiedTokens.spaceMd),
                          TextButton.icon(
                            onPressed: () => context
                                .read<PalmProvider>()
                                .clearSelectedImage(),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('다시 선택하기'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (hasImage)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startAnalysis(context),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('분석 시작'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPicking
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('갤러리에서 선택'),
                      ),
                    ),
                    SizedBox(width: UnifiedTokens.spaceMd),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPicking
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('카메라로 촬영'),
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
