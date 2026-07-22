import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/compatibility_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/compatibility/request` 대응 Mock Repository
/// 09단계 §3.2-⑥ 궁합 프롬프트 출력 스키마 반영
class CompatibilityRepository {
  final List<CompatibilityResultModel> _history = [];

  static const _topicPool = {
    '애정': [
      '서로에 대한 호감과 관심이 자연스럽게 이어지는 좋은 궁합입니다.',
      '처음엔 조심스럽지만 시간이 지날수록 깊어지는 인연입니다.',
    ],
    '성격': [
      '서로 다른 성향이 오히려 균형을 이루며 좋은 시너지를 만듭니다.',
      '비슷한 가치관을 공유하여 편안한 관계를 유지할 수 있습니다.',
    ],
    '미래': [
      '함께 성장하며 장기적으로 안정적인 관계를 이어갈 가능성이 높습니다.',
      '서로의 부족한 부분을 채워주며 좋은 파트너가 될 수 있습니다.',
    ],
  };

  Future<ApiResult<CompatibilityResultModel>> requestCompatibility({
    required String birthDateA,
    required String birthDateB,
    String? nameA,
    String? nameB,
  }) async {
    await mockDelay(ms: 1800);

    final seed = (birthDateA + birthDateB).hashCode.abs();
    final score = 55 + (seed % 41); // 55~95점

    final topicResults = <String, String>{};
    _topicPool.forEach((topic, options) {
      topicResults[topic] = options[seed % options.length];
    });

    final result = CompatibilityResultModel(
      id: 'compat_${DateTime.now().millisecondsSinceEpoch}',
      nameA: nameA?.isNotEmpty == true ? nameA! : '나',
      nameB: nameB?.isNotEmpty == true ? nameB! : '상대방',
      score: score,
      topicResults: topicResults,
      summary: score >= 80
          ? '천생연분에 가까운 궁합입니다. 서로를 향한 신뢰와 애정이 관계를 더욱 단단하게 만들어줄 것입니다.'
          : score >= 65
          ? '전반적으로 좋은 궁합입니다. 서로 조금씩 배려한다면 더욱 좋은 관계로 발전할 수 있습니다.'
          : '노력이 필요한 궁합이지만, 서로를 이해하려는 마음이 있다면 충분히 좋은 관계를 만들 수 있습니다.',
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }

  Future<ApiResult<List<CompatibilityResultModel>>> getHistory() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_history));
  }
}
