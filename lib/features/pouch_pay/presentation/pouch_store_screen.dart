// [S5 복주머니 결제] 곳간(Store) 화면 — design_handoff_pouch_payment
// PayStore.jsx `StoreScreen` 1:1 포팅. 한번담기(팩)/매달받기(구독) 2탭,
// 선택한 상품으로 체크아웃 화면을 여는 하단 고정 CTA.
//
// [재화 절대 원칙] 이 화면은 잔액을 직접 보유하지 않는다 — 상단 잔액 표시는
// 항상 LuckPouchProvider.balance를 그대로 구독해서 보여준다. 실제 지급은
// PouchCheckoutScreen → PouchPayService.buyPack/buySubscription에서만 발생한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/legacy_wish_room/wish_room_bg_atmosphere.dart';
import '../../../core/theme/legacy_wish_room/wish_room_theme.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../application/pouch_pay_service.dart';
import '../domain/pouch_pay_catalog.dart';
import '../domain/pouch_pay_models.dart';
import 'pouch_checkout_screen.dart';

class PouchStoreScreen extends StatefulWidget {
  const PouchStoreScreen({super.key});

  @override
  State<PouchStoreScreen> createState() => _PouchStoreScreenState();
}

class _PouchStoreScreenState extends State<PouchStoreScreen> {
  int _tab = 0; // 0: 한번담기(팩), 1: 매달받기(구독)
  String _billing = 'month'; // 구독탭 전용: month | year
  PouchPack? _selPack;
  PouchSubTier? _selSub;

  @override
  void initState() {
    super.initState();
    _selPack = kPouchPacks[3]; // 가장 많이 담아요 기본 선택
    _selSub = kPouchSubs[1]; // 정성 기본 선택
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<LuckPouchProvider>().balance;
    final pay = context.watch<PouchPayService>();
    final activeSub = pay.activeSubscription;

    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 360, sigilOpacity: 0.16),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(context, balance, activeSub),
                _tabs(),
                Expanded(
                  child: _tab == 0 ? _packsPanel() : _subsPanel(activeSub),
                ),
                _bottomBar(context, activeSub),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    int balance,
    PouchSubscriptionState? activeSub,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Semantics(
            identifier: 'pouch_store_back',
            button: true,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
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
                child: const Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: WishRoomColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('곳간', style: WishRoomTextStyles.screenTitle),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text('🧧', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '지금 $balance개',
                      style: WishRoomTextStyles.bodySm.copyWith(
                        color: WishRoomColors.glow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (activeSub != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: WishRoomColors.glow.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${activeSub.tier.hanja} ${activeSub.tier.name} 구독중',
                          style: WishRoomTextStyles.pillLabel.copyWith(
                            color: WishRoomColors.glow,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
      ),
      child: Row(children: [_tabBtn('한번 담기', 0), _tabBtn('매달 받기', 1)]),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: Semantics(
        identifier: 'pouch_store_tab_$idx',
        button: true,
        child: InkWell(
          onTap: () => setState(() => _tab = idx),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? WishRoomColors.glow : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: WishRoomTextStyles.buttonLabel.copyWith(
                fontSize: 13,
                color: active
                    ? WishRoomColors.backgroundDeep
                    : WishRoomColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _packsPanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [for (final pk in kPouchPacks) _packRow(pk)],
    );
  }

  Widget _packRow(PouchPack pk) {
    final selected = _selPack?.id == pk.id;
    final featured = pk.tag != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        identifier: 'pouch_store_pack_${pk.id}',
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => setState(() => _selPack = pk),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: featured
                  ? WishRoomColors.glow.withValues(alpha: 0.10)
                  : WishRoomColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? WishRoomColors.glow
                    : WishRoomColors.surfaceCardBorder,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: selected
                      ? WishRoomColors.glow
                      : WishRoomColors.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(pk.name, style: WishRoomTextStyles.bodyMd),
                          if (pk.tag != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: WishRoomColors.glow,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                pk.tag!,
                                style: WishRoomTextStyles.pillLabel.copyWith(
                                  color: WishRoomColors.backgroundDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pk.bonus > 0
                            ? '🎁 ${pk.base}개 + 덤 ${pk.bonus}개 (${pk.bonusPct}%)'
                            : '🎁 ${pk.base}개',
                        style: WishRoomTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${pk.price}원',
                  style: WishRoomTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: WishRoomColors.glow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subsPanel(PouchSubscriptionState? activeSub) {
    final pay = context.watch<PouchPayService>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        _billingToggle(),
        const SizedBox(height: 12),
        for (final tier in kPouchSubs) _tierCard(tier, activeSub, pay),
      ],
    );
  }

  Widget _billingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
      ),
      child: Row(
        children: [
          _billingBtn('매달 결제', 'month'),
          _billingBtn('한해 결제 (2개월 무료)', 'year'),
        ],
      ),
    );
  }

  Widget _billingBtn(String label, String val) {
    final active = _billing == val;
    return Expanded(
      child: Semantics(
        identifier: 'pouch_store_billing_$val',
        button: true,
        child: InkWell(
          onTap: () => setState(() => _billing = val),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? WishRoomColors.crystal : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: WishRoomTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: active
                    ? WishRoomColors.backgroundDeep
                    : WishRoomColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tierCard(
    PouchSubTier tier,
    PouchSubscriptionState? activeSub,
    PouchPayService pay,
  ) {
    final selected = _selSub?.id == tier.id;
    final isCurrent = activeSub?.tierId == tier.id;
    // [초심/정성/신통 구독 실결제 연동 — 2026-11-27] 서버에 실결제 가능한
    // 플랜이 등록돼 있으면 서버 가격/지급량을 우선 표시한다(관리자가 바꾼
    // 값과 화면이 어긋나지 않도록). 서버 미등록 시에만 클라이언트 하드코딩
    // 카탈로그(pouch_pay_catalog.dart) 값으로 폴백한다.
    final serverPlan = pay.findServerPlan(tier, _billing);
    final price = serverPlan?.canRealPurchase == true
        ? serverPlan!.price
        : (_billing == 'year' ? pouchSubYearPrice(tier) : tier.month);
    final grant = serverPlan?.canRealPurchase == true
        ? serverPlan!.pouchGrantTotal
        : pouchSubGrant(tier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        identifier: 'pouch_store_sub_${tier.id}',
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => setState(() => _selSub = tier),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: tier.premium
                  ? const LinearGradient(
                      colors: [Color(0x33E8C878), Color(0x11E8C878)],
                    )
                  : null,
              color: tier.premium ? null : WishRoomColors.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? (tier.premium
                          ? const Color(0xFFE8C878)
                          : WishRoomColors.glow)
                    : WishRoomColors.surfaceCardBorder,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier.hanja,
                      style: WishRoomTextStyles.sectionTitle.copyWith(
                        color: tier.premium
                            ? const Color(0xFFE8C878)
                            : WishRoomColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tier.name, style: WishRoomTextStyles.bodyMd),
                        Text(tier.en, style: WishRoomTextStyles.eyebrow),
                      ],
                    ),
                    const Spacer(),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: WishRoomColors.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '지금 함께하는 길',
                          style: WishRoomTextStyles.pillLabel.copyWith(
                            color: WishRoomColors.success,
                          ),
                        ),
                      )
                    else if (tier.tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: WishRoomColors.glow.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tier.tag!,
                          style: WishRoomTextStyles.pillLabel.copyWith(
                            color: WishRoomColors.glow,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tier.tagline, style: WishRoomTextStyles.bodySm),
                const SizedBox(height: 10),
                Text(
                  '$price원 · 🧧 $grant개 (기본+${tier.bonusPct}%)',
                  style: WishRoomTextStyles.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tier.premium
                        ? const Color(0xFFE8C878)
                        : WishRoomColors.glow,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(height: 10),
                  ...tier.perks.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Text('✦ ', style: TextStyle(fontSize: 11)),
                          Expanded(
                            child: Text(p, style: WishRoomTextStyles.caption),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, PouchSubscriptionState? activeSub) {
    String label;
    VoidCallback? onTap;
    if (_tab == 0) {
      final pk = _selPack;
      label = pk != null ? '🧧 ${pk.name} 담기' : '팩을 선택하세요';
      onTap = pk == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PouchCheckoutScreen(request: PouchPurchaseRequest.pack(pk)),
              ),
            );
    } else {
      final tier = _selSub;
      if (tier == null) {
        label = '길을 선택하세요';
        onTap = null;
      } else if (activeSub == null) {
        label = '${tier.name} 구독 시작하기';
        onTap = () => _goCheckoutSub(context, tier);
      } else if (activeSub.tierId == tier.id) {
        label = '지금 함께하는 길이에요';
        onTap = null;
      } else {
        final cur = kPouchSubs.indexWhere((t) => t.id == activeSub.tierId);
        final sel = kPouchSubs.indexWhere((t) => t.id == tier.id);
        label = sel > cur ? '${tier.name}(으)로 길 올리기' : '${tier.name}(으)로 길 바꾸기';
        onTap = () => _goCheckoutSub(context, tier);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x001E1A3A), Color(0xF01E1A3A)],
          stops: [0, 0.4],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Semantics(
          identifier: 'pouch_store_cta',
          button: true,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: WishRoomColors.glow,
              disabledBackgroundColor: WishRoomColors.surfaceCardBorder,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              label,
              style: WishRoomTextStyles.buttonLabel.copyWith(
                color: WishRoomColors.backgroundDeep,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goCheckoutSub(BuildContext context, PouchSubTier tier) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PouchCheckoutScreen(
          request: PouchPurchaseRequest.sub(tier, subBilling: _billing),
        ),
      ),
    );
  }
}
