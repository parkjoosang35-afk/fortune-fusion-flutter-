/// [운세 카테고리 확장] 전체보기(all_categories_screen.dart) 화면이 관리자
/// 기준(FortuneCategory/FortuneCategoryGroup)으로 렌더링할 수 있도록,
/// admin_web `GET /api/public/fortune/categories` 응답을 그대로 옮긴 모델.
///
/// [주의] 이 모델은 "부가 메타데이터"만 담는다. 각 카테고리의 실제 입력/로딩/
/// 결과 화면은 기존 feature 모듈(saju/tarot/compatibility/...)이 그대로
/// 담당하며, 이 모델은 전체보기 화면에서 어떤 카테고리를 어떤 순서/그룹으로
/// 보여줄지, 어떤 route로 이동할지 결정하는 데에만 사용된다.
class FortuneCategoryItem {
  final String categoryKey;
  final String slug;
  final String title;
  final String? shortDescription;
  final String? icon;
  final String? heroImageUrl;
  final bool isFeatured;
  final String? badgeLabel;
  final bool requiresPass;

  /// null이면 아직 앱에서 연결된 화면이 없는 "준비중" 카테고리를 의미한다
  /// (기존 all_categories_screen.dart의 `route: null` 관례를 그대로 따른다).
  final String? route;
  final String? resultLengthHint;
  final int? currentLiveVersion;
  final List<String> relatedCategoryKeys;

  const FortuneCategoryItem({
    required this.categoryKey,
    required this.slug,
    required this.title,
    this.shortDescription,
    this.icon,
    this.heroImageUrl,
    this.isFeatured = false,
    this.badgeLabel,
    this.requiresPass = true,
    this.route,
    this.resultLengthHint,
    this.currentLiveVersion,
    this.relatedCategoryKeys = const [],
  });

  factory FortuneCategoryItem.fromJson(Map<String, dynamic> json) {
    return FortuneCategoryItem(
      categoryKey: json['categoryKey'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      shortDescription: json['shortDescription'] as String?,
      icon: json['icon'] as String?,
      heroImageUrl: json['heroImageUrl'] as String?,
      isFeatured: json['isFeatured'] as bool? ?? false,
      badgeLabel: json['badgeLabel'] as String?,
      requiresPass: json['requiresPass'] as bool? ?? true,
      route: json['route'] as String?,
      resultLengthHint: json['resultLengthHint'] as String?,
      currentLiveVersion: json['currentLiveVersion'] as int?,
      relatedCategoryKeys:
          (json['relatedCategoryKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

class FortuneCategoryGroupData {
  final String code;
  final String label;
  final String? description;
  final int displayOrder;
  final List<FortuneCategoryItem> categories;

  const FortuneCategoryGroupData({
    required this.code,
    required this.label,
    required this.displayOrder,
    required this.categories,
    this.description,
  });

  factory FortuneCategoryGroupData.fromJson(Map<String, dynamic> json) {
    return FortuneCategoryGroupData(
      code: json['code'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
      categories:
          (json['categories'] as List<dynamic>? ?? const [])
              .map((e) => FortuneCategoryItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
