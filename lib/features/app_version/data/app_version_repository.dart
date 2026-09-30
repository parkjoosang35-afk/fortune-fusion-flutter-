import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/config/env_config.dart';

/// [DEV-2026-001 작업3-5-1/5-2 재발방지체계] `GET /api/public/app-version`
/// 응답을 담는 모델. admin_web이 system_settings(key-value)에서 읽어 만든
/// Android 플랫폼 버전 정책(latest/min versionCode, 업데이트 URL, 안내문구).
class AppVersionPolicy {
  final int latestVersionCode;
  final int minVersionCode;
  final String updateUrl;
  final String? notice;

  const AppVersionPolicy({
    required this.latestVersionCode,
    required this.minVersionCode,
    required this.updateUrl,
    this.notice,
  });

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    return AppVersionPolicy(
      latestVersionCode: (json['latestVersionCode'] as num?)?.toInt() ?? 1,
      minVersionCode: (json['minVersionCode'] as num?)?.toInt() ?? 1,
      updateUrl:
          json['updateUrl'] as String? ??
          'https://play.google.com/store/apps',
      notice: json['notice'] as String?,
    );
  }

  /// 현재 실행 중인 앱의 versionCode가 이 정책의 minVersionCode보다
  /// 낮으면 강제 업데이트 대상이다.
  bool isForceUpdateRequired(int currentVersionCode) =>
      currentVersionCode < minVersionCode;

  /// 강제 대상은 아니지만 최신 버전보다 낮은 경우(선택적 업데이트 안내용,
  /// 현재는 강제 팝업에만 사용하고 선택적 안내 UI는 별도 범위이므로
  /// 이 값 자체를 강제로 사용하지는 않음 — 향후 확장 지점).
  bool hasNewerVersion(int currentVersionCode) =>
      currentVersionCode < latestVersionCode;
}

/// `GET /api/public/app-version` 호출 Repository.
///
/// [설계 원칙] 이 API는 인증이 필요 없는 공개 엔드포인트이며(앱 부팅 시점,
/// 로그인 여부와 무관하게 항상 체크해야 함), 실패 시 앱 시작을 막아서는
/// 안 된다 — 네트워크 문제로 이 호출이 실패했다고 서비스 자체를 차단하면
/// 오프라인/네트워크 불안정 상황에서 정상 사용자까지 피해를 입는다. 그래서
/// 호출 실패는 "강제 업데이트 아님"으로 안전하게 폴백한다(fail-open).
class AppVersionRepository {
  Future<ApiResult<AppVersionPolicy>> checkVersion() async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/app-version');
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[AppVersionRepository] [checkVersion] 실패 -> HTTP ${response.statusCode}');
        return ApiResult.fail('버전 정보를 불러오지 못했습니다.');
      }

      final policy = AppVersionPolicy.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      return ApiResult.ok(policy);
    } catch (e) {
      debugPrint('[AppVersionRepository] [checkVersion] 예외 -> $e');
      return ApiResult.fail('버전 정보를 불러오지 못했습니다: $e');
    }
  }
}
