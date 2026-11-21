// SCR-05 수호자 탭 `/vault/guardians` — app3/guardians.jsx › GuardiansScreen 1:1 이식
// [Stage 3-B — 대표 판정 "3-A 옷장 완료 승인 → 3-B 수호자 자세히를 시작하세요"]
// 기존(3-A까지) 구조 — 큰 무대(흉상)+여자/남자/👕 의상 3탭+5열 그리드+하단 CTA —를
// 전면 재구성한다. 의상 탭/그리드(_outfitGrid·_wearOutfit)는 옷장 화면
// (wardrobe/wardrobe_screen.dart)으로 이미 분리됐으므로 이 화면에서는 완전히
// 제거하고, app3/guardians.jsx 1:1로 다음 구조만 남긴다:
//   1) 맨 위 「함께하는 수호자」 카드 — 큰 그림·이름·[👗 옷 갈아입히기][자세히]
//   2) 거르기 칩(전체/내 수호자/여성/남성)
//   3) 22명 그리드 — 탭하면 전부 「수호자 자세히」 시트(guardian_detail_sheet.dart)로
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/wr_nav_pill.dart';
import '../../core/wr_bottom_nav.dart';
import '../wallet/wallet_sheet.dart';
import 'guardian_detail_sheet.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../../core/wr_toast.dart';

class CharacterShopScreen extends StatefulWidget {
  const CharacterShopScreen({super.key});
  @override
  State<CharacterShopScreen> createState() => _CharacterShopScreenState();
}

class _CharacterShopScreenState extends State<CharacterShopScreen> {
  // app3/guardians.jsx `g` 1:1 — all | mine | F | M.
  String _filter = 'all';

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
    final room = p.room;
    if (!mounted || room == null) return;
    await p.loadOutfits(room.char);
  }

  int _leftDays(WishRoom? room, String key) {
    final unlockDay = (WrCatalog.I.raw['UNLOCK'] as Map)[key] as int? ?? 0;
    final dayN = room?.dayN ?? 1;
    return (unlockDay - dayN) < 1 ? 1 : (unlockDay - dayN);
  }

  // app3/guardians.jsx `outfitName` 1:1 — 지금 입은 의상의 표시 이름.
  String _outfitName(WishRoom room) {
    final cat = WrCatalog.I;
    if (room.outfitId != null) {
      final hit = cat.newOutfits
          .where((o) => o['id'] == room.outfitId)
          .toList();
      if (hit.isNotEmpty) return hit.first['name'] as String? ?? '사복';
    }
    final hit = cat.themes.where((t) => t['id'] == room.outfitNow.name).toList();
    return hit.isNotEmpty ? (hit.first['label'] as String? ?? '사복') : '사복';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        bottomNavigationBar: wrBottomNavBar(
          context,
          currentIndex: 1,
          onTabTap: (i) => wrReturnToTab(context, i),
        ),
        body: Consumer<WishRoomProvider>(
          builder: (context, p, __) {
            if (p.characters.isEmpty) {
              return SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          WrNavPill(
                            onBack: () => Navigator.of(context).maybePop(),
                            onExitHome: () => wrExitHome(context),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            '소원방을 지켜줄 수호자',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p.catalogError == null)
                                const CircularProgressIndicator()
                              else ...[
                                const Text(
                                  '수호자 정보를 불러오지 못했어요',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  p.catalogError!.message,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _init,
                                  child: const Text('다시 불러오기'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            final room = p.room;
            final cur = p.characters
                .where((c) => c.id == room?.char)
                .firstOrNull;
            final shopOpen = room?.isFeatureUnlocked('shop') ?? false;
            final list = p.characters.where((c) {
              switch (_filter) {
                case 'mine':
                  return p.me?.ownedChars.contains(c.id) ?? (c.price == 0);
                case 'F':
                case 'M':
                  return c.gender == _filter;
                default:
                  return true;
              }
            }).toList();
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(
                      children: [
                        WrNavPill(
                          onBack: () => Navigator.of(context).maybePop(),
                          onExitHome: () => wrExitHome(context),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              '소원방 수호자',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => openWalletSheet(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: WrC.glass,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/wishroom/items/pouch.png',
                                  width: 16,
                                  height: 16,
                                  errorBuilder: (_, __, ___) => const Text(
                                    '💰',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${p.me?.pouch ?? 0}',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSerifKR',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
                      children: [
                        Text(
                          'GUARDIANS · ${p.me?.ownedChars.length ?? 0} / ${p.characters.length}',
                          textAlign: TextAlign.center,
                          style: WrF.mono(size: 10.5),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '소원방을 지켜줄\n수호자',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSerifKR',
                            fontWeight: FontWeight.w900,
                            fontSize: 25,
                            height: 1.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── 함께하는 수호자 ──
                        if (cur != null && room != null) _curGuardianCard(room, cur),
                        const SizedBox(height: 18),
                        // ── 거르기 ──
                        Row(
                          children: [
                            for (final f in const [
                              ('all', '전체'),
                              ('mine', '내 수호자'),
                              ('F', '여성'),
                              ('M', '남성'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Semantics(
                                  identifier: 'guardian_filter_${f.$1}',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _filter = f.$1),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 7,
                                      ),
                                      decoration: _filter == f.$1
                                          ? WrDeco.chipOn
                                          : WrDeco.chip,
                                      child: Text(
                                        f.$2,
                                        style: WrF.body(
                                          12,
                                          w: FontWeight.w700,
                                          color: _filter == f.$1
                                              ? Colors.white
                                              : WrC.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!shopOpen)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: WrC.line,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: WrF.body(12, color: WrC.muted),
                                  children: [
                                    const TextSpan(text: '🔒 새 수호자는 '),
                                    TextSpan(
                                      text:
                                          '${_leftDays(room, 'shop')}일 뒤',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' 상점이 열리면 복주머니로 모실 수 있어요. 지금은 구경만 할 수 있어요.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: list.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: .72,
                          ),
                          itemBuilder: (_, i) => _guardianCard(
                            p,
                            room,
                            list[i],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _curGuardianCard(WishRoom room, WrCharacter cur) {
    final cat = WrCatalog.I;
    final unlocked = room.isFeatureUnlocked('wardrobe');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: WrC.card,
        border: Border.all(color: WrC.blossom2.withValues(alpha: .4)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.6, .9),
                  radius: 1.1,
                  colors: [
                    WrC.blossom.withValues(alpha: .28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 128,
                height: 156,
                child: Image.asset(
                  cat.charImage(cur.id, room.outfitNow, outfitId: room.outfitId),
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      cur.emblem,
                      style: const TextStyle(fontSize: 40, color: Colors.white54),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '함께하는 중',
                        style: WrF.mono(size: 9.5, color: WrC.blossom2),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: cur.name,
                              style: WrF.display(20, color: Colors.white),
                            ),
                            TextSpan(
                              text: '  ${cur.title}',
                              style: WrF.body(12, color: WrC.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '지금 옷 · ${_outfitName(room)}',
                        style: WrF.body(12, color: WrC.muted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              identifier: 'guardian_top_wardrobe',
                              button: true,
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (!unlocked) {
                                      WrToast.show(
                                        context,
                                        '옷장은 ${_leftDays(room, 'wardrobe')}일 뒤에 열려요',
                                      );
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const WardrobeScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: WrC.blossom,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    unlocked ? '👗 옷 갈아입히기' : '🔒 옷장',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Semantics(
                            identifier: 'guardian_top_detail',
                            button: true,
                            child: SizedBox(
                              height: 36,
                              child: OutlinedButton(
                                onPressed: () =>
                                    showGuardianDetailSheet(context, cur.id),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: WrC.line),
                                  backgroundColor: WrC.darkBtn,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: Text(
                                  '자세히',
                                  style: WrF.body(
                                    12.5,
                                    w: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
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
        ],
      ),
    );
  }

  Widget _guardianCard(WishRoomProvider p, WishRoom? room, WrCharacter c) {
    final cat = WrCatalog.I;
    final own = p.me?.ownedChars.contains(c.id) ?? (c.price == 0);
    final on = room?.char == c.id;
    final statusLabel = on
        ? '✓ 함께하는 중'
        : own
        ? '내 수호자'
        : c.grade == 'event'
        ? '이벤트로 만나요'
        : '🧧 ${c.price ?? 0}';
    final statusColor = on
        ? WrC.blossom2
        : own
        ? WrC.muted
        : (c.price == null ? const Color(0xFFFFB0D0) : WrC.glow);
    return Semantics(
      identifier: 'guardian_card_${c.id}',
      button: true,
      child: GestureDetector(
        onTap: () => showGuardianDetailSheet(context, c.id),
        child: Container(
          decoration: BoxDecoration(
            color: WrC.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? WrC.blossom2 : WrC.cardBorder,
              width: on ? 1.6 : 1,
            ),
            boxShadow: on
                ? const [BoxShadow(color: Color(0x40F2628F), blurRadius: 14)]
                : const [],
          ),
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                  child: Opacity(
                    opacity: own ? 1 : .75,
                    child: Image.asset(
                      cat.charImage(c.id, on ? (room?.outfitNow ?? WrTheme.free) : WrTheme.free),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          c.emblem,
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                c.name,
                style: WrF.body(11.5, w: FontWeight.w700, color: WrC.fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
