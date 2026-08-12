/// [웹→앱 이식] 신통방통 js/saju-profile-engine.js `saju_profiles` 테이블 대응
/// 관계(relationship) 코드 - self/father/mother/spouse/child/sibling/friend/other
enum SajuRelationship {
  self,
  father,
  mother,
  spouse,
  child,
  sibling,
  friend,
  other,
}

/// 신통방통 `SAJU_RELATIONSHIP_LABEL` 한글 매핑 이식
const Map<SajuRelationship, String> sajuRelationshipLabel = {
  SajuRelationship.self: '본인',
  SajuRelationship.father: '아버지',
  SajuRelationship.mother: '어머니',
  SajuRelationship.spouse: '배우자',
  SajuRelationship.child: '자녀',
  SajuRelationship.sibling: '형제자매',
  SajuRelationship.friend: '지인',
  SajuRelationship.other: '기타',
};

/// [웹→앱 이식] "내 사주함" - 회원 1인당 여러 인물(본인/가족/지인)의 사주 정보를
/// 저장해두고 재사용하는 프로필 모델. 04A 원칙(과설계 방지)에 따라 saju_charts와
/// 별도 관계형 테이블을 신설하지 않고, 프로필 자체는 독립 엔티티로 두되
/// [SajuResultModel]에는 profileId/profileName만 편의 필드로 포함한다.
class SajuProfileModel {
  final String id;
  final String profileName; // 별칭, 예: "엄마 사주", "나"
  final String name; // 실제 이름
  final String gender; // '남' | '여'
  final String birthDate; // YYYY-MM-DD
  final String? birthTime; // HH:mm
  final bool isLunar;
  final SajuRelationship relationship;
  final bool isPrimary;
  final DateTime createdAt;

  const SajuProfileModel({
    required this.id,
    required this.profileName,
    required this.name,
    required this.gender,
    required this.birthDate,
    this.birthTime,
    this.isLunar = false,
    this.relationship = SajuRelationship.self,
    this.isPrimary = false,
    required this.createdAt,
  });

  SajuProfileModel copyWith({
    String? profileName,
    String? name,
    String? gender,
    String? birthDate,
    String? birthTime,
    bool? isLunar,
    SajuRelationship? relationship,
    bool? isPrimary,
  }) {
    return SajuProfileModel(
      id: id,
      profileName: profileName ?? this.profileName,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      isLunar: isLunar ?? this.isLunar,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt,
    );
  }
}

/// 04A E-2 `fortune_results` + E-3 `saju_charts` 대응 모델
class SajuPillars {
  final String year;
  final String month;
  final String day;
  final String? hour;

  const SajuPillars({
    required this.year,
    required this.month,
    required this.day,
    this.hour,
  });
}

class SajuResultModel {
  final String id;

  /// [사주정보 이름 필드 보완] 이번 분석을 요청한 사람의 이름(입력 화면에서
  /// 사용자가 직접 입력한 값, 또는 미입력 시 '게스트'). 결과 화면에서
  /// "OOO님의 사주 결과"처럼 개인화 표시에 사용할 수 있다.
  final String name;
  final SajuPillars pillars;
  final Map<String, int> fiveElements; // 목화토금수
  final Map<String, String> topicResults; // 재물/애정/직업/건강
  final String summary;
  final DateTime createdAt;

  /// [웹→앱 이식] "내 사주함" 연계 편의 필드 - 어떤 프로필로 분석했는지 표시용.
  /// (별도 관계형 조인 없이 이름만 복사해두는 단순 참조 - 04A 과설계 방지 원칙)
  final String? profileId;
  final String? profileName;

  const SajuResultModel({
    required this.id,
    required this.name,
    required this.pillars,
    required this.fiveElements,
    required this.topicResults,
    required this.summary,
    required this.createdAt,
    this.profileId,
    this.profileName,
  });
}
