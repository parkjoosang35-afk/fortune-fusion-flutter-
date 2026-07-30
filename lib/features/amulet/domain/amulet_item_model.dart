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

  /// admin_web에는 아직 이모지/아이콘 컬럼이 없어(imageUrl만 존재), 등급코드+AI생성여부
  /// 기준으로 클라이언트에서 고정 매핑한다(03§3.1 임시표기 규칙과 동일한 원칙).
  static String iconForGrade(String gradeCode, bool isAiGenerated) {
    if (isAiGenerated) return '🎨';
    switch (gradeCode) {
      case 'legendary':
        return '👑';
      case 'heroic':
        return '⭐';
      case 'rare':
        return '💖';
      default:
        return '🧧';
    }
  }

  /// GET /api/public/amulets/shop 대응
  factory AmuletItemModel.fromJson(Map<String, dynamic> json) {
    final gradeCode = json['gradeCode'] as String? ?? 'common';
    final isAiGenerated = json['isAiGenerated'] as bool? ?? false;
    return AmuletItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      grade: AmuletGrade.byCode(gradeCode),
      effectDescription: json['effectDescription'] as String? ?? '',
      iconEmoji: iconForGrade(gradeCode, isAiGenerated),
      isAiGenerated: isAiGenerated,
      pricePoint: json['pricePoint'] as int? ?? 0,
      isLimited: json['isLimited'] as bool? ?? false,
    );
  }
}
