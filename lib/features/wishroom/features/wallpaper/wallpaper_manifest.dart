// [소원방 v2.6 배경화면] docs/WALLPAPER.md §1 — `wallpaper_manifest.dart` (모델).
// Android(WishRoomWallpaperService.kt › WpManifest)와 "같은 수식"으로 그리기
// 위해 전달하는 평평한 레이어 JSON을 만든다. 좌표는 전부 room_layout.dart가
// 계산한 390×844 기준 값 그대로("같은 좌표" 원칙, §3) — 이 파일은 좌표를
// 다시 계산하지 않고 room_scene.dart/room_layout.dart의 결과만 모아 담는다.
import 'dart:convert';
import '../../data/models.dart';
import '../../data/wr_catalog.dart';
import '../room/room_layout.dart';

class WpNativeLayer {
  final String asset;
  final double x, y, s, rotateDeg;
  const WpNativeLayer({required this.asset, required this.x, required this.y, required this.s, this.rotateDeg = 0});
  Map<String, dynamic> toJson() => {'asset': asset, 'x': x, 'y': y, 's': s, 'rotateDeg': rotateDeg};
}

/// WishRoom + 카탈로그로부터 네이티브가 그릴 레이어 명세(JSON)를 만든다.
/// Flutter 미리보기는 RoomScene을 그대로 쓰고, 이 함수는 "실제 라이브
/// 배경화면"(네이티브 Canvas 렌더러) 전용 — 두 렌더러가 같은 입력(room+equip)에서
/// 출발하므로 미리보기와 실제 배경화면이 같아 보장된다(FR-W-11).
String buildNativeManifestJson(WishRoom room, List<WrItem> items) {
  final cat = WrCatalog.I;
  final lv = room.level;
  final sacred = room.sacred;
  final roomAsset = sacred ? cat.roomImage(room.theme) : RoomLayout.roomImg;

  WrItem? itemOf(String? id) {
    if (id == null) return null;
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  final candleItem = itemOf(room.equip.candle);
  WpNativeLayer? candleLayer;
  if (!sacred && candleItem != null && candleItem.id != 'c_basic' && candleItem.asset != null) {
    candleLayer = WpNativeLayer(asset: candleItem.asset!, x: RoomLayout.candle.x, y: RoomLayout.candle.y, s: RoomLayout.candle.s);
  }

  // 캐릭터 레이어 — room_scene.dart L5 위치(left:-2, top:468, width:162, height:226)를
  // "바닥 중심" 좌표(x,y,s)로 환산: x = left + width/2, y = top + height(바닥선), s = width.
  final charAsset = cat.charImage(room.char, room.outfitNow);
  final charLayer = WpNativeLayer(asset: charAsset, x: -2.0 + 162.0 / 2, y: 468.0 + 226.0, s: 162.0);

  final decos = placeDecos(room.equip, items, room.layout);
  final decoLayers = <WpNativeLayer>[
    for (final d in decos)
      if (d.item.asset != null)
        WpNativeLayer(
          asset: d.item.asset!,
          x: d.x,
          y: d.kind == 'float' ? d.y : d.y, // float은 중심 좌표, 나머지는 바닥 좌표 — 네이티브 쪽에서 kind 구분 없이 bottom-anchor로 단순화해 그린다.
          s: d.s,
        ),
  ];
  final flowerItem = itemOf(room.equip.flower);
  if (!sacred && flowerItem?.asset != null) {
    final fx = room.layout[flowerItem!.id]?.x ?? RoomLayout.flower.x;
    final fy = room.layout[flowerItem.id]?.y ?? RoomLayout.flower.y;
    final fs = room.layout[flowerItem.id]?.s ?? RoomLayout.flower.s;
    decoLayers.add(WpNativeLayer(asset: flowerItem.asset!, x: fx, y: fy, s: fs));
  }
  if (!sacred) {
    for (final e in RoomLayout.unlocks.entries.where((e) => lv >= e.key)) {
      for (final it in (e.value['items'] as List).cast<Map>()) {
        decoLayers.add(WpNativeLayer(asset: 'assets/wishroom/items/${it['img']}.png', x: (it['x'] as num).toDouble(), y: (it['y'] as num).toDouble(), s: (it['s'] as num).toDouble()));
      }
    }
  }

  String band;
  if (lv >= 7) {
    band = 'B4';
  } else if (lv >= 5) {
    band = 'B3';
  } else if (lv >= 3) {
    band = 'B2';
  } else {
    band = 'B1';
  }

  final map = {
    'version': 1,
    'theme': room.theme.name,
    'roomAsset': roomAsset,
    'brightness': room.brightness,
    'band': band,
    'fulfilled': room.status == RoomStatus.ARCHIVED,
    'candle': candleLayer?.toJson(),
    'character': charLayer.toJson(),
    'decorations': decoLayers.map((d) => d.toJson()).toList(),
    'auraGold': lv >= 9,
  };
  return jsonEncode(map);
}
