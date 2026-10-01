// 신통방통 소원방 · 방 배치 좌표 — prototype/app/room-layout.js 1:1 이식 (앱 방 · 꾸미기 · 배경화면 공용)
// 좌표계 = 390×844 캔버스. 실제 화면에서는 scale = screenWidth / 390 으로 곱하세요.
// 기본 방 = assets/wishroom/room-empty.jpg (창 · 탁자 · 연꽃 촛불 · 방석 · 빈 선반 · 벽 등잔만)
// → 방에 보이는 물건은 전부 "레벨 해금" 또는 "사용자가 고른 꾸미기"에서만 나옵니다.
import 'dart:ui';
import '../../data/models.dart';

class Anchor { final double x, y, len; const Anchor(this.x, this.y, [this.len = 0]); }

class RoomLayout {
  static const canvas = Size(390, 844);
  static const roomImg = 'assets/wishroom/room-empty.jpg';
  /// 둥근 창 — 배경(BACKGROUND) 아이템은 이 원 안의 창밖 풍경만 바꿉니다
  static const windowCx = 195.0, windowCy = 214.0, windowR = 131.0;

  /// 종류별 자리. 장착 순서대로 빈 자리에 배치. 한 종류가 차면 float → stand → hang 순으로 넘김
  static const anchors = <String, List<Anchor>>{
    'hang':  [Anchor(70, 58, 58), Anchor(320, 58, 70), Anchor(122, 58, 30), Anchor(268, 58, 38), Anchor(176, 58, 16), Anchor(218, 58, 20)], // y = 천장 고정점, len = 끈 길이
    'stand': [Anchor(298, 352), Anchor(262, 566), Anchor(366, 298), Anchor(366, 402), Anchor(146, 348)],                                   // x = 중심, y = 바닥
    'seal':  [Anchor(110, 540), Anchor(300, 540), Anchor(366, 350)],
    'float': [Anchor(52, 250), Anchor(340, 196), Anchor(252, 150), Anchor(132, 168), Anchor(318, 460)],                                    // x,y = 중심
  };
  static const flower = (x: 336.0, y: 596.0, s: 96.0);                 // 꽃 — 오른쪽 아래
  static const candle = (x: 204.0, y: 560.0, s: 250.0, flameY: 330.0); // 장착 촛불 — 탁자 위

  /// 레벨 해금 §5 — 물건은 가장자리에만, 나머지는 빛·파티클
  static const unlocks = <int, Map<String, Object>>{
    2:  {'name': '작은 정성', 'say': '창가에 첫 꽃잎이 날리기 시작했어요', 'icon': 'petal', 'focus': [195, 214], 'items': []},
    3:  {'name': '향로 등장', 'say': '작은 향로에서 향이 피어올라요', 'icon': 'incense', 'focus': [150, 330], 'items': [{'img': 'incense', 'x': 150, 'y': 346, 's': 46, 'kind': 'stand', 'smoke': true}]},
    4:  {'name': '등불 추가', 'say': '양쪽 기둥에 등불이 켜졌어요', 'icon': 'lantern', 'focus': [195, 150], 'items': [{'img': 'lantern', 'x': 10, 'y': 52, 's': 54, 'kind': 'hang', 'len': 110}, {'img': 'lantern', 'x': 380, 'y': 52, 's': 54, 'kind': 'hang', 'len': 110}]},
    5:  {'name': '소원함 빛남', 'say': '촛불 받침이 은은하게 빛나요', 'icon': 'chest', 'focus': [204, 505], 'items': []},
    6:  {'name': '연꽃 장식', 'say': '창가에 연꽃등이 떠올랐어요', 'icon': 'lotus', 'focus': [195, 300], 'items': [{'img': 'lotus', 'x': 150, 'y': 300, 's': 32, 'kind': 'float'}, {'img': 'lotus', 'x': 244, 'y': 292, 's': 36, 'kind': 'float'}]},
    7:  {'name': '천장 별빛', 'say': '천장에 별이 내려앉았어요', 'icon': 'star', 'focus': [195, 110], 'items': []},
    8:  {'name': '복주머니 장식', 'say': '기둥에 복주머니가 걸렸어요', 'icon': 'pouch', 'focus': [195, 260], 'items': [{'img': 'pouch', 'x': 14, 'y': 52, 's': 38, 'kind': 'hang', 'len': 200}, {'img': 'pouch', 'x': 376, 'y': 52, 's': 38, 'kind': 'hang', 'len': 200}]},
    9:  {'name': '방 전체 밝아짐', 'say': '방 전체가 환하게 밝아졌어요', 'icon': 'spark', 'focus': [195, 380], 'items': [], 'aura': true},
    10: {'name': '소원방 완성', 'say': '당신의 소원방이 완성되었어요', 'icon': 'gift', 'focus': [204, 214], 'items': [], 'sigil': true},
  };
}

class PlacedDeco { final String id; final String kind; final double x, y, s, len; final WrItem item; final bool custom;
  const PlacedDeco(this.id, this.kind, this.x, this.y, this.s, this.len, this.item, this.custom); }

/// 장착된 DECORATION + SEAL + THEME → 배치 목록. 웹 WRLayout.decos() 와 같은 알고리즘
List<PlacedDeco> placeDecos(Equip e, List<WrItem> items, Map<String, LayoutPos> layout) {
  final used = <String, int>{'hang': 0, 'stand': 0, 'float': 0, 'seal': 0};
  final out = <PlacedDeco>[];
  for (final id in [...e.decoration, ...e.seal, ...e.theme]) {
    final it = items.where((i) => i.id == id).firstOrNull; if (it == null) continue;
    final cu = layout[id];
    if (cu != null) {
      final k = it.slot == Slot.SEAL ? 'stand' : (it.kind == 'hang' ? 'hang' : it.kind == 'float' ? 'float' : 'stand');
      out.add(PlacedDeco(id, k, cu.x, cu.y, cu.s, k == 'hang' ? (cu.y - 58).clamp(8, 999).toDouble() : 0, it, true)); continue;
    }
    var kind = it.slot == Slot.SEAL ? 'seal' : (it.kind ?? 'stand');
    if (kind == 'seal') { final a = RoomLayout.anchors['seal']![used['seal']!.clamp(0, 2)]; used['seal'] = used['seal']! + 1; out.add(PlacedDeco(id, 'stand', a.x, a.y, it.s ?? 40, 0, it, false)); continue; }
    if (used[kind]! >= RoomLayout.anchors[kind]!.length) kind = ['float', 'stand', 'hang'].firstWhere((k) => used[k]! < RoomLayout.anchors[k]!.length, orElse: () => 'float');
    final a = RoomLayout.anchors[kind]![used[kind]!.clamp(0, RoomLayout.anchors[kind]!.length - 1)]; used[kind] = used[kind]! + 1;
    out.add(PlacedDeco(id, kind, a.x, a.y, it.s ?? 52, a.len, it, false));
  }
  return out;
}

/// 꾸미기 적용 연출(빛기둥·고리·반짝이)과 카메라 이동의 중심점
Offset focusOf(WrItem it, Equip e, List<WrItem> items, Map<String, LayoutPos> layout) {
  switch (it.slot) {
    case Slot.CANDLE: return const Offset(204, 420);
    case Slot.FLOWER: final cu = layout[it.id]; return cu == null ? Offset(RoomLayout.flower.x, RoomLayout.flower.y - RoomLayout.flower.s / 2) : Offset(cu.x, cu.y - cu.s / 2);
    case Slot.BACKGROUND: return const Offset(RoomLayout.windowCx, RoomLayout.windowCy);
    case Slot.SPECIAL: return const Offset(195, 300);
    default:
      final d = placeDecos(e, items, layout).where((x) => x.id == it.id).firstOrNull;
      if (d == null) return const Offset(195, 300);
      if (d.kind == 'hang' && !d.custom) return Offset(d.x, d.y + d.len + d.s / 2);
      if (d.kind == 'stand') return Offset(d.x, d.y - d.s / 2);
      return Offset(d.x, d.y);
  }
}
