import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/wish_room_model.dart';

/// [소원방 MVP] 소원방 상태/치성 기록 Repository.
///
/// [1차 개발 범위 결정] 통합정책서 §17은 "화면마다 임시 판정하지 말고 공통
/// 상태/정책 함수로 연결한다"를 요구하지만, 소원게시판/소원방 실서버(백엔드
/// DB) 구축 자체는 이번 1차 개발 범위에서 명시적으로 제외되어 있다. 따라서
/// [LuckPouchRepository]와 동일한 패턴으로 SharedPreferences 기반 로컬
/// Mock으로 구현하고, 향후 커뮤니티 본개발 시 이 파일의 구현부만 admin_web
/// 실 API 호출로 교체하면 Provider/Presentation 레이어는 그대로 재사용된다.
class WishRoomRepository {
  static const _kRoomKey = 'wish_room_state';
  static const _kHistoryKey = 'wish_room_ritual_history';
  static const _kIntroSeenKey = 'wish_room_intro_seen';

  /// MVP 단계는 멀티유저 서버 분리가 없으므로(LuckPouchRepository와 동일한
  /// 단순화) 디바이스 1개당 소원방 1개로 고정한다.
  static const String _localUserId = 'local_user';

  Future<WishRoomModel> getRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRoomKey);
    if (raw == null || raw.isEmpty) {
      return WishRoomModel.initial(userId: _localUserId);
    }
    return WishRoomModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> saveRoom(WishRoomModel room) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRoomKey, jsonEncode(room.toJson()));
  }

  Future<bool> getIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIntroSeenKey) ?? false;
  }

  Future<void> setIntroSeen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIntroSeenKey, value);
  }

  Future<List<RitualRecordModel>> getRitualHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => RitualRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 치성 기록은 향후 CMS/통계 연동을 대비한 원장 성격이라 최근 50건만
  /// 보관한다(LuckPouchRepository._appendHistory와 동일한 정책).
  Future<void> appendRitualHistory(RitualRecordModel record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getRitualHistory();
    final next = [record, ...history].take(50).toList();
    await prefs.setString(
      _kHistoryKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
