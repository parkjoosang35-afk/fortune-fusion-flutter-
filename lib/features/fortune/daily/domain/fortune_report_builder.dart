import 'dart:math';
import '../domain/daily_fortune_model.dart';
import 'fortune_report_model.dart';

/// [클라이언트 결정론적 파생 생성] `DailyFortuneModel`(백엔드 실 API 응답:
/// categoryScores/luckyColor/luckyNumber/summaryText)을 시드로 삼아,
/// 12섹션 리치 리포트([FortuneReport])를 클라이언트에서 결정론적으로 파생 생성한다.
///
/// 신규 백엔드 필드/API를 추가하지 않는다(기존 세그먼트에서 확립된 원칙).
/// 같은 [DailyFortuneModel] + 같은 이름이 주어지면 항상 같은 결과가 나온다
/// (RNG는 날짜+점수 합으로 시드를 고정).
class FortuneReportBuilder {
  FortuneReportBuilder._();

  static FortuneReport build(DailyFortuneModel model, {required String name}) {
    final scores = model.categoryScores;
    final seed =
        model.date.year * 10000 +
        model.date.month * 100 +
        model.date.day +
        scores.values.fold<int>(0, (a, b) => a + b) +
        model.luckyNumber;
    final rng = Random(seed);

    int scoreOf(String key, {int fallbackMin = 60, int fallbackMax = 95}) {
      return scores[key] ??
          (fallbackMin + rng.nextInt(fallbackMax - fallbackMin + 1));
    }

    final overall =
        scores['총운'] ??
        (scores.isEmpty
            ? 75
            : (scores.values.fold<int>(0, (a, b) => a + b) / scores.length)
                  .round());

    final love = scoreOf('애정');
    final money = scoreOf('재물');
    final health = scoreOf('건강');
    final relationship = _clamp(
      ((love + money) / 2).round() + _offset(rng),
      50,
      96,
    );
    final work = _clamp(
      ((overall + health) / 2).round() + _offset(rng),
      50,
      96,
    );

    // [§6-1 히어로 카드 보강] 상태뱃지(보통/상승/주의) + 오늘의 키워드 chip 2~3개.
    // 5종 세부 운세 중 가장 점수가 높은 항목을 우선 키워드로 반영해, 점수와
    // 무관한 임의 태그가 아니라 실제 오늘의 흐름을 반영한 키워드가 되도록 한다.
    final aspectScores = <String, int>{
      '연애운': love,
      '금전운': money,
      '인간관계운': relationship,
      '건강운': health,
      '일/학업운': work,
    };
    final topAspect = aspectScores.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    final statusLabel = overall >= 78
        ? '상승'
        : (overall >= 55 ? '보통' : '주의');
    final keywords = <String>{
      _aspectKeywordPool[topAspect.key]!,
      _pickOne(rng, _heroKeywordPool),
    }.toList();
    if (keywords.length < 3 && rng.nextBool()) {
      keywords.add(_pickOne(rng, _heroKeywordPool));
    }

    final hero = FortuneHero(
      score: overall,
      headline: model.summaryText,
      name: name,
      date: model.date,
      statusLabel: statusLabel,
      keywords: keywords.toSet().toList(),
      subDescription: _pickOne(rng, _heroSubDescriptionPool),
    );

    final sections = <FortuneSection>[
      OverviewSection(
        title: '오늘의 흐름',
        body: _overviewBody(rng, overall, scores),
      ),
      TimelineSection(title: '시간대별 흐름', slots: _timelineSlots(rng)),
      AspectSection(
        title: '연애운',
        index: love,
        body: _aspectBody(rng, '연애운', love),
      ),
      AspectSection(
        title: '금전운',
        index: money,
        body: _aspectBody(rng, '금전운', money),
      ),
      AspectSection(
        title: '인간관계운',
        index: relationship,
        body: _aspectBody(rng, '인간관계운', relationship),
      ),
      AspectSection(
        title: '건강운',
        index: health,
        body: _aspectBody(rng, '건강운', health),
      ),
      AspectSection(
        title: '일/학업운',
        index: work,
        body: _aspectBody(rng, '일/학업운', work),
      ),
      ListSection(
        title: '오늘 피해야 할 것',
        items: _pickN(rng, _avoidPool, 3),
        listType: FortuneSectionType.avoid,
      ),
      ListSection(
        title: '오늘 추천 행동',
        items: _pickN(rng, _recommendPool, 3),
        listType: FortuneSectionType.recommend,
      ),
      LuckySection(
        title: '오늘의 행운 요소',
        items: [
          LuckyItem(label: '색', value: model.luckyColor),
          LuckyItem(label: '숫자', value: '${model.luckyNumber}'),
          LuckyItem(
            label: '시간',
            value: _pickOne(rng, _luckyTimePool),
            requiresPass: true,
          ),
          LuckyItem(
            label: '방향',
            value: _pickOne(rng, _luckyDirectionPool),
            requiresPass: true,
          ),
          LuckyItem(
            label: '아이템',
            value: _pickOne(rng, _luckyItemPool),
            requiresPass: true,
          ),
          LuckyItem(
            label: '오늘의 키워드',
            value: _pickOne(rng, _luckyKeywordPool),
            requiresPass: true,
          ),
        ],
      ),
    ];

    return FortuneReport(hero: hero, sections: sections);
  }

  static int _clamp(int v, int min, int max) =>
      v < min ? min : (v > max ? max : v);

  static int _offset(Random rng) => rng.nextInt(11) - 5; // -5 ~ +5

  static String _pickOne(Random rng, List<String> pool) =>
      pool[rng.nextInt(pool.length)];

  static List<String> _pickN(Random rng, List<String> pool, int n) {
    final shuffled = [...pool]..shuffle(rng);
    return shuffled.take(n).toList();
  }

  static String _overviewBody(
    Random rng,
    int overall,
    Map<String, int> scores,
  ) {
    final tone = overall >= 80
        ? '오늘은 전반적으로 기운이 맑고 흐름이 순조로운 날이에요.'
        : overall >= 60
        ? '오늘은 무난한 흐름 속에서 작은 기회들이 곳곳에 숨어 있는 날이에요.'
        : '오늘은 서두르기보다 천천히 정리하며 가는 것이 좋은 날이에요.';
    final variants = [
      '$tone 마음을 편하게 갖고 순간순간에 집중하면 좋은 결과로 이어질 수 있어요.',
      '$tone 작은 선택 하나하나가 하루 전체의 분위기를 좌우할 수 있으니 신중하게 움직여보세요.',
      '$tone 주변 사람들과의 교류에서 의외의 힌트를 얻을 수 있는 하루예요.',
    ];
    final closing = [
      '연애·금전·인간관계·건강·일/학업 모두 큰 굴곡 없이 안정적으로 흘러갈 가능성이 높아요.',
      '무리한 욕심을 내기보다는 지금 가진 것을 잘 지키는 데 집중하면 좋겠어요.',
      '오후로 갈수록 에너지가 살아나는 흐름이니 중요한 일은 조금 미뤄도 괜찮아요.',
    ];
    return '${variants[rng.nextInt(variants.length)]} ${closing[rng.nextInt(closing.length)]}';
  }

  static List<TimelineSlot> _timelineSlots(Random rng) {
    return [
      TimelineSlot(label: '오전', body: _pickOne(rng, _timelineMorning)),
      TimelineSlot(label: '오후', body: _pickOne(rng, _timelineAfternoon)),
      TimelineSlot(label: '저녁', body: _pickOne(rng, _timelineEvening)),
      TimelineSlot(label: '밤', body: _pickOne(rng, _timelineNight)),
    ];
  }

  static String _aspectBody(Random rng, String aspect, int index) {
    final tier = index >= 80 ? 2 : (index >= 60 ? 1 : 0);
    final pool = _aspectPool[aspect]![tier]!;
    return _pickOne(rng, pool);
  }

  // ── 문구 풀(결정론적 랜덤 선택용) ──

  static const _timelineMorning = [
    '차분하게 하루를 준비하기 좋은 시간이에요. 무리한 일정보다는 순서를 정리해보세요.',
    '생각보다 컨디션이 가볍게 올라오는 시간대예요. 중요한 대화는 이 시간에 나쁘지 않아요.',
  ];
  static const _timelineAfternoon = [
    '집중력이 살아나는 시간이에요. 미뤄둔 일을 처리하기에 좋은 흐름이에요.',
    '사람들과의 교류에서 좋은 기운이 들어오는 시간대예요. 대화를 많이 나눠보세요.',
  ];
  static const _timelineEvening = [
    '조금씩 여유가 생기는 시간이에요. 감정적인 결정은 살짝 미뤄두는 게 좋아요.',
    '하루를 정리하며 스스로를 돌아보기 좋은 시간대예요.',
  ];
  static const _timelineNight = [
    '편안한 휴식이 필요한 시간이에요. 내일을 위해 일찍 마음을 정리해보세요.',
    '생각이 많아질 수 있는 시간이지만, 무리한 결정은 내일로 미뤄도 괜찮아요.',
  ];

  static const _avoidPool = [
    '즉흥적인 큰 지출',
    '감정적인 말다툼',
    '무리한 약속 잡기',
    '과도한 야근·무리한 일정',
    '검증되지 않은 정보에 대한 성급한 판단',
    '평소보다 늦은 취침',
  ];

  static const _recommendPool = [
    '가까운 사람에게 먼저 연락하기',
    '짧은 산책이나 스트레칭으로 몸 풀기',
    '오늘 할 일 우선순위 정리하기',
    '평소 미뤄둔 정리·청소 해보기',
    '가벼운 감사 인사 전하기',
    '물을 충분히 마시며 컨디션 관리하기',
  ];

  static const _luckyTimePool = ['오전 9~11시', '오후 1~3시', '오후 3~5시', '저녁 6~8시'];
  static const _luckyDirectionPool = ['동쪽', '서쪽', '남쪽', '북쪽', '남동쪽'];
  static const _luckyItemPool = [
    '따뜻한 색의 소품',
    '작은 노트',
    '향이 좋은 차',
    '손편지',
    '동그란 액세서리',
  ];
  static const _luckyKeywordPool = ['균형', '여유', '용기', '경청', '정리', '시작'];

  // [§6-1 히어로 카드] 오늘의 키워드 chip 풀 + 세부 운세별 대표 키워드 매핑.
  static const _heroKeywordPool = ['안정', '여유', '집중', '균형', '기회', '휴식'];
  static const _aspectKeywordPool = <String, String>{
    '연애운': '설렘',
    '금전운': '안정',
    '인간관계운': '소통',
    '건강운': '활력',
    '일/학업운': '집중',
  };

  // [§6-1] 히어로 카드 보조 설명 1문장(전체 흐름 카드의 3~4문장 서술과는 겹치지
  // 않도록, 오늘 하루를 대하는 태도에 대한 짧은 한 줄 조언만 담는다).
  static const _heroSubDescriptionPool = [
    '오늘은 무리하지 않고 흐름을 읽는 것이 중요한 날이에요.',
    '오늘은 서두르지 않고 하나씩 정리해가면 좋은 하루예요.',
    '오늘은 평소보다 조금 더 여유를 갖고 움직이면 좋겠어요.',
    '오늘은 작은 신호에도 귀 기울이면 좋은 힌트를 얻을 수 있어요.',
  ];

  static const _aspectPool = <String, Map<int, List<String>>>{
    '연애운': {
      0: [
        '오늘은 감정 기복이 있을 수 있어요. 서두르지 말고 상대의 말을 한 번 더 들어주면 오해를 줄일 수 있어요.',
        '연인이나 좋아하는 사람과의 대화에서 오해가 생기기 쉬운 하루예요. 표현은 부드럽게 해보세요.',
      ],
      1: [
        '평소와 비슷한 흐름이 이어져요. 작은 관심 표현이 관계를 한 단계 더 따뜻하게 만들어줄 수 있어요.',
        '무난한 하루지만, 먼저 다가가는 쪽이 더 좋은 흐름을 만들 수 있어요.',
      ],
      2: [
        '설레는 기운이 감도는 하루예요. 솔직한 마음을 표현하면 좋은 반응으로 이어질 가능성이 높아요.',
        '관계에 좋은 에너지가 흐르는 날이에요. 함께 시간을 보내는 것만으로도 만족도가 높아져요.',
      ],
    },
    '금전운': {
      0: [
        '지출에 신중해야 하는 하루예요. 큰 결정은 며칠 미뤄두는 것이 안전해요.',
        '예상치 못한 지출이 생기기 쉬운 날이에요. 가계부를 한 번 점검해보세요.',
      ],
      1: [
        '안정적인 흐름이 이어져요. 계획적인 소비라면 큰 문제는 없는 하루예요.',
        '들어오고 나가는 흐름이 균형을 이루는 날이에요. 무리한 투자는 피해보세요.',
      ],
      2: [
        '재물운이 좋은 하루예요. 계획했던 지출이나 계약이 있다면 순조롭게 진행될 가능성이 높아요.',
        '작은 행운이 따라오는 날이에요. 저축이나 투자 계획을 세워보기에도 좋아요.',
      ],
    },
    '인간관계운': {
      0: [
        '사람들과의 관계에서 조금 예민해지기 쉬운 하루예요. 말투에 신경 쓰면 좋겠어요.',
        '오해가 생기기 쉬운 시기예요. 확인이 필요한 부분은 직접 물어보는 것이 좋아요.',
      ],
      1: [
        '무난한 관계 흐름이 이어져요. 먼저 안부를 물어보면 좋은 인연으로 이어질 수 있어요.',
        '평소와 비슷한 하루지만, 작은 배려가 관계를 더 좋게 만들어줘요.',
      ],
      2: [
        '주변 사람들과 좋은 케미가 느껴지는 하루예요. 새로운 인연이 생길 수도 있어요.',
        '도움을 주고받기 좋은 흐름이에요. 먼저 나서서 도움을 청해도 좋은 반응을 얻을 수 있어요.',
      ],
    },
    '건강운': {
      0: [
        '컨디션 관리가 필요한 하루예요. 무리한 일정보다는 휴식을 우선해보세요.',
        '평소보다 피로가 쌓이기 쉬운 날이에요. 수면 시간을 조금 더 확보해보세요.',
      ],
      1: [
        '평소와 비슷한 컨디션이 이어져요. 가벼운 스트레칭 정도면 충분해요.',
        '큰 이상은 없지만 물을 충분히 마시면 더 가벼운 하루를 보낼 수 있어요.',
      ],
      2: [
        '몸과 마음의 균형이 좋은 하루예요. 가벼운 운동을 곁들이면 더 좋은 흐름을 이어갈 수 있어요.',
        '에너지가 넘치는 날이에요. 다만 과신하지 말고 적정선을 지켜보세요.',
      ],
    },
    '일/학업운': {
      0: [
        '집중력이 흔들리기 쉬운 하루예요. 중요한 결정은 다음으로 미루는 것이 안전해요.',
        '생각보다 진행이 더딜 수 있어요. 욕심내지 말고 하나씩 처리해보세요.',
      ],
      1: [
        '평소와 비슷한 성과가 이어져요. 계획한 대로만 진행해도 무난한 하루가 될 거예요.',
        '무난한 흐름이지만, 우선순위를 다시 점검해보면 더 효율적으로 움직일 수 있어요.',
      ],
      2: [
        '집중력이 좋은 하루예요. 미뤄둔 일을 처리하거나 새로운 시도를 하기에 좋은 흐름이에요.',
        '성과가 눈에 보이는 날이에요. 자신 있게 밀고 나가도 좋은 결과로 이어질 수 있어요.',
      ],
    },
  };
}
