// SCR-05 캐릭터 `/vault/guardians` — docs/SCREENS.md §SCR-05
// 무대(흉상 + 방사광선) + 탭(여자/남자) + 5열 그리드 + CTA(대표설정/구매).
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
  WrCharacter? _selected;

  @override
  void initState() {
    super.initState();
    final p = context.read<WishRoomProvider>();
    if (!p.catalogLoaded) p.loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    // [버그수정] Theme(...) 적용 전 context에는 WrColors extension이 없어
    // context.wr(null-check)가 터진다. midnight 고정이므로 상수를 직접 참조.
    const c = WrColors.midnight;
    final cat = WrCatalog.I;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text('캐릭터', style: TextStyle(color: c.fg)),
        iconTheme: IconThemeData(color: c.fg)),
      body: Consumer<WishRoomProvider>(builder: (context, p, __) {
        final list = p.characters.where((ch) => ch.gender == _gender).toList();
        final sel = _selected ?? (list.isNotEmpty ? list.first : null);
        final owned = sel != null && p.me != null && (p.me!.ownedChars.contains(sel.id));
        return Column(children: [
          SizedBox(height: 330, child: Stack(alignment: Alignment.center, children: [
            ...List.generate(14, (i) {
              final angle = i / 14 * 2 * 3.14159;
              return Transform.rotate(angle: angle, child: Container(
                width: 2, height: 160, margin: const EdgeInsets.only(bottom: 160),
                color: const Color(0x1AF5CF6A)));
            }),
            if (sel != null) Column(children: [
              const SizedBox(height: 20),
              Opacity(opacity: owned ? 1 : .6, child: Image.asset(cat.charImage(sel.id, WrTheme.free), height: 220, fit: BoxFit.contain)),
              const SizedBox(height: 8),
              if (sel.grade == 'rare') _gradeChip('레어', const [Color(0xFFB88AFF), Color(0xFFFF8FB1)])
              else if (sel.grade == 'event') _gradeChip('이벤트', const [Color(0xFFF5CF6A), Color(0xFFFF8FB1)]),
              Text(sel.name, style: const TextStyle(fontFamily: 'NotoSerifKRWish', fontSize: 30, color: Colors.white)),
              Text(sel.title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (sel.behaviors.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: sel.behaviors.map((b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text(b.name, style: const TextStyle(color: Colors.white70, fontSize: 10)))).toList())),
            ]),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            _genderTab('여자 캐릭터', 'F', c),
            const SizedBox(width: 8),
            _genderTab('남자 캐릭터', 'M', c),
          ])),
          const SizedBox(height: 10),
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemBuilder: (_, i) {
              final ch = list[i];
              final isOwned = p.me?.ownedChars.contains(ch.id) ?? (ch.price == 0);
              final isSel = sel?.id == ch.id;
              return GestureDetector(onTap: () => setState(() => _selected = ch), child: Container(
                decoration: BoxDecoration(
                  color: c.card, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSel ? c.accent : c.line, width: isSel ? 2 : 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Opacity(opacity: isOwned ? 1 : .5, child: Image.asset(cat.charImage(ch.id, WrTheme.free), fit: BoxFit.contain)),
              ));
            },
          )),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: sel == null || sel.grade == 'event' ? null : () => _onCta(sel, owned),
              style: ElevatedButton.styleFrom(backgroundColor: owned ? c.accent : const Color(0xFFF5CF6A)),
              child: Text(
                sel == null ? '' : (owned ? '대표 캐릭터로 설정' : '💰${sel.price ?? 0} · 함께하기'),
                style: TextStyle(color: owned ? Colors.white : const Color(0xFF4A2A10), fontWeight: FontWeight.w700),
              ),
            ),
          )),
        ]);
      }),
    ));
  }

  Widget _gradeChip(String label, List<Color> colors) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      );

  Widget _genderTab(String label, String g, WrColors c) {
    final sel = _gender == g;
    return Expanded(child: GestureDetector(onTap: () => setState(() { _gender = g; _selected = null; }), child: Container(
      height: 38, alignment: Alignment.center,
      decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 13)),
    )));
  }

  Future<void> _onCta(WrCharacter ch, bool owned) async {
    final p = context.read<WishRoomProvider>();
    if (owned) {
      await p.setCharacter(ch.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('대표 캐릭터로 설정했어요')));
      return;
    }
    final ok = await p.buyCharacter(ch.id);
    if (!ok && mounted) {
      final err = p.lastError;
      if (err?.code == 'INSUFFICIENT') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('복주머니가 부족해요')));
      } else if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
      }
    }
  }
}
