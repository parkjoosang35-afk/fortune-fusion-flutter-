// ============================================================
//  oz_home_data.dart
//
//  신통방통 타로 · 홈 화면(오즈 스타일) 전용 큐레이션 데이터
//  - 히어로 배너 슬라이드 3장
//  - 인기/NEW 배너 2개
//  - 테마 카드 6개
//
//  [handoff-home 이식 주의사항 - targetRoute 조정 내역]
//  원본 handoff-home의 targetRoute는 `/tarot/category/today` 등 임의
//  플레이스홀더였다. 이 프로젝트의 실제 라우팅 규칙에 맞춰 다음처럼
//  조정했다(README 지시사항 그대로 반영):
//
//  1) 히어로 3장 → [categoryId]에 실제 [TarotCategoryData] id를 직접
//     저장한다(기존 오즈 리스킨 `oz_category_illustrations.dart`의
//     heroSlides가 이미 사용하던 동일한 3개 id: daily_today_tarot /
//     love_fortune / career_aptitude_direction). 화면에서는 문자열
//     라우트 파싱 없이 `enterTarotCategory()`(기존 tarot_home_screen.dart
//     의 공용 함수, 절대 변경하지 않음)를 그대로 호출해 카테고리 상세
//     화면(③, 손대지 않음)으로 이동한다.
//  2) 인기/NEW 배너 → 전용 "필터링된 리스트 화면"이 기존 앱에 없으므로
//     (기존 홈 화면도 인라인 그리드로만 노출했을 뿐, 별도 라우트가 없었음)
//     서브 카테고리 허브(②, [AppRouter.tarotHubRoute], 손대지 않음)로
//     이동해 전체 카테고리를 훑어보게 한다. [group]은 null로 두어 허브가
//     "전체" 상태로 열리게 한다.
//  3) 테마 카드 6개 → [group]에 실제 [TarotCategoryGroup] enum 값을 저장.
//     탭 시 기존 홈이 항상 하던 것과 동일하게
//     `Navigator.pushNamed(AppRouter.tarotHubRoute, arguments: group)`로
//     이동한다. id↔그룹 매핑과 개수(14/12/9/10/10/10)는 실제
//     [TarotCategoryData.byGroup]과 1:1 검증된 값이다.
//
//  ⚠️ 이 파일은 홈 화면 노출용 큐레이션 데이터일 뿐이며, 실제 65개
//  카테고리 데이터/그룹 정의([TarotCategoryData], [TarotCategoryGroup])는
//  domain/tarot_category_model.dart에 있는 것을 그대로 참조한다(중복 정의
//  없음, 변경 없음).
// ============================================================

import '../../domain/tarot_category_model.dart' show TarotCategoryGroup;

// ─────────────────────────────────────────────────────
//  Hero Slide (히어로 배너 · 자동 스와이프)
// ─────────────────────────────────────────────────────
class OzHeroSlide {
  final String tag; // 상단 짧은 라벨 (모노 라벨)
  final List<String> titleLines; // 두 줄 시적 타이틀
  final String cta; // CTA 버튼 텍스트
  final String imageAsset; // 배경 이미지 경로

  /// 실제 [TarotCategoryData] 카테고리 id. 탭 시 이 id로 카테고리를
  /// 조회해 `enterTarotCategory()`를 호출한다(기존 로직 그대로 재사용).
  final String categoryId;

  const OzHeroSlide({
    required this.tag,
    required this.titleLines,
    required this.cta,
    required this.imageAsset,
    required this.categoryId,
  });
}

// ─────────────────────────────────────────────────────
//  Category Banner (인기/NEW 큰 배너)
// ─────────────────────────────────────────────────────
enum OzBannerAccent { gold, rose }

class OzCategoryBannerData {
  final String id; // 'popular' or 'new'
  final String tagline; // 상단 모노 태그 (예: 'MOST · LOVED')
  final List<OzBannerTitleLine> titleLines; // 두 줄 타이틀(2번째 줄 액센트)
  final int count; // 카테고리 개수(표시용, 8)
  final String imageAsset; // 배경 이미지 경로
  final OzBannerAccent accent; // 골드 or 로즈

  const OzCategoryBannerData({
    required this.id,
    required this.tagline,
    required this.titleLines,
    required this.count,
    required this.imageAsset,
    required this.accent,
  });
}

class OzBannerTitleLine {
  final String text;
  final bool accent; // true면 골드/로즈 이탤릭 스타일

  const OzBannerTitleLine({required this.text, this.accent = false});
}

// ─────────────────────────────────────────────────────
//  Theme Card (테마 카드 · 6개)
// ─────────────────────────────────────────────────────
class OzThemeCardData {
  final String id; // 'love' | 'work' | 'money' | 'daily' | 'inner' | 'special'
  final String name; // '연애 · 관계'
  final int count; // 소속 카테고리 개수
  final String imageAsset; // 배경 이미지 경로
  final bool premium; // 프리미엄 여부(자물쇠 아이콘)

  /// 실제 [TarotCategoryGroup]. 탭 시 이 그룹으로 서브 카테고리 허브(②)를
  /// 연다(기존 홈이 항상 하던 것과 동일한 방식).
  final TarotCategoryGroup group;

  const OzThemeCardData({
    required this.id,
    required this.name,
    required this.count,
    required this.imageAsset,
    this.premium = false,
    required this.group,
  });
}

// ============================================================
//  홈 화면 데이터 (실제 값)
// ============================================================

/// 히어로 배너 슬라이드 · 3장 · 5초마다 자동 전환
const kOzHeroSlides = <OzHeroSlide>[
  OzHeroSlide(
    tag: '공들여 만든 하나의 타로 세계',
    titleLines: ['오늘, 카드가', '건네는 한마디'],
    cta: '오늘의 타로 뽑기',
    imageAsset: 'assets/tarot/oz/hero-today.png',
    categoryId: 'daily_today_tarot',
  ),
  OzHeroSlide(
    tag: '흔들리는 마음의 답',
    titleLines: ['지금 그 사람의', '마음이 궁금해요'],
    cta: '연애운 뽑기',
    imageAsset: 'assets/tarot/oz/hero-love.png',
    categoryId: 'love_fortune',
  ),
  OzHeroSlide(
    tag: '조용히 자라는 씨앗',
    titleLines: ['내가 나아갈 길', '어디를 향할까요'],
    cta: '커리어 타로 뽑기',
    imageAsset: 'assets/tarot/oz/hero-career.png',
    categoryId: 'career_aptitude_direction',
  ),
];

/// 인기/NEW 배너 2개 (탭 시 서브 카테고리 허브②로 이동, group=null)
const kOzCategoryBanners = <OzCategoryBannerData>[
  OzCategoryBannerData(
    id: 'popular',
    tagline: 'MOST · LOVED',
    titleLines: [
      OzBannerTitleLine(text: '지금 많이', accent: false),
      OzBannerTitleLine(text: '보는 카테고리', accent: true), // 골드 이탤릭
    ],
    count: 8,
    imageAsset: 'assets/tarot/oz/banner-popular.png',
    accent: OzBannerAccent.gold,
  ),
  OzCategoryBannerData(
    id: 'new',
    tagline: 'FRESH · TAROT',
    titleLines: [
      OzBannerTitleLine(text: '새로 생긴', accent: false),
      OzBannerTitleLine(text: '카테고리', accent: true), // 로즈 이탤릭
    ],
    count: 8,
    imageAsset: 'assets/tarot/oz/banner-new.png',
    accent: OzBannerAccent.rose,
  ),
];

/// 테마 카드 6개 · 2열 그리드
/// id↔group↔count 매핑은 [TarotCategoryData.byGroup]과 1:1로 검증됨:
///   love(14) · career(12, 화면 표기 "일·커리어") · wealth(9, "금전·현실")
///   · daily(10) · emotion(10, "감정·내면") · special(10, "특별 테마")
const kOzThemeCards = <OzThemeCardData>[
  OzThemeCardData(
    id: 'love',
    name: '연애 · 관계',
    count: 14,
    imageAsset: 'assets/tarot/oz/theme-love.png',
    group: TarotCategoryGroup.love,
  ),
  OzThemeCardData(
    id: 'work',
    name: '일 · 커리어',
    count: 12,
    imageAsset: 'assets/tarot/oz/theme-work.png',
    group: TarotCategoryGroup.career,
  ),
  OzThemeCardData(
    id: 'money',
    name: '금전 · 현실',
    count: 9,
    imageAsset: 'assets/tarot/oz/theme-money.png',
    group: TarotCategoryGroup.wealth,
  ),
  OzThemeCardData(
    id: 'daily',
    name: '일상 · 운세',
    count: 10,
    imageAsset: 'assets/tarot/oz/theme-daily.png',
    group: TarotCategoryGroup.daily,
  ),
  OzThemeCardData(
    id: 'inner',
    name: '감정 · 내면',
    count: 10,
    imageAsset: 'assets/tarot/oz/theme-inner.png',
    group: TarotCategoryGroup.emotion,
  ),
  OzThemeCardData(
    id: 'special',
    name: '특별 테마',
    count: 10,
    imageAsset: 'assets/tarot/oz/theme-special.png',
    premium: true,
    group: TarotCategoryGroup.special,
  ),
];
