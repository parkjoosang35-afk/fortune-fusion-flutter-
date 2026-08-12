import 'package:flutter/material.dart';

import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';
import '../widgets/wish_room_pouch_widgets.dart';

/// 신통방통 소원방 · 조각 부족 안내 바텀시트
/// 출처: `handoff/ShortageDialog.jsx`
///
/// 절대 원칙 3 준수: 이 다이얼로그에는 어떤 형태의 결제/충전 버튼도 없다.
/// 오직 "복주머니 모으러 가기"(활동) / "지금 광고 하나 보고 오기"(광고)만 안내한다.
class WishRoomShortageDialog extends StatelessWidget {
  const WishRoomShortageDialog({
    super.key,
    required this.itemName,
    required this.itemIcon,
    required this.need,
    required this.have,
    this.onGoEarn,
    this.onWatchAd,
  });

  final String itemName;
  final Widget itemIcon;
  final int need;
  final int have;
  final VoidCallback? onGoEarn;
  final VoidCallback? onWatchAd;

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final short = (need - have).clamp(0, need);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WishRoomColors.sheetGradientTop,
            WishRoomColors.sheetGradientBottom,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: WishRoomColors.sheetBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: WishRoomColors.sheetBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEED MORE · 조각 부족',
                  style: WishRoomText.monoSm(palette.muted),
                ),
                WishRoomPouchIconButton(
                  icon: Icons.close,
                  palette: palette,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: palette.card,
                border: Border.all(color: palette.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0x663C2D5A),
                            border: Border.all(color: palette.line),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Opacity(opacity: 0.6, child: itemIcon),
                          ),
                        ),
                        Positioned(
                          bottom: -6,
                          right: -6,
                          child: Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: WishRoomColors.sheetGradientBottom,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.line),
                            ),
                            child: Text(
                              '♢',
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '담고 싶은 것',
                          style: WishRoomText.monoSm(palette.muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          itemName,
                          style: WishRoomText.h3(
                            palette.fg,
                          ).copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const WishRoomShard(size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '$need',
                              style: TextStyle(
                                fontFamily: WishRoomText.fontDisplay,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: palette.fg,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '필요',
                              style: WishRoomText.body(
                                palette.muted,
                              ).copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const WishRoomShard(size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '$have',
                    style: TextStyle(
                      fontFamily: WishRoomText.fontDisplay,
                      fontWeight: FontWeight.w700,
                      color: palette.fg,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '지금',
                    style: WishRoomText.body(
                      palette.muted,
                    ).copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '·',
                    style: TextStyle(
                      color: palette.muted.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const WishRoomShard(size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '$short',
                    style: TextStyle(
                      fontFamily: WishRoomText.fontDisplay,
                      fontWeight: FontWeight.w700,
                      color: palette.glow,
                      shadows: [
                        Shadow(color: palette.glowShadow, blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '더 담으면 돼요',
                    style: WishRoomText.body(
                      palette.muted,
                    ).copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: palette.line,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: WishRoomText.body(
                    palette.muted.withValues(alpha: 0.9),
                  ).copyWith(height: 1.75),
                  children: [
                    const TextSpan(text: '이 앱은 결제가 없어요.\n'),
                    const TextSpan(text: '오늘의 촛불을 밝히거나, 짧은 광고를 조용히 보시면\n'),
                    TextSpan(
                      text: '조각이 조금씩 담깁니다.',
                      style: TextStyle(color: palette.glow),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            WishRoomPouchButton(
              label: '❖  복주머니 모으러 가기',
              primary: true,
              palette: palette,
              expand: true,
              onPressed: () {
                Navigator.of(context).maybePop();
                onGoEarn?.call();
              },
            ),
            if (onWatchAd != null) ...[
              const SizedBox(height: 8),
              WishRoomPouchButton(
                label: '☾  지금 광고 하나 보고 오기',
                primary: false,
                palette: palette,
                expand: true,
                onPressed: () {
                  Navigator.of(context).maybePop();
                  onWatchAd?.call();
                },
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(
                '다음에 담을래요',
                style: WishRoomText.body(
                  palette.muted.withValues(alpha: 0.7),
                ).copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 조각 부족 바텀시트 표시 헬퍼.
Future<void> showWishRoomShortageDialog(
  BuildContext context, {
  required String itemName,
  required Widget itemIcon,
  required int need,
  required int have,
  VoidCallback? onGoEarn,
  VoidCallback? onWatchAd,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: WishRoomColors.backdropColor,
    builder: (ctx) => WishRoomShortageDialog(
      itemName: itemName,
      itemIcon: itemIcon,
      need: need,
      have: have,
      onGoEarn: onGoEarn,
      onWatchAd: onWatchAd,
    ),
  );
}
