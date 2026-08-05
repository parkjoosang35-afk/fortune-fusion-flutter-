import 'dart:math';
import '../../../home/domain/fortune_matrix.dart';
import '../../daily/domain/fortune_report_model.dart';

/// [운섹션 87 카테고리 통합] 공용 결과 화면(GenericFortuneResultScreen)을 위한
/// 결정론적 콘텐츠 생성기.
///
/// 기존 [FortuneReportBuilder](오늘의 운세 12섹션)와 동일한 원칙 — "같은 입력이면
/// 항상 같은 결과"(날짜+카테고리 id를 시드로 한 [Random]) — 을 따르되, 87개
/// 카테고리 중 아직 전용 화면이 없는 카테고리(K/V/O 일부/X/G/B/D/R, 약 45개)를
/// 모두 하나의 빌더로 커버할 수 있도록 섹션 구성을 가볍게 유지한다.
///
/// 신규 백엔드 API를 추가하지 않고, 카테고리 메타데이터([FortuneCategoryEntry])
/// 만으로 클라이언트에서 즉시 결과를 만들어낸다.
class GenericFortuneReportBuilder {
  GenericFortuneReportBuilder._();

  static FortuneReport build(FortuneCategoryEntry entry, {DateTime? date}) {
    final today = date ?? DateTime.now();
    final seed =
        today.year * 10000 +
        today.month * 100 +
        today.day +
        entry.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final rng = Random(seed);

    final overall = 60 + rng.nextInt(36); // 60~95
    final statusLabel = overall >= 78 ? '상승' : (overall >= 55 ? '보통' : '주의');
    final primaryTag = entry.resultSeedTags.isNotEmpty
        ? entry.resultSeedTags.first
        : entry.group.label;
    final keywords = <String>{primaryTag, _pickOne(rng, _keywordPool)}.toList();

    final hero = FortuneHero(
      score: overall,
      headline: _headline(rng, entry.title, overall),
      name: entry.title,
      date: today,
      statusLabel: statusLabel,
      keywords: keywords,
      subDescription: _pickOne(rng, _subDescriptionPool),
    );

    final sections = <FortuneSection>[
      OverviewSection(title: '핵심 해석', body: _overviewBody(rng, entry, overall)),
      AspectSection(
        title: '자세히 보면',
        index: _clamp(overall + _offset(rng), 50, 96),
        body: _pickOne(rng, _detailPool),
      ),
      AspectSection(
        title: '오늘 참고할 점',
        index: _clamp(overall + _offset(rng), 50, 96),
        body: _pickOne(rng, _adviceDetailPool),
      ),
      ListSection(
        title: '이렇게 해보면 좋아요',
        items: _pickN(rng, _recommendPool, 3),
        listType: FortuneSectionType.recommend,
      ),
      LuckySection(
        title: '함께 보면 좋은 행운 요소',
        items: [
          LuckyItem(label: '색', value: _pickOne(rng, _luckyColorPool)),
          LuckyItem(label: '키워드', value: _pickOne(rng, _keywordPool)),
        ],
      ),
    ];

    return FortuneReport(hero: hero, sections: sections);
  }

  static int _clamp(int v, int min, int max) =>
      v < min ? min : (v > max ? max : v);
  static int _offset(Random rng) => rng.nextInt(11) - 5;
  static String _pickOne(Random rng, List<String> pool) =>
      pool[rng.nextInt(pool.length)];
  static List<String> _pickN(Random rng, List<String> pool, int n) {
    final shuffled = [...pool]..shuffle(rng);
    return shuffled.take(n).toList();
  }

  static String _headline(Random rng, String title, int score) {
    final tone = score >= 80
        ? '$title, 오늘은 특히 흐름이 좋아요'
        : score >= 60
        ? '$title, 무난하게 흘러가는 하루예요'
        : '$title, 차분하게 살펴보면 좋은 하루예요';
    return tone;
  }

  static String _overviewBody(
    Random rng,
    FortuneCategoryEntry entry,
    int score,
  ) {
    final tone = score >= 80
        ? '전체적으로 기운이 맑고 흐름이 순조로워요.'
        : score >= 60
        ? '무난한 흐름 속에서 작은 기회들이 곳곳에 있어요.'
        : '서두르기보다 천천히 정리하며 가면 좋은 흐름이에요.';
    final closing = _pickOne(rng, _closingPool);
    return '${entry.shortDescription}. $tone $closing';
  }

  static const _keywordPool = ['균형', '여유', '용기', '경청', '정리', '시작', '안정', '집중'];

  static const _subDescriptionPool = [
    '무리하지 않고 흐름을 읽는 것이 중요해요.',
    '서두르지 않고 하나씩 정리해가면 좋아요.',
    '평소보다 조금 더 여유를 갖고 움직이면 좋겠어요.',
    '작은 신호에도 귀 기울이면 좋은 힌트를 얻을 수 있어요.',
  ];

  static const _closingPool = [
    '큰 욕심을 내지 않는다면 안정적으로 흘러갈 가능성이 높아요.',
    '작은 선택 하나가 전체 분위기를 좌우할 수 있으니 신중하게 움직여보세요.',
    '주변과의 교류에서 의외의 힌트를 얻을 수 있어요.',
    '지금 가진 것을 잘 지키는 데 집중하면 좋겠어요.',
  ];

  static const _detailPool = [
    '지금까지 쌓아온 흐름이 서서히 결과로 드러나는 시기예요. 조급해하지 않아도 괜찮아요.',
    '작은 변화가 감지되는 시점이에요. 평소와 다른 선택을 해봐도 나쁘지 않아요.',
    '주변의 도움이나 조언이 의외로 큰 힘이 되는 시기예요. 귀를 기울여보세요.',
    '스스로 정한 기준을 지키는 것이 무엇보다 중요한 시기예요.',
  ];

  static const _adviceDetailPool = [
    '무리한 결정은 잠시 미뤄두고, 지금 가진 정보를 다시 점검해보세요.',
    '가까운 사람과 이야기를 나누면 생각보다 좋은 힌트를 얻을 수 있어요.',
    '평소보다 여유 있는 일정을 잡아보는 것도 좋은 방법이에요.',
    '작은 것부터 하나씩 실천하면 전체 흐름이 자연스럽게 좋아져요.',
  ];

  static const _recommendPool = [
    '오늘 할 일의 우선순위를 다시 점검해보기',
    '가까운 사람에게 먼저 안부 전하기',
    '짧은 산책이나 스트레칭으로 몸 풀기',
    '평소 미뤄둔 정리 해보기',
    '중요한 결정은 하루 정도 더 생각해보기',
    '작은 목표 하나를 정해 실천해보기',
  ];

  static const _luckyColorPool = ['화이트', '베이지', '네이비', '연그린', '라벤더', '옐로우'];
}
