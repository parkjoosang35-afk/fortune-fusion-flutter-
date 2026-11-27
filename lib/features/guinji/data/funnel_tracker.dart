import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/env_config.dart';

/// [P3 작업 지시서 — 귀인지도 앱 정합화] 앱 퍼널 이벤트 배선.
///
/// [서버 계약] admin_web에 이미 배포된 `POST /api/public/events`
/// (`guinji_repository`와 동일한 `EnvConfig.adminApiBaseUrl` base URL)로
/// `{ eventName, anonymousId, mapToken? }` 바디를 전송한다.
///
/// [설계 원칙 — fire-and-forget]
/// - 이 트래커는 순수 분석/퍼널 집계 용도이며, 결제·재화·UX 흐름과는
///   완전히 무관하다. 호출부는 `unawaited(...)`로 걸고 결과를 기다리지
///   않는다.
/// - 네트워크 실패/타임아웃/서버 400(미허용 이벤트명·형식 위반) 모두
///   조용히 무시한다 — 어떤 경우에도 UI를 막거나 에러를 노출하지 않는다.
/// - 인증 헤더를 쓰지 않는다(사용자 지시서에 익명ID만 명시되어 있고,
///   퍼널 이벤트는 로그인 여부와 무관하게 익명 식별자로만 집계된다 —
///   `guinji_repository`의 `requireUser` 인증 라우트들과는 별개 계약).
class FunnelTracker {
  FunnelTracker._();

  static const String _anonymousIdPrefsKey = 'guinji_funnel_anonymous_id';

  /// [서버 계약상 허용된 7종 이벤트 중 앱에서 실제로 기록하는 것만 정의]
  /// - [unlockAdWatched]: 광고 시청으로 관계 상세 해금 성공(B-2).
  /// - [milestoneReached]: 친구 초대 마일스톤 달성(B-3).
  static const String unlockAdWatched = 'unlock_ad_watched';
  static const String milestoneReached = 'milestone_reached';

  static String? _cachedAnonymousId;

  /// SharedPreferences에 익명ID를 1회 발급해 재사용한다. 이미 발급된 값이
  /// 있으면 그대로 반환하고, 없으면 랜덤 영숫자 문자열(32자, `[A-Za-z0-9_-]`
  /// 허용 범위 내)을 새로 만들어 저장한다.
  static Future<String> _getOrCreateAnonymousId() async {
    if (_cachedAnonymousId != null) return _cachedAnonymousId!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_anonymousIdPrefsKey);
    if (existing != null && existing.isNotEmpty) {
      _cachedAnonymousId = existing;
      return existing;
    }
    final generated = _generateRandomId();
    await prefs.setString(_anonymousIdPrefsKey, generated);
    _cachedAnonymousId = generated;
    return generated;
  }

  static String _generateRandomId({int length = 32}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  /// 이벤트 1건을 서버로 전송한다 — fire-and-forget, 실패 무시, UI 비차단.
  ///
  /// 호출부는 반드시 `unawaited(FunnelTracker.track(...))`로 호출해야 한다
  /// (이 메서드 자체는 awaitable하지만, 결과를 기다려 UI를 막아서는 안 됨).
  static Future<void> track(String eventName, {String? mapToken}) async {
    try {
      final anonymousId = await _getOrCreateAnonymousId();
      final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/events');
      await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'eventName': eventName,
              'anonymousId': anonymousId,
              if (mapToken != null) 'mapToken': mapToken,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // [의도적 무음 실패] 분석 이벤트 전송 실패가 앱 기능에 영향을
      // 주어서는 안 된다. 디버그 빌드에서만 원인 추적용 로그를 남긴다.
      if (kDebugMode) {
        debugPrint('[FunnelTracker] [track] $eventName 전송 실패(무시) -> $e');
      }
    }
  }
}
