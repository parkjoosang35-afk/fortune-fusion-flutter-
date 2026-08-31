import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../sintong/theme/sintong_colors.dart';
import '../../sintong/theme/sintong_typography.dart';
import '../../sintong/widgets/bangtong_coach_card.dart';
import '../../sintong/widgets/palm_sigil.dart';
import '../../sintong/widgets/palm_silhouette.dart';
import '../../sintong/widgets/sintong_button.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../application/palm_provider.dart';
import '../domain/palm_model.dart';

/// [관상·손금 신통방통 "새벽 한지" 리스킨] AI 손금 인트로/촬영 화면.
///
/// 기존 로직(image_picker 기반 2단계 플로우: 사진 선택 → 미리보기 →
/// "분석 시작" 버튼 → PalmProvider.analyze() → analyzing 라우트 이동)은
/// 전혀 변경하지 않는다. 위젯 트리와 색상/타이포/모티프만 핸드오프의
/// PalmIntroScreen 디자인(Dawn Hanji 그라디언트 + 방통선녀 코칭 카드 +
/// 손금 마법진/실루엣)으로 교체한다.
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
    final palmProvider = context.watch<PalmProvider>();
    final selectedImageBytes = palmProvider.selectedImageBytes;
    final hasImage = selectedImageBytes != null;
    final handSide = palmProvider.handSide;

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
                    title: '手紋 · INTRO · 07',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 8),
                  Text('STEP 01 / 03', style: SintongType.eyebrow),
                  const SizedBox(height: 8),
                  Text(
                    hasImage ? '이 손금으로 / 들여다볼까요' : '손바닥을 / 펼쳐주세요',
                    style: SintongType.displayLg,
                  ),
                  const SizedBox(height: 14),

                  BangtongCoachCard(
                    message: hasImage
                        ? '결이 잘 보여요.\n이대로 분석을 시작해볼게요.'
                        : '${handSide == PalmHandSide.right ? '오른손' : '왼손'}바닥에 네 갈래 길이 흘러요.\n결이 잘 보이게 펼쳐 주세요.',
                  ),
                  const SizedBox(height: 14),

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
                                          .read<PalmProvider>()
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
                                    child: PalmSigil(size: 240, opacity: 0.55),
                                  ),
                                  const PalmSilhouette(
                                    size: 140,
                                    showLines: true,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // [신통방통 리스킨] 손 선택 토글 — 분석 전에만 변경 가능
                  if (!hasImage) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _HandToggle(
                            label: '오른손',
                            sub: '현재 · 후천',
                            selected: handSide == PalmHandSide.right,
                            onTap: () => context
                                .read<PalmProvider>()
                                .setHandSide(PalmHandSide.right),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HandToggle(
                            label: '왼손',
                            sub: '과거 · 선천',
                            selected: handSide == PalmHandSide.left,
                            onTap: () => context
                                .read<PalmProvider>()
                                .setHandSide(PalmHandSide.left),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

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

/// [신통방통 리스킨] 왼손/오른손 선택 토글 칩.
class _HandToggle extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _HandToggle({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? SintongColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? SintongColors.accent : SintongColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              selected ? '◉' : '○',
              style: TextStyle(
                fontSize: 16,
                color: selected ? SintongColors.accent : SintongColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SintongType.cardTitle),
                Text(sub, style: SintongType.caption.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
