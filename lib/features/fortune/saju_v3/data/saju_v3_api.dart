// 신통방통 - 정통사주 v3 API 클라이언트 (http 1.5.0 기반)
//
// [2차 지시서 - 옵션 2] 엔진 킷의 api_client.dart(dio 기반)를 앱의 실제 스택
// (http 패키지)으로 재작성한 버전. 메서드 시그니처와 반환 모델은 원본과
// 동일하게 유지해, 화면 계층(presentation)이 원본 설계를 그대로 따를 수
// 있도록 한다.
//
// [인증 체계 불일치 — 별도 보고 필요] 엔진 서버는 데모용 `X-Free-Pass` 헤더
// (STB- 접두사 32자 토큰)로 게이트하지만, 앱은 `AuthTokenStore.authHeader()`
// 가 발급하는 `Authorization: Bearer <JWT>`를 표준으로 쓴다. 이 두 체계는
// 서로 다른 것이므로, 엔진 서버가 실제로 앱의 JWT를 검증하도록 바뀌기
// 전까지는 [freePassToken]을 별도로 주입받아 X-Free-Pass 헤더에 실어 보낸다
// (임시 브릿지 — 최종 인증 통합은 백엔드 결정 필요, 완료 보고서에 기재).
//
// [배포 주소 — 하드코딩 금지] baseUrl은 항상 호출부에서 EnvConfig 계열 값을
// 주입받는다. 이 파일 자체에는 localhost:8000 등 임시 주소를 남기지 않는다.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/birth_input.dart';
import '../domain/category_item.dart';
import '../domain/interpretation_result.dart';
import '../domain/saju_report.dart';
import '../domain/saju_result_v3.dart';

/// 프리패스 토큰을 매 요청 시점에 조회하기 위한 콜백.
/// (원본 dio 버전의 `FreePassProvider` 타입을 그대로 유지)
typedef FreePassProvider = String? Function();

/// [saju/v3/*] 전용 API 결과 래퍼 — 앱 표준 `ApiResult<T>`와는 별도로,
/// 엔진 서버 특유의 402(FreePassError) 상황까지 함께 표현하기 위해
/// 이 파일 안에서만 쓰는 경량 결과형을 둔다(Provider 계층에서 필요 시
/// 표준 LoadState/ApiResult로 다시 감싼다).
class SajuV3ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isFreePassRequired;
  final bool isRateLimited;

  const SajuV3ApiException(
    this.message, {
    this.statusCode,
    this.isFreePassRequired = false,
    this.isRateLimited = false,
  });

  @override
  String toString() => 'SajuV3ApiException($statusCode): $message';
}

class SajuV3Api {
  final String baseUrl;
  final FreePassProvider freePassProvider;
  final Duration timeout;

  SajuV3Api({
    required this.baseUrl,
    required this.freePassProvider,
    this.timeout = const Duration(seconds: 15),
  });

  Map<String, String> _headers() {
    final token = freePassProvider();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'X-Free-Pass': token,
    };
  }

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('[SajuV3Api] GET -> $uri');
    try {
      final res = await http
          .get(uri, headers: _headers())
          .timeout(timeout);
      return _decode(res);
    } on TimeoutException {
      throw const SajuV3ApiException('요청 시간이 초과되었습니다.');
    } catch (e) {
      if (e is SajuV3ApiException) rethrow;
      debugPrint('[SajuV3Api] GET 예외 -> $e');
      throw SajuV3ApiException('네트워크 오류: $e');
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    debugPrint('[SajuV3Api] POST -> $uri');
    try {
      final res = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(timeout);
      return _decode(res);
    } on TimeoutException {
      throw const SajuV3ApiException('요청 시간이 초과되었습니다.');
    } catch (e) {
      if (e is SajuV3ApiException) rethrow;
      debugPrint('[SajuV3Api] POST 예외 -> $e');
      throw SajuV3ApiException('네트워크 오류: $e');
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 402) {
      // 엔진 서버의 프리패스 게이트 실패 응답
      Map<String, dynamic> data = const {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      final detail = data['detail'];
      final message = detail is Map
          ? (detail['message_kr']?.toString() ?? '열림패스가 필요합니다.')
          : '열림패스가 필요합니다.';
      throw SajuV3ApiException(
        message,
        statusCode: 402,
        isFreePassRequired: true,
      );
    }
    if (res.statusCode == 429) {
      // §15 rate limit — 5차 지시서: 시간당/일일 한도 초과. 네트워크 오류와
      // 구분되는 안내 문구를 화면 쪽에서 노출할 수 있도록 플래그로 표시한다.
      String message = '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['detail'] != null) {
          message = decoded['detail'].toString();
        }
      } catch (_) {}
      throw SajuV3ApiException(message, statusCode: 429, isRateLimited: true);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = '요청에 실패했습니다 (${res.statusCode})';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['detail'] != null) {
          final d = decoded['detail'];
          message = d is Map
              ? (d['message_kr']?.toString() ?? message)
              : d.toString();
        }
      } catch (_) {}
      throw SajuV3ApiException(message, statusCode: res.statusCode);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  // 🔓 공개 엔드포인트
  Future<List<CategoryItem>> getCategoriesV3() async {
    final data = await _get('/saju/v3/categories');
    return (data as List)
        .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // 🔒 게이트 엔드포인트 (X-Free-Pass 필요)
  Future<SajuResultV3> getSajuV3Facts(
    BirthInput b, {
    String zihourPolicy = 'traditional',
  }) async {
    final data = await _post('/saju/v3/facts', {
      ...b.toJson(),
      'zihour_policy': zihourPolicy,
    });
    return SajuResultV3.fromJson(data as Map<String, dynamic>);
  }

  Future<SajuAll69> getSajuV3Categories69(
    BirthInput b, {
    String zihourPolicy = 'traditional',
  }) async {
    final data = await _post('/saju/v3/categories69', {
      ...b.toJson(),
      'zihour_policy': zihourPolicy,
    });
    return SajuAll69.fromJson(data as Map<String, dynamic>);
  }

  /// v3.1+ AI 해석 레이어 — LLM 미연결 상태에서는 서버가 rule_fallback을 반환.
  Future<InterpretationResult> getSajuV3Interpret(
    BirthInput b, {
    required String categoryCode,
    String zihourPolicy = 'traditional',
  }) async {
    final data = await _post('/saju/v3/interpret', {
      ...b.toJson(),
      'zihour_policy': zihourPolicy,
      'category_code': categoryCode,
    });
    return InterpretationResult.fromJson(data as Map<String, dynamic>);
  }

  /// [5차 지시서] AI 정통사주 해석 엔진 v1.0 — 9 PART 장문 개인 리포트.
  /// LLM 미연결 상태에서는 서버가 rule_fallback(계산값 나열)을 200으로 반환한다.
  /// 402(프리패스 없음)·429(rate limit)는 SajuV3ApiException으로 던져지므로
  /// 화면 쪽에서 isFreePassRequired / isRateLimited로 분기해 안내한다.
  Future<SajuReportResult> getSajuV3Report(
    BirthInput b, {
    String question = '',
    String zihourPolicy = 'traditional',
  }) async {
    final data = await _post('/saju/v3/report', {
      ...b.toJson(),
      'zihour_policy': zihourPolicy,
      'question': question,
    });
    return SajuReportResult.fromJson(data as Map<String, dynamic>);
  }
}
