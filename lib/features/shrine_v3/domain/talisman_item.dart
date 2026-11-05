/// 신당(THE SHRINE) v3 — 부적 마스터 카탈로그 1건.
///
/// admin_web `GET /api/public/shrine/talismans`의 `toTalismanDto()` 응답과
/// 1:1 매핑한다(필드명도 동일하게 camelCase 유지). 클라이언트는 이 데이터를
/// 그대로 표시만 할 뿐, 가격/차감/재고 같은 값은 전혀 갖지 않는다(§8
/// 서버 전담 원칙).
class TalismanItem {
  const TalismanItem({
    required this.id,
    required this.category,
    required this.hanja,
    required this.name,
    required this.aim,
    this.sub,
    required this.meaning,
    required this.effects,
    required this.recommendFor,
    required this.validityTerm,
    required this.usage,
    required this.goesWith,
    required this.imagePath,
    this.thumbPath,
  });

  /// 서버의 `slug`를 그대로 id로 사용(예: 'wealth-01').
  final String id;

  /// 9개 카테고리 중 하나(wealth/biz/love/harmony/exam/suneung/health/ward/wish).
  final String category;

  /// 한자 이름(예: '財福符').
  final String hanja;

  /// 한글 이름(예: '재복부').
  final String name;

  /// 한 줄 목적 설명.
  final String aim;

  /// 부제(수능 부적 등 일부만 존재, 그 외 null).
  final String? sub;

  final String meaning;

  /// 효과 목록(서버가 JSON 배열로 내려줌).
  final List<String> effects;

  /// 추천 대상 목록.
  final List<String> recommendFor;

  final String validityTerm;

  /// 사용법 단계(서버가 JSON 배열로 내려줌, 보통 3단계).
  final List<String> usage;

  /// 함께 쓰면 좋은 다른 부적 설명 목록.
  final List<String> goesWith;

  /// 부적 원본 이미지 경로(프로토타입 기준 'bj/talisman/xxx.jpg' 형태 —
  /// 실제 자산은 `assets/shrine_v3/`에 WebP로 반입되어 있으므로, 화면단
  /// 매핑 헬퍼가 확장자/디렉토리를 변환해 사용한다).
  final String imagePath;

  /// 썸네일 경로(없으면 null — 그 경우 imagePath를 그대로 썸네일로도 사용).
  final String? thumbPath;

  static List<String> _asStringList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  factory TalismanItem.fromJson(Map<String, dynamic> json) => TalismanItem(
    id: json['id'] as String,
    category: json['category'] as String,
    hanja: json['hanja'] as String,
    name: json['name'] as String,
    aim: json['aim'] as String,
    sub: json['sub'] as String?,
    meaning: json['meaning'] as String? ?? '',
    effects: _asStringList(json['effects']),
    recommendFor: _asStringList(json['recommendFor']),
    validityTerm: json['validityTerm'] as String? ?? '',
    usage: _asStringList(json['usage']),
    goesWith: _asStringList(json['goesWith']),
    imagePath: json['imagePath'] as String? ?? '',
    thumbPath: json['thumbPath'] as String?,
  );
}
