import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/tarot_audio_controller.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import 'theme/tarot_colors.dart';
import 'theme/tarot_perf_config.dart';
import 'theme/tarot_text_styles.dart';
import 'theme/tarot_theme_scope.dart';
import 'theme/tarot_tokens.dart';
import 'widgets/tarot_mystic_background.dart';

/// [타로 섹션 전면 개편 §2 정보구조 ⑤ / §7 P2] 카드 선택 화면(신규).
///
/// [TarotSessionController]의 상태머신을 그대로 UI로 옮긴 화면이다:
/// `questionReady`(진입 즉시 `beginShuffle()`) → `shuffling`(부채꼴 셔플
/// 연출, 약 1200ms) → `shuffleFinished()` → `selectingCards`(카드 뒷면
/// 탭 대기, `requiredCardCount`만큼) → 선택 완료 시 컨트롤러가 자동으로
/// `cardsChosen`으로 전이 → "펼쳐보기" CTA 노출 → 탭하면 `reveal()` 호출.
///
/// 실제 카드 정체(무슨 카드/정역방향)는 이 화면 어디에서도 다루지 않는다
/// (§10 설계 원칙) - [TarotFaceDownSlot]은 오직 "몇 번 슬롯이 선택됐는지"만
/// 안다. `reveal()`이 끝나 `resultReady`가 되면 기존 로딩 화면
/// (`/ai-fortune/tarot/loading`)으로 이동해, 로딩 화면의 "카드가 떠오르는"
/// 연출 + 결과화면의 리빌 연출로 자연스럽게 이어진다.
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
    // §10 상태 가드: questionReady일 때만 셔플을 시작한다. 뒤로가기 후
    // 재진입 등으로 이미 selectingCards/cardsChosen이면 셔플 연출을
    // 다시 재생하지 않고 바로 현재 상태를 그대로 보여준다.
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

    // [Revealing 전이] reveal() 호출 중(§6)에도 이 화면에 머물며 CTA를
    // 로딩 인디케이터로 바꾼다 - 로딩 화면 진입은 성공 시점에만 일어난다.
    return TarotThemeScope(
      child: Scaffold(
        backgroundColor: TarotColors.bgVoid,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            state.category?.label ?? '카드를 골라주세요',
            style: TarotTextStyles.screenTitle,
          ),
        ),
        body: Stack(
          children: [
            TarotMysticBackground(
              intensity: TarotPerfConfig.backgroundIntensity(0.7),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: TarotTokens.spaceMd),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TarotTokens.spaceLg,
                    ),
                    child: Text(
                      _statusCopy(state),
                      textAlign: TextAlign.center,
                      style: TarotTextStyles.body,
                    ),
                  ),
                  const SizedBox(height: TarotTokens.spaceLg),
                  // [버그 수정] reveal() API 호출이 실패하면 상태가 error로
                  // 바뀌는데, 기존에는 이 상태를 화면 어디에서도 처리하지
                  // 않아 상단 문구는 default로 떨어지고("카드를 준비하고
                  // 있어요...") 버튼은 disabled인 채 "n/n장 선택 중..."
                  // 텍스트에 멈춰버려 사용자가 재시도할 방법이 전혀 없는
                  // "먹통" 상태처럼 보였다. 명확한 에러 메시지 + 재시도
                  // 버튼을 노출해 흐름을 이어갈 수 있게 한다.
                  if (state.status == TarotSessionStatus.error)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TarotTokens.spaceLg,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 40,
                                color: TarotColors.textFaint,
                              ),
                              const SizedBox(height: TarotTokens.spaceMd),
                              Text(
                                state.errorMessage ?? '타로 리딩에 실패했습니다.',
                                textAlign: TextAlign.center,
                                style: TarotTextStyles.body,
                              ),
                              const SizedBox(height: TarotTokens.spaceLg),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: TarotColors.pinkGlow,
                                  side: BorderSide(color: TarotColors.pinkGlow),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      TarotTokens.radiusPill,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: TarotTokens.spaceXl,
                                    vertical: TarotTokens.spaceSm,
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
                      child: Center(
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
                    ),
                  // error 상태에서는 위쪽에 이미 "다시 시도하기" 버튼이
                  // 노출되므로, 하단 CTA는 숨겨 버튼이 중복되지 않게 한다.
                  if (state.status != TarotSessionStatus.error)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TarotTokens.spaceLg,
                        0,
                        TarotTokens.spaceLg,
                        TarotTokens.spaceXl,
                      ),
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                state.status == TarotSessionStatus.cardsChosen
                                ? TarotColors.pinkGlow
                                : TarotColors.surfaceCardStrong,
                            foregroundColor: TarotColors.bgVoid,
                            disabledBackgroundColor:
                                TarotColors.surfaceCardStrong,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                TarotTokens.radiusPill,
                              ),
                            ),
                          ),
                          onPressed:
                              state.status == TarotSessionStatus.cardsChosen
                              ? _onRevealPressed
                              : null,
                          child: state.status == TarotSessionStatus.revealing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: TarotColors.textPrimary,
                                  ),
                                )
                              : Text(
                                  state.status == TarotSessionStatus.cardsChosen
                                      ? '카드 펼쳐보기'
                                      : '${state.selectedSlotIndexes.length}/${state.requiredCardCount}장 선택 중...',
                                  style: TarotTextStyles.ctaLabel.copyWith(
                                    color:
                                        state.status ==
                                            TarotSessionStatus.cardsChosen
                                        ? TarotColors.bgVoid
                                        : TarotColors.textFaint,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

/// 셔플 중(§5) - 부채꼴로 놓인 카드 뒷면들이 짧게 흔들리며 뒤섞이는 느낌을
/// 준다. 실제로 슬롯을 재배열하지는 않고(신뢰감 있는 단순함), 회전/위치를
/// 미세하게 흔들어 "섞이는 느낌"만 연출한다.
class _ShuffleFan extends StatelessWidget {
  final double progress;
  const _ShuffleFan({required this.progress});

  @override
  Widget build(BuildContext context) {
    const count = 7;
    final wobble = sin(progress * pi * 6) * (1 - progress);
    return SizedBox(
      width: 260,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final angle = (i - count / 2) * 0.12 + wobble * 0.15;
          final dx = (i - count / 2) * 14.0 * (1 + wobble.abs() * 0.4);
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(
              angle: angle,
              child: const _FaceDownCard(width: 78, height: 118),
            ),
          );
        }),
      ),
    );
  }
}

/// 카드 탭 대기/선택 완료 상태(§5) - 선택된 슬롯은 살짝 위로 떠오르고
/// 글로우가 켜진다. [requiredCount]만큼 선택되면 컨트롤러가 자동으로
/// 더 이상의 탭을 막는다(상태 가드는 컨트롤러 쪽에 있으므로 이 위젯은
/// 순수하게 시각 표현만 담당).
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
          final dx = (i - count / 2) * 20.0;
          final lift = slot.isSelected ? -18.0 : 0.0;
          return Transform.translate(
            offset: Offset(dx, lift),
            child: Transform.rotate(
              angle: angle,
              child: GestureDetector(
                onTap: interactive ? () => onSlotTap(slot.slotIndex) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: slot.isSelected
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: TarotColors.pinkGlow.withValues(
                                alpha: 0.55,
                              ),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        )
                      : const BoxDecoration(),
                  child: _FaceDownCard(
                    width: 72,
                    height: 108,
                    highlighted: slot.isSelected,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FaceDownCard extends StatelessWidget {
  final double width;
  final double height;
  final bool highlighted;
  const _FaceDownCard({
    required this.width,
    required this.height,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: TarotColors.cardBackGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? TarotColors.pinkGlow
              : TarotColors.moonSilver.withValues(alpha: 0.5),
          width: highlighted ? 1.6 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: width * 0.62,
        height: height * 0.62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: TarotColors.moonSilver.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Text('✨', style: TextStyle(fontSize: width * 0.26)),
      ),
    );
  }
}
