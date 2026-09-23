import 'dart:math';
import 'package:flutter/material.dart';

import '../../../application/tarot_session_controller.dart';
import '../../../domain/tarot_card_assets.dart';
import '../oz_theme.dart';
import '../tarot_spread_deck.dart';

/// 디자인 핸드오프(TarotApp.jsx `SpreadCard`/`CardSpread`)에서 그대로
/// 이식한 이징 곡선. Flutter의 [Cubic]은 y값이 1을 넘는 오버슈트도
/// 허용하므로 CSS cubic-bezier 값을 그대로 사용할 수 있다.
const Cubic _overshootCurve = Cubic(0.34, 1.56, 0.64, 1);

enum _ShufflePhase { gather, cross, restack }

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 78장 그리드 진열대.
///
/// CSS 대응: `<CardSpread>` + `<SpreadCard>`(TarotApp.jsx). 원본 스펙의
/// 고정 px 그리드(7행 × 12열, 26×39px 카드)를 [LayoutBuilder]로 측정한
/// 실제 가용 영역에 비례 스케일링해, 화면 크기가 달라져도 항상 스크롤
/// 없이 전부 들어오게 한다(Turn 1의 원 요구사항 "78장이 스크롤 없이 한
/// 화면에" 유지) - 스펙의 7×12 비율/간격 구조는 그대로 보존한다.
///
/// 카드 정체(진짜로 뽑힌 5장이 무엇인지)는 이 위젯이 절대 결정하지
/// 않는다. [slots]는 오직 "선택 여부"만 담은 [TarotFaceDownSlot] 목록이고,
/// 화면에 앞면으로 뒤집혀 보이는 이름/키워드는 [tarotSpreadDeck]의
/// 순수 장식용 레이블이다.
class OzCardSpread extends StatefulWidget {
  final List<TarotFaceDownSlot> slots;
  final bool canPick;
  final bool canPeek;
  final ValueChanged<int> onPick;
  final ValueChanged<TarotSpreadCardMeta> onPeek;
  final int shuffleSignal;
  final VoidCallback? onShuffleVisualComplete;

  const OzCardSpread({
    super.key,
    required this.slots,
    required this.canPick,
    required this.canPeek,
    required this.onPick,
    required this.onPeek,
    required this.shuffleSignal,
    this.onShuffleVisualComplete,
  });

  @override
  State<OzCardSpread> createState() => _OzCardSpreadState();
}

class _OzCardSpreadState extends State<OzCardSpread>
    with TickerProviderStateMixin {
  static const int _rows = 7;
  static const double _baseCardW = 26;
  static const double _baseCardH = 39;
  static const double _baseColGap = 2;
  static const double _baseRowGap = 42;

  late AnimationController _shuffleController;
  _ShufflePhase? _shufflePhase;
  int _appearGeneration = 0;
  bool _appeared = false;

  /// slotIndex → tarotSpreadDeck 인덱스. 셔플 버튼을 누르면 이 매핑만
  /// 뒤섞여 "겉보기 카드"가 바뀐 것처럼 보인다(순수 장식 효과).
  late List<int> _deckAssignment;

  int? _pickingSlotIndex;
  int? _lastUndoneSlotIndex;
  List<TarotFaceDownSlot> _prevSlots = const [];

  @override
  void initState() {
    super.initState();
    _deckAssignment = List.generate(78, (i) => i);
    _prevSlots = widget.slots;
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _appeared = true);
    });
  }

  @override
  void didUpdateWidget(OzCardSpread oldWidget) {
    super.didUpdateWidget(oldWidget);

    // [§5.4 되돌리기 감지] 선택→미선택으로 되돌아간 슬롯을 찾아 잠깐
    // 하이라이트를 준다(cardUndo 연출용).
    for (final slot in widget.slots) {
      final prev = _prevSlots.where((s) => s.slotIndex == slot.slotIndex);
      if (prev.isNotEmpty && prev.first.isSelected && !slot.isSelected) {
        _lastUndoingReset(slot.slotIndex);
      }
    }
    _prevSlots = widget.slots;

    if (widget.shuffleSignal != oldWidget.shuffleSignal) {
      _playShuffleVisual();
    }
  }

  void _lastUndoingReset(int slotIndex) {
    setState(() => _lastUndoneSlotIndex = slotIndex);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_lastUndoneSlotIndex == slotIndex) {
        setState(() => _lastUndoneSlotIndex = null);
      }
    });
  }

  void _playShuffleVisual() {
    setState(() => _shufflePhase = _ShufflePhase.gather);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _shufflePhase = _ShufflePhase.cross);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _shufflePhase = _ShufflePhase.restack);
    });
    Future.delayed(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      final rnd = Random();
      setState(() {
        _deckAssignment.shuffle(rnd);
        _appeared = false;
      });
    });
    Future.delayed(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      setState(() {
        _shufflePhase = null;
        _appeared = true;
        _appearGeneration++;
      });
      widget.onShuffleVisualComplete?.call();
    });
  }

  void _handleTapSlot(int slotIndex, TarotSpreadCardMeta meta) {
    if (_shufflePhase != null || _pickingSlotIndex != null) return;
    if (widget.canPeek) {
      widget.onPeek(meta);
      return;
    }
    if (!widget.canPick) return;
    setState(() => _pickingSlotIndex = slotIndex);
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      widget.onPick(slotIndex);
      setState(() => _pickingSlotIndex = null);
    });
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.slots.where((s) => !s.isSelected).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final total = visible.length;
    final perRow = (total / _rows).ceil().clamp(1, 78);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 340.0;
        final availH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 300.0;

        final baseStageW = perRow * _baseCardW + (perRow - 1) * _baseColGap;
        final baseStageH = (_rows - 1) * _baseRowGap + _baseCardH;

        final scale = min(availW / baseStageW, availH / baseStageH).clamp(
          0.1,
          3.0,
        );

        final cardW = _baseCardW * scale;
        final cardH = _baseCardH * scale;
        final colGap = _baseColGap * scale;
        final rowGap = _baseRowGap * scale;
        final stageW = perRow * cardW + (perRow - 1) * colGap;
        final stageH = (_rows - 1) * rowGap + cardH;

        // 각 줄로 분할.
        final rowsOfSlots = <List<TarotFaceDownSlot>>[];
        for (var r = 0; r < _rows; r++) {
          final start = r * perRow;
          if (start >= total) break;
          final end = min(start + perRow, total);
          rowsOfSlots.add(visible.sublist(start, end));
        }

        final tiles = <Widget>[];
        var globalIdx = 0;
        for (var rowIdx = 0; rowIdx < rowsOfSlots.length; rowIdx++) {
          final rowSlots = rowsOfSlots[rowIdx];
          final rowW = rowSlots.length * cardW + (rowSlots.length - 1) * colGap;
          final rowOffset = (stageW - rowW) / 2;
          for (var colIdx = 0; colIdx < rowSlots.length; colIdx++) {
            final slot = rowSlots[colIdx];
            final deckIdx = _deckAssignment[slot.slotIndex % 78] % 78;
            final meta = tarotSpreadDeck[deckIdx];
            final left = rowOffset + colIdx * (cardW + colGap);
            final top = rowIdx * rowGap;

            tiles.add(
              _OzSpreadTile(
                key: ValueKey('spread-slot-${slot.slotIndex}'),
                slotIndex: slot.slotIndex,
                meta: meta,
                left: left,
                top: top,
                width: cardW,
                height: cardH,
                rowIdx: rowIdx,
                rowGap: rowGap,
                appeared: _appeared,
                appearGeneration: _appearGeneration,
                appearIndex: globalIdx,
                shufflePhase: _shufflePhase,
                isPicking: _pickingSlotIndex == slot.slotIndex,
                isUndoing: _lastUndoneSlotIndex == slot.slotIndex,
                revealAll: widget.canPeek,
                revealDelayMs: widget.canPeek ? globalIdx * 20 : 0,
                interactive:
                    (widget.canPick || widget.canPeek) &&
                    _shufflePhase == null,
                onTap: () => _handleTapSlot(slot.slotIndex, meta),
              ),
            );
            globalIdx++;
          }
        }

        return Center(
          child: SizedBox(
            width: stageW,
            height: stageH,
            child: Stack(clipBehavior: Clip.none, children: tiles),
          ),
        );
      },
    );
  }
}

class _OzSpreadTile extends StatefulWidget {
  final int slotIndex;
  final TarotSpreadCardMeta meta;
  final double left;
  final double top;
  final double width;
  final double height;
  final int rowIdx;
  final double rowGap;
  final bool appeared;
  final int appearGeneration;
  final int appearIndex;
  final _ShufflePhase? shufflePhase;
  final bool isPicking;
  final bool isUndoing;
  final bool revealAll;
  final int revealDelayMs;
  final bool interactive;
  final VoidCallback onTap;

  const _OzSpreadTile({
    super.key,
    required this.slotIndex,
    required this.meta,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.rowIdx,
    required this.rowGap,
    required this.appeared,
    required this.appearGeneration,
    required this.appearIndex,
    required this.shufflePhase,
    required this.isPicking,
    required this.isUndoing,
    required this.revealAll,
    required this.revealDelayMs,
    required this.interactive,
    required this.onTap,
  });

  @override
  State<_OzSpreadTile> createState() => _OzSpreadTileState();
}

class _OzSpreadTileState extends State<_OzSpreadTile>
    with TickerProviderStateMixin {
  late AnimationController _appearController;
  late AnimationController _flipController;
  late final Random _rnd;
  int _lastAppearGen = -1;

  @override
  void initState() {
    super.initState();
    _rnd = Random(widget.slotIndex);
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: widget.revealAll ? 1 : 0,
    );
    _playAppear();
  }

  void _playAppear() {
    _lastAppearGen = widget.appearGeneration;
    if (!widget.appeared) return;
    final delay = min(widget.appearIndex * 15, 900);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _appearController.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_OzSpreadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appearGeneration != _lastAppearGen && widget.appeared) {
      _playAppear();
    }
    if (widget.revealAll != oldWidget.revealAll) {
      final delay = widget.revealAll ? widget.revealDelayMs : 0;
      final duration = widget.revealAll ? 700 : 400;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _flipController.duration = Duration(milliseconds: duration);
        if (widget.revealAll) {
          _flipController.forward();
        } else {
          _flipController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  /// 셔플 단계별 카드 하나의 오프셋(중심 기준 상대 이동).
  Offset _shuffleOffset() {
    final jitterX = (_rnd.nextDouble() - 0.5) * 8;
    final jitterY = (_rnd.nextDouble() - 0.5) * 6;
    final side = _rnd.nextBool() ? -1.0 : 1.0;
    final crossX = (_rnd.nextDouble() - 0.5) * 60;
    final crossY = (_rnd.nextDouble() - 0.5) * 40;
    switch (widget.shufflePhase) {
      case _ShufflePhase.gather:
        return Offset(jitterX, jitterY);
      case _ShufflePhase.cross:
        return Offset(side * (30 + crossX.abs() * 0.6), crossY * 0.5);
      case _ShufflePhase.restack:
        return Offset(jitterX * 0.5, jitterY * 0.5);
      case null:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShuffling = widget.shufflePhase != null;

    Widget card = AnimatedBuilder(
      animation: _flipController,
      builder: (context, _) {
        final angle = _flipController.value * pi; // 0..pi
        final showFront = angle > pi / 2;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _CardFace(
                    front: true,
                    meta: widget.meta,
                    width: widget.width,
                    height: widget.height,
                  ),
                )
              : _CardFace(
                  front: false,
                  meta: widget.meta,
                  width: widget.width,
                  height: widget.height,
                ),
        );
      },
    );

    card = GestureDetector(
      onTap: widget.interactive ? widget.onTap : null,
      child: card,
    );

    final content = AnimatedBuilder(
      animation: _appearController,
      builder: (context, child) {
        final appearT = widget.appeared
            ? _overshootCurve.transform(_appearController.value)
            : 0.0;
        final appearScale = widget.appeared ? lerpDouble(0.55, 1.0, appearT) : 0.55;
        final appearOpacity = widget.appeared
            ? Curves.easeOut.transform(_appearController.value)
            : 0.0;

        final shuffleOffset = _shuffleOffset();
        double dx = isShuffling ? shuffleOffset.dx : 0;
        double dy = isShuffling ? shuffleOffset.dy : 0;
        double scale = isShuffling
            ? (widget.shufflePhase == _ShufflePhase.cross ? 1.05 : 1.0)
            : 1.0;
        double opacity = appearOpacity;

        if (widget.isPicking) {
          dy -= widget.rowGap + 30;
          scale = 1.4;
          opacity = 0.0;
        }

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: (scale * appearScale), child: child),
          ),
        );
      },
      child: card,
    );

    return AnimatedPositioned(
      key: ValueKey('pos-${widget.slotIndex}'),
      duration: const Duration(milliseconds: 320),
      curve: _overshootCurve,
      left: widget.left,
      top: widget.top,
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          if (widget.isUndoing)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: OzColors.gold.withValues(alpha: 0.7),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.isPicking) ...[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: OzColors.gold.withValues(alpha: 0.9),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ..._sparkles(),
          ],
        ],
      ),
    );
  }

  List<Widget> _sparkles() {
    return List.generate(6, (i) {
      final angle = i * pi / 3;
      return Positioned(
        left: widget.width / 2 - 1.5,
        top: widget.height / 2 - 1.5,
        child: _SparkleDot(angle: angle, delayMs: i * 50),
      );
    });
  }
}

class _SparkleDot extends StatefulWidget {
  final double angle;
  final int delayMs;
  const _SparkleDot({required this.angle, required this.delayMs});

  @override
  State<_SparkleDot> createState() => _SparkleDotState();
}

class _SparkleDotState extends State<_SparkleDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        final dist = 30.0 * t;
        final dx = cos(widget.angle) * dist;
        final dy = sin(widget.angle) * dist;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OzColors.gold,
                boxShadow: [
                  BoxShadow(color: OzColors.gold.withValues(alpha: 0.8), blurRadius: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 카드 뒷면/앞면 표시. 앞면은 실제 78장 webp 카드 아트를 그대로 재사용한다
/// (README "브랜드 문양만" 원칙 - 스톡 사진이 아닌 자체 제작 카드 아트이므로
/// 준수). 이 카드가 "진짜 뽑힌 카드"가 아니라 순수 진열 장식이라는 점은
/// [OzCardSpread] 클래스 문서 참고.
class _CardFace extends StatelessWidget {
  final bool front;
  final TarotSpreadCardMeta meta;
  final double width;
  final double height;
  const _CardFace({
    required this.front,
    required this.meta,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (!front) {
      return const OzFaceDownCardArt();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        color: const Color(0xFFF4ECD8),
        child: Image.asset(
          tarotCardImagePath(meta.name),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              meta.symbol,
              style: TextStyle(fontSize: height * 0.4, color: OzColors.goldDeep),
            ),
          ),
        ),
      ),
    );
  }
}

/// [OzFaceDownCard]와 동일한 뒷면 이미지를 테두리/글로우 없이(진열 타일
/// 안에서는 이미 부모가 테두리를 그리므로) 순수 이미지로만 노출.
class OzFaceDownCardArt extends StatelessWidget {
  const OzFaceDownCardArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OzColors.bgTop.withValues(alpha: 0.9), OzColors.bgMid],
        ),
        border: Border.all(color: OzColors.borderStrong, width: 0.6),
      ),
      alignment: Alignment.center,
      child: Text(
        '✨',
        style: TextStyle(fontSize: 8, color: OzColors.gold.withValues(alpha: 0.85)),
      ),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
