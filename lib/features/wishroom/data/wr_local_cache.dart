// [비용 최소화 §3 "홈 화면을 켤 때마다 서버를 조회하지 마세요. 마지막 정상
// 방 데이터를 즉시 표시하고, 동기화는 방 변경·치성 완료·필요한 앱 진입 등
// 정해진 시점에만 수행하세요."]
//
// WishRoom/Me 모델에는 toJson()이 없고(fromJson만 존재), 전수 추가하는 대신
// — 서버가 보낸 원본 JSON(Map)을 가공 없이 그대로 저장했다가 그대로
// fromJson()에 되돌려주는 방식을 택했다(모델 변경 0줄, 서버 응답 계약과
// 100% 동일한 형태를 보존). 이 캐시는:
//   - 앱 콜드 스타트 시 네트워크 응답을 기다리지 않고 "마지막으로 성공한
//     내 방 데이터"를 즉시 화면에 그릴 수 있게 해준다(오프라인 포함).
//   - 그 뒤 WishRoomProvider.loadMyRoom()이 백그라운드로 1회 네트워크
//     조회를 시도해 최신화한다 — "필요한 앱 진입" 시점의 정해진 동기화이므로
//     §3 정책 위반이 아니다(매번 폴링하거나 화면 재진입마다 다시 쏘지 않음,
//     기존 main_room_screen.dart의 `if (p.room == null) loadMyRoom()` 가드가
//     이를 이미 보장한다).
//   - 네트워크가 실패해도(오프라인) 캐시된 마지막 데이터가 화면에 남아있으므로
//     "검은 미리보기/빈 화면"을 보이지 않는다(완료 불인정 사유 회피).
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WrLocalCache {
  WrLocalCache._();

  static const _myRoomJsonKey = 'wr_cache_myroom_json';
  static const _myRoomSavedAtKey = 'wr_cache_myroom_saved_at';

  /// 서버가 돌려준 `/wish-rooms/me` 원본 응답(data 필드, 가공 전)을 그대로
  /// 저장한다. 실패해도(쓰기 오류 등) 앱 동작에 영향 없도록 조용히 무시한다.
  static Future<void> saveMyRoomJson(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_myRoomJsonKey, jsonEncode(json));
      await prefs.setInt(_myRoomSavedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // 캐시는 best-effort다 — 실패해도 네트워크 응답 자체는 정상 반환된다.
    }
  }

  /// 마지막으로 저장된 원본 JSON을 읽는다. 없거나 파싱 실패 시 null.
  static Future<Map<String, dynamic>?> loadMyRoomJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_myRoomJsonKey);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// 캐시가 저장된 시각(ms) — 화면에서 "마지막 확인: n분 전" 같은 안내를
  /// 붙이고 싶을 때 참고용. 없으면 null.
  static Future<int?> loadMyRoomSavedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_myRoomSavedAtKey);
    } catch (_) {
      return null;
    }
  }

  /// 로그아웃 시 이전 계정의 캐시가 다음 계정 화면에 잠깐이라도 노출되지
  /// 않도록 반드시 비운다(샘플/타인 데이터 노출 금지 원칙과 동일 취지).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_myRoomJsonKey);
      await prefs.remove(_myRoomSavedAtKey);
    } catch (_) {}
  }
}
