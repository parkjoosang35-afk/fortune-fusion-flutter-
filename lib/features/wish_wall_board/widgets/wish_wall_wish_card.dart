import 'package:flutter/material.dart';

import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import 'wish_wall_seal.dart';

/// 소원 카드 — 옛 "신통방통 소원방"(wish_room) `WishRoomWishCard`를 이식.
///
/// [디자인 히스토리] 옛 소원방 홈/피드 화면은 이 카드로 소원 목록을 그렸다.
/// 병(Bottle) 대신 카테고리별 인장(Seal)을 좌측에 두고, 우측에 본문 3줄
/// 발췌 + "N일째 밝힘 · 응원 N" 통계를 배치하는 구조를 그대로 따른다.
/// [anonymous]가 true면 작성자 이름 대신 카테고리 라벨을 마스킹 표기해
/// 옛 피드 화면의 "익명 소원" 느낌을 살린다.
class WishWallWishCard extends StatelessWidget {
  const WishWallWishCard({
    super.key,
    required this.wish,
    this.onTap,
    this.anonymous = false,
  });

  final WishPost wish;
  final VoidCallback? onTap;
  final bool anonymous;

  int get _daysLit {
    final days = DateTime.now().difference(wish.createdAt).inDays;
    return days < 1 ? 1 : days;
  }

  @override
  Widget build(BuildContext context) {
    final showAnon = anonymous || wish.isAnonymous;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WishWallColors.bg2,
            border: Border.all(color: WishWallColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WishWallSeal(
                text: wish.categoryId.sealChar,
                color: wish.categoryId.lightColor,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showAnon) ...[
                      Text(
                        '◇ 익명 · ${wish.categoryId.label}',
                        style: WishWallText.mono(color: WishWallColors.muted),
                      ),
                      const SizedBox(height: 6),
                    ] else ...[
                      Text(
                        wish.displayName,
                        style: WishWallText.caption(
                          color: WishWallColors.accent2,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      '"${wish.text}"',
                      style: WishWallText.body().copyWith(height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 13,
                          color: wish.isGratitude
                              ? WishWallColors.muted
                              : WishWallColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wish.isGratitude ? '이루어짐' : '$_daysLit일째 밝힘',
                          style: WishWallText.caption(),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '· 응원 ${wish.supportCount}',
                          style: WishWallText.caption(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
