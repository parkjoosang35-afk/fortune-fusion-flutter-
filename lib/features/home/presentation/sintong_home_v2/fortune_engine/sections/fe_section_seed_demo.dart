// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_seed_demo.dart — 10.REPRODUCIBLE (시드 재현 카드뽑기,
// Y축 플립)
// 출처: design_files/engine-app.jsx SeedDemo().
// State: seed(String), cards(List<DrawnCard>?), flipped(bool),
// history(List, 최대6) — README "State Management" 표 5~8행.
//
// [데모 전용 — fe_tarot_seed.dart 참고] 실제 타로 서비스 결과와
// 무관한, 이 안내 화면만의 시드 재현 데모다.
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../fe_tarot_seed.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeSeedDemoSection extends StatefulWidget {
  const FeSeedDemoSection({super.key});
  @override
  State<FeSeedDemoSection> createState() => _FeSeedDemoSectionState();
}

class _FeSeedHistoryEntry {
  final String seed, key;
  const _FeSeedHistoryEntry(this.seed, this.key);
}

class _FeSeedDemoSectionState extends State<FeSeedDemoSection> {
  final _controller = TextEditingController(text: 'DEMO1');
  List<FeDrawnCard>? _cards;
  bool _flipped = false;
  final List<_FeSeedHistoryEntry> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final seed = _controller.text.trim().isEmpty
        ? '0'
        : _controller.text.trim();
    setState(() => _flipped = false);
    if (_cards != null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final drawn = feDrawThree(seed);
    setState(() {
      _cards = drawn;
      _history.insert(
        0,
        _FeSeedHistoryEntry(seed, drawn.map((c) => c.index).join('-')),
      );
      if (_history.length > 6) _history.removeRange(6, _history.length);
    });
    await Future.delayed(const Duration(milliseconds: 60));
    if (mounted) setState(() => _flipped = true);
  }

  @override
  Widget build(BuildContext context) {
    final last = _history.isNotEmpty ? _history.first : null;
    final prevSame = last == null
        ? null
        : _history
              .skip(1)
              .cast<_FeSeedHistoryEntry?>()
              .firstWhere((h) => h!.seed == last.seed, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FeSpace.screenH,
        FeSpace.sectionTop,
        FeSpace.screenH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FeReveal(
            child: FeSectionHead(
              hanja: '再現',
              mono: 'REPRODUCIBLE · 09',
              title: Text('같은 입력, 같은 시드라면\n언제나 같은 결과'),
              sub:
                  '무작위 추출이 들어가는 타로도 시드로 고정되어, 나중에 같은 리딩을 다시 검증할 수 있습니다. 같은 번호로 두 번 뽑아 보세요.',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontFamily: FeFonts.mono,
                      fontSize: 14,
                      letterSpacing: 1.5,
                      color: FeColors.fg,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: FeColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: FeColors.tarot),
                      ),
                    ),
                    onChanged: (v) {
                      final upper = v.toUpperCase();
                      if (upper != v) {
                        _controller.value = TextEditingValue(
                          text: upper,
                          selection: TextSelection.collapsed(
                            offset: upper.length,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FePrimaryButton('✦ 카드 뽑기', onTap: _run),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['過去', '現在', '未來'].asMap().entries.map((entry) {
              final k = entry.key;
              final p = entry.value;
              final card = _cards != null ? _cards![k] : null;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _FeFlipCard(
                    position: p,
                    card: card,
                    flipped: _flipped,
                    delay: Duration(milliseconds: (k * 180)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _cards == null
                  ? '78장 · 중복 없이 · 시드 고정'
                  : (prevSame != null
                        ? '시드 ${last!.seed} — 이전과 완전히 같은 세 장이 나왔어요'
                        : '시드 ${last!.seed} · 카드 번호 ${last.key}'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: FeColors.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeFlipCard extends StatefulWidget {
  final String position;
  final FeDrawnCard? card;
  final bool flipped;
  final Duration delay;
  const _FeFlipCard({
    required this.position,
    required this.card,
    required this.flipped,
    required this.delay,
  });
  @override
  State<_FeFlipCard> createState() => _FeFlipCardState();
}

class _FeFlipCardState extends State<_FeFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FeMotion.cardFlip,
  );

  @override
  void didUpdateWidget(covariant _FeFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flipped && !oldWidget.flipped) {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward(from: 0);
      });
    } else if (!widget.flipped && oldWidget.flipped) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final angle = _c.value * math.pi;
          final showFront = angle > math.pi / 2;
          final displayAngle = showFront ? angle - math.pi : angle;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(displayAngle),
            child: showFront ? _front() : _back(),
          );
        },
      ),
    );
  }

  Widget _back() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: FeColors.tarot.withValues(alpha: 0.35)),
      gradient: const RadialGradient(
        colors: [Color(0xFF3D3568), Color(0xFF1A0D2E)],
      ),
    ),
    alignment: Alignment.center,
    child: const FeSigil(
      size: 72,
      color: FeColors.tarot,
      opacity: 0.6,
      period: Duration(seconds: 90),
    ),
  );

  Widget _front() {
    final card = widget.card;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FeColors.tarot),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2050), Color(0xFF150C2C)],
        ),
        boxShadow: [
          BoxShadow(
            color: FeColors.tarot.withValues(alpha: 0.25),
            blurRadius: 22,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: card == null
          ? const SizedBox.shrink()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.position,
                  style: const TextStyle(
                    fontFamily: FeFonts.mono,
                    fontSize: 9,
                    letterSpacing: 2,
                    color: FeColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Transform.rotate(
                  angle: card.reversed ? math.pi : 0,
                  child: Text(
                    card.symbol,
                    style: TextStyle(
                      fontSize: 26,
                      color: FeColors.tarot,
                      shadows: [
                        Shadow(
                          color: FeColors.tarot.withValues(alpha: 0.6),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    card.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: FeFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  card.reversed ? '역방향' : '정방향',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: card.reversed ? FeColors.tense : FeColors.muted,
                  ),
                ),
              ],
            ),
    );
  }
}
