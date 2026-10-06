import 'package:flutter/foundation.dart';

import 'web_ad_config.dart';
import 'web_ad_injector.dart';
import 'web_ad_page_level.dart';

/// [웹 AdSense 광고 시스템 — STEP C] 중앙 광고 서비스.
///
/// [배경 — 지시서 §3 "WebAdService를 새로 만든다"] 정통사주/타로/소원방/
/// 귀인지도/관상/손금 각 서비스가 광고를 직접 관리하지 않고, 전부 이
/// 단일 서비스를 거친다:
/// ```
/// 정통사주 ─┐
/// 타로 ────┤
/// 소원방 ──┤        ↓
/// 귀인지도 ─┤   WebAdService  ──→  Google AdSense
/// 관상 ────┤
/// 손금 ────┘
/// ```
///
/// [절대 원칙 — AdMob과 완전 분리] 이 클래스는 Web 플랫폼에서만 의미가
/// 있다. `kIsWeb`이 false인 모든 분기(Android/iOS 앱 빌드)에서는 아무
/// 것도 하지 않는다 — 기존 AdMob 구조(`AdmobAdIds`,
/// `google_mobile_ads`)는 단 한 줄도 건드리지 않는다(지시서 §2).
///
/// [사용 방법] 앱 부팅 시(main.dart) 단 한 번 [ensureInitialized]를
/// 호출해 AdSense 로더 스크립트를 주입한다. 이후 각 화면은
/// [WebAdService.shouldShow]로 "지금 이 자리에 광고를 그려도 되는지"만
/// 물어보고, 실제 광고 포맷 위젯(`WebAdBanner` 등)을 조건부로 배치한다.
class WebAdService {
  WebAdService._();

  static bool _initialized = false;

  /// 앱 부팅 시 1회 호출 — AdSense 로더 스크립트를 `<head>`에 주입한다.
  /// Web이 아니거나, 아직 설정이 꺼져 있거나(퍼블리셔 ID 미발급 등)이면
  /// 아무 일도 하지 않는다(지시서 §12 "승인 전에는 실제 광고가 나오는
  /// 것으로 가정해서 개발하면 안 된다" — 스크립트조차 섣불리 심지
  /// 않는다).
  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) return; // [AdMob과 분리] 앱(Android/iOS)에서는 완전히 no-op.
    if (!WebAdConfig.enabled) return;
    if (WebAdConfig.publisherId.isEmpty) return;

    injectAdSenseScriptOnce(WebAdConfig.publisherId);
  }

  /// 특정 화면(surface)의 특정 포맷(format) 광고를 지금 그려도 되는지.
  /// Web이 아니면 항상 false(앱에서는 이 서비스 자체가 관여하지 않음).
  static bool shouldShow(WebAdSurface surface, WebAdFormat format) {
    if (!kIsWeb) return false;
    return WebAdConfig.shouldShow(surface, format);
  }

  /// [STEP F 레이아웃 검증용] 실제 광고를 그릴 수는 없지만(미승인 등)
  /// 개발 중 자리 배치 확인을 위한 플레이스홀더를 보여줄지.
  static bool shouldShowPlaceholder(WebAdSurface surface, WebAdFormat format) {
    if (!kIsWeb) return false;
    if (!WebAdConfig.showPlaceholderWhenDisabled) return false;
    // 이미 실제 광고가 나가는 상태라면 플레이스홀더를 겹쳐 보일 필요 없음.
    if (shouldShow(surface, format)) return false;
    // 서비스별 스위치가 꺼져 있는 화면(아직 적용 대상이 아닌 서비스)에는
    // 플레이스홀더도 보이지 않는다 — STEP E는 정통사주만 먼저 적용한다는
    // 지시서 원칙을 플레이스홀더 단계에서도 동일하게 지킨다.
    return WebAdConfig.isSurfacePlaceholderAllowed(surface);
  }

  /// [Anchor/Vignette 전용] 특정 화면에 진입했을 때 페이지 레벨 광고를
  /// 1회 활성화한다. `<ins>` 슬롯형(banner/inPage)과 달리 Anchor/
  /// Vignette는 "이 페이지에서 이 타입의 자동 배치를 켜 달라"는 전역
  /// 신호만 보내면 Google이 실제 표시 위치/타이밍을 자체 판단한다.
  ///
  /// [호출 시점] 해당 화면의 `initState`/`build` 초반에서 1회 호출하면
  /// 된다 — 내부적으로 adType별 1회 제한([enablePageLevelAdsOnce])이
  /// 걸려 있어 여러 번 호출해도 안전하다.
  static void enablePageLevelAd(WebAdSurface surface, WebAdFormat format) {
    assert(
      format == WebAdFormat.anchor || format == WebAdFormat.vignette,
      'enablePageLevelAd는 anchor/vignette 전용입니다. '
      '배치형 배너는 WebAdBanner/WebAdInPage 위젯을 쓰세요.',
    );
    if (!shouldShow(surface, format)) return;
    enablePageLevelAdsOnce(
      WebAdConfig.publisherId,
      format == WebAdFormat.anchor ? 'anchor' : 'vignette',
    );
  }
}
