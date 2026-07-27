import 'dart:typed_data';

import '../../../../core/api/api_result.dart';
import '../../../../core/utils/mock_delay.dart';
import '../domain/face_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/face/analyze` 대응 Mock Repository
/// 실제 사진 업로드/분석 대신 09단계 §7 개인정보보호 원칙(이미지 즉시파기)에 맞춰
/// Mock 단계에서는 이미지를 서버에 전송하지 않고 로컬에서 결과만 시뮬레이션한다.
///
/// 07단계(추가) §3.3 - [analyze]가 선택적으로 [image]를 전달받도록 확장되었으나,
/// Mock 구현에서는 실제로 파일을 읽거나 전송하지 않는다(향후 실제 API 연동 시
/// multipart 업로드 로직으로 교체될 지점).
///
/// 07단계(추가, 수정) §3.3 - Flutter Web은 dart:io의 File을 지원하지 않으므로
/// 웹/Android 공통으로 동작하는 [Uint8List] 기반으로 시그니처를 변경한다.
class FaceRepository {
  final List<FaceResultModel> _history = [];

  static const _featurePool = {
    '이마': ['넓고 둥근 이마로 지혜와 포용력을 나타냅니다', '반듯한 이마로 계획적이고 신중한 성향을 보여줍니다'],
    '눈': ['또렷하고 생기있는 눈매로 총명한 기운이 느껴집니다', '온화한 눈빛으로 주변에 신뢰감을 줍니다'],
    '코': ['곧고 균형잡힌 코로 재물운이 안정적입니다', '콧대가 뚜렷해 자립심과 추진력이 강합니다'],
    '입': ['단정한 입매로 언행에 신중함이 느껴집니다', '입꼬리가 살짝 올라가 있어 긍정적인 기운이 강합니다'],
    '턱': ['둥근 턱선으로 온화하고 사교적인 성향입니다', '단단한 턱선으로 강한 의지와 인내심을 보여줍니다'],
  };

  static const _topicTexts = {
    '재물': '코와 이마의 조화가 좋아 안정적인 재물운을 타고났습니다. 꾸준한 노력이 결실로 이어질 것입니다.',
    '애정': '눈매와 입매에서 따뜻한 기운이 느껴지며, 주변 사람들과 좋은 관계를 맺는 데 유리한 인상입니다.',
    '직업': '전체적으로 균형잡힌 인상으로, 리더십과 신뢰를 동시에 얻을 수 있는 관상입니다.',
    '건강': '혈색과 윤곽이 안정적이라 전반적인 건강 기운이 양호한 편입니다. 다만 무리한 스케줄은 주의하세요.',
    '종합': '전체적으로 조화롭고 안정적인 인상으로, 스스로의 강점을 잘 살리면 좋은 흐름을 이어갈 수 있습니다.',
  };

  Future<ApiResult<FaceResultModel>> analyze({Uint8List? image}) async {
    await mockDelay(ms: 2000); // 09단계 §5 이미지 분석 대기시간 재현

    // 07단계(추가) §3.3 - 실제 API 연동 시 이 지점에서 image를 multipart로 전송한다.
    final seed = DateTime.now().millisecondsSinceEpoch;
    final features = <String, String>{};
    _featurePool.forEach((part, options) {
      features[part] = options[seed % options.length];
    });

    final result = FaceResultModel(
      id: 'face_$seed',
      features: features,
      topicResults: Map.of(_topicTexts),
      summary: _topicTexts['종합']!,
      createdAt: DateTime.now(),
    );

    _history.insert(0, result);
    return ApiResult.ok(result);
  }

  Future<ApiResult<List<FaceResultModel>>> getHistory() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_history));
  }
}
