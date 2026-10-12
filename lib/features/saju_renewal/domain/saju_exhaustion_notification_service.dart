import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// [다음 클라 배치 2026-10-12 — 소진 복귀 유도] 정통사주 "다른 사주
/// 이야기" 후보가 전부 소진(서버 재호출까지 했는데도 0건)되면, 서버
/// topic-engine의 recentlyShown 7일 감쇠 정책과 동일한 기준으로 **+7일
/// 뒤** 재후보화됨을 안내 문구(9ea90af)로 알려주고 있다. 이 서비스는 그
/// 시점에 맞춰 복귀를 유도하는 로컬 알림 1건을 예약한다.
///
/// [서버 cron 없음 — evening_bell과 동일 설계 원칙] admin_web에 scheduler가
/// 없는 인프라이므로(evening_bell_notification_service.dart 주석 참고)
/// 서버 푸시가 아닌 클라이언트 로컬 알림(flutter_local_notifications)으로
/// 구현한다. 이 알림은 결제/재화와 무관한 순수 UX 리마인더다.
///
/// [환경 버전 고정] flutter_local_notifications 20.1.0 — evening_bell과
/// 동일한 전역 [FlutterLocalNotificationsPlugin] 싱글턴을 재사용한다(같은
/// 플러그인 인스턴스를 두 개 따로 만들 필요가 없고, evening_bell이 앱
/// 부팅 시 이미 `initialize()`를 호출해 둔다 — main.dart 참고). 버전을
/// 임의로 올리지 않는다.
///
/// [정밀도 설계 결정] evening_bell과 동일하게 초 단위 정밀 타이밍이
/// 필요 없으므로 Android exact alarm 권한 없이 inexact 예약만 사용한다.
///
/// [Web 플랫폼] evening_bell과 동일하게 kIsWeb 가드로 Android/iOS
/// 전용 기능으로 국한한다(웹 탭을 닫으면 예약 자체가 무의미).
class SajuExhaustionNotificationService {
  SajuExhaustionNotificationService._();

  static const _channelId = 'saju_renewal_exhaustion_recall';
  static const _channelName = '정통사주 이야기 재입고 안내';
  static const _channelDescription = '소진됐던 사주 이야기가 새 후보로 다시 채워지면 알려드립니다.';

  /// 고정 알림 id(단일 알림이므로 상수 하나만 사용 — evening_bell의 700과
  /// 충돌하지 않도록 다른 대역을 쓴다).
  static const int _notificationId = 701;

  /// 예약 후 +7일(168시간) — 9ea90af 안내 문구 "일주일 뒤면 이야기들이
  /// 새 후보로 다시 찾아와요"와 서버 recentlyShown 감쇠 정책 기준에 맞춘다.
  static const Duration _recallDelay = Duration(hours: 168);

  /// [중복 예약 방지] 이미 소진 알림이 예약된 상태인지 저장하는 키.
  /// "소진 전환 시점에 **처음** 저장"(지시서)을 구현하기 위한 플래그 —
  /// 이 값이 true인 동안은 소진 상태가 재차 감지돼도 다시 예약하지 않는다.
  static const String _scheduledPrefsKey =
      'saju_renewal_exhaustion_notification_scheduled';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// [독립 초기화 — evening_bell 완료 순서에 의존하지 않음] main.dart는
  /// `EveningBellNotificationService.initialize()`를 await 없이
  /// fire-and-forget으로 호출한다(부가 기능이 앱 시작을 블로킹하지 않도록
  /// 하는 기존 설계). 이 서비스의 트리거는 그보다 늦게(사용자가 실제로
  /// 후보를 다 소진한 뒤) 일어나는 게 보통이지만, 혹시 그 초기화가 아직
  /// 끝나기 전에 호출되더라도 안전하도록 플러그인 초기화와 timezone 설정을
  /// 이 서비스 자체적으로도 멱등하게 보장한다(두 서비스가 같은 전역
  /// `FlutterLocalNotificationsPlugin` 패키지 싱글턴을 공유하므로 중복
  /// `initialize()` 호출 자체는 안전 — 플러그인 내부가 멱등하게 설계됨).
  static Future<void> _ensureInitialized() async {
    if (kIsWeb || _initialized) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        developer.log('초기화 실패: $e', name: 'SajuExhaustionNotificationService');
      }
    }
  }

  /// [SajuRenewalProvider 전용] 후보가 처음 소진 상태(`_candidatesExhausted`
  /// false → true)로 전환되는 순간 호출한다. 이미 예약돼 있으면(중복 방지
  /// 플래그 true) 아무 것도 하지 않는다 — "소진 화면을 열 때마다"가 아니라
  /// "처음 소진되는 시점"에만 1회 예약되도록 하는 핵심 가드.
  static Future<void> scheduleOnFirstExhaustion() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyScheduled = prefs.getBool(_scheduledPrefsKey) ?? false;
      if (alreadyScheduled) return;

      await _ensureInitialized();
      // [권한 요청 — evening_bell과의 차이점] evening_bell은 사용자가
      // 설정에서 토글을 켤 때만 권한을 요청하는 "옵트인" 기능이라, 토글을
      // 한 번도 켠 적 없는 사용자는 Android 13+ POST_NOTIFICATIONS 권한이
      // 아예 요청된 적이 없을 수 있다. 이 알림은 소진이라는 자동 발생
      // 이벤트로 트리거되는 기능이므로, 예약 직전에 한 번 더 권한을
      // 확인·요청한다(이미 허용됐다면 즉시 true를 반환하므로 중복 다이얼로그
      // 걱정은 없다 — 플랫폼 표준 동작).
      await _requestPermission();
      final scheduled = tz.TZDateTime.now(tz.local).add(_recallDelay);

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        id: _notificationId,
        title: '새로운 사주 이야기가 도착했어요',
        body: '일주일 전 다 보셨던 이야기들이 새 후보로 다시 채워졌어요. 지금 확인해보세요.',
        scheduledDate: scheduled,
        notificationDetails: details,
        // exact alarm 권한이 필요 없는 inexact 방식(evening_bell과 동일
        // 설계 결정). matchDateTimeComponents를 쓰지 않는 단발성 예약이므로
        // 생략한다 — 7일 뒤 1회만 울리면 되고 반복 알림이 아니다.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      await prefs.setBool(_scheduledPrefsKey, true);
    } catch (e) {
      // 예약 실패해도 소진 안내 UI 자체는 정상 동작해야 한다(부가 기능).
      if (kDebugMode) {
        developer.log('예약 실패: $e', name: 'SajuExhaustionNotificationService');
      }
    }
  }

  static Future<bool> _requestPermission() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      if (kDebugMode) {
        developer.log(
          '권한 요청 실패: $e',
          name: 'SajuExhaustionNotificationService',
        );
      }
      return false;
    }
  }

  /// [SajuRenewalProvider 전용] 후보가 재후보화됨을 확인했을 때(소진
  /// 상태였다가 서버 재조회로 새 후보가 실제로 채워졌을 때) 호출한다.
  /// 예약을 취소하고 중복 방지 플래그도 리셋해, 다음에 다시 소진되면
  /// 또 새로 예약될 수 있게 한다.
  static Future<void> cancelOnRecovery() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {
      // 무시 - 애초에 예약이 없었을 수 있음(evening_bell과 동일 관례).
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_scheduledPrefsKey, false);
    } catch (_) {
      // 저장 실패 - 무시.
    }
  }

  /// [로그아웃/계정 격리] evening_bell에는 없는 조치이지만, 이 알림은
  /// 소진 상태라는 "계정별" 데이터에 종속되므로 로그아웃 시에도 예약을
  /// 취소해야 사용자A의 소진 알림이 사용자B에게 잘못 울리는 일을 막는다
  /// (SajuRenewalProvider.clearOnLogout과 동일한 계정 격리 원칙).
  static Future<void> cancelOnLogout() => cancelOnRecovery();
}
