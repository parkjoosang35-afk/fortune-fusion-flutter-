import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/router/guinji_deep_link_handler.dart';
import 'features/home/domain/saju_fortune_rules.dart';
import 'features/home/domain/saju_interpreter.dart';
import 'features/wish_room/domain/evening_bell_notification_service.dart';

/// [로컬 영속성] 앱 실행 시 실제 기기 documents 디렉터리를 기준으로
/// Hive를 초기화한다. Hive를 사용하는 로컬 스토어 모듈이 `Hive.openBox()`를
/// 호출하기 전에 반드시 이 초기화가 먼저 끝나 있어야 한다.
///
/// 순수 Dart 테스트 환경에서는 이 위젯 플러그인 기반 초기화를 쓸 수
/// 없으므로, 대신 `test/flutter_test_config.dart`에서 `Hive.init(경로)`로
/// 별도 초기화한다(Flutter 플러그인 경로 조회가 필요 없는 순수 Dart API).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // [정통사주 실계산 활성화 - 미션 2] 만세력 해석 룰 DB(일간/십신/오행 +
  // 세운/월운/일운/개운아이템/궁합)를 앱 부팅 시점에 fire-and-forget으로
  // 미리 로드해 둔다. await 하지 않는 이유: 이 로드가 끝나기 전에
  // JeontongReportBuilder.build()가 호출돼도 기존 폴백(결정론적 시드
  // 기반) 경로로 안전하게 동작하므로 앱 시작을 블로킹할 필요가 없다 —
  // 로드가 끝나는 즉시(보통 앱 시작 후 수백ms 이내) 이후 호출부터 자동으로
  // 실계산 경로로 전환된다(jeontong_eighty_report_builder.dart 참고).
  SajuRules.preload();
  SajuFortuneRules.preload();
  // [귀인지도 딥링크 버그수정 — Phase A] `fortunefusion://g/{token}` 커스텀
  // 스킴 딥링크 수신을 앱 부팅 시점에 등록한다. await 하지 않는 이유: 이
  // 초기화가 runApp보다 늦게 끝나도(콜드 스타트 초기 링크 처리) 문제없이
  // 동작하도록 설계되어 있고(GuinjiDeepLinkHandler.init 내부에서 프레임 콜백
  // 사용), 앱 시작 자체를 블로킹할 필요는 없다.
  GuinjiDeepLinkHandler.init();
  // [Phase C-1] 저녁 7시 종소리 알림 — 플러그인 초기화 후, 사용자가 과거에
  // 옵트인했다면 예약을 다시 걸어준다(기기 재설치/데이터 초기화로 예약이
  // 사라졌을 가능성 보정). await 하지 않는 이유: 이 부가 기능이 앱 시작을
  // 블로킹할 필요가 없다(GuinjiDeepLinkHandler.init와 동일한 설계).
  EveningBellNotificationService.initialize().then((_) {
    EveningBellNotificationService.syncFromSavedPreference();
  });
  // [애드몹 테스트 연동] Google Mobile Ads SDK 초기화. Web 플랫폼은 SDK 자체가
  // 지원되지 않으므로(google_mobile_ads는 Android/iOS 전용) kIsWeb일 때는
  // 아예 호출하지 않는다 — 호출해도 즉시 실패하지만, 불필요한 콘솔 오류를
  // 남기지 않기 위해 사전에 가드한다. await 하지 않는 이유는 다른 초기화
  // (Hive/딥링크/알림)와 동일하게 앱 최초 프레임을 블로킹할 필요가 없어서다.
  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }
  runApp(const App());
}
