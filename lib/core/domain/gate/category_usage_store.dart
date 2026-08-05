import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// [운섹션 87 카테고리 통합] 카테고리별 무료 열람 이력 저장소.
///
/// 프리패스(시간제 이용권)와는 별개로, "하루 1회 무료"/"최초 1회(평생)
/// 무료" 정책을 판정하려면 카테고리별 마지막 열람 시각을 클라이언트에
/// 기록해야 한다. 서버 왕복 없이 가볍게 판단할 수 있도록 SharedPreferences
/// 에 저장한다(기존 [MyFortuneRecordStore]와 동일한 저장 패턴 재사용).
///
/// [주의] 이 저장소는 "정책 판정을 위한 로컬 힌트"일 뿐이며, 실제 프리패스/
/// 결제 검증은 여전히 [PassProvider]/서버가 단일 진실 소스다. 앱을
/// 재설치하면 초기화되는 것도 허용 범위다(악용 방지를 목표로 하는
/// 서버측 acquireCooldown/dailyLimit과는 역할이 다르다).
class CategoryUsageStore {
  CategoryUsageStore._();

  static const _lastViewedKeyPrefix = 'fortune_category_last_viewed_v1_';
  static const _everViewedKeyPrefix = 'fortune_category_ever_viewed_v1_';

  /// 카테고리 [id]를 오늘 이미 무료로 열람했는지 여부([freeOncePerDay] 판정용).
  static Future<bool> viewedToday(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_lastViewedKeyPrefix$id');
    if (raw == null) return false;
    final last = DateTime.tryParse(raw);
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  /// 카테고리 [id]를 과거에 한 번이라도 열람했는지 여부([lockedFreeFirst] 판정용).
  static Future<bool> viewedEver(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_everViewedKeyPrefix$id') ?? false;
  }

  /// 카테고리 [id]를 열람했음을 기록(오늘 날짜 + 평생 이력 둘 다 갱신).
  static Future<void> markViewed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_lastViewedKeyPrefix$id',
      DateTime.now().toIso8601String(),
    );
    await prefs.setBool('$_everViewedKeyPrefix$id', true);
  }

  /// [디버그/QA용] 특정 카테고리의 이력을 초기화한다.
  static Future<void> reset(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_lastViewedKeyPrefix$id');
    await prefs.remove('$_everViewedKeyPrefix$id');
  }

  /// [디버그/QA용] 전체 카테고리 이력을 한 번에 내보낸다(문제 리포트용).
  static Future<Map<String, dynamic>> exportAll() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_lastViewedKeyPrefix) ||
          key.startsWith(_everViewedKeyPrefix)) {
        result[key] = prefs.get(key);
      }
    }
    return jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
  }
}
