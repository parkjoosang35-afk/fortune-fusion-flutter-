import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/gratitude_models.dart';
import 'gratitude_repository.dart';

/// [GratitudeRepository] 실 API 구현체 — admin_web
/// `/api/public/gratitude/{sealable,seal,received}` 3개 엔드포인트와 통신한다.
///
/// [아키텍처 패턴] `shop_api_repository.dart`(ApiShopRepository)와 동일한
/// `_authHeaders()`/`_fail()` 헬퍼 패턴을 그대로 따른다.
class ApiGratitudeRepository implements GratitudeRepository {
  String get _base => '${EnvConfig.adminApiBaseUrl}/api/public/gratitude';

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final auth = await AuthTokenStore.authHeader();
    return {if (json) 'Content-Type': 'application/json', ...auth};
  }

  Never _fail(String context, Object error) {
    debugPrint('[ApiGratitudeRepository] [$context] 실패 -> $error');
    throw Exception('$context 요청에 실패했습니다: $error');
  }

  @override
  Future<List<GratitudeSealableCandidate>> fetchSealable() async {
    final uri = Uri.parse('$_base/sealable');
    try {
      final res = await http.get(uri, headers: await _authHeaders());
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        _fail('GET /gratitude/sealable', body['error'] ?? res.statusCode);
      }
      final data = body['data'] as List<dynamic>? ?? const [];
      return data
          .map(
            (e) => GratitudeSealableCandidate.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      if (e is Exception) rethrow;
      _fail('GET /gratitude/sealable', e);
    }
  }

  @override
  Future<List<GratitudeSeal>> fetchReceived() async {
    final uri = Uri.parse('$_base/received');
    try {
      final res = await http.get(uri, headers: await _authHeaders());
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        _fail('GET /gratitude/received', body['error'] ?? res.statusCode);
      }
      final data = body['data'] as List<dynamic>? ?? const [];
      return data
          .map((e) => GratitudeSeal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is Exception) rethrow;
      _fail('GET /gratitude/received', e);
    }
  }

  @override
  Future<GratitudeSeal> seal(int sourcePouchId) async {
    final uri = Uri.parse('$_base/seal');
    late final http.Response res;
    try {
      res = await http.post(
        uri,
        headers: await _authHeaders(json: true),
        body: jsonEncode({'sourcePouchId': sourcePouchId}),
      );
    } catch (e) {
      throw const GratitudeException(
        GratitudeSealFailureReason.unknown,
        '네트워크 오류로 답례 도장 찍기에 실패했습니다.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const GratitudeException(
        GratitudeSealFailureReason.unknown,
        '응답을 해석할 수 없습니다.',
      );
    }

    if (res.statusCode == 200 && body['success'] == true) {
      return GratitudeSeal.fromJson(body['data'] as Map<String, dynamic>);
    }

    final message = body['error'] as String? ?? '답례 도장 찍기에 실패했습니다.';
    final GratitudeSealFailureReason reason;
    if (res.statusCode == 404) {
      reason = GratitudeSealFailureReason.pouchNotFound;
    } else if (res.statusCode == 403 && message.contains('자신에게')) {
      reason = GratitudeSealFailureReason.selfSend;
    } else if (res.statusCode == 403) {
      reason = GratitudeSealFailureReason.notPouchReceiver;
    } else if (res.statusCode == 400) {
      reason = GratitudeSealFailureReason.expired;
    } else if (res.statusCode == 409) {
      reason = GratitudeSealFailureReason.alreadySealed;
    } else {
      reason = GratitudeSealFailureReason.unknown;
    }
    throw GratitudeException(reason, message);
  }
}
