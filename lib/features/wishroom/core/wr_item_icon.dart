// 상점/시트 공용 아이템 썸네일 — app2/fx2.jsx › ItemIcon({it, size}) 1:1.
//
// [버그수정 — 전수감사] decor_screen.dart의 _itemGrid/_itemCardSheet/_shortageSheet와
// character_shop_screen.dart의 Shortage가 전부 `it.asset != null ? Image : Text(glyph)`
// 제네릭 폴백만 썼다. 하지만 원본 데이터(wishroom_data.json)에서 SEAL(10종)·CANDLE(9종)·
// BACKGROUND(9종) 슬롯 아이템은 `img` 필드가 전부 null이라 glyph도 없어(SEAL/BACKGROUND는
// `glyph` 필드 자체가 없음) 제네릭 폴백이 '✦' 하나로만 뭉개 보여줬다. 원본 ItemIcon은
// 슬롯별로 완전히 다른 비주얼을 쓴다:
//   - THEME(img 없음): tier색 방사형 글로우 배경 + glyph
//   - SEAL: 슬롯 전용 한자(hanja) + 아이템 고유색(color) 그라디언트 박스, -5deg 회전
//   - CANDLE: assets/items/{id}.png (촛불류는 사실 이미지 자체가 있음 — 아래 확인)
//   - BACKGROUND: 원형 창(window) 썸네일 + winFilter/tint
//   - 그 외 img 없음: ◇ 플레이스홀더
//   - img 있음: 일반 PNG
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/wr_catalog.dart';
import 'theme/wr_theme.dart';

class WrItemIcon extends StatelessWidget {
  const WrItemIcon({super.key, required this.it, this.size = 60});
  final WrItem it;
  final double size;

  Map<String, dynamic>? get _raw {
    final list = WrCatalog.I.raw['ITEMS'] as List?;
    if (list == null) return null;
    for (final e in list) {
      if (e is Map && e['id'] == it.id) return Map<String, dynamic>.from(e);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String slot = it.slot.name;
    final String? img = it.img;
    final String? glyph = it.glyph;

    // THEME & !img: tier색 방사형 글로우 + glyph.
    if (slot == 'THEME' && img == null) {
      const tierColor = {'free': Color(0xFFC8F5D4), 'normal': Color(0xFFFFE08A), 'special': Color(0xFFE8C8FF)};
      final c = tierColor[it.tier] ?? const Color(0xFFFFE08A);
      return Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .28),
          gradient: RadialGradient(colors: [c.withValues(alpha: .2), Colors.transparent], stops: const [0, .7]),
        ),
        child: Text(glyph ?? '✦', style: TextStyle(fontSize: size * .56)),
      );
    }

    // SEAL: hanja + 고유색 그라디언트 박스, -5deg 회전.
    if (slot == 'SEAL') {
      final colorHex = it.color;
      final c = colorHex != null ? _hex(colorHex) : const Color(0xFFC94A3B);
      final hanja = it.hanja ?? '';
      return Transform.rotate(
        angle: -5 * 3.14159265 / 180,
        child: Container(
          width: size * .8, height: size * .8, alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .12),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [c, c.withValues(alpha: .8), const Color(0xFF3A1010)], stops: const [0, .6, 1]),
            boxShadow: [BoxShadow(color: c.withValues(alpha: .53), blurRadius: 14)],
          ),
          child: Text(hanja, style: TextStyle(fontFamily: 'Noto Serif KR', fontWeight: FontWeight.w900, fontSize: size * .42, color: const Color(0xFFFFF4E0))),
        ),
      );
    }

    // CANDLE: assets/wishroom/items/{id}.png + glow 필터(근사 — drop-shadow).
    if (slot == 'CANDLE') {
      final glow = _rawField('glow') as String? ?? '#ffd98a';
      final c = _hex(glow);
      return SizedBox(width: size * 1.2, height: size * 1.2, child: Stack(alignment: Alignment.center, children: [
        Container(width: size * .9, height: size * .9, decoration: BoxDecoration(shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: c.withValues(alpha: .53), blurRadius: 16)])),
        Image.asset('assets/wishroom/items/${it.id}.png', width: size * 1.2, height: size * 1.2,
          errorBuilder: (_, __, ___) => Text(glyph ?? '🕯', style: TextStyle(fontSize: size * .6))),
      ]));
    }

    // BACKGROUND: 원형 창 썸네일(win 이미지 또는 기본 밤하늘) + tint 오버레이.
    if (slot == 'BACKGROUND') {
      final win = _rawField('win') as String?;
      final tint = _rawField('tint') as String?;
      final asset = win != null ? 'assets/wishroom/${win.replaceFirst('assets/', '')}' : 'assets/wishroom/room-empty.jpg';
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6A3A22), width: 3),
          boxShadow: const [BoxShadow(color: Color(0x59FFDCB4), blurRadius: 14)]),
        child: ClipOval(child: Stack(fit: StackFit.expand, children: [
          Image.asset(asset, fit: BoxFit.cover, alignment: const Alignment(0, -.68),
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF2A1230))),
          if (tint != null) DecoratedBox(decoration: BoxDecoration(color: _rgba(tint))),
        ])),
      );
    }

    if (img == null) {
      return SizedBox(width: size, height: size,
        child: Center(child: Text('◇', style: TextStyle(color: WrC.muted, fontSize: 22))));
    }
    return Image.asset(it.asset!, width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(child: Text(glyph ?? '✦', style: TextStyle(fontSize: size * .7))));
  }

  Object? _rawField(String k) => _raw?[k];
}

Color _hex(String s) { final h = s.replaceFirst('#', ''); return Color(int.parse('FF$h', radix: 16)); }

/// `rgba(r,g,b,a)` 문자열 파싱 — BACKGROUND tint 필드용.
Color _rgba(String s) {
  final m = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s);
  if (m == null) return Colors.transparent;
  final parts = m.group(1)!.split(',').map((e) => e.trim()).toList();
  final r = int.parse(parts[0]), g = int.parse(parts[1]), b = int.parse(parts[2]);
  final a = parts.length > 3 ? double.parse(parts[3]) : 1.0;
  return Color.fromRGBO(r, g, b, a);
}
