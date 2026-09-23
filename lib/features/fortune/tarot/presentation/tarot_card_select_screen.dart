import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_dialog.dart';
import '../../../pass/presentation/pass_gate_helper.dart';
import '../application/tarot_audio_controller.dart';
import '../application/tarot_provider.dart';
import '../application/tarot_session_controller.dart';
import 'oz/oz_theme.dart';
import 'oz/tarot_spread_deck.dart';
import 'oz/widgets/oz_background.dart';
import 'oz/widgets/oz_card_peek_modal.dart';
import 'oz/widgets/oz_card_spread.dart';
import 'oz/widgets/oz_frame_divider.dart';
import 'oz/widgets/oz_mystic_orb_inline.dart';
import 'oz/widgets/oz_picked_slots.dart';
import 'oz/widgets/oz_primary_button.dart';
import 'oz/widgets/oz_reset_confirm_dialog.dart';
import 'oz/widgets/oz_tool_button.dart';
import 'oz/widgets/oz_topbar.dart';

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 카드 선택 화면.
///
/// `design_handoffs/tarot_picker/`(README + tarot-spec.md + TarotApp.jsx +
/// TarotCards.jsx)의 "Card Pick Screen" 공식 스펙을 이 화면에 매핑한다.
/// 레이아웃(7행×12열 그리드, 마지막 줄 6장 중앙정렬) · 컴포넌트 구성
/// (PickedSlots · Toolbar 3버튼 · FrameDivider ×2 · MysticOrbInline ·
/// CardPeekModal · ResetConfirmDialog) · 인터랙션 타이밍(뽑기 550ms 지연 +
/// 반짝임, 4단계 셔플 ~1.35s, 5장 완성 시 나머지 카드 20ms/장 시차 flip)을
/// 스펙 그대로 재현한다.
///
/// [핵심 원칙 - 절대 변경 금지] 실제로 "뽑힌" 5장의 정체는 이 화면이 결정
/// 하지 않는다. [TarotSessionController]가 관리하는 [TarotFaceDownSlot]은
/// 여전히 "선택 여부"만 담은 빈 슬롯이고, 서버가 [reveal] 단계에서 정/역
/// 방향과 실제 카드를 확정한다. 화면에 뒤집혀 보이는 나머지 73장의 이름/
/// 키워드([tarotSpreadDeck])는 순수 진열 장식이며, 사용자가 뽑은 5장은
/// 리딩을 시작하기 전까지 끝까지 뒷면으로 유지된다(스펙 §5.3 원칙).
class TarotCardSelectScreen extends StatefulWidget {
  const TarotCardSelectScreen({super.key});

  @override
  State<TarotCardSelectScreen> createState() => _TarotCardSelectScreenState();
}

class _TarotCardSelectScreenState extends State<TarotCardSelectScreen> {
  bool _navigatedToLoading = false;
  int _shuffleSignal = 0;
  bool _isShuffling = false;
  TarotSpreadCardMeta? _peekMeta;
  bool _showResetConfirm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startShuffle());
  }

  void _startShuffle() {
    final controller = context.read<TarotSessionController>();
    if (controller.state.status == TarotSessionStatus.questionReady) {
      controller.beginShuffle();
      context.read<TarotAudioController>().playShuffle();
      setState(() {
        _isShuffling = true;
        _shuffleSignal++;
      });
    }
  }

  /// [디자인 스펙 §5.5 4단계 셔플] 진열대 자체의 셔플 연출이 끝났을 때
  /// 호출된다. 최초 진입 시(`shuffling` 상태)에는 이 콜백이 곧
  /// [TarotSessionController.shuffleFinished]를 호출해 `selectingCards`
  /// 상태로 전이시킨다. 사용자가 "카드 섞기" 버튼을 눌러 재생하는 경우는
  /// 이미 `selectingCards`/`cardsChosen` 상태이므로 이 조건에 걸리지 않고
  /// 그냥 시각 효과로만 끝난다.
  void _onShuffleVisualComplete() {
    if (!mounted) return;
    setState(() => _isShuffling = false);
    final controller = context.read<TarotSessionController>();
    if (controller.state.status == TarotSessionStatus.shuffling) {
      controller.shuffleFinished();
    }
  }

  void _replaySuffleVisual() {
    context.read<TarotAudioController>().playShuffle();
    setState(() {
      _isShuffling = true;
      _shuffleSignal++;
    });
  }

  void _handlePick(int slotIndex) {
    context.read<TarotAudioController>().playCardTap();
    context.read<TarotSessionController>().selectSlot(slotIndex);
  }

  void _handlePeek(TarotSpreadCardMeta meta) {
    context.read<TarotAudioController>().playUiTap();
    setState(() => _peekMeta = meta);
  }

  void _handleUndo() {
    context.read<TarotAudioController>().playUiTap();
    context.read<TarotSessionController>().undoLastSelection();
  }

  void _handleResetConfirmed() {
    setState(() => _showResetConfirm = false);
    context.read<TarotSessionController>().resetSelection();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _replaySuffleVisual();
    });
  }

  Future<void> _onRevealPressed() async {
    final session = context.read<TarotSessionController>();
    final tarotProvider = context.read<TarotProvider>();
    context.read<TarotAudioController>().playRevealImpact();
    await session.reveal(tarotProvider);
    if (!mounted) return;
    if (session.state.status == TarotSessionStatus.resultReady &&
        !_navigatedToLoading) {
      _navigatedToLoading = true;
      Navigator.of(context).pushReplacementNamed('/ai-fortune/tarot/loading');
      return;
    }
    // [프리패스 카테고리 제한 안내 버그 수정] 카드를 다 고르고 실제 서버에
    // 요청을 보낸 이 시점에야 "오늘 이 프리패스로 이용할 수 있는 횟수를
    // 모두 사용했습니다" 같은 카테고리별 제한 초과가 확인되는 경우, 일반
    // 오류(OOPS) 전체화면 대신 다른 운세 카테고리와 동일한 안내
    // 다이얼로그([showCategoryLimitReachedSheet])를 보여주고 이전 화면으로
    // 돌아간다.
    final state = session.state;
    if (state.status == TarotSessionStatus.error &&
        state.errorReason == 'CATEGORY_LIMIT_REACHED') {
      final title = state.category?.label ?? '타로';
      await showCategoryLimitReachedSheet(
        context,
        categoryTitle: title,
        message: state.errorMessage,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    // [자유질문 무관 텍스트 리딩 생성 버그 수정] 서버가 질문 자체를 부적절하다고
    // 판단해 거부한 경우(INVALID_QUESTION)는 "다시 시도하기"로 같은 질문을
    // 재전송해도 계속 동일하게 거부된다(질문 내용 자체가 원인이므로). 따라서
    // 일반 오류(OOPS) 화면 대신 안내 다이얼로그를 보여준 뒤 질문 입력 화면으로
    // 돌아가 사용자가 질문을 고쳐 쓰도록 한다.
    if (state.status == TarotSessionStatus.error &&
        state.errorReason == 'INVALID_QUESTION') {
      await showAppInfoDialog(
        context,
        title: '질문을 다시 입력해주세요',
        message: state.errorMessage ?? '타로로 궁금한 내용을 질문해주세요.',
        confirmLabel: '질문 다시 쓰기',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TarotSessionController>();
    final audio = context.watch<TarotAudioController>();
    final state = session.state;
    final selected = state.selectedSlotIndexes.length;
    final required = state.requiredCardCount;
    final complete = state.status == TarotSessionStatus.cardsChosen;
    final canShowSpread = state.status != TarotSessionStatus.error;

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
                  actions: [
                    OzTopbarIconButton(
                      icon: audio.muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      tooltip: audio.muted ? '소리 켜기' : '소리 끄기',
                      onTap: () => audio.toggleMute(),
                    ),
                  ],
                ),
                if (state.status == TarotSessionStatus.error)
                  Expanded(child: _ErrorView(state: state))
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OzTokens.spaceXl,
                    ),
                    child: _TitleBlock(state: state),
                  ),
                  const SizedBox(height: OzTokens.spaceMd),
                  OzPickedSlots(count: selected, target: required),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 10, 36, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OzToolButton(
                            icon: Icons.shuffle_rounded,
                            label: '카드 섞기',
                            disabled:
                                _isShuffling ||
                                state.status ==
                                    TarotSessionStatus.revealing,
                            onTap: _replaySuffleVisual,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OzToolButton(
                            icon: Icons.restart_alt_rounded,
                            label: '다시 뽑기',
                            disabled: selected == 0 || _isShuffling,
                            onTap: () =>
                                setState(() => _showResetConfirm = true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OzToolButton(
                            icon: Icons.undo_rounded,
                            label: complete ? '다시 고르기' : '되돌리기',
                            disabled: selected == 0 || _isShuffling,
                            onTap: _handleUndo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canShowSpread)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            OzFrameDivider(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '78',
                                      style: TextStyle(
                                        color: OzColors.gold,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(text: ' CARDS '),
                                    TextSpan(
                                      text: '·',
                                      style: TextStyle(
                                        color: OzColors.goldDeep,
                                      ),
                                    ),
                                    const TextSpan(text: ' FULL DECK'),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontStyle: FontStyle.italic,
                                  color: OzColors.muted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: OzCardSpread(
                                slots: state.deckSlots,
                                canPick:
                                    state.status ==
                                        TarotSessionStatus.selectingCards &&
                                    !_isShuffling,
                                canPeek: complete,
                                onPick: _handlePick,
                                onPeek: _handlePeek,
                                shuffleSignal: _shuffleSignal,
                                onShuffleVisualComplete:
                                    _onShuffleVisualComplete,
                              ),
                            ),
                            OzFrameDivider(
                              child: OzMysticOrbInline(
                                pickedCount: selected,
                                target: required,
                                isShuffling: _isShuffling,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      OzTokens.spaceLg,
                      OzTokens.spaceSm,
                      OzTokens.spaceLg,
                      OzTokens.spaceXl,
                    ),
                    child: OzPrimaryButton(
                      label: complete
                          ? '리딩 시작하기'
                          : '${required - selected}장 더 골라주세요',
                      loading: state.status == TarotSessionStatus.revealing,
                      onPressed: complete ? _onRevealPressed : null,
                      trailingIcon: complete
                          ? Icons.auto_awesome_rounded
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_peekMeta != null)
            OzCardPeekModal(
              meta: _peekMeta!,
              onClose: () => setState(() => _peekMeta = null),
            ),
          if (_showResetConfirm)
            OzResetConfirmDialog(
              pickedCount: selected,
              onCancel: () => setState(() => _showResetConfirm = false),
              onConfirm: _handleResetConfirmed,
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final TarotSessionState state;
  const _ErrorView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OzTokens.spaceLg),
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
                  borderRadius: BorderRadius.circular(OzTokens.radiusPill),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: OzTokens.spaceXl,
                  vertical: OzTokens.spaceSm,
                ),
              ),
              onPressed: () {
                context.read<TarotSessionController>().retryReveal(
                  context.read<TarotProvider>(),
                );
              },
              child: const Text('다시 시도하기'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 안내 문구. `selectingCards`/`cardsChosen` 상태에서는 디자인
/// 핸드오프 §타이틀 블록의 "마음이 이끄는 카드 N장을 골라주세요" 2행
/// 타이틀(숫자만 골드 강조)을 그대로 재현하고, 그 외 상태(셔플 중/리빙 중
/// 등)에서는 기존 상태별 안내 문구를 유지한다.
class _TitleBlock extends StatelessWidget {
  final TarotSessionState state;
  const _TitleBlock({required this.state});

  static String _countWord(int n) {
    switch (n) {
      case 1:
        return '한 장';
      case 3:
        return '세 장';
      case 5:
        return '다섯 장';
      default:
        return '$n장';
    }
  }

  String _eyebrow() {
    switch (state.status) {
      case TarotSessionStatus.shuffling:
        return 'SHUFFLING';
      case TarotSessionStatus.selectingCards:
        return 'CHOOSE YOUR CARDS';
      case TarotSessionStatus.cardsChosen:
        return 'READY';
      case TarotSessionStatus.revealing:
        return 'REVEALING';
      default:
        return 'PREPARING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final eyebrow = _eyebrow();
    final isPickingStage =
        state.status == TarotSessionStatus.selectingCards ||
        state.status == TarotSessionStatus.cardsChosen;

    return Column(
      children: [
        Text(
          eyebrow,
          style: OzTypography.monoLabel(fontSize: 10, letterSpacing: 3),
        ),
        const SizedBox(height: 10),
        if (isPickingStage)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '마음이 이끄는 카드\n'),
                TextSpan(
                  text: _countWord(state.requiredCardCount),
                  style: TextStyle(color: OzColors.gold),
                ),
                const TextSpan(text: '을 골라주세요'),
              ],
            ),
            textAlign: TextAlign.center,
            style: OzTypography.sectionTitle(fontSize: 18),
          )
        else
          Text(
            state.status == TarotSessionStatus.shuffling
                ? '카드를 섞고 있어요...'
                : '카드의 기운을 읽는 중...',
            textAlign: TextAlign.center,
            style: OzTypography.sectionTitle(fontSize: 18),
          ),
      ],
    );
  }
}
