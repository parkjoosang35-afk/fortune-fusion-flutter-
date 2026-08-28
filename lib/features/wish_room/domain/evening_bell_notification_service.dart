import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// [Phase C-1] 소원방 — 저녁 7시 은은한 종소리 알림.
///
/// [절대 원칙] 이 기능은 결제/재화와 무관한 순수 UX 리마인더다. 서버
/// cron이 전혀 없는 인프라이므로(admin_web에 scheduler 부재 확인됨) 서버가
/// 아닌 클라이언트 로컬 알림(flutter_local_notifications)으로 구현한다 —
/// 즉 이 알림은 지급/포인트/PointPolicy와 아무 관련이 없다.
///
/// [환경 버전 고정] flutter_local_notifications 20.1.0 + timezone 0.10.1은
/// Flutter 3.35.4 / Dart 3.9.2 고정 환경에서 실제로 pub get 성공 + web/APK
/// 빌드 성공까지 실증 검증된 조합이다(21.x+는 Flutter 3.38.1+ 요구로
/// 사용 불가). 이 버전들을 임의로 올리지 않는다.
///
/// [정밀도 설계 결정] "은은한 종소리" 컨셉은 초 단위 정밀 타이밍이 필요
/// 없으므로 Android의 exact alarm(SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM)을
/// 사용하지 않고 inexact 예약만 사용한다 — 별도 권한 승인 절차나 스토어
/// 심사 부담을 피하기 위함이다. 실제 발화 시각은 시스템 배터리 최적화에
/// 따라 19:00 KST 전후 몇 분 오차가 있을 수 있다(허용 가능한 트레이드오프).
///
/// [Web 플랫폼] flutter_local_notifications 20.1.0은 web 구현체
/// (flutter_local_notifications_web)를 의존성으로 갖지 않음을
/// `flutter pub get` + `flutter build web --release` 실증 검증으로
/// 확인했다. 그럼에도 웹에는 "매일 저녁 알림"이라는 개념 자체가 어울리지
/// 않으므로(탭을 닫으면 무의미) kIsWeb 가드로 Android/iOS 전용 기능으로
/// 명확히 국한한다.
class EveningBellNotificationService {
  EveningBellNotificationService._();

  static const _channelId = 'wish_room_evening_bell';
  static const _channelName = '소원방 저녁 종소리';
  static const _channelDescription = '매일 저녁 7시, 소원방에서 은은한 종소리로 알려드립니다.';

  /// 매일 반복 예약 알림의 고정 id(단일 알림이므로 상수 하나만 사용).
  static const int _notificationId = 700;

  /// 옵트인 여부를 저장하는 SharedPreferences 키.
  ///
  /// [wish_room_entry_gate.dart]의 `wishRoomOnboardingSeenPrefsKey`와 동일한
  /// 관례(top-level 공개 상수 + 별도 함수)를 따른다.
  static const String enabledPrefsKey = 'wish_room_evening_bell_enabled';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 앱 부팅 시 1회 호출. 실제 알림 예약은 하지 않고 플러그인 초기화만
  /// 수행한다(예약 여부는 사용자의 저장된 옵트인 상태에 따라 별도로
  /// [syncFromSavedPreference]가 결정한다).
  static Future<void> initialize() async {
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
      // 초기화 실패해도 앱 부팅을 막지 않는다(리마인더 기능은 부가 기능).
      if (kDebugMode) {
        developer.log(
          '초기화 실패: $e',
          name: 'EveningBellNotificationService',
        );
      }
    }
  }

  /// 저장된 옵트인 상태를 읽어, true면 알림을 예약하고 false/미설정이면
  /// 아무 것도 하지 않는다. [initialize] 이후, 앱 부팅 시 1회 호출해
  /// "예약이 기기 재설치/데이터 초기화 등으로 사라진" 경우를 보정한다.
  static Future<void> syncFromSavedPreference() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(enabledPrefsKey) ?? false;
      if (enabled) {
        await _scheduleDaily();
      }
    } catch (_) {
      // 저장소 접근 실패 - 무시(다음 실행에 재시도됨).
    }
  }

  /// 사용자가 온보딩/설정에서 "저녁 종소리 받기"를 켰을 때 호출한다.
  /// 1) 알림 권한 요청(Android 13+) → 2) 매일 19:00 KST 예약 → 3) 결과
  /// (권한 허용 여부)를 반환하고, 저장은 호출부(UI)에서 결정한다.
  static Future<bool> enable() async {
    if (kIsWeb) return false;
    await initialize();
    final granted = await _requestPermission();
    if (!granted) return false;
    await _scheduleDaily();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledPrefsKey, true);
    } catch (_) {
      // 저장 실패해도 예약 자체는 이미 완료된 상태.
    }
    return true;
  }

  /// 사용자가 알림을 끌 때 호출한다. 예약을 취소하고 옵트인 상태를 false로
  /// 저장한다.
  static Future<void> disable() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {
      // 무시 - 애초에 예약이 없었을 수 있음.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledPrefsKey, false);
    } catch (_) {
      // 저장 실패 - 무시.
    }
  }

  /// 현재 저장된 옵트인 상태(설정 화면 토글 초기값 등에 사용).
  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(enabledPrefsKey) ?? false;
    } catch (_) {
      return false;
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
          name: 'EveningBellNotificationService',
        );
      }
      return false;
    }
  }

  static Future<void> _scheduleDaily() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        19, // 19:00 KST
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // [디자인 의도] "은은한 종소리" — 기본 알림음/진동으로 충분하며
        // 별도 사운드 파일을 추가하지 않는다(자산 관리 최소화).
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.zonedSchedule(
        id: _notificationId,
        title: '소원방에 저녁이 찾아왔어요',
        body: '오늘 마음속에 담아둔 소원을 잠시 들여다보세요.',
        scheduledDate: scheduled,
        notificationDetails: details,
        // exact alarm 권한(SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM)이 필요 없는
        // inexact 방식. 매일 같은 시각에 반복되도록 matchDateTimeComponents로
        // "시:분"만 매칭한다.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) {
        developer.log('예약 실패: $e', name: 'EveningBellNotificationService');
      }
    }
  }
}
