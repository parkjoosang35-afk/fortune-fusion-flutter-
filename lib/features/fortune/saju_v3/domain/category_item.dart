// 신통방통 - 80종 카테고리 목록 모델
// GET /categories 응답

class CategoryItem {
  final String code;  // "A01" 등
  final String name;  // "평생 총운" 등

  const CategoryItem({required this.code, required this.name});

  factory CategoryItem.fromJson(Map<String, dynamic> j) =>
      CategoryItem(code: j['code'], name: j['name']);
}
