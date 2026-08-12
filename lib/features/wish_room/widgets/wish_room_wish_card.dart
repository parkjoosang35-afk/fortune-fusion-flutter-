import 'package:flutter/material.dart';

import '../domain/wish_room_models.dart';
import '../theme/wish_room_colors.dart';
import '../theme/wish_room_text_styles.dart';
import 'wish_room_sigils.dart';

/// 신통방통 소원방 · 소원 카드 (홈/피드 공용)
///
/// 재제작 화면(03 홈 · 05 피드)에서 공용으로 쓰는 신규 컴포넌트다.
/// JSX 미커업이 없는 화면이라 기존 어휘([WishRoomSeal]/텍스트 토큰)만으로
/// 새로 저작했다. `anonymous: true`면 지역/연령대를 상단에 노출해
/// 익명 피드 카드처럼 보이게 한다(dev-spec §5.1 Wish.region/ageGroup).
class WishRoomWishCard extends StatelessWidget {
  const WishRoomWishCard({
    super.key,
    required this.wish,
    required this.palette,
    this.onTap,
    this.trailing,
    this.anonymous = false,
  });

  final WishRoomWish wish;
  final WishRoomPaletteTokens palette;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WishRoomSeal(text: wish.seal, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (anonymous) ...[
                      Text(
                        '◇ ${wish.region ?? '어딘가'} · ${wish.ageGroup ?? '누군가'}',
                        style: WishRoomText.monoSm(palette.muted),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      '"${wish.text}"',
                      style: WishRoomText.h3(palette.fg).copyWith(height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 13,
                          color: wish.isFulfilled
                              ? palette.muted
                              : palette.glow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wish.isFulfilled ? '이루어짐' : '${wish.daysLit}일째 밝힘',
                          style: WishRoomText.monoSm(palette.muted),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '· 함께빌기 ${wish.cheersReceived}',
                          style: WishRoomText.monoSm(palette.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
