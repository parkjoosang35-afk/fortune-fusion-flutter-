import 'package:flutter/material.dart';

import '../../wish_room/theme/wish_room_theme.dart';

/// 상점 카탈로그 itemCode → 시각 요소(한자 글리프/색상) 매핑.
///
/// [출처] `prisma/seed_pouch_expansion_phase02.ts`의 실제 itemCode 값과
/// `design_files/new-screens.jsx`의 `ScreenSealShop`/`ScreenCandleShop`
/// 디자인 스펙(한자/색상)을 그대로 대응시킨다. 서버 카탈로그가 새 itemCode를
/// 추가하면 이 맵에도 항목을 추가해야 하며, 매핑이 없는 코드는 기본값
/// (願/glow색)으로 안전하게 폴백한다.
class ShopSealVisual {
  final String glyph;
  final bool rare;

  const ShopSealVisual(this.glyph, {this.rare = false});
}

const Map<String, ShopSealVisual> sealVisuals = {
  'seal_jade': ShopSealVisual('玉'),
  'seal_silver': ShopSealVisual('銀'),
  'seal_turtle': ShopSealVisual('龜'),
  'seal_crane': ShopSealVisual('鶴'),
  'seal_gold_leaf': ShopSealVisual('金', rare: true),
};

ShopSealVisual sealVisualFor(String itemCode) =>
    sealVisuals[itemCode] ?? const ShopSealVisual('願');

const Map<String, Color> candleColors = {
  'candle_lotus': Color(0xFFF4B8C8),
  'candle_incense': Color(0xFFC9A374),
  'candle_star': Color(0xFFE8C8F5),
  'candle_jade_wax': Color(0xFFD4AF37),
};

/// 별초/유촉은 디자인 스펙상 rare(은은한 glow 배경) 처리된다.
const Set<String> rareCandleCodes = {'candle_star', 'candle_jade_wax'};

Color candleColorFor(String itemCode) =>
    candleColors[itemCode] ?? WishRoomColors.glow;

/// 부적(talisman) 시각 매핑 — JSX에 명시 코드가 없어 CandleShop 패턴을
/// 준용해 자체 설계했다. 아이콘(이모지)과 강조색으로 구분한다.
class ShopTalismanVisual {
  final String icon;
  final Color color;

  const ShopTalismanVisual(this.icon, this.color);
}

const Map<String, ShopTalismanVisual> talismanVisuals = {
  'talisman_guardian': ShopTalismanVisual('🧿', Color(0xFF8FB9E8)),
  'talisman_full_moon': ShopTalismanVisual('🌕', Color(0xFFE8D8A8)),
  'talisman_friend': ShopTalismanVisual('🤝', Color(0xFFC8A8E8)),
};

ShopTalismanVisual talismanVisualFor(String itemCode) =>
    talismanVisuals[itemCode] ??
    const ShopTalismanVisual('🧿', WishRoomColors.glow);
