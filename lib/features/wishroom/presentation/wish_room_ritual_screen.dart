import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../application/wish_room_provider.dart';
import '../domain/wish_room_model.dart';
import 'widgets/wish_room_flame_widget.dart';
import 'widgets/wish_room_reward_popup.dart';

/// [소원방 MVP §9 오늘의 치성 플로우] 오늘의 치성 진행 화면.
///
/// 권장 플로우(§9)를 그대로 따른다: 진입 시 부드러운 확대 등장(카메라가
/// 제단으로 다가가는 느낌의 대체 표현) → 안내 문구 → 촛불 터치 →
/// [WishRoomRewardConfig.requiredTapCount](5~7회 권장, MVP는 6회)회
/// 터치로 게이지 100% 도달 → 완료 연출 → 보상 팝업 → 메인 화면 복귀.
///
/// [사운드 관련 노트] §15는 "MVP에서는 BGM on/off 가능 구조만 열어두어도
/// 좋다"고 명시한다. 이 화면의 상단 음소거 아이콘은 그 "구조적 훅"만
/// 구현한 것으로, 실제 오디오 자산/재생 로직은 이번 MVP에 포함하지
/// 않는다(최종 보고에 명시적으로 disclosure).
class WishRoomRitualScreen extends StatefulWidget {
  const WishRoomRitualScreen({super.key});

  @override
  State<WishRoomRitualScreen> createState() => _WishRoomRitualScreenState();
}

class _WishRoomRitualScreenState extends State<WishRoomRitualScreen> {
  int _tapCount = 0;
  bool _completed = false;
  bool _bgmOn = true;

  int get _requiredTaps => WishRoomRewardConfig.requiredTapCount;
  double get _progress => (_tapCount / _requiredTaps).clamp(0.0, 1.0);

  void _handleFlameTap() {
    if (_completed) return;
    setState(() {
      _tapCount = (_tapCount + 1).clamp(0, _requiredTaps);
    });
    if (_tapCount >= _requiredTaps) {
      _handleRitualComplete();
    }
  }

  Future<void> _handleRitualComplete() async {
    setState(() => _completed = true);
    // 완료 연출(황금빛 확산)이 잠깐 보이도록 짧게 대기한 뒤 보상을
    // 적용한다 — §12 "연출은 짧고 품위 있게 마무리한다".
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final result = await context.read<WishRoomProvider>().applyRitualReward(
      tapCount: _tapCount,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WishRoomRewardPopup(result: result),
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _RitualHeader(
                  bgmOn: _bgmOn,
                  onToggleBgm: () => setState(() => _bgmOn = !_bgmOn),
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: FadeSlideIn(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _tapCount == 0
                              ? '촛불을 터치해 오늘의 정성을 전해보세요'
                              : '당신의 마음을 조용히 담아보세요',
                          style: UnifiedText.body(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: UnifiedTokens.spaceXxl),
                        GestureDetector(
                          onTap: _handleFlameTap,
                          child: WishRoomFlameWidget(
                            intensity: 0.32 + _progress * 0.68,
                            size: 168,
                          ),
                        ),
                        const SizedBox(height: UnifiedTokens.spaceXxl),
                        _TapDots(filled: _tapCount, total: _requiredTaps),
                        const SizedBox(height: UnifiedTokens.spaceSm),
                        Text(
                          '정성의 빛 ${(_progress * 100).toStringAsFixed(0)}%',
                          style: UnifiedText.caption(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 완료 시 화면 전체를 은은한 황금빛으로 감싸는 연출(§8/§12).
            // IgnorePointer라 터치를 가리지 않는다.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _completed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.1,
                      colors: [Color(0x33F3C988), Color(0x00F3C988)],
                    ),
                  ),
                ),
              ),
            ),
            if (_completed) const _CompletionSparkles(),
          ],
        ),
      ),
    );
  }
}

class _RitualHeader extends StatelessWidget {
  const _RitualHeader({
    required this.bgmOn,
    required this.onToggleBgm,
    required this.onClose,
  });

  final bool bgmOn;
  final VoidCallback onToggleBgm;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceMd,
        vertical: UnifiedTokens.spaceSm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: UnifiedColors.textPrimary),
            onPressed: onClose,
          ),
          const Spacer(),
          Text('오늘의 치성', style: UnifiedText.title()),
          const Spacer(),
          IconButton(
            icon: Icon(
              bgmOn ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              color: UnifiedColors.textSecondary,
            ),
            onPressed: onToggleBgm,
          ),
        ],
      ),
    );
  }
}

class _TapDots extends StatelessWidget {
  const _TapDots({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: isFilled ? 10 : 8,
            height: isFilled ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? UnifiedColors.textPrimary : UnifiedColors.border,
            ),
          ),
        );
      }),
    );
  }
}

/// [소원방 MVP §12] 치성 완료 시 "작은 꽃잎 2~3장 또는 별가루" 대신, 과한
/// 파티클 폭발 없이 아주 절제된 반짝임 2개만 잠깐 보여준다.
class _CompletionSparkles extends StatelessWidget {
  const _CompletionSparkles();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 140,
            left: 60,
            child: SparkleDot(size: 16, color: Color(0xFFE9C989)),
          ),
          Positioned(
            top: 180,
            right: 70,
            child: SparkleDot(size: 12, color: Color(0xFFD8CFF3)),
          ),
        ],
      ),
    );
  }
}
