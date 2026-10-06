import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/topic_card.dart';

/// [신통방통 정통사주 리뉴얼 — 화면① "최근 본 이야기" 카드]
/// docs/03_화면명세.md §01 "최근 본 이야기 카드" — 재방문 시에만 노출되는
/// 카드가 참조할 "마지막으로 상세(07)까지 본 이야기" 1건을 로컬에 보관한다.
///
/// [설계 근거] 서버(topics/select)는 "마지막으로 본 토픽"을 따로 캐싱해
/// 내려주지 않는다(screens/saju_renewal_home_screen.dart 기존 주석 참고).
/// 그렇다고 가짜 더미 카드를 보여줄 수는 없으므로(원칙 위반), 실제
/// 사용자가 이번 기기에서 상세까지 완료한 이야기를 클라이언트가 직접
/// 기록해 재사용한다 — "서버가 안 주면 로컬에 있는 실제 값을 쓴다"는
/// MyFortuneRecordStore(core/data)와 동일한 패턴이다.
class SajuRecentStory {
  const SajuRecentStory({
    required this.topicId,
    required this.scene,
    required this.title,
    required this.evidenceFactKeys,
    required this.viewedAt,
  });

  final String topicId;
  final SajuRenewalScene scene;
  final String title;
  final List<String> evidenceFactKeys;
  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {
    'topic_id': topicId,
    'scene': scene.name,
    'title': title,
    'evidence_fact_keys': evidenceFactKeys,
    'viewed_at': viewedAt.toIso8601String(),
  };

  static SajuRenewalScene _sceneFromName(String raw) {
    for (final s in SajuRenewalScene.values) {
      if (s.name == raw) return s;
    }
    return SajuRenewalScene.life;
  }

  factory SajuRecentStory.fromJson(Map<String, dynamic> json) {
    final rawEvidence = json['evidence_fact_keys'];
    return SajuRecentStory(
      topicId: json['topic_id'] as String? ?? '',
      scene: _sceneFromName(json['scene'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      evidenceFactKeys: rawEvidence is List
          ? rawEvidence.map((e) => e.toString()).toList()
          : const [],
      viewedAt:
          DateTime.tryParse(json['viewed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 재방문 카드 탭 시 [SajuRenewalProvider.loadPreview]에 바로 넘길 수
  /// 있도록 [TopicCard]로 변환한다.
  TopicCard toTopicCard() => TopicCard(
    topicId: topicId,
    scene: scene,
    title: title,
    isTiming: false,
    evidenceFactKeys: evidenceFactKeys,
  );
}

class SajuRecentStoryStore {
  SajuRecentStoryStore._();

  static const _key = 'saju_renewal_recent_story_v1';

  /// 화면⑦(상세) 노출이 성공적으로 끝난 직후 호출한다.
  static Future<void> save(SajuRecentStory story) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(story.toJson()));
  }

  static Future<SajuRecentStory?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SajuRecentStory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// [계정 격리 원칙] 로그아웃 시 사용자A의 "최근 본 이야기"가 사용자B
  /// 화면에 남아있으면 안 된다.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
