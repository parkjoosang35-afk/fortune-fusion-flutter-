import '../../../../core/api/api_result.dart';
import '../../../../core/utils/mock_delay.dart';
import '../domain/saju_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/saju/request` → `GET /v1/fortune/result/:id` 대응 Mock
/// 09단계 §3.2-① 프롬프트 출력 스키마(pillars/five_elements/topic_results/summary)를 반영한 Mock 생성
class SajuRepository {
  final List<SajuResultModel> _history = [];

  static const _stems = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const _branches = [
    '자',
    '축',
    '인',
    '묘',
    '진',
    '사',
    '오',
    '미',
    '신',
    '유',
    '술',
    '해',
  ];

  Future<ApiResult<SajuResultModel>> requestSaju({
    required String birthDate,
    String? birthTime,
    required bool isLunar,
    required List<String> topics,
  }) async {
    await mockDelay(ms: 1800); // 09단계 §5 재시도/타임아웃 UX 재현을 위한 의도적 지연

    final seed = birthDate.hashCode.abs();
    String pillar(int offset) =>
        '${_stems[(seed + offset) % 10]}${_branches[(seed + offset * 3) % 12]}';

    final pillars = SajuPillars(
      year: pillar(1),
      month: pillar(2),
      day: pillar(3),
      hour: birthTime != null ? pillar(4) : null,
    );

    final fiveElements = {
      '목': 10 + (seed % 20),
      '화': 10 + ((seed ~/ 2) % 20),
      '토': 10 + ((seed ~/ 3) % 20),
      '금': 10 + ((seed ~/ 5) % 20),
      '수': 10 + ((seed ~/ 7) % 20),
    };

    const topicTexts = {
      '재물':
          '올해는 안정적인 재물운이 이어지며, 특히 하반기에 예상치 못한 수입이 생길 가능성이 있습니다. 무리한 투자보다는 저축과 계획적인 소비가 유리합니다.',
      '애정':
          '인간관계에서 따뜻한 기운이 감돌며, 솔로라면 새로운 인연을 만날 기회가 열립니다. 커플은 서로에 대한 신뢰가 더욱 깊어지는 시기입니다.',
      '직업':
          '주변의 인정을 받으며 성장할 수 있는 흐름입니다. 다만 성급한 결정은 피하고, 신중하게 기회를 살펴보는 것이 중요합니다.',
      '건강': '전반적으로 무난하나 과로에 주의가 필요합니다. 규칙적인 생활 패턴을 유지하면 큰 탈 없이 지나갈 수 있는 시기입니다.',
      '종합':
          '전반적으로 안정과 성장이 조화를 이루는 시기입니다. 스스로의 페이스를 지키며 꾸준히 나아간다면 좋은 결실을 맺을 수 있습니다.',
    };

    final topicResults = <String, String>{};
    for (final t in (topics.isEmpty ? ['종합'] : topics)) {
      topicResults[t] = topicTexts[t] ?? topicTexts['종합']!;
    }

    final result = SajuResultModel(
      id: 'saju_${DateTime.now().millisecondsSinceEpoch}',
      pillars: pillars,
      fiveElements: fiveElements,
      topicResults: topicResults,
      summary: topicTexts['종합']!,
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }

  Future<ApiResult<List<SajuResultModel>>> getHistory() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_history));
  }
}
