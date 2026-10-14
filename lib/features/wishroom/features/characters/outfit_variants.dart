import 'package:flutter/material.dart';

import '../../data/models.dart';

/// [의상 20종 확장 — 사용자 요청 2026-10-14]
/// 서버 계약은 "캐릭터별 테마 의상 소유"(buyOutfit(char, theme))이므로
/// 스키마를 건드리지 않으면서 샵에서 보이는 의상을 늘리는 방식: 각 테마
/// 의상에 색조 변형 5종(기본/황금빛/장미빛/달빛/보라빛)을 둔다. 4테마 ×
/// 5변형 = 총 20종이 샵 그리드에 노출된다. 테마 의상을 보유하면 그 테마의
/// 변형 5종이 모두 해금되고, 구매·착용 기록(서버 저장)은 테마 단위 그대로.
class WrOutfitVariant {
  const WrOutfitVariant(this.offer, this.index, this.label, this.tint);
  final OutfitOffer offer;

  /// 테마 안에서의 변형 순서(0=기본).
  final int index;
  final String label;

  /// 변형 색조(기본은 null — 원본 그대로).
  final Color? tint;
}

const List<(String, Color?)> _wrOutfitTints = [
  ('기본', null),
  ('황금빛', Color(0xFFE9C46A)),
  ('장미빛', Color(0xFFF2628F)),
  ('달빛', Color(0xFF7FC8E9)),
  ('보라빛', Color(0xFF9C6AD9)),
];

/// 테마 의상 목록을 색조 변형으로 확장한다 — 4테마 기준 20장.
List<WrOutfitVariant> wrExpandOutfitVariants(List<OutfitOffer> offers) => [
  for (final o in offers)
    for (var i = 0; i < _wrOutfitTints.length; i++)
      WrOutfitVariant(o, i, _wrOutfitTints[i].$1, _wrOutfitTints[i].$2),
];
