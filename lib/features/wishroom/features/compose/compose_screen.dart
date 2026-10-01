// SCR-02 소원 작성 `/compose` — docs/SCREENS.md §SCR-02
// 한지 카드(텍스트 100자) + 수호자 선택 + 테마/빛깔/종이 + 공개범위 + 봉인일 + CTA.
// 제출 성공 시 인장 stamp 연출 후 인트로(full)로 자연 전환(WishRoomIntroScreen push replacement).
import 'dart:ui';
import 'package:flutter/material.dart' hide Visibility;
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../intro/wish_room_intro_screen.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _textCtrl = TextEditingController();
  String? _char;
  Visibility _visibility = Visibility.PUBLIC;
  WrTheme _theme = WrTheme.free;
  String _wishColor = 'hope';
  String _paper = 'hanji';
  DateTime _sealUntil = DateTime.now().add(const Duration(days: 100));
  bool _submitting = false;
  bool _piiWarning = false;

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  List<WrCharacter> get _myChars {
    final me = context.read<WishRoomProvider>().me;
    final owned = me?.ownedChars ?? const ['F00', 'M00'];
    final all = WrCatalog.I.characters;
    final list = all.where((c) => owned.contains(c.id)).toList();
    return list.isEmpty ? all.take(2).toList() : list;
  }

  Future<void> _submit({bool force = false}) async {
    if (_textCtrl.text.trim().isEmpty || _char == null) return;
    setState(() => _submitting = true);
    final p = context.read<WishRoomProvider>();
    final ok = await p.createRoom(
      text: _textCtrl.text.trim(),
      char: _char!,
      sealUntil: _sealUntil.toIso8601String().substring(0, 10),
      visibility: _visibility,
      theme: _theme,
      wishColor: _wishColor,
      paper: _paper,
      force: force,
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WishRoomIntroScreen()));
      return;
    }
    final err = p.lastError;
    if (err?.code == 'PII_WARNING') {
      setState(() => _piiWarning = true);
    } else if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wr;
    final cat = WrCatalog.I;
    final hasHistory = context.watch<WishRoomProvider>().archiveRooms.isNotEmpty;
    return Theme(data: wrTheme(WrPalette.midnight), child: Scaffold(
      backgroundColor: c.bg2,
      body: Stack(fit: StackFit.expand, children: [
        ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            .45,0,0,0,0, 0,.45,0,0,0, 0,0,.45,0,0, 0,0,0,1,0,
          ]),
          child: Image.asset('assets/wishroom/room-main.jpg', fit: BoxFit.cover),
        )),
        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.close, color: c.fg)),
            ]),
            Text(hasHistory ? '새로운 마음을\n담아볼까요' : '소원을 담을\n준비가 되셨나요',
                style: WrType.display2(c.fg)),
            const SizedBox(height: 18),
            // 한지 카드
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xF7FFF4E2), Color(0xF2F7E2C8)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_dateLabel(), style: const TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 11, color: Color(0x993C2D1E))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textCtrl,
                    maxLength: 100,
                    maxLines: 4,
                    style: const TextStyle(fontFamily: 'GowunBatangWish', fontSize: 17, height: 1.65, color: Color(0xFF4A2A1C)),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: '이곳에 소원을 적어주세요', counterStyle: TextStyle(color: Color(0x663C2D1E))),
                  ),
                ]),
                Positioned(right: 0, top: 0, child: Transform.rotate(angle: -6 * 3.14159 / 180,
                  child: Container(width: 34, height: 34, alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFC94A3B), borderRadius: BorderRadius.circular(6)),
                    child: const Text('願', style: TextStyle(fontFamily: 'NotoSerifKRWish', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFFFF9E8)))))),
              ]),
            ),
            if (_piiWarning) Padding(padding: const EdgeInsets.only(top: 10), child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x33C94A3B), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('개인정보로 보일 수 있는 내용이 담겨 있어요', style: TextStyle(color: c.fg, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(onPressed: () => setState(() => _piiWarning = false), child: const Text('고쳐 쓸게요')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => _submit(force: true), child: const Text('그대로 담기')),
                ]),
              ]),
            )),
            const SizedBox(height: 24),
            Text('수호자 선택', style: WrType.h3(c.fg)),
            const SizedBox(height: 10),
            SizedBox(height: 120, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _myChars.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final ch = _myChars[i];
                final sel = _char == ch.id;
                return GestureDetector(onTap: () => setState(() => _char = ch.id), child: Container(
                  width: 96,
                  decoration: BoxDecoration(
                    color: sel ? c.card : Colors.transparent,
                    border: Border.all(color: sel ? c.accent : c.line, width: sel ? 2 : 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Expanded(child: Image.asset(cat.charImage(ch.id, WrTheme.free), fit: BoxFit.contain)),
                    const SizedBox(height: 4),
                    Text(ch.name, style: TextStyle(color: c.fg, fontSize: 12)),
                  ]),
                ));
              },
            )),
            const SizedBox(height: 22),
            Text('테마', style: WrType.h3(c.fg)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: cat.themes.map((t) {
              final id = t['id'] as String;
              final sel = _theme.name == id;
              return GestureDetector(onTap: () => setState(() => _theme = WrTheme.values.byName(id)), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(999)),
                child: Text('${t['glyph']} ${t['label']}', style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 13)),
              ));
            }).toList()),
            const SizedBox(height: 22),
            Text('소원 빛깔', style: WrType.h3(c.fg)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: cat.wishColors.map((w) {
              final id = w['id'] as String;
              final sel = _wishColor == id;
              return GestureDetector(onTap: () => setState(() => _wishColor = id), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _hex(w['color'] as String) : c.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: sel ? _hex(w['deep'] as String) : c.line),
                ),
                child: Text('${w['hanja']} ${w['label']}', style: TextStyle(color: sel ? const Color(0xFF2A1F14) : c.fg, fontSize: 12)),
              ));
            }).toList()),
            const SizedBox(height: 22),
            Text('종이', style: WrType.h3(c.fg)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: cat.papers.map((pp) {
              final id = pp['id'] as String;
              final sel = _paper == id;
              final bg = (pp['bg'] as List).cast<String>();
              return GestureDetector(onTap: () => setState(() => _paper = id), child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_hex(bg[0]), _hex(bg[1])]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? c.accent : Colors.transparent, width: 2),
                ),
              ));
            }).toList()),
            const SizedBox(height: 22),
            Text('공개 범위', style: WrType.h3(c.fg)),
            const SizedBox(height: 10),
            Row(children: [
              _seg('모두에게', Visibility.PUBLIC, c),
              const SizedBox(width: 6),
              _seg('링크로만', Visibility.LINK, c),
              const SizedBox(width: 6),
              _seg('나만 보기', Visibility.PRIVATE, c),
            ]),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
              onPressed: _submitting || _char == null ? null : () => _submit(),
              style: ElevatedButton.styleFrom(backgroundColor: c.accent, disabledBackgroundColor: c.accent.withValues(alpha: .4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('🕯 촛불에 봉인하고 소원방 만들기', style: TextStyle(fontFamily: 'GowunBatangWish', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
            )),
          ]),
        )),
      ]),
    ));
  }

  Widget _seg(String label, Visibility v, WrColors c) {
    final sel = _visibility == v;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _visibility = v), child: Container(
      height: 40, alignment: Alignment.center,
      decoration: BoxDecoration(color: sel ? c.accent : c.card, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: sel ? Colors.white : c.fg, fontSize: 13)),
    )));
  }

  String _dateLabel() {
    final now = DateTime.now();
    return '${now.year}. ${now.month}. ${now.day}';
  }
}

Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
