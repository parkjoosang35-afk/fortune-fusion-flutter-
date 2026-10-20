import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../web_ads/web_ad_config.dart';
import '../web_ads/web_ad_service.dart';

/// [신통방통 관리자 통합 간소화 실행 지시서 - task 4 "광고관리 통합메뉴"]
/// admin_web의 `GET /api/public/ad-config` 공개 API를 앱 시작 시 1회 조회해,
/// AdMob의 노출 킬스위치(isEnabled)와 WebAdConfig(AdSense)의 컴파일타임
/// 기본값을 런타임에 덮어쓰는 서비스.
///
/// [왜 필요한가] 기존 `web_ad_config.dart`(WebAdConfig)는 enabled/publisherId/
/// 서비스별·포맷별 노출을 전부 `bool.fromEnvironment` 컴파일타임 상수로
/// 하드코딩하고 있어, admin_web에서 아무리 설정을 바꿔도 재빌드 전까지
/// 전혀 반영되지 않는 구조였다(사장님 지시서 "설정변경이 실제 서비스에
/// 반영 안되는 구조 금지"에 정확히 해당하는 결함). 이 서비스가 그 간극을
/// 메운다 — 호출부(WebAdConfig.isSurfaceActive/isFormatActive/shouldShow 등)
/// 의 시그니처는 전혀 바꾸지 않고, 그 메서드들이 내부적으로 참조하는 값만
/// "조회 성공 시 원격값, 실패 시 기존 컴파일타임 기본값"으로 안전하게
/// 바뀌도록 [WebAdConfig]에 오버라이드 레이어를 추가했다.
///
/// [AdMob은 왜 isEnabled만 원격화하는가] 사장님이 명시한 "무효 트래픽→
/// 계정정지 위험"을 재도입하지 않기 위해, 실제 Ad Unit ID 전환은 여전히
/// `--dart-define=ADMOB_USE_REAL_IDS=true` 빌드타임 플래그로만 허용한다
/// (admob_ad_ids.dart 참고). 이 서비스는 "광고 노출 여부"만 원격 제어해,
/// 재배포 없이 광고를 끌 수 있는 실질적인 운영 레버를 제공한다.
///
/// [폴백 원칙] API 조회가 실패(네트워크 오류/타임아웃/서버 다운 등)하면
/// 아무 것도 덮어쓰지 않고 기존 컴파일타임 기본값을 그대로 사용한다 —
/// 이 서비스가 있든 없든 서비스가 "절대 더 나빠지지 않는다".
class AdRemoteConfigService {
  AdRemoteConfigService._();

  static bool _loaded = false;

  /// AdMob 광고 노출 여부(원격 오버라이드). null이면 원격 조회 전/실패이며,
  /// 이 경우 호출부는 기존 기본값(true)을 사용해야 한다.
  static bool? _admobEnabledOverride;

  static bool get admobEnabled => _admobEnabledOverride ?? true;

  static const Map<String, WebAdSurface> _surfaceKeyMap = {
    'home': WebAdSurface.home,
    'sajuRenewal': WebAdSurface.sajuRenewal,
    'tarot': WebAdSurface.tarot,
    'wishRoom': WebAdSurface.wishRoom,
    'guinji': WebAdSurface.guinji,
    'face': WebAdSurface.face,
    'palm': WebAdSurface.palm,
  };

  static const Map<String, WebAdFormat> _formatKeyMap = {
    'banner': WebAdFormat.banner,
    'inPage': WebAdFormat.inPage,
    'anchor': WebAdFormat.anchor,
    'vignette': WebAdFormat.vignette,
  };

  /// 앱 시작 시 1회 호출. 실패해도 예외를 던지지 않고 조용히 폴백한다
  /// (ad_banner_repository.dart와 동일한 디버그 로그 패턴 사용).
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/ad-config');
    debugPrint('[AdRemoteConfigService] [1] 요청 시작 -> $uri');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      debugPrint(
        '[AdRemoteConfigService] [2] 응답 수신 -> statusCode=${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[AdRemoteConfigService] [X] 실패 -> statusCode=${response.statusCode}, 기존 컴파일타임 기본값으로 폴백',
        );
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true || decoded['data'] is! Map) {
        debugPrint('[AdRemoteConfigService] [X] 응답 형식 오류, 폴백');
        return;
      }

      final data = decoded['data'] as Map<String, dynamic>;

      // ── AdMob: isEnabled만 반영 ──
      final admob = data['admob'] as Map<String, dynamic>?;
      if (admob != null && admob['isEnabled'] is bool) {
        _admobEnabledOverride = admob['isEnabled'] as bool;
      }

      // ── AdSense: publisherId + surface + format 전부 WebAdConfig에 주입 ──
      final adsense = data['adsense'] as Map<String, dynamic>?;
      if (adsense != null) {
        bool? adsenseEnabled;
        String? publisherId;
        bool? showPlaceholder;
        Map<WebAdSurface, bool>? surfaceOverride;
        Map<WebAdFormat, bool>? formatOverride;

        if (adsense['isEnabled'] is bool) {
          adsenseEnabled = adsense['isEnabled'] as bool;
        }
        final pubId = adsense['publisherId'];
        publisherId = pubId is String && pubId.isNotEmpty ? pubId : '';
        if (adsense['showPlaceholderWhenDisabled'] is bool) {
          showPlaceholder = adsense['showPlaceholderWhenDisabled'] as bool;
        }

        final surfaceJson = adsense['surfaceConfig'] as Map<String, dynamic>?;
        if (surfaceJson != null) {
          final map = <WebAdSurface, bool>{};
          surfaceJson.forEach((key, value) {
            final surface = _surfaceKeyMap[key];
            if (surface != null && value is bool) map[surface] = value;
          });
          surfaceOverride = map;
        }

        final formatJson = adsense['formatConfig'] as Map<String, dynamic>?;
        if (formatJson != null) {
          final map = <WebAdFormat, bool>{};
          formatJson.forEach((key, value) {
            final format = _formatKeyMap[key];
            if (format != null && value is bool) map[format] = value;
          });
          formatOverride = map;
        }

        WebAdConfig.applyRemoteOverride(
          enabled: adsenseEnabled,
          publisherId: publisherId,
          showPlaceholderWhenDisabled: showPlaceholder,
          surfaceEnabled: surfaceOverride,
          formatEnabled: formatOverride,
        );
      }

      debugPrint(
        '[AdRemoteConfigService] [3] 적용 완료 -> admobEnabled=$_admobEnabledOverride, '
        'adsenseEnabled=${WebAdConfig.enabled}, publisherId=${WebAdConfig.publisherId.isNotEmpty ? "(설정됨)" : "(없음)"}',
      );
      // [버그 수정] main.dart가 이 load() 완료를 기다리지 않고 이미
      // WebAdService.ensureInitialized()를 한 번 호출했을 수 있다(그
      // 시점엔 컴파일타임 기본값 enabled=false라 스크립트를 건너뛰었을
      // 것). 원격 설정이 지금 막 enabled=true로 바뀌었을 수 있으므로,
      // 여기서 다시 호출해 "실제로 아직 주입 안 됐다면" 지금 주입한다
      // (WebAdService._initialized가 이미 true면 멱등하게 아무 일도
      // 안 한다).
      WebAdService.ensureInitialized();
    } catch (e) {
      debugPrint(
        '[AdRemoteConfigService] [X] 예외 발생, 기존 컴파일타임 기본값으로 폴백 -> $e',
      );
    }
  }
}
