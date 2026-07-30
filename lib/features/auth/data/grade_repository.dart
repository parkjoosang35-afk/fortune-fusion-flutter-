import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env_config.dart';
import '../domain/grade_model.dart';

/// 04A §A-5 `user_grades` 마스터 대응 Repository
///
/// [실API 전환] admin_web 공개 API(`GET /api/public/grades`)로 기존 4등급
/// 하드코딩 Mock을 교체한다. 등급 마스터는 자주 바뀌지 않으므로 앱 프로세스
/// 생애주기 동안 1회만 서버에서 조회해 메모리에 캐싱하고, 이후 호출은 캐시를
/// 재사용한다(AuthProvider가 로그인/세션복원마다 getGradeByCode를 호출하므로
/// 매번 네트워크 요청을 보내지 않기 위함).
class GradeRepository {
  static List<GradeModel>? _cache;

  /// 서버 응답을 못 받았을 때(오프라인 등) 최소한의 폴백으로 사용하는 기본값.
  static const List<GradeModel> _fallback = [
    GradeModel(
      code: 'bronze',
      name: '브론즈',
      minActivityScore: 0,
      pointEarnMultiplier: 1.0,
      sortOrder: 1,
    ),
  ];

  Future<List<GradeModel>> getAllGrades() async {
    if (_cache != null) return _cache!;

    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/grades');
    debugPrint('[GradeRepository] [getAllGrades] 요청 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint(
          '[GradeRepository] [getAllGrades] 실패 -> ${decoded['error']}',
        );
        return _fallback;
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final rows = (data['grades'] as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return _fallback;

      final grades = rows.map(GradeModel.fromJson).toList();
      _cache = grades;
      return grades;
    } catch (e) {
      debugPrint('[GradeRepository] [getAllGrades] 예외 -> $e');
      return _fallback;
    }
  }

  Future<GradeModel> getGradeByCode(String code) async {
    final grades = await getAllGrades();
    return grades.firstWhere((g) => g.code == code, orElse: () => grades.first);
  }

  /// 활동점수 기준 등급 산정 (배치 산정 로직의 Flutter측 간이 버전)
  /// [주의] 캐시된 등급 목록이 아직 없을 수 있어 동기 호출이 필요한 경우
  /// (예: 위젯 build 중)에는 반드시 getAllGrades()를 먼저 호출해 캐시를
  /// 채운 뒤 사용해야 한다. 캐시가 비어 있으면 폴백 등급만 반환한다.
  GradeModel resolveByActivityScore(int activityScore) {
    final grades = _cache ?? _fallback;
    final sorted = [...grades]
      ..sort((a, b) => b.minActivityScore.compareTo(a.minActivityScore));
    return sorted.firstWhere(
      (g) => activityScore >= g.minActivityScore,
      orElse: () => grades.first,
    );
  }
}
