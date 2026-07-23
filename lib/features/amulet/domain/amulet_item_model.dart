/// 04A 도메인H `amulet_items`(H-1) + `amulet_grades`(H-2, 마스터) 대응 모델
class AmuletGrade {
  final String code; // common/rare/heroic/legendary
  final String name;
  final int sortOrder;

  const AmuletGrade({
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  static const List<AmuletGrade> all = [
    AmuletGrade(code: 'common', name: '일반', sortOrder: 1),
    AmuletGrade(code: 'rare', name: '희귀', sortOrder: 2),
    AmuletGrade(code: 'heroic', name: '영웅', sortOrder: 3),
    AmuletGrade(code: 'legendary', name: '전설', sortOrder: 4),
  ];

  static AmuletGrade byCode(String code) =>
      all.firstWhere((g) => g.code == code, orElse: () => all.first);
}

class AmuletItemModel {
  final String id;
  final String name;
  final AmuletGrade grade;
  final String effectDescription;
  final String iconEmoji; // 04A image_file_id 대응(Mock: 이모지로 대체, 03§3.1 임시표기 규칙)
  final bool isAiGenerated;
  final int pricePoint;
  final bool isLimited;

  const AmuletItemModel({
    required this.id,
    required this.name,
    required this.grade,
    required this.effectDescription,
    required this.iconEmoji,
    this.isAiGenerated = false,
    required this.pricePoint,
    this.isLimited = false,
  });
}
