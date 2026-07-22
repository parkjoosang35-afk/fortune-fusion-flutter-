import '../../../../core/api/api_result.dart';
import '../../../../core/utils/mock_delay.dart';
import '../domain/daily_fortune_model.dart';

/// 06단계 §4.3 `GET /v1/fortune/daily/today` 대응 Mock Repository
/// 09단계 §3.2-② 프롬프트 출력 스키마(category_scores/lucky_color/lucky_number/summary_text)를
/// DB 컬럼과 1:1 매핑한 것과 동일한 구조로 Mock 데이터를 생성한다.
class DailyFortuneRepository {
  static const _summaries = [
    '오늘은 새로운 인연이 다가올 좋은 기운이 감돌고 있어요. 평소보다 적극적인 태도가 행운을 부릅니다.',
    '작은 실수에 주의가 필요한 날입니다. 서두르지 않고 차분하게 하루를 보내면 무난하게 지나갈 거예요.',
    '재물운이 상승하는 하루! 뜻밖의 좋은 소식이 있을 수 있으니 기대해도 좋습니다.',
    '몸과 마음의 휴식이 필요한 시기입니다. 무리한 일정보다는 컨디션 관리에 집중하세요.',
  ];

  Future<ApiResult<DailyFortuneModel>> getToday() async {
    await mockDelay(ms: 500);
    final now = DateTime.now();
    final seed = now.day + now.month;
    return ApiResult.ok(
      DailyFortuneModel(
        id: 'df_${now.year}${now.month}${now.day}',
        date: DateTime(now.year, now.month, now.day),
        categoryScores: {
          '총운': 60 + (seed * 7) % 40,
          '애정': 55 + (seed * 3) % 40,
          '재물': 50 + (seed * 11) % 45,
          '건강': 65 + (seed * 5) % 30,
        },
        luckyColor: ['보라', '골드', '블루', '그린'][seed % 4],
        luckyNumber: (seed % 9) + 1,
        summaryText: _summaries[seed % _summaries.length],
      ),
    );
  }
}
