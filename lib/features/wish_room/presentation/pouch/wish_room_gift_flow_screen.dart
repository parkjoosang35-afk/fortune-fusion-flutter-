import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../wish_room_shortage_dialog.dart';

/// 13. 복 나눔 · 조각 선물 — 출처: PouchScreens.jsx `ScreenGiftFlow`
class WishRoomGiftFlowScreen extends StatefulWidget {
  const WishRoomGiftFlowScreen({super.key, required this.wish});

  final WishRoomWish wish;

  @override
  State<WishRoomGiftFlowScreen> createState() => _WishRoomGiftFlowScreenState();
}

class _WishRoomGiftFlowScreenState extends State<WishRoomGiftFlowScreen> {
  static const _amounts = [10, 30, 50, 100];
  int _selectedIndex = 1;
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final amount = _amounts[_selectedIndex];

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.5),
                child: WishRoomSigil(size: 340, color: palette.sigil, opacity: 0.22),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(text: 'GIFT · 복 나눔', palette: palette),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('누구의 소원에\n조각을 얹으시겠어요', style: WishRoomText.h1(palette.fg).copyWith(fontSize: 22)),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(color: palette.line),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '◇ ${widget.wish.region ?? '지역 비공개'} · ${widget.wish.ageGroup ?? ''}',
                                  style: WishRoomText.monoSm(palette.muted),
                                ),
                                const SizedBox(height: 6),
                                Text('"${widget.wish.text}"', style: WishRoomText.h3(palette.fg).copyWith(height: 1.5)),
                                const SizedBox(height: 8),
                                Text(
                                  '🕯 ${widget.wish.cheersReceived}명이 함께 빌었어요',
                                  style: WishRoomText.monoSm(palette.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('얹을 조각', style: WishRoomText.body(palette.muted).copyWith(fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(_amounts.length, (i) {
                              final selected = i == _selectedIndex;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: i == _amounts.length - 1 ? 0 : 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedIndex = i),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selected ? palette.glowShadow : palette.card,
                                        border: Border.all(color: selected ? palette.glow : palette.line),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const WishRoomShard(size: 16),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_amounts[i]}',
                                            style: TextStyle(
                                              fontFamily: WishRoomText.fontDisplay,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: selected ? palette.glow : palette.fg,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          Text('짧은 마음 한 마디 (선택)', style: WishRoomText.body(palette.muted).copyWith(fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(color: palette.line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _messageCtrl,
                              maxLines: 2,
                              style: WishRoomText.body(palette.fg).copyWith(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: '어머니께서 편안하시기를',
                                hintStyle: WishRoomText.body(palette.muted).copyWith(fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    WishRoomPouchButton(
                      label: '❖ 조각 $amount개 얹기',
                      primary: true,
                      palette: palette,
                      expand: true,
                      onPressed: () => _handleGift(context, provider, amount),
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

  Future<void> _handleGift(BuildContext context, WishRoomProvider provider, int amount) async {
    try {
      await provider.giftShards(
        wishId: widget.wish.id,
        amount: amount,
        message: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      );
      if (context.mounted) Navigator.of(context).maybePop();
    } on WishRoomShortageException catch (e) {
      if (!context.mounted) return;
      await showWishRoomShortageDialog(
        context,
        itemName: '조각 나눔',
        itemIcon: const Icon(Icons.favorite, size: 22),
        need: e.need,
        have: e.have,
        onGoEarn: () => Navigator.of(context).maybePop(),
        onWatchAd: () => Navigator.of(context).maybePop(),
      );
    }
  }
}
