import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_dialog.dart';
import '../../../pass/presentation/pass_gate_helper.dart';
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
                        style: OzTypography.monoLabel(
                          fontSize: 10,
                          letterSpacing: 3,
                        ),
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
                                side: BorderSide(
                                  color: OzColors.gold.withValues(alpha: 0.6),
                                ),
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
                                    .retryReveal(context.read<TarotProvider>());
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
                      onPressed: state.status == TarotSessionStatus.cardsChosen
                          ? _onRevealPressed
                          : null,
                      trailingIcon:
                          state.status == TarotSessionStatus.cardsChosen
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
///
/// [타로 78장 풀덱 진열 - 스크롤 제거] 기존에는 고정 높이(340px) 컨테이너 +
/// Wrap + SingleChildScrollView 조합으로 78장을 배치해, 실제로는 화면에
/// 45장 정도만 보이고 나머지는 스크롤해야 볼 수 있었다("78장이 한번에
/// 보인다"는 요구를 충족하지 못함). 이를 [LayoutBuilder]로 실제 가용
/// 영역(width x height)을 측정한 뒤, [_computeGrid]가 78장이 스크롤 없이
/// 전부 들어갈 수 있는 열(columns) 수와 카드 크기를 매 순간 계산해 [Stack]
/// + [Positioned]로 절대좌표 배치한다. 화면 크기가 달라져도 항상 78장
/// 전체가 한 화면에 보인다.
///
/// [한게임 포커 스타일 "카드 딜링" 연출] 단순히 제자리에서 페이드인/확대
/// 되는 연출은 사용자가 기대한 "카드섞기 후 카드가 78장이 1장씩 차례대로
/// 쫙 깔리는" 한게임 포커의 딜링 연출과 다르다. 이를 반영해 78장 전부가
/// 그리드 중앙(셔플 애니메이션이 있던 자리, 즉 "덱"이 놓인 자리)에서
/// 시작해, 인덱스 순서대로 아주 촘촘한 시차를 두고 각자의 최종 격자
/// 자리로 실제로 "이동"하며 날아가 앉는다. StatefulWidget으로 전환해
/// 위젯이 새로 mount될 때(셔플 종료 → selectingCards 전이로 이 위젯이
/// 새로 생성될 때) 딱 한 번 [_dealController]를 재생한다 - 탭
/// 상호작용/선택 상태(lift)에는 영향을 주지 않는 순수 시각 연출이다.
class _SelectableFan extends StatefulWidget {
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
  State<_SelectableFan> createState() => _SelectableFanState();
}

class _SelectableFanState extends State<_SelectableFan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dealController;

  // 카드 뒷면 이미지 기준 가로:세로 비율(38:58). 그리드 칸 크기를 계산할 때
  // 이 비율을 유지해 카드가 찌그러지지 않게 한다.
  static const double _cardAspect = 38 / 58;
  static const double _gridSpacing = 4.0;

  @override
  void initState() {
    super.initState();
    // [한게임 포커 딜링 타이밍] 78장이 한 장씩 순서대로 자리에 앉는 게
    // 눈에 보이려면 900ms로는 너무 짧다(사실상 동시에 나타나는 것처럼
    // 보임). 2400ms로 늘려 카드 사이의 시차가 실제로 인지되도록 한다.
    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _dealController.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// [maxWidth] x [maxHeight] 영역 안에 [count]장의 카드를 스크롤 없이
  /// 모두 배치할 수 있는 최적의 열(columns) 수와 카드 크기를 계산한다.
  /// 1~20열까지 브루트포스로 시도해, 카드 한 장의 크기가 최대가 되는
  /// 조합을 고른다 - 화면 크기가 달라져도 78장 전체가 항상 한 화면에
  /// 들어오게 하기 위함.
  ({int columns, int rows, double cardWidth, double cardHeight}) _computeGrid(
    double maxWidth,
    double maxHeight,
    int count,
  ) {
    int bestColumns = 1;
    double bestCardWidth = 0;
    for (int cols = 1; cols <= 20; cols++) {
      final rows = (count / cols).ceil();
      final cellWidth = (maxWidth - _gridSpacing * (cols - 1)) / cols;
      final cellHeight = (maxHeight - _gridSpacing * (rows - 1)) / rows;
      if (cellWidth <= 0 || cellHeight <= 0) continue;
      double cardWidth = cellWidth;
      double cardHeight = cardWidth / _cardAspect;
      if (cardHeight > cellHeight) {
        cardHeight = cellHeight;
        cardWidth = cardHeight * _cardAspect;
      }
      if (cardWidth > bestCardWidth) {
        bestCardWidth = cardWidth;
        bestColumns = cols;
      }
    }
    if (bestCardWidth <= 0) {
      // 극단적으로 작은 영역이 들어오는 예외 상황 대비 안전값.
      bestColumns = (sqrt(count.toDouble())).ceil().clamp(1, 20);
      bestCardWidth = 20;
    }
    final rows = (count / bestColumns).ceil();
    final cardHeight = bestCardWidth / _cardAspect;
    return (
      columns: bestColumns,
      rows: rows,
      cardWidth: bestCardWidth,
      cardHeight: cardHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.slots;
    if (slots.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 380.0;
        final grid = _computeGrid(maxWidth, maxHeight, slots.length);
        final gridWidth =
            grid.columns * grid.cardWidth +
            (grid.columns - 1) * _gridSpacing;
        final gridHeight =
            grid.rows * grid.cardHeight + (grid.rows - 1) * _gridSpacing;
        final offsetX = (maxWidth - gridWidth) / 2;
        final offsetY = (maxHeight - gridHeight) / 2;

        // [딜링 시작점] 셔플 애니메이션이 놓였던 화면 중앙 = "덱"이 있던
        // 자리. 78장 전부가 이 한 점에서 출발해 각자의 격자 자리로
        // 퍼져나가야 한게임 포커에서 카드를 돌리는 느낌이 난다.
        final sourceX = maxWidth / 2 - grid.cardWidth / 2;
        final sourceY = maxHeight / 2 - grid.cardHeight / 2;

        return SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(slots.length, (i) {
              final slot = slots[i];
              final row = i ~/ grid.columns;
              final col = i % grid.columns;
              final finalLeft = offsetX + col * (grid.cardWidth + _gridSpacing);
              final finalTop = offsetY + row * (grid.cardHeight + _gridSpacing);

              // 자리에 앉은 뒤에도 손으로 펼쳐놓은 듯한 아주 미세한 각도
              // (그리드가 촘촘하므로 옆 칸과 겹치지 않을 정도로만).
              final wobbleSeed = (i * 37) % 7 - 3;
              final finalAngle = wobbleSeed / 160;
              final lift = slot.isSelected ? -8.0 : 0.0;

              // [순서대로 한 장씩] 인덱스가 클수록 시작 시점을 아주
              // 조금씩 뒤로 미뤄, 78장이 "차례대로" 쫙 깔리는 웨이브를
              // 만든다. 각 카드의 비행 구간(0.16)은 서로 겹치도록 두어
              // 자연스러운 연속 딜링처럼 보이게 한다.
              final start = slots.length > 1
                  ? (i / (slots.length - 1) * 0.84).clamp(0.0, 0.84)
                  : 0.0;
              final dealAnim = CurvedAnimation(
                parent: _dealController,
                curve: Interval(
                  start,
                  (start + 0.16).clamp(0.0, 1.0),
                  curve: Curves.easeOutCubic,
                ),
              );

              final card = GestureDetector(
                onTap: widget.interactive
                    ? () => widget.onSlotTap(slot.slotIndex)
                    : null,
                child: OzFaceDownCard(
                  width: grid.cardWidth,
                  height: grid.cardHeight,
                  selected: slot.isSelected,
                ),
              );

              return AnimatedBuilder(
                animation: dealAnim,
                builder: (context, child) {
                  final t = dealAnim.value;
                  final left = _lerp(sourceX, finalLeft, t);
                  final top = _lerp(sourceY, finalTop, t) + lift * t;
                  // 날아가는 동안엔 덱과 같은 각도(0)에서 시작해 자기
                  // 자리의 미세한 wobble 각도로 안착한다.
                  final angle = _lerp(0, finalAngle, t);
                  // 덱에서 튀어나올 땐 살짝 크게(1.15) 보였다가 제자리에
                  // 앉으며 원래 크기(1.0)로 줄어드는 깊이감을 준다.
                  final scale = _lerp(1.15, 1.0, t);
                  return Positioned(
                    left: left,
                    top: top,
                    child: Transform.rotate(
                      angle: angle,
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: card,
              );
            }),
          ),
        );
      },
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
