import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../pouch/wish_room_earn_moment_screen.dart';
import '../pouch/wish_room_gift_flow_screen.dart';

/// 04 · 소원 상세 (Wish Detail) — dev-spec §1 재제작 대상, JSX 미커업.
///
/// 촛불이 타는 모습(누적 밝힌 일수), 함께 빌기(1일 5회 한도), 복 나눔(조각 얹기,
/// [WishRoomGiftFlowScreen]으로 이동), 소원 이룸 표시(`markFulfilled`)를 제공한다.
/// 모두 기존 `WishRoomProvider`의 기존 메서드만 호출하며 신규 상태는 없다.
class WishRoomDetailScreen extends StatefulWidget {
  const WishRoomDetailScreen({super.key, required this.wishId});

  final String wishId;

  @override
  State<WishRoomDetailScreen> createState() => _WishRoomDetailScreenState();
}

class _WishRoomDetailScreenState extends State<WishRoomDetailScreen> {
  bool _busy = false;

  Future<void> _cheer(WishRoomProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await provider.earnCheer(widget.wishId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WishRoomEarnMomentScreen(result: result),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 함께 빌기는 다 채웠어요')));
    }
  }

  Future<void> _markFulfilled(WishRoomProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    await provider.markFulfilled(widget.wishId);
    if (!mounted) return;
    setState(() => _busy = false);
    final result = provider.lastEarnResult;
    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WishRoomEarnMomentScreen(result: result),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final wish = provider.findWish(widget.wishId);

    if (wish == null) {
      return WishRoomPouchBg(
        palette: palette,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Text(
                '이 소원은 더 이상 없어요',
                style: WishRoomText.body(palette.muted),
              ),
            ),
          ),
        ),
      );
    }

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(
                  size: 340,
                  color: palette.sigil,
                  opacity: 0.2,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(
                          text: 'WISH · 소원 상세',
                          palette: palette,
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: WishRoomCandle(
                              size: 84,
                              lit: !wish.isFulfilled,
                              melted: wish.isFulfilled
                                  ? 0
                                  : (wish.daysLit.clamp(0, 30) / 2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: WishRoomSeal(text: wish.seal, size: 48),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(color: palette.line),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '"${wish.text}"',
                                  style: WishRoomText.h2(
                                    palette.fg,
                                  ).copyWith(height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: List.generate(5, (i) {
                                    final on = i < wish.intensity;
                                    return Icon(
                                      on
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 16,
                                      color: on ? palette.glow : palette.muted,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  label: wish.isFulfilled ? '이루어짐' : '밝힌 지',
                                  value: wish.isFulfilled
                                      ? '成'
                                      : '${wish.daysLit}일',
                                  palette: palette,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  label: '함께 빌기',
                                  value: '${wish.cheersReceived}',
                                  palette: palette,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  label: '얹힌 조각',
                                  value: '${wish.shardsPledged}',
                                  palette: palette,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (!wish.isFulfilled) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: WishRoomPouchButton(
                                    label: '🕯 함께 빌기',
                                    primary: false,
                                    palette: palette,
                                    expand: true,
                                    onPressed: _busy
                                        ? null
                                        : () => _cheer(provider),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: WishRoomPouchButton(
                                    label: '❖ 복 나눔',
                                    primary: true,
                                    palette: palette,
                                    expand: true,
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => WishRoomGiftFlowScreen(
                                          targetWish: wish,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            WishRoomPouchButton(
                              label: '소원이 이루어졌어요',
                              primary: false,
                              palette: palette,
                              expand: true,
                              onPressed: _busy
                                  ? null
                                  : () => _markFulfilled(provider),
                            ),
                          ] else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: palette.line),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '이 소원은 이루어져 조용히 내려두었어요',
                                style: WishRoomText.body(
                                  palette.muted,
                                ).copyWith(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: WishRoomText.fontDisplay,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: palette.fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: WishRoomText.monoSm(palette.muted)),
        ],
      ),
    );
  }
}
