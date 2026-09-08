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
  // [Phase05 확장 5종]
  'seal_bamboo': ShopSealVisual('竹'),
  'seal_pearl': ShopSealVisual('珠'),
  'seal_tiger': ShopSealVisual('虎'),
  'seal_phoenix': ShopSealVisual('鳳', rare: true),
  'seal_dragon': ShopSealVisual('龍', rare: true),
};

ShopSealVisual sealVisualFor(String itemCode) =>
    sealVisuals[itemCode] ?? const ShopSealVisual('願');

const Map<String, Color> candleColors = {
  'candle_lotus': Color(0xFFF4B8C8),
  'candle_incense': Color(0xFFC9A374),
  'candle_star': Color(0xFFE8C8F5),
  'candle_jade_wax': Color(0xFFD4AF37),
  // [Phase05 확장 6종]
  'candle_pine': Color(0xFF9FD8A8),
  'candle_plum': Color(0xFFE8A8C0),
  'candle_moon': Color(0xFFC8D8F0),
  'candle_sunrise': Color(0xFFF5B87A),
  'candle_phoenix': Color(0xFFF08A5D),
  'candle_eternal': Color(0xFFD4AF37),
};

/// 별초/유촉/봉황초/만년초는 디자인 스펙상 rare(은은한 glow 배경) 처리된다.
const Set<String> rareCandleCodes = {
  'candle_star',
  'candle_jade_wax',
  'candle_phoenix',
  'candle_eternal',
};

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
  // [Phase05 확장 7종]
  'talisman_travel': ShopTalismanVisual('🧳', Color(0xFF8FD8C8)),
  'talisman_health': ShopTalismanVisual('🍀', Color(0xFF9FD8A8)),
  'talisman_study': ShopTalismanVisual('📖', Color(0xFFB8C8E8)),
  'talisman_dream': ShopTalismanVisual('🌙', Color(0xFFC8B8E8)),
  'talisman_love': ShopTalismanVisual('💞', Color(0xFFE8A8C0)),
  'talisman_wealth': ShopTalismanVisual('💰', Color(0xFFE8C878)),
  'talisman_phoenix': ShopTalismanVisual('🔥', Color(0xFFF08A5D)),
};

ShopTalismanVisual talismanVisualFor(String itemCode) =>
    talismanVisuals[itemCode] ??
    const ShopTalismanVisual('🧿', WishRoomColors.glow);
