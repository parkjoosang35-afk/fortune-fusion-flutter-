import '../../domain/tarot_category_model.dart';

/// [타로 오즈 리스킨] 카테고리 ID → 오즈 AI 일러스트 자산 매핑.
///
/// 핸드오프 자산(`assets/tarot/oz/`)에는 `cat-*.png` 16장, `theme-*.png`
/// 6장, `hero-*.png` 3장, `card-back.png` 1장(총 26장)만 존재한다. 반면
/// 실제 앱의 [TarotCategoryData.all]은 65개 카테고리를 가진다(read-only,
/// 절대 변경하지 않음). 이 파일은 두 세계를 잇는 유일한 매핑 레이어다.
///
/// 매핑 원칙(README "기존 앱에 아이콘 매핑이 이미 있다면 그걸 우선" 정책):
/// 1) `cat-*.png` 16장은 매핑표.md `HOME_POPULAR`(8)+`HOME_NEW`(8)의
///    이름/설명이 실제 앱의 인기8([TarotCategoryData.popular])·신규8
///    ([TarotCategoryData.newest]) 카테고리와 정확히 1:1 대응하므로,
///    이름을 근거로 실제 카테고리 id에 정확히 연결한다(추측 없음).
/// 2) 전용 일러스트가 없는 나머지 49개 카테고리는 소속 그룹의
///    `theme-*.png`를 배경으로 쓰고, 카테고리 고유 [TarotCategoryMeta.emoji]를
///    글리프로 얹어 구분한다(전용 자산 재생성 없이 일관된 룩 유지).
class OzCategoryIllustrations {
  OzCategoryIllustrations._();

  static const String _base = 'assets/tarot/oz';

  /// 16개 카테고리 id → 전용 일러스트 경로(홈 인기8 + 신규8과 정확히 일치).
  static const Map<String, String> _dedicated = {
    // 지금 가장 많이 보는 카테고리 (8)
    'daily_today_tarot': '$_base/cat-today.png',
    'love_fortune': '$_base/cat-love.png',
    'love_flow_of_crush': '$_base/cat-flow.png',
    'wealth_fortune': '$_base/cat-money.png',
    'love_inner_truth': '$_base/cat-mind.png',
    'love_will_they_contact': '$_base/cat-bell.png',
    'love_reunion_chance': '$_base/cat-return.png',
    'love_confession_timing': '$_base/cat-letter.png',
    // 새로 생긴 카테고리 (8)
    'love_next_chapter_of_crush': '$_base/cat-unrequited.png',
    'love_timing_of_fate': '$_base/cat-timing.png',
    'career_aptitude_direction': '$_base/cat-aptitude.png',
    'career_new_sprout': '$_base/cat-sprout.png',
    'wealth_asset_direction': '$_base/cat-box.png',
    'wealth_harvest_timing': '$_base/cat-wheat.png',
    'daily_tomorrow_feeling': '$_base/cat-sunrise.png',
    'daily_quarterly_flow': '$_base/cat-calendar.png',
  };

  /// 6개 그룹 → 테마 히어로 일러스트.
  static const Map<TarotCategoryGroup, String> themeHero = {
    TarotCategoryGroup.love: '$_base/theme-love.png',
    TarotCategoryGroup.career: '$_base/theme-work.png',
    TarotCategoryGroup.wealth: '$_base/theme-money.png',
    TarotCategoryGroup.daily: '$_base/theme-daily.png',
    TarotCategoryGroup.emotion: '$_base/theme-inner.png',
    TarotCategoryGroup.special: '$_base/theme-special.png',
  };

  /// 카드 뒷면(셔플/드로우 화면 공용).
  static const String cardBack = '$_base/card-back.png';

  /// 홈 히어로 캐러셀(3장, 자동 스와이프).
  static const List<OzHeroSlide> heroSlides = [
    OzHeroSlide(
      tag: '공들여 만든 하나의 타로 세계',
      title: '오늘, 카드가\n건네는 한마디',
      cta: '오늘의 타로 뽑기',
      image: '$_base/hero-today.png',
      categoryId: 'daily_today_tarot',
    ),
    OzHeroSlide(
      tag: '흔들리는 마음의 답',
      title: '지금 그 사람의\n마음이 궁금해요',
      cta: '연애운 뽑기',
      image: '$_base/hero-love.png',
      categoryId: 'love_fortune',
    ),
    OzHeroSlide(
      tag: '조용히 자라는 씨앗',
      title: '내가 나아갈 길\n어디를 향할까요',
      cta: '커리어 타로 뽑기',
      image: '$_base/hero-career.png',
      categoryId: 'career_aptitude_direction',
    ),
  ];

  /// 카테고리의 대표 이미지 경로. 전용 자산이 없으면 소속 그룹의 테마
  /// 히어로 이미지로 대체한다(항상 null이 아닌 값을 반환 - 화면에서
  /// null 분기 처리를 불필요하게 만들어 실수를 방지).
  static String imageFor(TarotCategoryMeta category) {
    return _dedicated[category.id] ?? themeHero[category.group]!;
  }

  /// 카테고리가 전용 AI 일러스트를 갖는지 여부(그리드에서 사진 vs
  /// 이모지+그라디언트 표현을 가를 때 사용 가능).
  static bool hasDedicatedArt(String categoryId) =>
      _dedicated.containsKey(categoryId);
}

class OzHeroSlide {
  final String tag;
  final String title;
  final String cta;
  final String image;
  final String categoryId;
  const OzHeroSlide({
    required this.tag,
    required this.title,
    required this.cta,
    required this.image,
    required this.categoryId,
  });
}
