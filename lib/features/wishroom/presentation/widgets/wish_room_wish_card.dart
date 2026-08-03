import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/fortune/primary_cta.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../application/wish_room_provider.dart';

/// [소원방 MVP §7 메인 화면 구조] "내 소원 문구 영역".
/// 소원게시판 본개발과는 무관한, 이 사람만 보는 개인 소원 한 줄이다.
class WishRoomWishCard extends StatelessWidget {
  const WishRoomWishCard({super.key, required this.wishText});

  final String wishText;

  @override
  Widget build(BuildContext context) {
    final hasWish = wishText.trim().isNotEmpty;

    return PremiumCard(
      backgroundColor: UnifiedColors.cardWish,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: () => _openEditor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: UnifiedTokens.iconMd,
                      color: UnifiedColors.textSecondary,
                    ),
                    const SizedBox(width: UnifiedTokens.spaceSm),
                    Text('내 소원', style: UnifiedText.title()),
                  ],
                ),
                const SizedBox(height: UnifiedTokens.spaceSm),
                Text(
                  hasWish ? wishText : '당신의 소원을 조용히 적어보세요',
                  style: hasWish
                      ? UnifiedText.body(color: UnifiedColors.textPrimary)
                      : UnifiedText.caption(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.edit_outlined,
            size: UnifiedTokens.iconSm,
            color: UnifiedColors.textCaption,
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final provider = context.read<WishRoomProvider>();
    final controller = TextEditingController(text: wishText);
    await showAppBottomSheet<void>(
      context,
      title: '소원 적기',
      child: _WishEditorBody(controller: controller, provider: provider),
    );
  }
}

class _WishEditorBody extends StatelessWidget {
  const _WishEditorBody({required this.controller, required this.provider});

  final TextEditingController controller;
  final WishRoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: UnifiedColors.bg,
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusSm),
            border: Border.all(color: UnifiedColors.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: UnifiedTokens.spaceMd,
            vertical: UnifiedTokens.spaceSm,
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 60,
            style: UnifiedText.body(color: UnifiedColors.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '이루고 싶은 마음을 조용히 적어보세요',
              hintStyle: UnifiedText.caption(),
              counterStyle: UnifiedText.caption(),
            ),
          ),
        ),
        const SizedBox(height: UnifiedTokens.spaceLg),
        PrimaryCTA(
          label: '저장하기',
          onPressed: () async {
            await provider.updateWishText(controller.text);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
