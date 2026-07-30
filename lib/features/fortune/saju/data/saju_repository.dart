import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/api_result.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/utils/mock_delay.dart';
import '../domain/saju_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/saju/request` → `GET /v1/fortune/result/:id` 대응
/// 09단계 §3.2-① 프롬프트 출력 스키마(pillars/five_elements/topic_results/summary)를 반영
///
/// [Phase6 - AI운세 실LLM 연동] [requestSaju]는 admin_web 공개 API
/// (`POST /api/public/fortune/saju`)를 호출해 실제 LLM(ai_prompt_templates 기반)이
/// 생성한 주제별 해석 텍스트를 받아온다(Mock→실API 전환). 명식(사주 4주)과
/// 오행 점수는 서버에서도 여전히 결정론적 규칙으로 계산되며, 이 부분은 이번
/// 연동 범위가 아니다(운세 "해석 텍스트"만 실LLM으로 교체).
///
/// [내 사주함(프로필 CRUD)] 서버에 대응 API가 아직 없어, 프로필 관리는
/// 이전과 동일하게 로컬 Mock으로 유지한다(범위 밖).
///
/// [로드맵④] 실 로그인 사용자 ID를 [AuthTokenStore]에서 조회한다.
/// 비로그인 상태에서는 폴백 테스트 유저(userId=1)를 그대로 사용한다.
class SajuRepository {
  final List<SajuResultModel> _history = [];

  // [웹→앱 이식] 신통방통 js/saju-profile-engine.js "내 사주함" Mock 저장소
  final List<SajuProfileModel> _profiles = [];

  Future<ApiResult<SajuResultModel>> requestSaju({
    required String birthDate,
    String? birthTime,
    required bool isLunar,
    required List<String> topics,
    String? profileId,
    String? profileName,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/fortune/saju',
    );
    debugPrint('[SajuRepository] [requestSaju] 요청 시작 -> $uri');

    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'birthDate': birthDate,
              'birthTime': birthTime,
              'isLunar': isLunar,
              'topics': topics,
              'profileId': profileId,
              'profileName': profileName,
            }),
          )
          .timeout(const Duration(seconds: 45));

      debugPrint(
        '[SajuRepository] [requestSaju] 응답 수신 -> statusCode=${response.statusCode}',
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '사주 분석에 실패했습니다.';
        debugPrint('[SajuRepository] [requestSaju] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final pillarsRaw = data['pillars'] as Map<String, dynamic>;
      final pillars = SajuPillars(
        year: pillarsRaw['year'] as String,
        month: pillarsRaw['month'] as String,
        day: pillarsRaw['day'] as String,
        hour: pillarsRaw['hour'] as String?,
      );

      final fiveElementsRaw = data['fiveElements'] as Map<String, dynamic>;
      final fiveElements = fiveElementsRaw.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );

      final topicResultsRaw = data['topicResults'] as Map<String, dynamic>;
      final topicResults = topicResultsRaw.map(
        (key, value) => MapEntry(key, value as String),
      );

      final result = SajuResultModel(
        id: data['id'] as String,
        pillars: pillars,
        fiveElements: fiveElements,
        topicResults: topicResults,
        summary: data['summary'] as String,
        createdAt: DateTime.parse(data['createdAt'] as String),
        profileId: data['profileId'] as String?,
        profileName: data['profileName'] as String?,
      );

      _history.insert(0, result);
      return ApiResult.ok(result);
    } catch (e, st) {
      debugPrint('[SajuRepository] [requestSaju] 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('사주 분석에 실패했습니다: $e');
    }
  }

  Future<ApiResult<List<SajuResultModel>>> getHistory() async {
    // [Phase6 범위] 히스토리 조회 API는 아직 신설하지 않아, 이번 요청으로
    // 새로 생성된 결과들을 로컬에 누적해두고 그대로 반환한다(범위 밖: 서버 영속 조회).
    return ApiResult.ok(List.unmodifiable(_history));
  }

  // ── [웹→앱 이식] "내 사주함" 프로필 CRUD Mock (Phase6 범위 밖, 로컬 유지) ──
  // 신통방통 js/saju-profile-engine.js getMySajuProfiles/createSajuProfile/
  // updateSajuProfile/deleteSajuProfile/setPrimarySajuProfile 대응

  Future<ApiResult<List<SajuProfileModel>>> getProfiles() async {
    await mockDelay(ms: 250);
    return ApiResult.ok(List.unmodifiable(_profiles));
  }

  Future<ApiResult<SajuProfileModel>> createProfile({
    required String profileName,
    required String name,
    required String gender,
    required String birthDate,
    String? birthTime,
    bool isLunar = false,
    SajuRelationship relationship = SajuRelationship.self,
  }) async {
    await mockDelay(ms: 300);
    final isFirst = _profiles.isEmpty;
    final profile = SajuProfileModel(
      id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
      profileName: profileName,
      name: name,
      gender: gender,
      birthDate: birthDate,
      birthTime: birthTime,
      isLunar: isLunar,
      relationship: relationship,
      isPrimary: isFirst, // 첫 프로필은 자동으로 대표 프로필로 지정
      createdAt: DateTime.now(),
    );
    _profiles.add(profile);
    return ApiResult.ok(profile);
  }

  Future<ApiResult<SajuProfileModel>> updateProfile(
    SajuProfileModel updated,
  ) async {
    await mockDelay(ms: 300);
    final index = _profiles.indexWhere((p) => p.id == updated.id);
    if (index == -1) {
      return ApiResult.fail('프로필을 찾을 수 없습니다.');
    }
    _profiles[index] = updated;
    return ApiResult.ok(updated);
  }

  Future<ApiResult<void>> deleteProfile(String id) async {
    await mockDelay(ms: 250);
    _profiles.removeWhere((p) => p.id == id);
    return ApiResult.ok(null);
  }

  Future<ApiResult<void>> setPrimaryProfile(String id) async {
    await mockDelay(ms: 250);
    for (var i = 0; i < _profiles.length; i++) {
      _profiles[i] = _profiles[i].copyWith(isPrimary: _profiles[i].id == id);
    }
    return ApiResult.ok(null);
  }
}
