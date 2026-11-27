// [S5 복주머니 결제] 잔액 부족 바텀시트 — design_handoff_pouch_payment
// PayEntry.jsx `ShortageQuickSheet` 1:1 포팅. 기존 `ShortageDialog`(확인만
// 가능한 안내 전용 다이얼로그)를 대체해, 부족한 만큼 바로 담을 수 있는
// 추천 팩 3개 + "곳간 전체 보기" + "무료로 모으기(=기존 지갑시트)" 동선을
// 제공한다.
//
// [호출부 다형성] 기존 3개 상점 화면은 `ShopCatalogItem`을, pay_screen.dart는
// `PayOrder`를 각자의 모델로 들고 있어 하나의 타입으로 묶을 수 없으므로,
// 이 시트는 표시용 문자열(itemLabel)과 need/have 숫자만 받는 얇은
// 인터페이스로 설계했다 — 호출부가 늘어나도 이 시트를 고칠 필요가 없다.
//
// [테마] 상점 3화면과 동일한 WishRoomColors(소원방 V2 Moonlit Crystal)
// 팔레트를 그대로 사용해 시각적 통일성을 유지한다. pay_screen.dart(WrC/WrF
// 팔레트) 쪽 호출부는 이 시트 자체를 별도 Theme로 감싸 일관되게 보여준다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/legacy_wish_room/wish_room_theme.dart';
import '../application/pouch_pay_service.dart';
import '../domain/pouch_pay_catalog.dart';
import '../domain/pouch_pay_models.dart';
import 'pouch_checkout_screen.dart';
import 'pouch_store_screen.dart';

/// 어디서든 동일하게 호출하는 잔액 부족 시트 오프너.
/// [onCollectFree]가 주어지면 "무료로 모으기" 버튼이 그 콜백을 호출한다
/// (기존 지갑시트 openWalletSheet 등). 없으면 시트만 닫는다.
Future<void> openShortageQuickSheet(
  BuildContext context, {
  required String itemLabel,
  required int need,
  required int have,
  VoidCallback? onCollectFree,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ShortageQuickSheet(
      itemLabel: itemLabel,
      need: need,
      have: have,
      onCollectFree: onCollectFree,
    ),
  );
}

class ShortageQuickSheet extends StatelessWidget {
  const ShortageQuickSheet({
    super.key,
    required this.itemLabel,
    required this.need,
    required this.have,
    this.onCollectFree,
  });

  final String itemLabel;
  final int need;
  final int have;
  final VoidCallback? onCollectFree;

  @override
  Widget build(BuildContext context) {
    final short = (need - have).clamp(1, 1 << 30);
    final packs = suggestPouchPacks(short);
    final hasSub = context.watch<PouchPayService>().activeSubscription != null;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: WishRoomColors.backgroundSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: WishRoomColors.surfaceCardBorder),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: WishRoomColors.surfaceCardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('🧧', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '복주머니가 조금 모자라요',
                      style: WishRoomTextStyles.sectionTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$itemLabel · $need개 필요 · 지금 $have개 · $short개 부족',
                style: WishRoomTextStyles.bodySm,
              ),
              const SizedBox(height: 18),
              ...packs.asMap().entries.map((e) {
                final idx = e.key;
                final pk = e.value;
                final extra = hasSub
                    ? (pk.base * kPouchSubExtraPct / 100).round()
                    : 0;
                final total = pk.total + extra;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PackOptionTile(
                    pack: pk,
                    extra: extra,
                    total: total,
                    recommended: idx == 0,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PouchCheckoutScreen(
                            request: PouchPurchaseRequest.packWithResume(
                              pk,
                              '$itemLabel 이어서 봉인하기',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Semantics(
                  identifier: 'shortage_sheet_open_store',
                  button: true,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const PouchStoreScreen()));
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: WishRoomColors.surfaceCardBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      '곳간 전체 보기',
                      style: WishRoomTextStyles.buttonLabel.copyWith(
                        color: WishRoomColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: Semantics(
                  identifier: 'shortage_sheet_collect_free',
                  button: true,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCollectFree?.call();
                    },
                    child: Text(
                      '무료로 모으기',
                      style: WishRoomTextStyles.bodySm.copyWith(
                        color: WishRoomColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackOptionTile extends StatelessWidget {
  const _PackOptionTile({
    required this.pack,
    required this.extra,
    required this.total,
    required this.recommended,
    required this.onTap,
  });

  final PouchPack pack;
  final int extra;
  final int total;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'shortage_sheet_pack_${pack.id}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WishRoomColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: recommended
                  ? WishRoomColors.glow
                  : WishRoomColors.surfaceCardBorder,
              width: recommended ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(pack.name, style: WishRoomTextStyles.bodyMd),
                        if (recommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: WishRoomColors.glow.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '딱 맞아요',
                              style: WishRoomTextStyles.pillLabel.copyWith(
                                color: WishRoomColors.glow,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      extra > 0
                          ? '🎁 ${pack.base}개 + 덤 ${pack.bonus}개 + 구독보너스 $extra개'
                          : (pack.bonus > 0
                                ? '🎁 ${pack.base}개 + 덤 ${pack.bonus}개'
                                : '🎁 ${pack.base}개'),
                      style: WishRoomTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pack.price}원',
                    style: WishRoomTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: WishRoomColors.glow,
                    ),
                  ),
                  Text('= 🧧$total', style: WishRoomTextStyles.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
