// [v7 통합] ReadingArtifact 로컬 저장소.
//
// 디자인 핸드오프 ReadingArtifact.jsx의 localStorage 키 'sintong-v7-artifacts'
// (최대 12개) 그대로의 Flutter 포팅. core/data/my_fortune_record_store.dart와
// 동일한 shared_preferences 기반 패턴을 재사용한다(Hive는 이 프로젝트에서
// 실사용 0건이라 이미 제거된 죽은 의존성이므로 새로 끌어오지 않는다).
//
// [v7.4 "미결정" 사항 — CHANGES_v7.md 명시] 아티팩트의 서버 영속 여부/보관
// 정책은 "엔진 팀 결정 필요"로 남아 있다. 이 구현은 1단계로 로컬(기기)
// 전용 보관만 제공하고, 서버 저장(POST /readings 등 신규 엔드포인트)은
// 이번 범위에 포함하지 않는다(표준 불변 제약: 기존 엔드포인트 재사용,
// 새 엔드포인트는 서버 팀 결정 이후 별도 작업으로 추가).
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/reading_artifact.dart';

class ReadingArtifactStore {
  ReadingArtifactStore._();

  static const _key = 'sintong_v7_reading_artifacts';
  static const maxCount = 12;

  static Future<List<ReadingArtifact>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final items = raw
        .map((e) {
          try {
            return ReadingArtifact.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<ReadingArtifact>()
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static Future<ReadingArtifact?> get(String id) async {
    final all = await list();
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// 아티팩트를 저장한다. 최대 [maxCount]개를 넘으면 가장 오래된 것부터
  /// 버린다(ReadingArtifact.jsx listArtifacts()/saveArtifact() 1:1).
  static Future<void> save(ReadingArtifact artifact) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await list()).where((a) => a.id != artifact.id).toList();
    all.insert(0, artifact);
    final trimmed = all.take(maxCount).toList();
    await prefs.setStringList(
      _key,
      trimmed.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = (await list()).where((a) => a.id != id).toList();
    await prefs.setStringList(
      _key,
      all.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  /// 로그아웃 시 기기에 남은 풀이 보관함을 비운다(다음 계정에 노출 방지 —
  /// face_provider/palm_provider의 clearOnLogout과 동일 원칙).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
