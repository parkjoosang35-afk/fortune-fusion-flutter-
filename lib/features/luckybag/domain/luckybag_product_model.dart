/// 04A 도메인I(복주머니) `luckybag_products`(I-1) + `luckybag_grades`(I-2, 마스터) 대응 모델
class LuckyBagGrade {
  final String code; // none/common/rare/best
  final String name;
  final int sortOrder;

  const LuckyBagGrade({
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  static const List<LuckyBagGrade> all = [
    LuckyBagGrade(code: 'none', name: '꽝', sortOrder: 0),
    LuckyBagGrade(code: 'common', name: '일반', sortOrder: 1),
    LuckyBagGrade(code: 'rare', name: '레어', sortOrder: 2),
    LuckyBagGrade(code: 'best', name: '최고', sortOrder: 3),
  ];

  static LuckyBagGrade byCode(String code) =>
      all.firstWhere((g) => g.code == code, orElse: () => all.first);
}

class LuckyBagProductModel {
  final String id;
  final String name;
  final int pricePoint;
  final String iconEmoji; // 04A image_file_id 대응(Mock: 이모지로 대체, 03§3.1 임시표기 규칙)
  final String? seasonName; // luckybag_seasons(I-4) 대응(선택)

  const LuckyBagProductModel({
    required this.id,
    required this.name,
    required this.pricePoint,
    required this.iconEmoji,
    this.seasonName,
  });
}
