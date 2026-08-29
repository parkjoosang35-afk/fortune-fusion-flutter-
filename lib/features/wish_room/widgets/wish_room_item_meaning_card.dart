import 'package:flutter/material.dart';

import '../../shop/domain/shop_item_visuals.dart';
import '../theme/wish_room_theme.dart';
import 'wish_room_candle.dart';
import 'wish_room_growth_widgets.dart';
import 'wish_room_seal.dart';

/// [STEP05-B STEP9-6 — 아이템 설명 카드]
///
/// 지시서 §4 요구사항: 아이콘 하나만 던지지 않고 "이름 — 역할 — 오늘 할 수
/// 있는 한마디"를 함께 보여준다. 예)
///   🕯️ 촛불 — 소원을 밝히는 촛불 — 오늘도 소원의 불빛을 밝혀주세요
///   金 인장 — 소원을 지켜주는 인장 — 봉인한 소원을 든든하게 지켜줘요
///   🧿 수호 부적 — 소원을 지켜주는 부적 — 좋은 기운이 소원에 머물도록 도와줘요
///
/// [절대 원칙] 여기 적힌 문구는 전부 아이템 "타입"(촛불/인장/부적) 단위의
/// 고정 역할 설명이며, 성공률/달성률/행운 같은 서버가 주지 않는 수치는
/// 절대 만들지 않는다. 실제 장착된 아이템의 이름/글리프만
/// [shop_item_visuals.dart](서버 카탈로그 코드 매핑, 이미 검증된 데이터)에서
/// 그대로 가져와 조합한다.
enum WishItemKind { candle, seal, talisman }

class WishItemMeaningCard extends StatelessWidget {
  const WishItemMeaningCard({
    super.key,
    required this.kind,
    required this.itemLabel,
    required this.roleLabel,
    required this.todayMessage,
    required this.glowColor,
    required this.visual,
  });

  final WishItemKind kind;

  /// 예: "촛불", "金 인장", "🧿 수호 부적"
  final String itemLabel;

  /// 예: "소원을 밝히는 촛불"
  final String roleLabel;

  /// 예: "오늘도 소원의 불빛을 밝혀주세요"
  final String todayMessage;

  final Color glowColor;

  /// 시각 요소(촛불 위젯 / 인장 위젯 / 부적 이모지)를 그린다.
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: WishRoomColors.backgroundDeep.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: WishRoomColors.surfaceCardBorder.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 44, height: 46, child: Center(child: visual)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$itemLabel · $roleLabel',
                  style: const TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: WishRoomColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  todayMessage,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: WishRoomColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 촛불 아이템 설명 카드를 만든다 — 실제 candleItemCode가 있을 때만
/// 호출부에서 사용한다.
Widget buildCandleMeaningCard({required Color candleColor}) {
  return WishItemMeaningCard(
    kind: WishItemKind.candle,
    itemLabel: '🕯️ 촛불',
    roleLabel: '소원을 밝히는 촛불',
    todayMessage: '오늘도 소원의 불빛을 밝혀주세요',
    glowColor: candleColor,
    visual: WishRoomCandle(size: 30, color: candleColor),
  );
}

/// 인장 아이템 설명 카드 — 실제 sealItemCode(또는 카테고리 기본 seal)의
/// 글리프를 그대로 사용한다.
Widget buildSealMeaningCard({required String glyph}) {
  return WishItemMeaningCard(
    kind: WishItemKind.seal,
    itemLabel: '$glyph 인장',
    roleLabel: '소원을 지켜주는 인장',
    todayMessage: '봉인한 소원을 든든하게 지켜줘요',
    glowColor: WishRoomColors.accent,
    visual: SealBreathingGlow(
      color: WishRoomColors.accent,
      child: WishRoomSeal(text: glyph, color: WishRoomColors.accent, size: 28),
    ),
  );
}

/// 부적 아이템 설명 카드 — talismanItemCode가 있을 때만 호출부에서 사용.
Widget buildTalismanMeaningCard({required ShopTalismanVisual visual}) {
  return WishItemMeaningCard(
    kind: WishItemKind.talisman,
    itemLabel: '${visual.icon} 수호 부적',
    roleLabel: '소원을 지켜주는 부적',
    todayMessage: '좋은 기운이 소원에 머물도록 도와줘요',
    glowColor: visual.color,
    visual: TalismanPulseGlow(
      color: visual.color,
      child: Text(visual.icon, style: const TextStyle(fontSize: 22)),
    ),
  );
}
