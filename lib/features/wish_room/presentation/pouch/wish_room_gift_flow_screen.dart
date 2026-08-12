import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../domain/wish_room_models.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import 'wish_room_earn_list_screen.dart';

/// 08. 복 나눔 · 조각 선물 — 출처: PouchScreens.jsx `ScreenGiftFlow`
///
/// [targetWish]가 주어지면 해당 소원에 조각을 얹고, 없으면 provider가 가진
/// 소원 중 첫 번째(없으면 예시 카드만 보여주고 담기 버튼은 비활성화)를 사용한다.
/// (모두의 소원 피드가 아직 재제작되지 않아 임시로 자기 소원 목록을 활용함)
///
/// [주의] dev-spec §4.3 트리거 매트릭스: 복 나눔의 조각 부족은 다른 상점과
/// 달리 **모달(ShortageDialog) 대신 인라인 에러 + "복주머니 모으러 가기"
/// 링크**로 처리해야 한다.
class WishRoomGiftFlowScreen extends StatefulWidget {
  const WishRoomGiftFlowScreen({super.key, this.targetWish});

  final WishRoomWish? targetWish;

  @override
  State<WishRoomGiftFlowScreen> createState() => _WishRoomGiftFlowScreenState();
}

class _WishRoomGiftFlowScreenState extends State<WishRoomGiftFlowScreen> {
  static const _amounts = [10, 30, 50, 100];
  int _selectedIndex = 1; // 기본 30
  final _messageCtrl = TextEditingController(text: '어머니께서 편안하시기를');
  String? _inlineError;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final provider = context.watch<WishRoomProvider>();
    final wish =
        widget.targetWish ??
        (provider.wishes.isNotEmpty ? provider.wishes.first : null);
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
                child: WishRoomSigil(
                  size: 340,
                  color: palette.sigil,
                  opacity: 0.22,
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
                          text: 'GIFT · 복 나눔',
                          palette: palette,
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          Text(
                            '누구의 소원에\n조각을 얹으시겠어요',
                            style: WishRoomText.h1(
                              palette.fg,
                            ).copyWith(fontSize: 22, height: 1.25),
                          ),
                          const SizedBox(height: 14),
                          _TargetWishCard(wish: wish, palette: palette),
                          const SizedBox(height: 18),
                          Text(
                            '얹을 조각',
                            style: WishRoomText.body(
                              palette.muted,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(_amounts.length, (i) {
                              final selected = i == _selectedIndex;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == _amounts.length - 1 ? 0 : 8,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _selectedIndex = i),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? palette.glowShadow
                                              : palette.card,
                                          border: Border.all(
                                            color: selected
                                                ? palette.glow
                                                : palette.line,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const WishRoomShard(size: 16),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_amounts[i]}',
                                              style: TextStyle(
                                                fontFamily:
                                                    WishRoomText.fontDisplay,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: selected
                                                    ? palette.glow
                                                    : palette.fg,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '짧은 마음 한 마디 (선택)',
                            style: WishRoomText.body(
                              palette.muted,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(color: palette.line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _messageCtrl,
                              maxLength: 60,
                              maxLines: 2,
                              style: WishRoomText.body(
                                palette.fg,
                              ).copyWith(fontSize: 13),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                counterText: '',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_inlineError != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _inlineError!,
                              style: WishRoomText.body(
                                palette.accent,
                              ).copyWith(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() => _inlineError = null);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const WishRoomEarnListScreen(),
                                ),
                              );
                            },
                            child: Text(
                              '복주머니 모으러 가기',
                              style: WishRoomText.body(palette.glow).copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    WishRoomPouchButton(
                      label: '❖ 조각 $amount개 얹기',
                      primary: true,
                      palette: palette,
                      expand: true,
                      onPressed: wish == null
                          ? null
                          : () => _handleGift(context, provider, wish, amount),
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

  Future<void> _handleGift(
    BuildContext context,
    WishRoomProvider provider,
    WishRoomWish wish,
    int amount,
  ) async {
    setState(() => _inlineError = null);
    try {
      await provider.giftShards(
        wishId: wish.id,
        amount: amount,
        message: _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
      );
      if (context.mounted) Navigator.of(context).maybePop();
    } on WishRoomShortageException catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineError = '조각이 ${e.need - e.have}개 모자라요';
      });
    }
  }
}

class _TargetWishCard extends StatelessWidget {
  const _TargetWishCard({required this.wish, required this.palette});

  final WishRoomWish? wish;
  final WishRoomPaletteTokens palette;

  @override
  Widget build(BuildContext context) {
    final region = wish?.region ?? '대구';
    final ageGroup = wish?.ageGroup ?? '20대';
    final text = wish?.text ?? '아직 소원방에 밝힌 소원이 없어요';
    final cheers = wish?.cheersReceived ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -18,
            right: -18,
            child: Opacity(
              opacity: 0.4,
              child: WishRoomSigil(
                size: 80,
                color: palette.sigil,
                opacity: 0.5,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '◇ $region · $ageGroup',
                style: WishRoomText.monoSm(palette.muted),
              ),
              const SizedBox(height: 6),
              Text(
                '"$text"',
                style: WishRoomText.h3(palette.fg).copyWith(height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                '🕯 $cheers명이 함께 빌었어요',
                style: WishRoomText.monoSm(palette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
