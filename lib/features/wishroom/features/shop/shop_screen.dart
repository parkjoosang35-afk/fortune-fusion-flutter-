// app3/shopscreen.jsx › ShopScreen 1:1 포팅 — 8탭(수호자 · 옷 · 장식 · 꽃 · 촛불 ·
// 창밖 · 효과 · 인장) 공용 상점. 탭 자체(하단바 인덱스3)는 3일째(unlockKey:'decor')
// 열리지만, 정식 구매는 14일째(v.open('shop'))부터다 — 그 전엔 "구경만" 할 수
// 있고 구매를 시도하면 잠금 안내만 띄운다(화면 자체를 막지 않는다).
//
// [v5 S2 — "2번 진행할 때 지킬 것" ② "구매 로직은 1벌만"] 이 화면의 모든 Tile은
// 구매 처리를 직접 하지 않고 반드시 openPayScreen()으로 공용 PayScreen을 연다.
// 수호자 탭(character_shop_screen.dart의 _act/_wearOutfit)도 동일하게 PayScreen을
// 쓰도록 리팩토링되어 있다 — 구매 버튼/결제 처리가 이 두 곳에 따로 있지 않다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_nav_pill.dart';
import '../../core/wr_bottom_nav.dart';
import '../../core/wr_item_icon.dart';
import '../../core/wr_toast.dart';
import '../wallet/wallet_sheet.dart';
import '../decor/decor_screen.dart';
import 'pay_screen.dart';

const List<(Slot, String, String)> _kItemTabs = [
  (Slot.DECORATION, 'DECORATION', '장식'),
  (Slot.FLOWER, 'FLOWER', '꽃'),
  (Slot.CANDLE, 'CANDLE', '촛불'),
  (Slot.BACKGROUND, 'BACKGROUND', '창밖'),
  (Slot.SPECIAL, 'SPECIAL', '효과'),
  (Slot.SEAL, 'SEAL', '인장'),
];

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialTab});
  // [Stage 3-A — 옷장 「상점에서 보기」 딥링크] 옷장 화면에서 미보유 의상을
  // 눌렀을 때 '옷' 탭을 바로 펼친 채로 이 화면을 열기 위한 진입 탭 지정.
  // null이면 기존처럼 '수호자' 탭(_tab 기본값 'char')으로 시작한다.
  final String? initialTab;
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // char | outfit | DECORATION | FLOWER | CANDLE | BACKGROUND | SPECIAL | SEAL
  late String _tab = widget.initialTab ?? 'char';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WishRoomProvider>();
      if (!p.catalogLoaded) p.loadCatalog();
      if (p.me == null) p.loadMyRoom();
    });
  }

  bool _shopOpen(WishRoom? room) =>
      room != null && room.isFeatureUnlocked('shop');

  void _lockToast(BuildContext context, WishRoom? room) {
    final cat = WrCatalog.I;
    final unlockDay = (cat.raw['UNLOCK'] as Map)['shop'] as int? ?? 14;
    final dayN = room?.dayN ?? 1;
    final left = (unlockDay - dayN).clamp(1, 999);
    WrToast.show(context, '소원 상점은 $left일 뒤에 정식으로 열려요 · 구경은 지금도 할 수 있어요');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        bottomNavigationBar: wrBottomNavBar(
          context,
          currentIndex: 3,
          onTabTap: (i) => wrReturnToTab(context, i),
        ),
        body: Consumer<WishRoomProvider>(
          builder: (context, p, __) {
            final room = p.room;
            final open = _shopOpen(room);
            return SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _topBar(context, p),
                  if (!open) _lockBanner(context, room),
                  _tabBar(),
                  Expanded(child: _body(context, p, room, open)),
                  _footerNote(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, WishRoomProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          WrNavPill(
            onBack: () => wrBackOrAskExit(context),
            onExitHome: () => wrExitHome(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'WISH SHOP',
              textAlign: TextAlign.center,
              style: WrF.mono(size: 13, color: WrC.blossom2),
            ),
          ),
          GestureDetector(
            onTap: () => openWalletSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: WrC.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: WrC.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧧', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${p.me?.pouch ?? 0}',
                    style: WrF.body(13, w: FontWeight.w700, color: WrC.glow),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockBanner(BuildContext context, WishRoom? room) {
    final cat = WrCatalog.I;
    final unlockDay = (cat.raw['UNLOCK'] as Map)['shop'] as int? ?? 14;
    final dayN = room?.dayN ?? 1;
    final left = (unlockDay - dayN).clamp(1, 999);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0x1AF5CF6A),
          border: Border.all(color: const Color(0x80F5CF6A)),
        ),
        child: Text(
          '🔒 구경은 언제든 마음껏 · 정식으로 사기는 $left일 뒤부터예요',
          style: WrF.body(12.5, w: FontWeight.w700, color: WrC.fg),
        ),
      ),
    );
  }

  Widget _tabBar() {
    final tabs = <(String, String)>[
      ('char', '수호자'),
      ('outfit', '옷'),
      for (final t in _kItemTabs) (t.$2, t.$3),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: tabs.map((t) {
          final sel = _tab == t.$1;
          // [QA 테스트 보조 — 대표 지시, 기본 규칙화] 좌표 클릭 대신 이름표로
          // 탭을 누를 수 있도록 identifier 부여. 시각적 변화 없음.
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              identifier: 'shop_tab_${t.$1}',
              button: true,
              child: GestureDetector(
                onTap: () => setState(() => _tab = t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: sel ? WrDeco.chipOn : WrDeco.chip,
                  child: Text(
                    t.$2,
                    style: WrF.body(
                      12.5,
                      w: FontWeight.w700,
                      color: sel ? Colors.white : WrC.fg,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WishRoomProvider p,
    WishRoom? room,
    bool open,
  ) {
    if (p.characters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tab == 'char') return _charTab(context, p, room, open);
    if (_tab == 'outfit') return _outfitTab(context, p, room, open);
    final slotTab = _kItemTabs.firstWhere(
      (t) => t.$2 == _tab,
      orElse: () => _kItemTabs.first,
    );
    return _itemTab(context, p, room, open, slotTab.$1);
  }

  // ── 수호자 탭 ──
  Widget _charTab(
    BuildContext context,
    WishRoomProvider p,
    WishRoom? room,
    bool open,
  ) {
    final cat = WrCatalog.I;
    final list = p.characters;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .74,
      ),
      itemBuilder: (_, i) {
        final c = list[i];
        final owned = p.me?.ownedChars.contains(c.id) ?? (c.price == 0);
        return _Tile(
          imgProvider: AssetImage(cat.charImage(c.id, WrTheme.free)),
          glyph: c.emblem,
          name: c.name,
          sub: c.title,
          price: c.price,
          own: owned,
          // app3/shopscreen.jsx Tile ownLabel 1:1 — `v.guardian===c.id?'✓ 함께하는 중':'모셨어요'`.
          ownLabel: p.me?.repChar == c.id ? '✓ 함께하는 중' : '모셨어요',
          onClick: () => _buyCharacter(context, p, room, open, c, owned),
        );
      },
    );
  }

  Future<void> _buyCharacter(
    BuildContext context,
    WishRoomProvider p,
    WishRoom? room,
    bool open,
    WrCharacter c,
    bool owned,
  ) async {
    if (owned) {
      if (p.me?.repChar == c.id) return;
      final ok = await p.setCharacter(c.id);
      if (!context.mounted) return;
      WrToast.show(
        context,
        ok
            ? '${c.name}이(가) 소원방을 함께 지켜요'
            : (p.lastError?.message ?? '설정에 실패했어요'),
      );
      return;
    }
    if (!open) {
      _lockToast(context, room);
      return;
    }
    openPayScreen(
      context,
      PayOrder(
        kind: 'char',
        name: c.name,
        sub: c.title,
        glyph: c.emblem,
        price: c.price ?? 0,
        doneTitle: '${c.name}이(가) 함께하게 됐어요',
        afterLabel: null,
        onConfirmPay: (idempotencyKey) async {
          final ok = await p.buyCharacter(c.id, idempotencyKey: idempotencyKey);
          if (!ok) return false;
          await p.setCharacter(c.id);
          return true;
        },
      ),
    );
  }

  // ── 옷(신규 의상) 탭 ──
  // [v5 S2 — 대표 재지적] "상점 옷 탭에서는 지금 함께하는 수호자가 입을 수
  // 있는 옷을 먼저 보여 주세요. 못 입는 옷은 흐리게 하고 「OO 전용 의상이에요」
  // 표시만 해 주세요. 구매 버튼은 숨깁니다." — 호환 옷을 앞쪽 그룹으로 재정렬하고,
  // 비호환 타일은 가격(구매 버튼 역할)을 완전히 숨긴 채 전용 안내 라벨만 노출한다.
  Widget _outfitTab(
    BuildContext context,
    WishRoomProvider p,
    WishRoom? room,
    bool open,
  ) {
    final cat = WrCatalog.I;
    final repChar = p.me?.repChar;
    final repGender = repChar == null
        ? null
        : (repChar.startsWith('M') ? 'M' : 'F');
    final themeFiltered = cat.newOutfits
        .where((o) => room == null || o['theme'] == room.theme.name)
        .toList();
    if (themeFiltered.isEmpty) {
      return Center(
        child: Text(
          '지금 방 분위기에 맞는 신규 의상이 아직 없어요',
          style: WrF.body(13, color: WrC.muted),
        ),
      );
    }
    bool isCompatible(Map<String, dynamic> o) =>
        repGender == null || repGender == (o['gender'] as String);
    // 호환 옷(지금 함께하는 수호자가 입을 수 있는 옷)을 먼저, 비호환 옷을 뒤로.
    final list = [
      ...themeFiltered.where(isCompatible),
      ...themeFiltered.where((o) => !isCompatible(o)),
    ];
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .66,
      ),
      itemBuilder: (_, i) {
        final o = list[i];
        final id = o['id'] as String;
        final gender = o['gender'] as String;
        final compatible = isCompatible(o);
        final ownerLabel = gender == 'F' ? '하린' : '준';
        final owned =
            p.me?.ownedOutfits.contains(
              '${gender == 'F' ? 'F00' : 'M00'}:$id',
            ) ??
            false;
        final price = (o['price'] as num).toInt();
        // [QA 테스트 보조 — 대표 지시, 기본 규칙화] 좌표 클릭 대신 이름표로
        // 구매/착용을 트리거할 수 있도록 identifier 부여. 시각적 변화 없음.
        return Semantics(
          identifier: 'shop_outfit_$id',
          button: true,
          child: _Tile(
            imgProvider: AssetImage('assets/wishroom/outfits/$id.png'),
            glyph: '👗',
            name: o['name'] as String,
            sub: compatible ? (o['themeLabel'] as String? ?? '') : null,
            // 비호환이면 가격(=구매 버튼) 자체를 숨기고 전용 안내 라벨만 보여준다.
            price: compatible ? price : null,
            own: owned,
            ownLabel: '보유',
            lockedLabel: compatible ? null : '$ownerLabel 전용 의상이에요',
            dim: !compatible,
            onClick: () {
              if (!compatible) {
                WrToast.show(context, '${gender == 'F' ? '하린' : '준'} 전용 의상이에요');
                return;
              }
              final charId = gender == 'F' ? 'F00' : 'M00';
              if (owned) {
                _wearNewOutfit(context, p, charId, id, o['name'] as String);
                return;
              }
              if (!open) {
                _lockToast(context, room);
                return;
              }
              // [v5 S2 — 사용자 재지적] app3/shopscreen.jsx/wardrobe.jsx 1:1 —
              // 결제는 "구매"만 한다. 입히는 것은 영수증 화면의 "👗 지금 입혀
              // 보기" 버튼을 눌렀을 때 따로 일어난다(결제 즉시 자동으로 입혀지지
              // 않는다). wearNamedOutfit()은 여기서 쓰지 않고(그건 보유 의상을
              // 바로 입는 액션용), buyNamedOutfitOnly()로 구매만 완료한다.
              openPayScreen(
                context,
                PayOrder(
                  kind: 'outfit',
                  name: o['name'] as String,
                  sub: o['themeLabel'] as String?,
                  glyph: '👗',
                  price: price,
                  doneTitle: '${o['name']}, 옷장에 담겼어요',
                  afterLabel: '👗 지금 입혀 보기',
                  after: () => _wearNewOutfit(
                    context,
                    p,
                    charId,
                    id,
                    o['name'] as String,
                  ),
                  onConfirmPay: (idempotencyKey) => p.buyNamedOutfitOnly(charId, id, idempotencyKey: idempotencyKey),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _wearNewOutfit(
    BuildContext context,
    WishRoomProvider p,
    String charId,
    String outfitId,
    String name,
  ) async {
    final okChar = p.room?.char == charId || await p.setCharacter(charId);
    if (!context.mounted) return;
    if (!okChar) {
      WrToast.show(context, p.lastError?.message ?? '수호자 변경에 실패했어요');
      return;
    }
    await p.loadOutfits(charId);
    if (!context.mounted) return;
    final offer = p.outfitOffers.where((o) => o.id == outfitId).firstOrNull;
    if (offer == null) return;
    final ok = await p.wearNamedOutfit(charId, offer);
    if (!context.mounted) return;
    WrToast.show(
      context,
      ok ? '$name으로 갈아입었어요' : (p.lastError?.message ?? '적용에 실패했어요'),
    );
  }

  // ── 꾸미기(장식/꽃/촛불/창밖/효과/인장) 탭 ──
  Widget _itemTab(
    BuildContext context,
    WishRoomProvider p,
    WishRoom? room,
    bool open,
    Slot slot,
  ) {
    if (room == null) return const SizedBox.shrink();
    final items = p.items.where((i) {
      if (i.slot != slot) return false;
      return i.price != null || i.owned || i.reward != null;
    }).toList();
    if (items.isEmpty) {
      return Center(
        child: Text('아직 물건이 없어요', style: WrF.body(13, color: WrC.muted)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .8,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        final on = room.equip.all.contains(it.id);
        return _Tile(
          wrItem: it,
          name: it.name,
          sub: it.tier,
          price: it.owned ? null : it.price,
          own: it.owned,
          ownLabel: on ? '놓여 있음' : '보유',
          onClick: () => _buyItem(context, p, room, open, it),
        );
      },
    );
  }

  Future<void> _buyItem(
    BuildContext context,
    WishRoomProvider p,
    WishRoom room,
    bool open,
    WrItem it,
  ) async {
    if (it.owned) {
      // 이미 보유 — 구매 화면이 아니라 꾸미기 화면에서 배치/치우기를 하도록 안내.
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DecorScreen()));
      return;
    }
    if (it.price == null) {
      WrToast.show(context, '❤ 응원 ${it.reward}회를 받으면 열려요');
      return;
    }
    if (!open) {
      _lockToast(context, room);
      return;
    }
    openPayScreen(
      context,
      PayOrder(
        kind: 'item',
        name: it.name,
        sub: it.desc,
        img: it.asset,
        glyph: it.glyph,
        price: it.price!,
        doneTitle: '${it.name}을(를) 들였어요',
        afterLabel: '✿ 방에 놓으러 가기',
        after: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DecorScreen()));
        },
        onConfirmPay: (idempotencyKey) => p.buyItem(it.id, idempotencyKey: idempotencyKey),
      ),
    );
  }

  Widget _footerNote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Text(
        '복주머니 1개 = 10원 · 모은 복주머니는 신통방통 어디서나 함께 써요',
        textAlign: TextAlign.center,
        style: WrF.body(11, color: WrC.muted),
      ),
    );
  }
}

/// app3/shopscreen.jsx 공용 `Tile({img, icon, tall, cover, name, sub, price,
/// own, ownLabel, badge, onClick})` 1:1 — 구매 버튼 역할을 겸한다.
class _Tile extends StatelessWidget {
  const _Tile({
    this.imgProvider,
    this.wrItem,
    this.glyph,
    required this.name,
    this.sub,
    required this.price,
    required this.own,
    required this.ownLabel,
    this.dim = false,
    this.lockedLabel,
    required this.onClick,
  });

  final ImageProvider? imgProvider;
  final WrItem? wrItem;
  final String? glyph;
  final String name;
  final String? sub;
  final int? price;
  final bool own;
  final String ownLabel;
  final bool dim;
  // 다른 수호자 전용이라 지금 함께하는 수호자는 입을 수 없음을 알리는 라벨.
  // 값이 있으면 가격/구매 버튼 대신 이 라벨만 보여준다(구매 자체를 막기 위함).
  final String? lockedLabel;
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: Opacity(
        opacity: dim ? .5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: own ? const Color(0x24F2628F) : WrC.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: own ? WrC.blossom2 : WrC.cardBorder),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: wrItem != null
                      ? WrItemIcon(it: wrItem!, size: 46)
                      : (imgProvider != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image(
                                  image: imgProvider!,
                                  fit: BoxFit.contain,
                                  height: 54,
                                  errorBuilder: (_, __, ___) => Text(
                                    glyph ?? '✦',
                                    style: const TextStyle(fontSize: 30),
                                  ),
                                ),
                              )
                            : Text(
                                glyph ?? '✦',
                                style: const TextStyle(fontSize: 30),
                              )),
                ),
              ),
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WrF.body(12, w: FontWeight.w700, color: WrC.fg),
                      ),
                      if (sub != null && sub!.isNotEmpty)
                        Text(
                          sub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WrF.body(10, color: WrC.muted),
                        ),
                      const SizedBox(height: 2),
                      if (own)
                        Text(
                          ownLabel,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: WrC.muted,
                          ),
                        )
                      else if (lockedLabel != null)
                        // 비호환 의상: 가격/구매 버튼 대신 전용 안내만 노출.
                        Text(
                          lockedLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            color: WrC.muted,
                          ),
                        )
                      else if (price == null)
                        const Text(
                          '❤ 응원',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: WrC.glow,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🧧', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 2),
                            Text(
                              '$price',
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: WrC.glow,
                              ),
                            ),
                          ],
                        ),
                    ],
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
