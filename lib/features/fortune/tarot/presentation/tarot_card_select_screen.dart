import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/tarot_audio_controller.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import 'oz/oz_theme.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_face_down_card.dart';
import 'oz/widgets/oz_primary_button.dart';
import 'oz/widgets/oz_topbar.dart';

/// [타로 오즈 리스킨 · 화면05 DRAW] 카드 선택 화면.
///
/// 순수 리스킨: [TarotSessionController] 상태머신 연동 로직
/// ([_startShuffle], [_onRevealPressed], [_statusCopy], `_shuffleController`
/// 타이밍 1200ms)은 그대로 유지하고, 위젯 트리만 오즈 스타일로 교체한다.
class TarotCardSelectScreen extends StatefulWidget {
  const TarotCardSelectScreen({super.key});

  @override
  State<TarotCardSelectScreen> createState() => _TarotCardSelectScreenState();
}

class _TarotCardSelectScreenState extends State<TarotCardSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shuffleController;
  bool _navigatedToLoading = false;

  @override
  void initState() {
    super.initState();
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startShuffle());
  }

  void _startShuffle() {
    final controller = context.read<TarotSessionController>();
    if (controller.state.status == TarotSessionStatus.questionReady) {
      controller.beginShuffle();
      context.read<TarotAudioController>().playShuffle();
      _shuffleController.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        controller.shuffleFinished();
      });
    }
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    super.dispose();
  }

  Future<void> _onRevealPressed() async {
    final session = context.read<TarotSessionController>();
    final tarotProvider = context.read<TarotProvider>();
    await session.reveal(tarotProvider);
    if (!mounted) return;
    if (session.state.status == TarotSessionStatus.resultReady &&
        !_navigatedToLoading) {
      _navigatedToLoading = true;
      Navigator.of(context).pushReplacementNamed('/ai-fortune/tarot/loading');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TarotSessionController>();
    final state = session.state;

    return Scaffold(
      backgroundColor: OzColors.bgDeep,
      body: Stack(
        children: [
          const OzBackground(),
          SafeArea(
            child: Column(
              children: [
                OzTopbar(
                  title: state.category?.label ?? '카드를 골라주세요',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: OzTokens.spaceSm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OzTokens.spaceXl,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _statusEyebrow(state),
                        style: OzTypography.monoLabel(fontSize: 10, letterSpacing: 3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusCopy(state),
                        textAlign: TextAlign.center,
                        style: OzTypography.sectionTitle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: OzTokens.spaceLg),
                if (state.status == TarotSessionStatus.error)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OzTokens.spaceLg,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: OzColors.faint,
                            ),
                            const SizedBox(height: OzTokens.spaceMd),
                            Text(
                              state.errorMessage ?? '타로 리딩에 실패했습니다.',
                              textAlign: TextAlign.center,
                              style: OzTypography.body(),
                            ),
                            const SizedBox(height: OzTokens.spaceLg),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: OzColors.gold,
                                side: BorderSide(color: OzColors.gold.withValues(alpha: 0.6)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    OzTokens.radiusPill,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: OzTokens.spaceXl,
                                  vertical: OzTokens.spaceSm,
                                ),
                              ),
                              onPressed: () {
                                context
                                    .read<TarotSessionController>()
                                    .retryReveal(
                                      context.read<TarotProvider>(),
                                    );
                              },
                              child: const Text('다시 시도하기'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 30,
                          child: IgnorePointer(
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    OzColors.gold.withValues(alpha: 0.14),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: state.status == TarotSessionStatus.shuffling
                              ? AnimatedBuilder(
                                  animation: _shuffleController,
                                  builder: (context, _) => _ShuffleFan(
                                    progress: _shuffleController.value,
                                  ),
                                )
                              : _SelectableFan(
                                  slots: state.deckSlots,
                                  requiredCount: state.requiredCardCount,
                                  interactive:
                                      state.status ==
                                      TarotSessionStatus.selectingCards,
                                  onSlotTap: (index) {
                                    context
                                        .read<TarotAudioController>()
                                        .playCardTap();
                                    context
                                        .read<TarotSessionController>()
                                        .selectSlot(index);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                if (state.status != TarotSessionStatus.error) ...[
                  if (state.status == TarotSessionStatus.selectingCards ||
                      state.status == TarotSessionStatus.cardsChosen)
                    _DrawCounter(
                      selected: state.selectedSlotIndexes.length,
                      required: state.requiredCardCount,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      OzTokens.spaceLg,
                      OzTokens.spaceMd,
                      OzTokens.spaceLg,
                      OzTokens.spaceXl,
                    ),
                    child: OzPrimaryButton(
                      label: state.status == TarotSessionStatus.cardsChosen
                          ? '카드 펼쳐보기'
                          : '${state.selectedSlotIndexes.length}/${state.requiredCardCount}장 선택 중...',
                      loading: state.status == TarotSessionStatus.revealing,
                      onPressed:
                          state.status == TarotSessionStatus.cardsChosen
                          ? _onRevealPressed
                          : null,
                      trailingIcon: state.status == TarotSessionStatus.cardsChosen
                          ? Icons.auto_awesome_rounded
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusEyebrow(TarotSessionState state) {
    switch (state.status) {
      case TarotSessionStatus.shuffling:
        return 'SHUFFLING';
      case TarotSessionStatus.selectingCards:
        return 'CHOOSE YOUR CARDS';
      case TarotSessionStatus.cardsChosen:
        return 'READY';
      case TarotSessionStatus.revealing:
        return 'REVEALING';
      case TarotSessionStatus.error:
        return 'OOPS';
      default:
        return 'PREPARING';
    }
  }

  String _statusCopy(TarotSessionState state) {
    switch (state.status) {
      case TarotSessionStatus.shuffling:
        return '카드를 섞고 있어요...';
      case TarotSessionStatus.selectingCards:
        return '마음이 이끄는 카드 ${state.requiredCardCount}장을 골라주세요';
      case TarotSessionStatus.cardsChosen:
        return '카드를 모두 골랐어요. 준비되면 펼쳐보세요';
      case TarotSessionStatus.revealing:
        return '카드의 기운을 읽는 중...';
      case TarotSessionStatus.error:
        return '앗, 잠시 문제가 생겼어요';
      default:
        return '카드를 준비하고 있어요...';
    }
  }
}

/// 셔플 중(부채꼴 카드 뒷면이 흔들리며 뒤섞이는 느낌).
class _ShuffleFan extends StatelessWidget {
  final double progress;
  const _ShuffleFan({required this.progress});

  @override
  Widget build(BuildContext context) {
    const count = 7;
    final wobble = sin(progress * pi * 6) * (1 - progress);
    return SizedBox(
      width: 280,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final angle = (i - count / 2) * 0.12 + wobble * 0.15;
          final dx = (i - count / 2) * 15.0 * (1 + wobble.abs() * 0.4);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(
              angle: angle,
              child: const OzFaceDownCard(width: 78, height: 118),
            ),
          );
        }),
      ),
    );
  }
}

/// 카드 탭 대기/선택 완료 상태 - 선택된 슬롯은 위로 떠오르고 골드 글로우.
class _SelectableFan extends StatelessWidget {
  final List<TarotFaceDownSlot> slots;
  final int requiredCount;
  final bool interactive;
  final ValueChanged<int> onSlotTap;
  const _SelectableFan({
    required this.slots,
    required this.requiredCount,
    required this.interactive,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();
    final count = slots.length;
    return SizedBox(
      width: double.infinity,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final slot = slots[i];
          final angle = (i - count / 2) * 0.11;
          final dx = (i - count / 2) * 21.0;
          final lift = slot.isSelected ? -18.0 : 0.0;
          return Transform.translate(
            offset: Offset(dx, lift),
            child: Transform.rotate(
              angle: angle,
              child: GestureDetector(
                onTap: interactive ? () => onSlotTap(slot.slotIndex) : null,
                child: OzFaceDownCard(
                  width: 74,
                  height: 112,
                  selected: slot.isSelected,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 하단 고정 카운터. CSS 대응: .oz-draw-counter / .oz-draw-counter-dots /
/// .oz-draw-dot.
class _DrawCounter extends StatelessWidget {
  final int selected;
  final int required;
  const _DrawCounter({required this.selected, required this.required});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: OzTokens.spaceSm),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: OzColors.bgDeep.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(OzTokens.radiusPill),
        border: Border.all(color: OzColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(required, (i) {
          final lit = i < selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lit ? OzColors.gold : OzColors.fg.withValues(alpha: 0.2),
                boxShadow: lit ? OzColors.goldGlow(alpha: 0.6, blur: 6) : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
