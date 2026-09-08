import 'package:flutter/material.dart';

import '../../wish_room/theme/wish_room_theme.dart';
import '../domain/shop_models.dart';

/// 상점 3화면(SealShop/CandleShop/TalismanShop) + 보물함이 공유하는 공용
/// 위젯 모음. `03-dev-spec.html`의 `SealShopScreen` 코드 스펙과
/// `new-screens.jsx`의 `ScreenSealShop`/`ScreenCandleShop`/`ScreenTreasureBox`
/// 픽셀-퍼펙트 디자인을 Flutter로 재구현한다. 색/타이포는 기존 소원방 V2
/// (Moonlit Crystal) 팔레트인 [WishRoomColors]/[WishRoomTextStyles]를 그대로
/// 사용해 시각적 통일성을 유지한다.

/// 상단 헤더: ← 뒤로가기 + 중앙 라벨(mono) + 우측 [사용법 안내 · 복주머니 잔액 칩].
///
/// [상점 사용법 안내 — 요청1] [guideType]을 지정하면 잔액 칩 왼쪽에 "?" 안내
/// 아이콘이 추가되어 [ShopGuideDialog]를 띄운다. 최초 방문 시 사용자가 헤매지
/// 않도록 언제든 다시 열어볼 수 있게 상시 노출한다.
class ShopHeader extends StatelessWidget {
  const ShopHeader({
    super.key,
    required this.title,
    required this.balance,
    this.guideType,
  });

  final String title;
  final int balance;
  final ShopGuideType? guideType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Text(title, style: WishRoomTextStyles.eyebrow),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (guideType != null) ...[
                _IconButton(
                  icon: Icons.help_outline,
                  onTap: () => ShopGuideDialog.show(context, guideType!),
                ),
                const SizedBox(width: 8),
              ],
              _PouchChip(balance: balance),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WishRoomColors.surfaceCard,
          border: Border.all(color: WishRoomColors.surfaceCardBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: WishRoomColors.textPrimary),
      ),
    );
  }
}

class _PouchChip extends StatelessWidget {
  const _PouchChip({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        border: Border.all(color: WishRoomColors.glow),
        borderRadius: BorderRadius.circular(17),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            '$balance',
            style: const TextStyle(
              fontFamily: 'IBMPlexMonoWish',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: WishRoomColors.glow,
            ),
          ),
        ],
      ),
    );
  }
}

/// 소개 문구 블록: 큰 타이틀(2줄 가능) + 부제.
class ShopIntro extends StatelessWidget {
  const ShopIntro({super.key, required this.title, required this.sub});

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: WishRoomTextStyles.screenTitle),
          const SizedBox(height: 6),
          Text(sub, style: WishRoomTextStyles.bodySm),
        ],
      ),
    );
  }
}

/// 하단 서브 네비게이션(인장/촛불/부적/보물함 4탭). [active]는 'seal' |
/// 'candle' | 'talisman' | 'treasure' 중 하나.
class ShopSubNav extends StatelessWidget {
  const ShopSubNav({super.key, required this.active});

  final String active;

  static const _tabs = [
    ('seal', '인장', '/shop/seals'),
    ('candle', '촛불', '/shop/candles'),
    ('talisman', '부적', '/shop/talismans'),
    ('treasure', '보물함', '/shop/treasure'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _tabs.map((tab) {
          final isActive = tab.$1 == active;
          return InkWell(
            onTap: isActive
                ? null
                : () => Navigator.of(context).pushReplacementNamed(tab.$3),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                tab.$2,
                style: TextStyle(
                  fontFamily: 'GowunBatangWish',
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? WishRoomColors.glow
                      : WishRoomColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 잔액 부족 다이얼로그. `03-dev-spec.html` 테스트 시나리오
/// "SealShop 잔액 부족 — ShortageDialog 렌더링"에 대응.
class ShortageDialog extends StatelessWidget {
  const ShortageDialog({
    super.key,
    required this.item,
    required this.need,
    required this.have,
  });

  final ShopCatalogItem item;
  final int need;
  final int have;

  static Future<void> show(
    BuildContext context, {
    required ShopCatalogItem item,
    required int need,
    required int have,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ShortageDialog(item: item, need: need, have: have),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WishRoomColors.backgroundSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: WishRoomColors.surfaceCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              '복주머니가 부족해요',
              style: WishRoomTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${item.nameKo}은(는) $need개가 필요해요.\n지금 잔액은 $have개예요.',
              style: WishRoomTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: WishRoomColors.glow,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1A3A),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구매 확인 바텀시트. 확인 시 true를 반환한다.
class PurchaseConfirmSheet extends StatelessWidget {
  const PurchaseConfirmSheet({super.key, required this.item});

  final ShopCatalogItem item;

  static Future<bool?> show(
    BuildContext context, {
    required ShopCatalogItem item,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseConfirmSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: WishRoomColors.backgroundSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: WishRoomColors.surfaceCardBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: WishRoomColors.surfaceCardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(item.nameKo, style: WishRoomTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text(
            item.descriptionKo,
            style: WishRoomTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: WishRoomColors.glowShadow,
              border: Border.all(color: WishRoomColors.glow),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '${item.price}',
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMonoWish',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: WishRoomColors.glow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: WishRoomColors.glow,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '구매하기',
                style: TextStyle(
                  fontFamily: 'GowunBatangWish',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF2A1A3A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: WishRoomTextStyles.bodySm.copyWith(
                  color: WishRoomColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 가격/보유 뱃지 — 그리드/리스트 타일 공용. owned면 "보유중", 구매중이면
/// 로딩 스피너, 아니면 가격 칩.
class ShopPriceBadge extends StatelessWidget {
  const ShopPriceBadge({
    super.key,
    required this.owned,
    required this.price,
    required this.isPurchasing,
    this.ownedLabel = 'OWNED',
  });

  final bool owned;
  final int price;
  final bool isPurchasing;
  final String ownedLabel;

  @override
  Widget build(BuildContext context) {
    if (isPurchasing) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: WishRoomColors.glow,
        ),
      );
    }
    if (owned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: WishRoomColors.surfaceCardBorder,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          ownedLabel,
          style: const TextStyle(
            fontFamily: 'IBMPlexMonoWish',
            fontSize: 10,
            letterSpacing: 1.5,
            color: WishRoomColors.textSecondary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: WishRoomColors.glowShadow,
        border: Border.all(color: WishRoomColors.glow),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            '$price',
            style: const TextStyle(
              fontFamily: 'IBMPlexMonoWish',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: WishRoomColors.glow,
            ),
          ),
        ],
      ),
    );
  }
}

/// 상점 사용법 안내 다이얼로그 — 요청1 "사용방법 안내창 추가".
///
/// 화면마다(인장/촛불/부적) 조금씩 다른 "어디에 쓰이는지"를 설명해야 하므로
/// [ShopGuideType]으로 화면별 문구를 분기한다. 공통 흐름(복주머니로 구매 →
/// 소원을 봉인/응원할 때 골라 쓰기)은 항상 같이 보여준다.
enum ShopGuideType { seal, candle, talisman, treasure }

class _ShopGuideStep {
  const _ShopGuideStep(this.emoji, this.title, this.body);
  final String emoji;
  final String title;
  final String body;
}

class ShopGuideDialog extends StatelessWidget {
  const ShopGuideDialog({super.key, required this.type});

  final ShopGuideType type;

  static Future<void> show(BuildContext context, ShopGuideType type) {
    return showDialog<void>(
      context: context,
      builder: (_) => ShopGuideDialog(type: type),
    );
  }

  ({String headline, List<_ShopGuideStep> steps}) get _content {
    switch (type) {
      case ShopGuideType.seal:
        return (
          headline: '인장은 이렇게 사용해요',
          steps: const [
            _ShopGuideStep(
              '🎁',
              '1. 복주머니로 구매하기',
              '응원·소원 작성 등으로 모은 복주머니로 원하는 인장을 구매해요.',
            ),
            _ShopGuideStep(
              '✒️',
              '2. 소원을 봉인할 때 선택하기',
              '소원을 쓸 때(소원 작성 화면) 보유한 인장 중 하나를 골라 소원을 봉인해요.',
            ),
            _ShopGuideStep(
              '⏳',
              '3. 정해진 기간만 보유돼요',
              '구매한 인장은 표시된 기간(예: 14일)이 지나면 만료돼요. 만료 후 같은 인장을 다시 구매할 수 있어요.',
            ),
          ],
        );
      case ShopGuideType.candle:
        return (
          headline: '촛불은 이렇게 사용해요',
          steps: const [
            _ShopGuideStep(
              '🎁',
              '1. 복주머니로 구매하기',
              '모은 복주머니로 원하는 촛불을 구매해요.',
            ),
            _ShopGuideStep(
              '🕯️',
              '2. 소원 하나에 하나씩 밝히기',
              '소원마다 촛불을 하나씩 골라 밝혀요. 같은 촛불도 여러 소원에 나눠 쓸 수 있어요.',
            ),
            _ShopGuideStep(
              '⏳',
              '3. 정해진 기간만 보유돼요',
              '구매한 촛불은 표시된 기간이 지나면 꺼져요(만료). 이후 다시 구매해 새로 밝힐 수 있어요.',
            ),
          ],
        );
      case ShopGuideType.talisman:
        return (
          headline: '부적은 이렇게 사용해요',
          steps: const [
            _ShopGuideStep(
              '🎁',
              '1. 복주머니로 구매하기',
              '모은 복주머니로 원하는 부적을 구매해요.',
            ),
            _ShopGuideStep(
              '🧿',
              '2. 소원에 부적의 기운 더하기',
              '보유한 부적을 소원에 적용해 표시된 기간 동안 특별한 기운을 더해요.',
            ),
            _ShopGuideStep(
              '⏳',
              '3. 정해진 기간만 효력이 지속돼요',
              '부적은 표시된 기간(예: 30일)이 지나면 효력이 끝나요. 이후 다시 구매할 수 있어요.',
            ),
          ],
        );
      case ShopGuideType.treasure:
        return (
          headline: '보물함은 이렇게 채워져요',
          steps: const [
            _ShopGuideStep(
              '🛍️',
              '1. 인장·촛불·부적 구매하기',
              '상점에서 구매한 품목이 모두 이 보물함에 모여요.',
            ),
            _ShopGuideStep(
              '◇',
              '2. 색이 채워진 칸 = 보유 중',
              '흐릿한 칸은 아직 구매하지 않은 품목, 색이 채워진 칸은 지금 보유 중인 품목이에요.',
            ),
            _ShopGuideStep(
              '⏳',
              '3. 기간이 지나면 다시 흐려져요',
              '보유 기간이 끝나면 다시 흐린 칸으로 돌아가요. 상점에서 다시 구매하면 채워져요.',
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    return Dialog(
      backgroundColor: WishRoomColors.backgroundSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: WishRoomColors.surfaceCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.headline,
              style: WishRoomTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ...content.steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontFamily: 'GowunBatangWish',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: WishRoomColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step.body,
                            style: WishRoomTextStyles.bodySm.copyWith(
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: WishRoomColors.glow,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '알겠어요',
                  style: TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1A3A),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
