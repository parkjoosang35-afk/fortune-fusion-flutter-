// SCR-05-B 옷장 `/vault/wardrobe` — app3/wardrobe.jsx 1:1 이식
// [Stage 3-A — 대표 결정 2026-11] character_shop_screen.dart의 👕 의상 탭
// (_outfitGrid/_wearOutfit)을 "옷장"이라는 독립 화면으로 분리한다. 기존
// CharacterShopScreen은 지우지 않고 그대로 둔다(3-B에서 그 화면의 의상 탭만
// 정리 예정) — 이 화면은 새로 만들어 추가하는 것이고, 로직(_outfitGrid/
// _wearOutfit)은 원본 그대로 가져와 재사용한다(새로 작성하지 않음).
//
// 원본(wardrobe.jsx)과의 의도적 차이 — 대표 확정 사항:
//   - 원본은 미보유 의상을 눌렀을 때 그 자리에서 바로 app.checkout()으로
//     결제 시트를 띄운다. 이 포팅에서는 그렇게 하지 않고 "상점에서 보기"로
//     상점(ShopScreen)의 옷 탭으로 보낸다 — 옷장 화면 자체는 결제를
//     트리거하지 않는다(PayScreen은 상점에서만 연다, 기존 openPayScreen
//     단일 경로 원칙 유지).
//
// 진입점 3군데(대표 결정):
//   1) ⋯ 「옷 갈아입기」(main_room_screen.dart _onGoFor)
//   2) 수호자 자세히의 「옷 갈아입히기」 — 자세히 화면이 아직 따로 없어
//      character_shop_screen.dart _infoSheet()에 버튼만 추가(3-B에서 본
//      자세히 화면으로 교체 예정)
//   3) 방에서 수호자 누르기(room_scene.dart) — 3-B 전까지 임시로 이 옷장으로
//      연결(기획상 최종 목적지는 "수호자 자세히")
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_nav_pill.dart';
import '../../core/wr_toast.dart';
import '../shop/shop_screen.dart';
import '../characters/outfit_variants.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  // app3/wardrobe.jsx `tab` 1:1 — all | free | god | buddha | shaman.
  String _tab = 'all';
  // 의상 미리보기(아직 저장 안 함) — character_shop_screen.dart _wear/_newOutfitId와
  // 동일한 역할.
  WrTheme? _wear;
  String? _newOutfitId;
  int _variant = 0;
  bool _busy = false;

  String? get _char => context.read<WishRoomProvider>().room?.char;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    final p = context.read<WishRoomProvider>();
    if (!p.catalogLoaded) await p.loadCatalog();
    if (!mounted) return;
    if (p.me == null) await p.loadMyRoom();
    if (!mounted) return;
    final room = p.room;
    if (room == null) return;
    setState(() {
      _wear = room.outfitNow;
      _newOutfitId = room.outfitId;
    });
    await p.loadOutfits(room.char);
  }

  // [Stage 3-A] 상점에서 돌아온 뒤(의상 구매 등) 보유 현황을 새로 고치기
  // 위해 사용 — _goToShop()에서 ShopScreen을 push할 때 await로 받아
  // 복귀 시 호출한다.
  Future<void> _loadOutfits() async {
    final char = _char;
    if (char == null) return;
    await context.read<WishRoomProvider>().loadOutfits(char);
  }

  // app3/wardrobe.jsx wear() 1:1 — character_shop_screen.dart _wearOutfit()을
  // 그대로 옮겨 쓴다(새로 작성하지 않음). 유일한 의도적 변경점: 미보유 신규
  // 의상(o.isNew && !o.owned)일 때는 결제 시트를 열지 않고 상점 옷 탭으로
  // 보낸다("상점에서 보기" — 대표 결정).
  Future<void> _wearOutfit(WrCharacter c, OutfitOffer o) async {
    if (_busy) return;
    final p = context.read<WishRoomProvider>();
    if (o.isNew) {
      if (!o.compatible) {
        WrToast.show(context, '하린·준 전용 의상이에요');
        return;
      }
      if (!o.owned) {
        _goToShop();
        return;
      }
      setState(() => _busy = true);
      try {
        final ok = await p.wearNamedOutfit(c.id, o);
        if (!mounted) return;
        WrToast.show(
          context,
          ok ? '${o.name}으로 갈아입었어요' : (p.lastError?.message ?? '의상 적용에 실패했어요'),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    // 기본 4벌(사복·예배복·법복·신당복)은 항상 무료/보유 상태이므로 o.owned가
    // 항상 true다 — 미보유 분기는 실질적으로 호출되지 않지만, 혹시 데이터가
    // 어긋나는 경우에도 안전하게 상점으로 보낸다(여기서 직접 결제하지 않음).
    if (!o.owned) {
      _goToShop();
      return;
    }
    setState(() => _busy = true);
    try {
      final room = p.room;
      if (room != null) {
        if (room.char != c.id && !await p.setCharacter(c.id)) {
          if (!mounted) return;
          WrToast.show(context, p.lastError?.message ?? '수호자 변경에 실패했어요.');
          return;
        }
        if (!await p.setOutfit(room.id, o.theme)) {
          if (!mounted) return;
          WrToast.show(context, p.lastError?.message ?? '의상 적용에 실패했어요.');
          return;
        }
      }
      if (!mounted) return;
      final themeInfo = WrCatalog.I.themes
          .where((t) => t['id'] == o.theme.name)
          .toList();
      final label = themeInfo.isNotEmpty
          ? themeInfo.first['label'] as String
          : '';
      WrToast.show(context, '${c.name} · $label 의상으로 갈아입었어요');
      setState(() {
        _wear = o.theme;
        _newOutfitId = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // 「상점에서 보기」 — 옷장 화면은 결제를 트리거하지 않고 상점의 옷 탭으로
  // 보낸다(대표 결정 — 원본 wardrobe.jsx의 즉시 checkout()과 의도적으로 다름).
  // 상점에서 구매하고 돌아오면 보유 현황이 바뀌었을 수 있으므로 복귀 시
  // _loadOutfits()로 다시 불러온다.
  Future<void> _goToShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen(initialTab: 'outfit')),
    );
    if (mounted) await _loadOutfits();
  }

  // app3/wardrobe.jsx 「방 분위기에 맞춰 자동으로 입기」 1:1 — F.wear(null).
  // 서버 setOutfit(id, null)로 "핀 고정" 해제 → 이후 outfitNow가 방 테마를
  // 그대로 따라간다(wr_catalog.dart charImage()의 outfit=null 의미와 동일).
  Future<void> _autoMatchRoom() async {
    if (_busy) return;
    final p = context.read<WishRoomProvider>();
    final room = p.room;
    if (room == null) return;
    setState(() => _busy = true);
    try {
      final ok = await p.setOutfit(room.id, null);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _wear = p.room?.theme ?? room.theme;
          _newOutfitId = null;
        });
        WrToast.show(context, '방 분위기에 맞춰 자동으로 입어요');
      } else {
        WrToast.show(context, p.lastError?.message ?? '적용에 실패했어요');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: Consumer<WishRoomProvider>(
          builder: (context, p, __) {
            final room = p.room;
            final charId = room?.char;
            final c = p.characters.where((ch) => ch.id == charId).firstOrNull;
            if (room == null || c == null) {
              return const SafeArea(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final outfitTheme = _wear ?? room.outfitNow;
            return Column(
              children: [
                // ── 위: 지금 수호자 try-on 미리보기 ──
                SizedBox(
                  height: 330,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF2A1020), Color(0xFF12060E)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 40,
                        height: 290,
                        child: IgnorePointer(
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              ...List.generate(14, (i) {
                                final angle = i * 25.7 * 3.14159 / 180;
                                return Transform.rotate(
                                  angle: angle,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 2,
                                    height: 180,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0x99FFC8DC),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              Container(
                                width: 280,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0x80FFA0BE),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Image.asset(
                            WrCatalog.I.charImage(
                              c.id,
                              outfitTheme,
                              outfitId: _newOutfitId,
                            ),
                            key: ValueKey(_newOutfitId ?? outfitTheme.name),
                            height: 320,
                            width: 229,
                            fit: _newOutfitId == null
                                ? BoxFit.cover
                                : BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            errorBuilder: (_, __, ___) => SizedBox(
                              width: 229,
                              height: 320,
                              child: Center(
                                child: Text(
                                  c.emblem,
                                  style: const TextStyle(
                                    fontSize: 64,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Row(
                          children: [
                            WrNavPill(
                              onBack: () => Navigator.of(context).maybePop(),
                              onExitHome: () => wrExitHome(context),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 14,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WARDROBE · ${c.id}',
                              style: WrF.mono(size: 10.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.name,
                              style: WrF.display(22, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 아래: 옷 목록 ──
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xF53A1628), Color(0xFF1A0812)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(top: BorderSide(color: Color(0x40FFBED2))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.name} · 옷장',
                                  style: WrF.body(
                                    15,
                                    w: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // [QA 테스트 보조 — 대표 지시] 좌표 클릭 대신 이름표로
                              // 누를 수 있도록 identifier 부여. 시각적 변화 없음.
                              Semantics(
                                identifier: 'wardrobe_auto',
                                button: true,
                                child: GestureDetector(
                                  onTap: _busy ? null : _autoMatchRoom,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: WrC.chipBg,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: WrC.line),
                                    ),
                                    child: Text(
                                      '✨ 방 분위기에 맞춰 자동으로 입기',
                                      style: WrF.body(11, color: WrC.fg),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                          child: SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final t in const [
                                  ('all', '전체'),
                                  ('free', '🌸 자유'),
                                  ('god', '✝ 교회'),
                                  ('buddha', '🪷 법당'),
                                  ('shaman', '🎐 신당'),
                                ])
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _tabChip(
                                      t.$2,
                                      _tab == t.$1,
                                      () => setState(() => _tab = t.$1),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: _outfitGrid(p, c, outfitTheme)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabChip(String label, bool on, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: on ? WrDeco.chipOn : WrDeco.chip,
      child: Text(
        label,
        style: WrF.body(
          12.5,
          w: FontWeight.w700,
          color: on ? Colors.white : WrC.fg,
        ),
      ),
    ),
  );

  // character_shop_screen.dart _outfitGrid()를 옷장 화면으로 옮겨온 것 —
  // 로직은 그대로이되, 탭 필터(_tab: all/free/god/buddha/shaman)와 카드의
  // CTA 라벨("입기" / "상점에서 보기")만 이 화면 사양(대표 결정)에 맞게 조정.
  Widget _outfitGrid(WishRoomProvider p, WrCharacter c, WrTheme outfitTheme) {
    final cat = WrCatalog.I;
    final room = p.room;
    // 기존 테마 의상(무료 4벌)과 현재 방 테마의 신규 의상(최대 5벌)을 합친 목록.
    // app3/flow.js wardrobeOf(charId) 1:1 구조 — base(4벌) + extra(해당
    // 성별 신규 20벌 중 현재 방 테마와 일치하는 것들, F00/M00에게만).
    final variants = p.outfitOffers
        .where(
          (offer) =>
              !offer.isNew || offer.theme == (room?.theme ?? WrTheme.free),
        )
        .map((offer) => WrOutfitVariant(offer, 0, offer.name ?? '기본', null))
        .toList();
    final shown = _tab == 'all'
        ? variants
        : variants.where((v) => v.offer.theme.name == _tab).toList();
    if (shown.isEmpty) {
      return Center(
        child: Text('이 분류에는 옷이 없어요', style: WrF.body(13, color: WrC.muted)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: .64,
            ),
            itemBuilder: (_, i) {
              final v = shown[i];
              final o = v.offer;
              final themeInfo = cat.themes
                  .where((t) => t['id'] == o.theme.name)
                  .toList();
              final T = themeInfo.isNotEmpty ? themeInfo.first : null;
              if (T == null) return const SizedBox.shrink();
              final cur =
                  room != null &&
                  room.char == c.id &&
                  (o.isNew
                      ? room.outfitId == o.id
                      : room.outfitId == null && room.outfitNow == o.theme);
              final pv = o.isNew
                  ? _newOutfitId == o.id
                  : _newOutfitId == null &&
                        _wear == o.theme &&
                        _variant == v.index;
              final tColor = _hex(T['color'] as String);
              // [QA 테스트 보조 — 대표 지시] 좌표 클릭 대신 이름표로 누를 수
              // 있도록 outfit_<id> identifier 부여(기본 4벌은 id가 없으므로
              // 테마명으로 대체).
              return Semantics(
                identifier: 'outfit_${o.id ?? o.theme.name}',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    if (!o.compatible) {
                      WrToast.show(
                        context,
                        '${o.gender == 'F' ? '하린' : '준'} 전용 의상이에요',
                      );
                      return;
                    }
                    if (o.isNew && !o.owned) {
                      // 미보유 신규 의상은 바로 미리보기만 전환하지 않고
                      // 「상점에서 보기」 흐름으로 보낸다(아래 CTA에서 처리).
                      setState(() {
                        _wear = o.theme;
                        _newOutfitId = o.id;
                        _variant = v.index;
                      });
                      return;
                    }
                    setState(() {
                      _wear = o.theme;
                      _newOutfitId = o.id;
                      _variant = v.index;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: WrC.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: pv || cur ? tColor : WrC.cardBorder,
                        width: pv || cur ? 1.6 : 1,
                      ),
                      boxShadow: pv
                          ? [
                              BoxShadow(
                                color: tColor.withValues(alpha: .4),
                                blurRadius: 16,
                              ),
                            ]
                          : const [],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        tColor.withValues(alpha: .27),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: !o.compatible
                                      ? .35
                                      : (o.hasArt || o.theme == WrTheme.free
                                            ? 1
                                            : .4),
                                  child: Image.asset(
                                    o.isNew
                                        ? o.asset
                                        : cat.charImage(c.id, o.theme),
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomCenter,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        T['glyph'] as String,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (!o.hasArt && o.theme != WrTheme.free)
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x99000000),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '그림 준비 중',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Text(
                                  T['glyph'] as String,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.name ?? '${T['label']} 의상',
                                style: WrF.body(
                                  13,
                                  w: FontWeight.w700,
                                  color: WrC.fg,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                o.isNew
                                    ? '${o.gender == 'F' ? '하린' : '준'} 전용 · ${T['label']}'
                                    : T['outfitHint'] as String? ?? '',
                                style: WrF.body(
                                  10.5,
                                  color: WrC.muted,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                !o.compatible
                                    ? '잠김 · 다른 수호자 전용'
                                    : cur
                                    ? '✓ 입는 중'
                                    : o.owned
                                    ? '보유'
                                    : (o.hasArt ? '🧧 ${o.price}' : '곧 만나요'),
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: cur
                                      ? tColor
                                      : (o.owned ? WrC.muted : WrC.glow),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _ctaButton(p, c, outfitTheme),
        ],
      ),
    );
  }

  // app3/wardrobe.jsx 메인 버튼 상태(원본과의 차이는 미보유일 때 "상점에서
  // 보기"로 바뀌는 것뿐 — 대표 결정).
  // [QA 테스트 보조 — 대표 지시] 좌표 클릭 대신 이름표(wardrobe_cta)로 누를 수
  // 있도록 모든 분기의 버튼에 동일한 Semantics identifier를 부여한다.
  Widget _ctaButton(WishRoomProvider p, WrCharacter c, WrTheme outfitTheme) {
    final room = p.room;
    final offer = p.outfitOffers
        .where(
          (o) => _newOutfitId != null
              ? o.id == _newOutfitId
              : !o.isNew && o.theme == (_wear ?? WrTheme.free),
        )
        .firstOrNull;
    if (offer == null) return const SizedBox.shrink();
    final cur =
        room != null &&
        room.char == c.id &&
        (offer.isNew
            ? room.outfitId == offer.id
            : room.outfitId == null && room.outfitNow == offer.theme);
    Widget btn;
    if (cur) {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
          child: Text('지금 입고 있어요', style: WrF.body(14, color: Colors.white54)),
        ),
      );
    } else if (!offer.compatible) {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
          child: Text(
            '${offer.gender == 'F' ? '하린' : '준'} 전용 의상이에요',
            style: WrF.body(14, color: Colors.white54),
          ),
        ),
      );
    } else if (!offer.owned) {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _goToShop,
          style: ElevatedButton.styleFrom(backgroundColor: WrC.glow),
          child: Text(
            '🛍 상점에서 보기 · 🧧 ${offer.price}',
            style: const TextStyle(
              color: Color(0xFF4A2A10),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    } else {
      btn = SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _busy ? null : () => _wearOutfit(c, offer),
          style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
          child: Text(
            '${offer.name ?? '${WrCatalog.I.themes.firstWhere((t) => t['id'] == offer.theme.name)['label']} 의상'} 입기',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      );
    }
    return Semantics(identifier: 'wardrobe_cta', button: true, child: btn);
  }

  Color _hex(String s) =>
      Color(int.parse('FF${s.replaceFirst('#', '')}', radix: 16));
}
