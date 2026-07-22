import '../../../../core/api/api_result.dart';
import '../../../../core/utils/mock_delay.dart';
import '../domain/palm_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/palm/analyze` 대응 Mock Repository
/// 09단계 §7 개인정보보호 원칙에 따라 이미지는 서버 전송/저장 없이 로컬에서 결과만 시뮬레이션
class PalmRepository {
  final List<PalmResultModel> _history = [];

  static const _linePool = {
    '생명선': ['깊고 선명하게 뻗어 있어 강한 생명력과 활력을 나타냅니다', '완만하게 이어져 있어 안정적이고 평온한 삶의 흐름을 보여줍니다'],
    '두뇌선': ['뚜렷하고 길게 뻗어 있어 논리적이고 분석적인 사고력을 나타냅니다', '살짝 곡선을 이루어 창의적이고 유연한 사고를 보여줍니다'],
    '감정선': ['깊고 곧게 뻗어 있어 감정 표현이 솔직하고 직접적입니다', '부드러운 곡선으로 따뜻하고 공감능력이 높은 성향입니다'],
    '운명선': ['선명하게 이어져 있어 뚜렷한 목표의식을 갖고 나아가는 흐름입니다', '중간에 변화가 있어 인생의 전환점을 여러 번 맞이하는 흐름입니다'],
  };

  static const _topicTexts = {
    '재물': '운명선과 생명선의 조화가 좋아 꾸준한 재물 축적이 가능한 손금입니다.',
    '애정': '감정선이 뚜렷하여 진솔한 감정 표현으로 좋은 인연을 만날 가능성이 높습니다.',
    '직업': '두뇌선의 흐름이 안정적이라 전문성을 쌓아가는 데 유리한 조건입니다.',
    '건강': '생명선이 깊게 새겨져 있어 전반적인 체력과 회복력이 좋은 편입니다.',
    '종합': '전체적으로 균형 잡힌 손금으로, 스스로의 강점을 신뢰하고 나아가면 좋은 결실을 맺을 수 있습니다.',
  };

  Future<ApiResult<PalmResultModel>> analyze() async {
    await mockDelay(ms: 2000);

    final seed = DateTime.now().millisecondsSinceEpoch;
    final lines = <String, String>{};
    _linePool.forEach((line, options) {
      lines[line] = options[seed % options.length];
    });

    final result = PalmResultModel(
      id: 'palm_$seed',
      lines: lines,
      topicResults: Map.of(_topicTexts),
      summary: _topicTexts['종합']!,
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }

  Future<ApiResult<List<PalmResultModel>>> getHistory() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_history));
  }
}
