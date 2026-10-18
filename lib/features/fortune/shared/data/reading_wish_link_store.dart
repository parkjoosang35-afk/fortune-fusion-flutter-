// [v7 통합 — v7.1 핵심] "풀이를 소원에 얹기(동봉)" 로컬 매핑 저장소.
//
// v7.1 원칙: 봉인 시 새 소원을 만들지 않고, 이미 가진 내 소원에 artifactId를
// 누적한다(MyWish.readings[]). 그러나 이 Flutter 앱의 WishRoomProvider는
// 서버가 내려주는 WishRoom 모델을 그대로 쓰고 있어 서버 스키마에 `readings`
// 필드가 없다(v7.4가 요구하는 `POST /wishes/:id/readings` 엔드포인트는
// "엔진 팀 결정 필요"로 아직 미생성 — CHANGES_v7.md 명시).
//
// 따라서 1단계 구현으로, 소원(WishRoom.id) ↔ 풀이(ReadingArtifact.id) 동봉
// 관계를 기기 로컬에 보관한다. 서버 영속이 결정되면 이 저장소를
// WrRepository(wr_api.dart) 호출로 교체하면 된다 — 호출부(ComposeScreen,
// 결과 화면)는 이 클래스의 정적 API만 알면 되므로 교체 영향 범위가 작다.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingWishLinkStore {
  ReadingWishLinkStore._();

  static const _key = 'sintong_v7_reading_wish_links';

  static Future<Map<String, List<String>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeAll(Map<String, List<String>> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
  }

  /// 소원 [wishRoomId]에 풀이 [artifactId]를 동봉한다(멱등 — 이미 있으면
  /// 중복 추가하지 않는다, v7.4 §9 멱등성 원칙과 동일한 정신).
  static Future<void> attach(String wishRoomId, String artifactId) async {
    final all = await _readAll();
    final list = all[wishRoomId] ?? <String>[];
    if (!list.contains(artifactId)) list.add(artifactId);
    all[wishRoomId] = list;
    await _writeAll(all);
  }

  static Future<List<String>> readingsOf(String wishRoomId) async {
    final all = await _readAll();
    return all[wishRoomId] ?? const [];
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
