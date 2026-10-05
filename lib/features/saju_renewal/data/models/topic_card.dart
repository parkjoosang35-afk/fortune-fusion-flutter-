/// [신통방통 정통사주 리뉴얼 — STEP 6.5] admin_web
/// `topic-contract-adapter.ts`의 `TopicCard`(docs/11_API_계약서.md §2)에
/// 1:1 대응하는 Flutter 도메인 모델.
///
/// 서버가 내려주는 필드만 그대로 옮긴다(topic_id/scene/title/is_timing/
/// evidence_fact_keys). 내부 score/condition/evaluator/DB id/categoryGroup
/// (29종 분류) 등은 서버가 애초에 내려주지 않으므로 이 모델에도 존재하지
/// 않는다 — "사용자 화면에 내부 정보 노출 금지" 원칙이 모델 설계
/// 시점부터 구조적으로 지켜진다.
library;

/// docs/01_디자인토큰.md §1-4 "주제군 조명(scene tint)" 확정 5종.
/// admin_web `SceneCode`와 동일한 문자열 값을 그대로 사용한다(변환 없음).
enum SajuRenewalScene { money, talent, love, life, guin }

SajuRenewalScene _sceneFromServer(String raw) {
  switch (raw) {
    case 'money':
      return SajuRenewalScene.money;
    case 'talent':
      return SajuRenewalScene.talent;
    case 'love':
      return SajuRenewalScene.love;
    case 'life':
      return SajuRenewalScene.life;
    case 'guin':
      return SajuRenewalScene.guin;
    default:
      // [서버 계약 위반 방어] 서버가 이미 scene 미확정 토픽(PERSONALITY_001 등)을
      // 선정 단계에서부터 제외하도록 보장하므로(SCENE_UNRESOLVED_TOPIC_IDS),
      // 정상 흐름에서는 도달하지 않아야 한다. 혹시 알려지지 않은 값이 오면
      // 임의로 추정하지 않고 life로 안전 폴백한다(화면이 깨지지 않도록 최소
      // 방어만 — 내부 판단을 Flutter가 새로 하지 않는다).
      return SajuRenewalScene.life;
  }
}

/// admin_web `ElementCode` — "wood"|"fire"|"earth"|"metal"|"water" 5종.
enum SajuRenewalElement { wood, fire, earth, metal, water }

SajuRenewalElement? _elementFromServer(String raw) {
  switch (raw) {
    case 'wood':
      return SajuRenewalElement.wood;
    case 'fire':
      return SajuRenewalElement.fire;
    case 'earth':
      return SajuRenewalElement.earth;
    case 'metal':
      return SajuRenewalElement.metal;
    case 'water':
      return SajuRenewalElement.water;
    default:
      return null;
  }
}

/// POST /api/public/saju-renewal/topics/select 응답의 `first_topic`/
/// `candidates[]` 각 항목. admin_web `TopicCard` 타입과 1:1 대응.
class TopicCard {
  /// 내부 topic_id(예: MONEY_002). **화면에 직접 노출하지 않는다** —
  /// interpret 호출 시 서버 재검증용 식별자로만 쓰인다.
  final String topicId;
  final SajuRenewalScene scene;
  final String title;
  final bool isTiming;

  /// 참고용 근거 키(서버가 interpret에서 재검증하므로 클라이언트는 이
  /// 값을 신뢰하지 않고 단순히 왕복 전달만 한다).
  final List<String> evidenceFactKeys;

  const TopicCard({
    required this.topicId,
    required this.scene,
    required this.title,
    required this.isTiming,
    required this.evidenceFactKeys,
  });

  factory TopicCard.fromJson(Map<String, dynamic> json) {
    final rawEvidence = json['evidence_fact_keys'];
    return TopicCard(
      topicId: json['topic_id'] as String? ?? '',
      scene: _sceneFromServer(json['scene'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      isTiming: json['is_timing'] as bool? ?? false,
      evidenceFactKeys: rawEvidence is List
          ? rawEvidence.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// POST /api/public/saju-renewal/topics/select 응답 data 전체.
class TopicsSelectResult {
  final TopicCard firstTopic;
  final List<TopicCard> candidates;
  final List<SajuRenewalElement> keyFacts;
  final String factSchemaVersion;

  const TopicsSelectResult({
    required this.firstTopic,
    required this.candidates,
    required this.keyFacts,
    required this.factSchemaVersion,
  });

  factory TopicsSelectResult.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final rawKeyFacts = json['key_facts'];
    return TopicsSelectResult(
      firstTopic: TopicCard.fromJson(
        json['first_topic'] as Map<String, dynamic>,
      ),
      candidates: rawCandidates is List
          ? rawCandidates
                .map((e) => TopicCard.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
      keyFacts: rawKeyFacts is List
          ? rawKeyFacts
                .map((e) => _elementFromServer(e.toString()))
                .whereType<SajuRenewalElement>()
                .toList()
          : const [],
      factSchemaVersion: json['fact_schema_version'] as String? ?? '',
    );
  }
}
