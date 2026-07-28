import '../../../core/utils/mock_delay.dart';
import '../domain/grade_model.dart';

/// 04A §A-5 `user_grades` 마스터 대응 Repository
/// 10단계(Mock): 4등급 마스터를 고정 배열로 제공. 향후 실제 API 연동 시
/// `/v1/users/grades`(마스터 목록) 엔드포인트로 교체하되 상위 레이어는 무변경.
class GradeRepository {
  static const List<GradeModel> _grades = [
    GradeModel(
      code: 'bronze',
      name: '브론즈',
      minActivityScore: 0,
      pointEarnMultiplier: 1.0,
      sortOrder: 1,
    ),
    GradeModel(
      code: 'silver',
      name: '실버',
      minActivityScore: 100,
      pointEarnMultiplier: 1.1,
      sortOrder: 2,
    ),
    GradeModel(
      code: 'gold',
      name: '골드',
      minActivityScore: 500,
      pointEarnMultiplier: 1.3,
      sortOrder: 3,
    ),
    GradeModel(
      code: 'vip',
      name: 'VIP',
      minActivityScore: 2000,
      pointEarnMultiplier: 1.5,
      sortOrder: 4,
    ),
  ];

  Future<List<GradeModel>> getAllGrades() async {
    await mockDelay(ms: 150);
    return _grades;
  }

  Future<GradeModel> getGradeByCode(String code) async {
    await mockDelay(ms: 100);
    return _grades.firstWhere(
      (g) => g.code == code,
      orElse: () => _grades.first,
    );
  }

  /// 활동점수 기준 등급 산정 (배치 산정 로직의 Flutter측 간이 버전)
  GradeModel resolveByActivityScore(int activityScore) {
    final sorted = [..._grades]
      ..sort((a, b) => b.minActivityScore.compareTo(a.minActivityScore));
    return sorted.firstWhere(
      (g) => activityScore >= g.minActivityScore,
      orElse: () => _grades.first,
    );
  }
}
