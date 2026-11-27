import 'package:flutter/material.dart';
import '../../data/models.dart';

/// 기존 테마 의상 카드와 신규 원본 의상 카드의 화면 정보.
/// 색조를 씌운 중복 그림을 별도 의상으로 만들지 않는다.
class WrOutfitVariant {
  const WrOutfitVariant(this.offer, this.index, this.label, this.tint);
  final OutfitOffer offer;
  final int index;
  final String label;
  final Color? tint;
}

List<WrOutfitVariant> wrExpandOutfitVariants(List<OutfitOffer> offers) => [
  for (final offer in offers)
    WrOutfitVariant(offer, 0, offer.name ?? '기본', null),
];
