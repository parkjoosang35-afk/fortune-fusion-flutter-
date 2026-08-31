import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../sintong/theme/sintong_colors.dart';
import '../../sintong/theme/sintong_typography.dart';
import '../../sintong/widgets/bangtong_coach_card.dart';
import '../../sintong/widgets/face_sigil.dart';
import '../../sintong/widgets/face_silhouette.dart';
import '../../sintong/widgets/sintong_button.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../application/face_provider.dart';

/// [관상·손금 신통방통 "새벽 한지" 리스킨] AI 관상 인트로/촬영 화면.
///
/// 기존 로직(image_picker 기반 2단계 플로우: 사진 선택 → 미리보기 →
/// "분석 시작" 버튼 → FaceProvider.analyze() → analyzing 라우트 이동)은
/// 전혀 변경하지 않는다. 위젯 트리와 색상/타이포/모티프만 핸드오프의
/// FaceIntroScreen 디자인(Dawn Hanji 그라디언트 + 방통선녀 코칭 카드 +
/// 얼굴 마법진/실루엣 + 하자 스텝)으로 교체한다.
///
/// "촬영한 사진은 분석 즉시 파기되며 저장되지 않습니다" 개인정보 안내
/// 문구는 신뢰에 중요하므로 그대로 하단 캡션으로 유지한다.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      // 일부 모바일 브라우저(안드로이드 WebView 계열)는 파일 선택 취소(cancel)
      // 이벤트가 제대로 발생하지 않아 Future가 영원히 대기 상태로 멈추는
      // 경우가 있다. 30초 타임아웃으로 버튼이 무한 로딩되는 현상을 방지한다.
      final XFile? picked = await _picker
          .pickImage(source: source, imageQuality: 90, maxWidth: 1600)
          .timeout(const Duration(seconds: 30));
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      context.read<FaceProvider>().setSelectedImage(bytes);
    } catch (e) {
      if (!mounted) return;
      final isCamera = source == ImageSource.camera;
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
    context.read<FaceProvider>().analyze();
    Navigator.of(context).pushNamed('/ai-fortune/face/analyzing');
  }

  @override
  Widget build(BuildContext context) {
    final selectedImageBytes = context.watch<FaceProvider>().selectedImageBytes;
    final hasImage = selectedImageBytes != null;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SintongScreenBg()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopNav(
                    title: '觀相 · INTRO · 03',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  Text('STEP 01 / 03', style: SintongType.eyebrow),
                  const SizedBox(height: 8),
                  Text(
                    hasImage ? '이 얼굴로 / 들여다볼까요' : '얼굴을 / 보여주세요',
                    style: SintongType.displayLg,
                  ),
                  const SizedBox(height: 14),

                  BangtongCoachCard(
                    message: hasImage
                        ? '좋아요, 얼굴이 잘 보여요.\n이대로 분석을 시작해볼게요.'
                        : '천천히 정면을 바라봐 주세요.\n얼굴결이 잘 보이도록 도와드릴게요.',
                  ),
                  const SizedBox(height: 14),

                  // 가이드 영역 — 사진 없을 땐 마법진+실루엣, 있을 땐 실제 미리보기
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              SintongColors.glow.withValues(alpha: 0.08),
                              SintongColors.accent.withValues(alpha: 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SintongColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasImage
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    selectedImageBytes,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: _RetakeChip(
                                      onTap: () => context
                                          .read<FaceProvider>()
                                          .clearSelectedImage(),
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: 0.55,
                                    child: FaceSigil(size: 240, opacity: 0.55),
                                  ),
                                  const FaceSilhouette(
                                    size: 140,
                                    showLandmarks: true,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (!hasImage)
                    Column(
                      children: const [
                        _StepRow(num: '一', text: '밝은 곳에서 정면을 바라봐요'),
                        SizedBox(height: 8),
                        _StepRow(num: '二', text: '앞머리와 안경은 잠시 벗어주세요'),
                        SizedBox(height: 8),
                        _StepRow(num: '三', text: '표정은 자연스럽게 두어요'),
                      ],
                    ),

                  const SizedBox(height: 10),
                  Text(
                    '촬영한 사진은 분석 즉시 파기되며 저장되지 않습니다',
                    style: SintongType.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  if (hasImage)
                    SintongPrimaryButton(
                      label: '분석 시작하기',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: () => _startAnalysis(context),
                    )
                  else ...[
                    SintongPrimaryButton(
                      label: '촬영 시작하기',
                      icon: Icons.camera_alt_outlined,
                      onPressed: _isPicking
                          ? null
                          : () => _pickImage(ImageSource.camera),
                    ),
                    const SizedBox(height: 10),
                    SintongGhostButton(
                      label: '갤러리에서 불러오기',
                      icon: Icons.photo_library_outlined,
                      onPressed: _isPicking
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetakeChip extends StatelessWidget {
  final VoidCallback onTap;
  const _RetakeChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              '다시 선택',
              style: SintongType.monoSm.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  const _TopNav({required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _IconBtn(icon: Icons.arrow_back, onTap: onBack),
          Expanded(
            child: Center(child: Text(title, style: SintongType.monoSm)),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SintongColors.card,
          border: Border.all(color: SintongColors.line),
        ),
        child: Icon(icon, size: 16, color: SintongColors.fg),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String num;
  final String text;
  const _StepRow({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SintongColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SintongColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SintongColors.accent,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: TextStyle(
                fontFamily: SintongType.display,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: const Color(0xFFFFF9E8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: SintongType.bodySmall.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
