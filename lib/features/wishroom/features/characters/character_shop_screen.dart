// SCR-05 캐릭터 선택/상점 `/vault/guardians` — app2/screens-b2.jsx › CharShop() 1:1 이식
// 무대(흉상 + 방사광선 + 등급칩 + 대사) + 탭(여자/남자/👕 의상) + 5열 그리드(캐릭터) / 2열 그리드(의상)
// + 정보 시트(직업·성향·좋아하는 것·수호 기운·등급·성격·동작) + 복주머니 부족 시트
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';

class CharacterShopScreen extends StatefulWidget {
  const CharacterShopScreen({super.key});
  @override
  State<CharacterShopScreen> createState() => _CharacterShopScreenState();
}

class _CharacterShopScreenState extends State<CharacterShopScreen> {
  String _gender = 'F';
  String? _selId; // sel
  String _ptab = 'char'; // char | outfit
  WrTheme? _wear; // 의상 미리보기(아직 저장 안함)
  bool _busy = false;
  bool _info = false;
  ApiError? _shortErr;
  String? _shortLabel;

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    if (!p.catalogLoaded) p.loadCatalog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final me = context.read<WishRoomProvider>().me;
      if (me != null) {
        setState(() {
          _selId = me.repChar;
          _gender = _selId!.startsWith('M') ? 'M' : 'F';
        });
        _loadOutfits(_selId!);
      }
    });
  }

  Future<void> _loadOutfits(String char) async {
    await context.read<WishRoomProvider>().loadOutfits(char);
  }

  void _selectChar(WrCharacter ch) {
    setState(() { _selId = ch.id; _wear = null; });
    _loadOutfits(ch.id);
  }

  Future<void> _act(WrCharacter c, bool owned) async {
    if (_busy) return;
    setState(() => _busy = true);
    final p = context.read<WishRoomProvider>();
    if (!owned) {
      final ok = await p.buyCharacter(c.id);
      if (!mounted) return;
      if (!ok) {
        setState(() => _busy = false);
        final err = p.lastError;
        if (err?.code == 'INSUFFICIENT') {
          setState(() { _shortErr = err; _shortLabel = c.name; });
        } else if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
        }
        return;
      }
    }
    final ok2 = await p.setCharacter(c.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.name}이(가) 소원방을 함께 지켜요')));
    } else if (p.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.lastError!.message)));
    }
  }

  Future<void> _wearOutfit(WrCharacter c, OutfitOffer o) async {
    if (_busy) return;
    final p = context.read<WishRoomProvider>();
    if (!(p.me?.ownedChars.contains(c.id) ?? false) && c.price != 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 이 수호자와 함께해 주세요')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (!o.owned) {
        final ok = await p.buyOutfit(c.id, o.theme);
        if (!ok) {
          if (!mounted) return;
          setState(() => _busy = false);
          final err = p.lastError;
          final themeInfo = WrCatalog.I.themes.where((t) => t['id'] == o.theme.name).toList();
          final label = themeInfo.isNotEmpty ? themeInfo.first['label'] as String : '';
          if (err?.code == 'INSUFFICIENT') {
            setState(() { _shortErr = err; _shortLabel = '$label 의상'; });
          } else if (err != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
          }
          return;
        }
        await _loadOutfits(c.id);
      }
      final room = p.room;
      if (room != null) {
        if (room.char != c.id) await p.setCharacter(c.id);
        await p.setOutfit(room.id, o.theme);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      final themeInfo = WrCatalog.I.themes.where((t) => t['id'] == o.theme.name).toList();
      final label = themeInfo.isNotEmpty ? themeInfo.first['label'] as String : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.name} · $label 의상으로 갈아입었어요')));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = WrCatalog.I;
    return Theme(data: wrThemeData(), child: Scaffold(
      backgroundColor: WrC.bg2,
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final genderList = p.characters.where((ch) => ch.gender == _gender).toList();
        final id = _selId ?? p.me?.repChar ?? (genderList.isNotEmpty ? genderList.first.id : null);
        final c = p.characters.where((ch) => ch.id == id).firstOrNull;
        final owned = c != null && (p.me?.ownedChars.contains(c.id) ?? (c.price == 0));
        final room = p.room;
        final outfitTheme = _wear ?? (room != null && c != null && room.char == c.id ? room.outfitNow : WrTheme.free);

        return Stack(children: [
          Column(children: [
            // ── 무대 ──
            SizedBox(height: 330, child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF2A1020), Color(0xFF12060E)])))),
              // 방사 광선
              Positioned(left: 0, right: 0, top: 40, height: 290, child: IgnorePointer(child: Stack(alignment: Alignment.bottomCenter, children: [
                ...List.generate(14, (i) {
                  final angle = i * 25.7 * 3.14159 / 180;
                  return Transform.rotate(angle: angle, alignment: Alignment.bottomCenter, child: Container(
                    width: 2, height: 180, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0x99FFC8DC), Colors.transparent]))));
                }),
                Container(width: 280, height: 60, decoration: const BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x80FFA0BE), Colors.transparent]))),
              ]))),
              if (c != null) Positioned(right: 6, bottom: 0, child: GestureDetector(
                onTap: () => setState(() => _info = true),
                child: Opacity(opacity: owned ? 1 : .6, child: Image.asset(
                  cat.charImage(c.id, outfitTheme), height: 320, width: 229, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => SizedBox(width: 229, height: 320, child: Center(child: Text(c.emblem, style: const TextStyle(fontSize: 64, color: Colors.white54)))),
                )),
              )),
              if (c != null) Positioned(left: 20, top: 30, width: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (c.grade == 'rare') _gradeChip('레어', const [Color(0xFFB88AFF), Color(0xFFFF8FB1)])
                else if (c.grade == 'event') _gradeChip('이벤트', const [Color(0xFFF5CF6A), Color(0xFFFF8FB1)])
                else _gradeChip('기본', null),
                const SizedBox(height: 10),
                Text(c.name, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 30, color: Colors.white)),
                Text(c.title, style: WrF.body(13, color: WrC.muted)),
                Padding(padding: const EdgeInsets.only(top: 12), child: GestureDetector(
                  onTap: () => setState(() => _info = true),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0x59000000), borderRadius: BorderRadius.circular(999)),
                    child: Text('ⓘ 기본 정보 보기', style: WrF.body(11.5, w: FontWeight.w700, color: Colors.white))),
                )),
                Padding(padding: const EdgeInsets.only(top: 12), child: Text('"${c.line}"',
                  style: WrF.body(12.5, color: Colors.white, height: 1.55))),
              ])),
              Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white)),
                  const Expanded(child: Center(child: Text('소원방 캐릭터', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: WrC.glass, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('💰', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text('${p.me?.pouch ?? 0}', style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                    ])),
                  const SizedBox(width: 44), // 좌측 뒤로가기 버튼과 균형
                ]),
              ))),
            ])),
            // ── 목록 패널 ──
            Expanded(child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF53A1628), Color(0xFF1A0812)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0x40FFBED2))),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: Row(children: [
                  _tab('여자', _ptab == 'char' && _gender == 'F', () => setState(() { _ptab = 'char'; _gender = 'F'; })),
                  const SizedBox(width: 6),
                  _tab('남자', _ptab == 'char' && _gender == 'M', () => setState(() { _ptab = 'char'; _gender = 'M'; })),
                  const SizedBox(width: 6),
                  _tab('👕 의상', _ptab == 'outfit', () => setState(() => _ptab = 'outfit')),
                ])),
                Expanded(child: _ptab == 'outfit'
                    ? _outfitGrid(p, c)
                    : _charGrid(p, genderList, id)),
                Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), child: _ctaButton(p, c, owned, outfitTheme)),
              ]),
            )),
          ]),
          if (_info && c != null) _infoSheet(c),
          if (_shortErr != null) _shortageSheet(_shortErr!, _shortLabel ?? ''),
        ]);
      }),
    ));
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => Expanded(child: GestureDetector(onTap: onTap, child: Container(
      height: 34, alignment: Alignment.center,
      decoration: on ? WrDeco.tabOn : BoxDecoration(borderRadius: BorderRadius.circular(10), color: WrC.tabsBg),
      child: Text(label, style: WrF.body(13, w: FontWeight.w700, color: on ? Colors.white : WrC.muted)),
    )));

  Widget _gradeChip(String label, List<Color>? colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: colors != null ? LinearGradient(colors: colors) : null,
          color: colors == null ? WrC.chipBg : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 10.5, color: Colors.white)),
      );

  Widget _charGrid(WishRoomProvider p, List<WrCharacter> list, String? selId) {
    final cat = WrCatalog.I;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 7, crossAxisSpacing: 7, childAspectRatio: .72),
      itemBuilder: (_, i) {
        final ch = list[i];
        final isOwned = p.me?.ownedChars.contains(ch.id) ?? (ch.price == 0);
        final isSel = selId == ch.id;
        return GestureDetector(onTap: () => _selectChar(ch), child: Container(
          decoration: BoxDecoration(
            color: WrC.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? WrC.blossom2 : WrC.cardBorder, width: isSel ? 1.6 : 1),
            boxShadow: isSel ? const [BoxShadow(color: Color(0x40F2628F), blurRadius: 14)] : const [],
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(children: [
            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Opacity(opacity: isOwned ? 1 : .65, child: Image.asset(cat.charImage(ch.id, WrTheme.free), fit: BoxFit.cover, width: double.infinity,
                errorBuilder: (_, __, ___) => Center(child: Text(ch.emblem, style: const TextStyle(fontSize: 22, color: Colors.white54))))))),
            const SizedBox(height: 3),
            Text(ch.name, style: WrF.body(10.5, w: FontWeight.w700, color: WrC.fg), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(p.me?.repChar == ch.id ? '대표' : isOwned ? '보유' : (ch.grade == 'event' ? '이벤트' : '${ch.price ?? 0}'),
              style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 9.5, color: isOwned ? WrC.blossom2 : WrC.glow)),
          ]),
        ));
      },
    );
  }

  Widget _outfitGrid(WishRoomProvider p, WrCharacter? c) {
    final cat = WrCatalog.I;
    final offers = p.outfitOffers;
    final room = p.room;
    if (c == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(style: WrF.body(12, color: WrC.muted, height: 1.6), children: [
          TextSpan(text: c.name, style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)),
          const TextSpan(text: '의 테마 의상 · 소원방 테마에 맞는 의상을 입으면 방 분위기와 잘 어울려요'),
        ])),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 1.35),
          itemBuilder: (_, i) {
            final o = offers[i];
            final themeInfo = cat.themes.where((t) => t['id'] == o.theme.name).toList();
            final T = themeInfo.isNotEmpty ? themeInfo.first : null;
            if (T == null) return const SizedBox.shrink();
            final cur = room != null && room.char == c.id && room.outfitNow == o.theme;
            final pv = _wear == o.theme;
            final tColor = _hex(T['color'] as String);
            return GestureDetector(onTap: () => setState(() => _wear = o.theme), child: Container(
              decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pv || cur ? tColor : WrC.cardBorder, width: pv || cur ? 1.6 : 1),
                boxShadow: pv ? [BoxShadow(color: tColor.withValues(alpha: .4), blurRadius: 16)] : const []),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Stack(children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(colors: [tColor.withValues(alpha: .27), Colors.transparent])))),
                  Positioned.fill(child: Opacity(opacity: o.hasArt || o.theme == WrTheme.free ? 1 : .4,
                    child: Image.asset(cat.charImage(c.id, o.theme), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(child: Text(T['glyph'] as String, style: const TextStyle(fontSize: 28)))))),
                  if (!o.hasArt && o.theme != WrTheme.free) Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(999)),
                    child: const Text('그림 준비 중', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white)))),
                  Positioned(left: 8, top: 8, child: Text(T['glyph'] as String, style: const TextStyle(fontSize: 18))),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${T['label']} 의상', style: WrF.body(13, w: FontWeight.w700, color: WrC.fg)),
                  const SizedBox(height: 2),
                  Text(T['outfitHint'] as String? ?? '', style: WrF.body(10.5, color: WrC.muted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(cur ? '✓ 입고 있어요' : o.owned ? '보유' : (o.hasArt ? '🧧 ${o.price}' : '곧 만나요'),
                    style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 11, color: cur ? tColor : (o.owned ? WrC.muted : WrC.glow))),
                ])),
              ]),
            ));
          },
        ),
      ]),
    );
  }

  Widget _ctaButton(WishRoomProvider p, WrCharacter? c, bool owned, WrTheme outfitTheme) {
    if (c == null) return const SizedBox.shrink();
    if (_ptab == 'outfit') {
      final offer = p.outfitOffers.where((o) => o.theme == (_wear ?? WrTheme.free)).firstOrNull;
      if (offer == null) return const SizedBox.shrink();
      final themeInfo = WrCatalog.I.themes.where((t) => t['id'] == offer.theme.name).toList();
      final T = themeInfo.isNotEmpty ? themeInfo.first : null;
      if (T == null) return const SizedBox.shrink();
      if (!offer.hasArt && offer.theme != WrTheme.free) {
        return SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
          child: Text('${T['glyph']} ${T['label']} 의상은 준비 중이에요', style: WrF.body(14, color: Colors.white54)),
        ));
      }
      return SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _busy ? null : () => _wearOutfit(c, offer),
        style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
        child: Text(offer.owned ? '${T['glyph']} ${T['label']} 의상 입기' : '🧧 ${offer.price} · ${T['label']} 의상 입기',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ));
    }
    if (p.me?.repChar == c.id) {
      return SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
        child: Text('지금 소원방을 지키는 중', style: WrF.body(14, color: Colors.white54)),
      ));
    }
    if (c.grade == 'event' && !owned) {
      return SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: WrC.darkBtn),
        child: Text('이벤트 미션으로 만날 수 있어요', style: WrF.body(14, color: Colors.white54)),
      ));
    }
    return SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
      onPressed: _busy ? null : () => _act(c, owned),
      style: ElevatedButton.styleFrom(backgroundColor: owned ? WrC.blossom : WrC.glow),
      child: Text(owned ? '대표 캐릭터로 설정' : '💰 ${c.price ?? 0} · 함께하기',
        style: TextStyle(color: owned ? Colors.white : const Color(0xFF4A2A10), fontWeight: FontWeight.w700, fontSize: 15)),
    ));
  }

  Widget _infoSheet(WrCharacter c) {
    final cat = WrCatalog.I;
    final w = cat.wishColors.where((x) => x['id'] == c.aura).toList();
    final W = w.isNotEmpty ? w.first : null;
    const behaviorLabel = {
      Behavior.gaze: '촛불 바라보기', Behavior.pray: '두 손 모으기', Behavior.flower: '꽃 바라보기',
      Behavior.pouch: '복주머니 받기', Behavior.celebrate: '소원 완료 축하', Behavior.idle: '',
    };
    const gradeLabel = {'basic': '기본', 'normal': '일반', 'rare': '레어', 'event': '이벤트'};
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => setState(() => _info = false), child: Container(color: const Color(0x80000000)))),
      Positioned(left: 10, right: 10, bottom: 22, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('GUARDIAN · ${c.id}', style: WrF.mono(size: 10.5)),
          const SizedBox(height: 4),
          Text('${c.name} · ${c.title}', style: WrF.display(18, color: Colors.white)),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 96, height: 128, clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: WrC.line),
                gradient: const RadialGradient(colors: [Color(0x59FFA0BE), Colors.transparent])),
              child: Image.asset(cat.charImage(c.id, WrTheme.free), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: Text(c.emblem, style: const TextStyle(fontSize: 32, color: Colors.white54))))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('직업', c.job ?? '—'),
              _infoRow('성향', c.type ?? '—'),
              _infoRow('좋아하는 것', c.likes ?? '—'),
              _infoRow('수호 기운', W != null ? '${W['hanja']} · ${W['label']}' : '—', color: W != null ? _hex(W['color'] as String) : null),
              _infoRow('등급', '${gradeLabel[c.grade] ?? c.grade}${(c.price ?? 0) > 0 ? ' · 복주머니 ${c.price}' : ' · 무료'}'),
            ])),
          ]),
          Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: WrDeco.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('성격', style: WrF.mono(size: 10, color: WrC.blossom2)),
              const SizedBox(height: 6),
              Text(c.personality ?? '', style: WrF.body(13.5, color: Colors.white, height: 1.65)),
            ])),
          if (c.behaviors.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 6, runSpacing: 6,
            children: c.behaviors.map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: WrDeco.chip,
              child: Text('✦ ${behaviorLabel[b] ?? ''}', style: WrF.body(11, color: WrC.fg)),
            )).toList())),
          Padding(padding: const EdgeInsets.only(top: 16), child: Center(child: Text('"${c.line}"',
            style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFFFE6D0))))),
        ]),
      )),
    ]);
  }

  Widget _infoRow(String k, String v, {Color? color}) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 70, child: Text(k, style: WrF.body(12.5, color: WrC.muted))),
        Expanded(child: Text(v, style: WrF.body(12.5, w: FontWeight.w700, color: color ?? Colors.white))),
      ]));

  Widget _shortageSheet(ApiError e, String name) {
    return Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () => setState(() => _shortErr = null), child: Container(color: const Color(0x80000000)))),
      Positioned(left: 10, right: 10, bottom: 22, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: WrDeco.sheet,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text('NEED MORE', style: WrF.mono(size: 10.5)),
          const SizedBox(height: 4),
          Text('복주머니가 조금 부족해요', style: WrF.display(18, color: Colors.white)),
          const SizedBox(height: 14),
          Text(name, style: WrF.body(14, w: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('복주머니 ${e.need ?? '-'}개 필요', style: WrF.body(12.5, color: WrC.muted)),
          const SizedBox(height: 10),
          Text('지금 ${e.have ?? 0}개 · ${(e.need ?? 0) - (e.have ?? 0)}개 더 모으면 돼요', style: WrF.body(14, color: Colors.white, height: 1.7)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: () => setState(() => _shortErr = null),
            style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
            child: const Text('복주머니 모으러 가기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    ]);
  }
}

Color _hex(String s) { final h = s.replaceFirst('#', ''); return Color(int.parse('FF$h', radix: 16)); }
