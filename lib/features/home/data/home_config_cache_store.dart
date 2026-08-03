import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/page_config_model.dart';

/// [메인화면 관리자 편집기] §17 "앱 동작 원칙" - HomeConfigCacheStore
///
/// 서버(admin_web) 조회가 실패했을 때(오프라인/네트워크 오류/500 등) 마지막으로
/// 성공적으로 받아온 PageConfigData를 로컬(shared_preferences)에 보관해두고
/// 재사용한다. 캐시조차 없으면 HomePageConfigProvider가 그보다 한 단계 더 낮은
/// 최종 폴백(홈 화면의 기존 정적 레이아웃)으로 넘어간다.
class HomeConfigCacheStore {
  static const _key = 'home_page_config_cache_v1';

  Future<void> save(PageConfigData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('[HomeConfigCacheStore] [save] 실패(무시하고 계속) -> $e');
    }
  }

  Future<PageConfigData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return PageConfigData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[HomeConfigCacheStore] [load] 실패 -> $e');
      return null;
    }
  }
}
