import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_ad_ids.dart';

/// [애드몹 실서비스 전환 준비 - 3번] UMP(User Messaging Platform) 동의 관리.
///
/// [배경] EU/EEA(유럽경제지역) 및 영국 사용자에게는 개인화 광고를 보여주기
/// 전에 반드시 "동의를 구하는 절차"를 거쳐야 한다(GDPR 요구사항이자 Google
/// AdMob 정책 요구사항). 이 요구사항을 지키지 않으면 실제 서비스 전환 시
/// AdMob 계정이 정책 위반으로 제재될 수 있다.
///
/// [사용 패키지] 별도 패키지 설치 없이 이미 의존성으로 추가되어 있는
/// google_mobile_ads 안에 UMP 모듈이 내장되어 있다
/// (package:google_mobile_ads/src/ump/... — ConsentInformation, ConsentForm).
///
/// [동작 방식]
/// 1. `requestAndLoadIfRequired()`를 앱 시작 시 1회 호출한다.
/// 2. SDK가 이용자의 지역(IP 기반)을 판단해 동의가 필요한 지역(EEA/UK 등)이면
///    동의 폼을 자동으로 띄워 보여주고, 필요 없는 지역(한국 등)이면 아무 UI도
///    띄우지 않고 즉시 완료 처리된다.
/// 3. 완료 후에도 반드시 `canRequestAds()`를 확인한 뒤에만 실제 광고 요청을
///    시작해야 한다(동의가 완료되지 않았는데 광고를 요청하면 정책 위반).
///
/// [Web 미지원] google_mobile_ads 자체가 Android/iOS 전용이므로 Web에서는
/// 아무 동작도 하지 않는다(kIsWeb 가드).
class AdmobConsentService {
  AdmobConsentService._();

  /// 앱 시작 시 1회 호출. 동의가 필요한 지역이면 동의 폼을 자동으로
  /// 로드·표시하고, 필요 없으면 즉시 완료된다. 완료 후 `canRequestAds()`
  /// 값을 반환해 호출부가 "지금 광고를 요청해도 되는지" 판단할 수 있게 한다.
  static Future<bool> requestAndLoadIfRequired() async {
    if (kIsWeb) return false;

    final completer = Completer<bool>();
    final params = ConsentRequestParameters(
      // [테스트 기기 등록] 실제 서비스 전환 전, 개발/QA 기기에서 EEA 동의
      // 흐름 자체를 테스트해보고 싶을 때만 아래 debugGeography와
      // testIdentifiers를 채워 넣는다. 평소(운영 중)에는 반드시 비워둬야
      // 한다 — 채워진 채로 배포하면 실제 사용자에게도 디버그 동작이 적용될
      // 위험이 있다(AdmobAdIds.testDeviceIds 참고).
      consentDebugSettings: kDebugMode && AdmobAdIds.testDeviceIds.isNotEmpty
          ? ConsentDebugSettings(
              testIdentifiers: AdmobAdIds.testDeviceIds,
            )
          : null,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _loadAndShowForm(completer);
          } else {
            final canRequest =
                await ConsentInformation.instance.canRequestAds();
            completer.complete(canRequest);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AdmobConsentService] 동의 폼 처리 중 오류 -> $e');
          }
          completer.complete(false);
        }
      },
      (error) {
        if (kDebugMode) {
          debugPrint(
            '[AdmobConsentService] 동의 정보 업데이트 실패 -> ${error.message}',
          );
        }
        // 동의 정보 갱신 자체가 실패한 경우에도, 과거에 이미 동의를 받아둔
        // 상태라면(캐시됨) 광고 요청이 가능할 수 있으므로 canRequestAds()로
        // 한 번 더 확인한다.
        ConsentInformation.instance
            .canRequestAds()
            .then(completer.complete)
            .catchError((_) => completer.complete(false));
      },
    );

    return completer.future;
  }

  static Future<void> _loadAndShowForm(Completer<bool> completer) async {
    ConsentForm.loadConsentForm(
      (consentForm) {
        consentForm.show((formError) async {
          if (kDebugMode && formError != null) {
            debugPrint(
              '[AdmobConsentService] 동의 폼 표시 중 오류 -> ${formError.message}',
            );
          }
          final canRequest = await ConsentInformation.instance.canRequestAds();
          completer.complete(canRequest);
        });
      },
      (formError) async {
        if (kDebugMode) {
          debugPrint(
            '[AdmobConsentService] 동의 폼 로드 실패 -> ${formError.message}',
          );
        }
        final canRequest = await ConsentInformation.instance.canRequestAds();
        completer.complete(canRequest);
      },
    );
  }
}
