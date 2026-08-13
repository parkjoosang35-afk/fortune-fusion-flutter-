import 'dart:math';

import '../../fortune/daily/domain/fortune_report_model.dart';
import 'jeontong_eighty_matrix.dart';

/// [정통사주 80종 개편] 정통사주 80종 전용 결정론적 콘텐츠 생성기.
///
/// [백엔드 결정 - A안] 사용자가 클라이언트 룰베이스(백엔드 미배포)를
/// 선택했으므로, 사용자가 업로드한 `saju_engine_v4_final.zip`의 실제 만세력
/// 계산 로직(일간/오행/십신/대운 등)은 이식하지 않는다. 대신 기존
/// `GenericFortuneReportBuilder`와 완전히 동일한 원칙 — "같은 입력(오늘 날짜
/// + 카테고리 id)이면 항상 같은 결과"(시드 기반 [Random]) — 을 따르는 전용
/// 빌더를 새로 둔다.
///
/// [신규 클래스를 만든 이유] 기존 [GenericFortuneReportBuilder]는
/// `FortuneCategoryEntry`(37종 매트릭스 전용 모델)를 직접 참조하므로, 80종을
/// 그 모델에 억지로 끼워 넣으려면 `FortuneGroupCode` enum을 8개 그룹만큼
/// 확장해야 하고, 그 enum을 배타적으로 switch하는 기존 파일들
/// (`fortune_matrix_section.dart`, `categories_grid_screen.dart`)까지 함께
/// 고쳐야 해 기존 37종 시스템에 회귀 위험을 만든다. 대신 동일한 "패턴"만
/// 재사용하고 입력 타입을 [JeontongCategoryEntry]로 분리해 완전히 독립적으로
/// 동작하게 한다(기존 코드 無변경).
class JeontongReportBuilder {
  JeontongReportBuilder._();

  static FortuneReport build(JeontongCategoryEntry entry, {DateTime? date}) {
    final today = date ?? DateTime.now();
    final seed =
        today.year * 10000 +
        today.month * 100 +
        today.day +
        entry.id.codeUnits.fold<int>(0, (a, b) => a + b);
    final rng = Random(seed);

    final overall = 58 + rng.nextInt(38); // 58~95
    final statusLabel = overall >= 78 ? '상승' : (overall >= 55 ? '보통' : '주의');
    final primaryTag = entry.resultSeedTags.isNotEmpty
        ? entry.resultSeedTags.first
        : entry.major.title;
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
        title: '참고하면 좋을 점',
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
          LuckyItem(label: '방향', value: _pickOne(rng, _luckyDirectionPool)),
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
    return score >= 80
        ? '$title, 흐름이 뚜렷하게 좋아지는 시기예요'
        : score >= 60
        ? '$title, 무난하게 안정적으로 흘러가는 흐름이에요'
        : '$title, 차분히 다지면서 가면 좋은 시기예요';
  }

  static String _overviewBody(
    Random rng,
    JeontongCategoryEntry entry,
    int score,
  ) {
    final tone = score >= 80
        ? '사주 전체의 기운이 맑고 순조로운 흐름을 보이고 있어요.'
        : score >= 60
        ? '무난한 흐름 속에서 노력한 만큼 결과가 따라오는 시기예요.'
        : '서두르기보다 하나씩 정리하며 다져가면 좋은 흐름이에요.';
    final closing = _pickOne(rng, _closingPool);
    return '${entry.major.title} 관점에서 본 「${entry.title}」이에요. $tone $closing';
  }

  static const _keywordPool = [
    '균형',
    '여유',
    '용기',
    '경청',
    '정리',
    '시작',
    '안정',
    '집중',
    '성장',
    '인내',
  ];

  static const _subDescriptionPool = [
    '무리하지 않고 흐름을 읽는 것이 중요해요.',
    '서두르지 않고 하나씩 정리해가면 좋아요.',
    '평소보다 조금 더 여유를 갖고 움직이면 좋겠어요.',
    '작은 신호에도 귀 기울이면 좋은 힌트를 얻을 수 있어요.',
    '지금까지 쌓아온 흐름이 서서히 드러나는 시기예요.',
  ];

  static const _closingPool = [
    '큰 욕심을 내지 않는다면 안정적으로 흘러갈 가능성이 높아요.',
    '작은 선택 하나가 전체 분위기를 좌우할 수 있으니 신중하게 움직여보세요.',
    '주변과의 교류에서 의외의 힌트를 얻을 수 있어요.',
    '지금 가진 것을 잘 지키는 데 집중하면 좋겠어요.',
    '멀리 보고 천천히 쌓아가는 태도가 특히 중요한 시기예요.',
  ];

  static const _detailPool = [
    '지금까지 쌓아온 흐름이 서서히 결과로 드러나는 시기예요. 조급해하지 않아도 괜찮아요.',
    '작은 변화가 감지되는 시점이에요. 평소와 다른 선택을 해봐도 나쁘지 않아요.',
    '주변의 도움이나 조언이 의외로 큰 힘이 되는 시기예요. 귀를 기울여보세요.',
    '스스로 정한 기준을 지키는 것이 무엇보다 중요한 시기예요.',
    '겉으로 드러나는 변화보다 내면의 준비가 더 중요한 흐름이에요.',
  ];

  static const _adviceDetailPool = [
    '무리한 결정은 잠시 미뤄두고, 지금 가진 정보를 다시 점검해보세요.',
    '가까운 사람과 이야기를 나누면 생각보다 좋은 힌트를 얻을 수 있어요.',
    '평소보다 여유 있는 일정을 잡아보는 것도 좋은 방법이에요.',
    '작은 것부터 하나씩 실천하면 전체 흐름이 자연스럽게 좋아져요.',
    '중요한 판단은 하루 정도 더 생각해보고 결정해도 늦지 않아요.',
  ];

  static const _recommendPool = [
    '오늘 할 일의 우선순위를 다시 점검해보기',
    '가까운 사람에게 먼저 안부 전하기',
    '짧은 산책이나 스트레칭으로 몸 풀기',
    '평소 미뤄둔 정리 해보기',
    '중요한 결정은 하루 정도 더 생각해보기',
    '작은 목표 하나를 정해 실천해보기',
    '오늘 하루 감사한 일 한 가지 떠올려보기',
  ];

  static const _luckyColorPool = [
    '화이트',
    '베이지',
    '네이비',
    '연그린',
    '라벤더',
    '옐로우',
    '골드',
  ];
  static const _luckyDirectionPool = ['동쪽', '남동쪽', '남쪽', '서쪽', '북서쪽', '북쪽'];
}
