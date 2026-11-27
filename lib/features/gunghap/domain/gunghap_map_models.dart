// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_map_models.dart
// [궁합지도 「인연지도」 2차 디자인 핸드오프] design_handoff_gunghap_map
// (1).zip `MAP_HOME_SPEC.md` §5 데이터 계약 + `flutter_starter/lib/
// gunghap/map/destiny_map.dart` 참고 구현을 실제 서버 응답
// (`GET /api/public/gunghap/map`)에 맞춰 이식한 모델.
//
// [점수 불변 원칙] `score`는 서버가 이미 저장해 둔 "그 사람과 본 가장
// 최근 궁합"의 점수를 그대로 받아올 뿐이다 — 이 모델은 어떤 재계산도
// 하지 않는다(MAP_HOME_SPEC.md §2/§8 "저장 후 불변").
// ═══════════════════════════════════════════════════════════════
library;

/// 오행 한자(木火土金水) → 지도 별 색상. `flutter_starter/.../destiny_map.dart`의
/// `ghElementColor`와 동일 팔레트(2026-11 포인트 컬러 통일 — 土는 신규
/// Accent Gold #E2C07F).
const Map<String, int> ghElementColorValue = {
  '木': 0xFF91C8B0,
  '火': 0xFFD98C7A,
  '土': 0xFFE2C07F,
  '金': 0xFFF3EBDD,
  '水': 0xFF8C7CC3,
};

/// [MAP_HOME_SPEC.md §2] 점수 40~100 클램프(관리자 세팅값).
const int ghScoreMin = 40;
const int ghScoreMax = 100;

/// [MAP_HOME_SPEC.md §2] 궤도 구간 하한값(90/82/74/66/58, 그 아래는 궤도 5).
const List<int> ghOrbitCuts = [90, 82, 74, 66, 58];

int ghOrbitOf(int score) {
  final i = ghOrbitCuts.indexWhere((c) => score >= c);
  return i == -1 ? 5 : i;
}

/// [MAP_HOME_SPEC.md §8] 연속값 거리 공식 — `r = 46 + 105 × (100 − score) / 60`
/// (100점 → 46, 40점 → 151). viewBox 360 단위 기준.
///
/// [하위 호환] 과거 [DestinyMap](viewBox 360×360, 궤도 공전 방식)이
/// 쓰던 공식이다. 신규 [DestinyBurst](viewBox 360×512, 정지 배치)는
/// 아래 [ghBurstRadius]를 대신 쓴다 — 두 공식은 캔버스 크기와 연출이
/// 달라 서로 대체 관계가 아니다.
double ghScoreToRadius(int score) {
  final clamped = score.clamp(ghScoreMin, ghScoreMax);
  return 46.0 + 105.0 * (100 - clamped) / 60.0;
}

/// [00_DEV_MAPPING.md §6-2] DestinyBurst 전용 거리 공식 —
/// `r = 88 + 40 × (100 − clamp(score,40,100)) / 60`(100점 → 88, 40점 → 128).
/// viewBox 360×512, 중심 C(180,250) 기준.
double ghBurstRadius(int score) => 88 + 40 * (100 - score.clamp(ghScoreMin, ghScoreMax)) / 60;

/// `GET /gunghap/map` 응답의 history[] 항목 — "{이름} 님과 본 궁합" 목록.
class MapPersonHistory {
  const MapPersonHistory({
    required this.resultId,
    required this.sub,
    required this.date,
    required this.paid,
    required this.score,
  });

  final String resultId;
  final String sub;
  final DateTime? date;
  final bool paid;
  final int score;

  factory MapPersonHistory.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'] as String?;
    return MapPersonHistory(
      resultId: json['resultId'] as String? ?? '',
      sub: json['sub'] as String? ?? '',
      date: dateRaw != null ? DateTime.tryParse(dateRaw) : null,
      paid: json['paid'] == true,
      score: (json['score'] as num?)?.round() ?? 0,
    );
  }
}

/// `GET /gunghap/map` 응답의 people[] 항목 — 인연지도 위의 별 하나.
class MapPerson {
  const MapPerson({
    required this.personKey,
    required this.name,
    required this.element,
    required this.stem,
    required this.score,
    this.angleDeg,
    required this.majorId,
    required this.resultId,
    required this.history,
  });

  /// 동일 인물 판정 키(서버가 계산해 내려줌 — person_id 원칙).
  final String personKey;
  final String name;

  /// 상대 일간 오행 한자(木火土金水).
  final String element;

  /// 상대 일간 한자(甲..癸).
  final String stem;

  /// 저장 후 불변 — 가장 최근 분석의 엔진 점수.
  final int score;

  /// [v4 §12-5 반영] 서버는 등록순서 기반 황금각 고정 좌표를 계속
  /// 내려주지만, 신규 [DestinyBurst]는 분야순 → 점수 내림차순 정렬 후
  /// 균등분할·정지 배치를 쓰므로 이 값을 사용하지 않는다(과거
  /// [DestinyMap] 궤도 공전 방식에서만 쓰던 값) — nullable로 바꿔
  /// 서버가 계속 내려줘도 무시할 수 있게 한다.
  final double? angleDeg;

  final String? majorId;

  /// 이 인물의 "최신" 궁합 결과 id — RelationSheet·결과보기 CTA에 사용.
  final String resultId;

  final List<MapPersonHistory> history;

  int get orbit => ghOrbitOf(score.clamp(ghScoreMin, ghScoreMax));

  factory MapPerson.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['history'];
    return MapPerson(
      personKey: json['personKey'] as String? ?? '',
      name: json['name'] as String? ?? '상대방',
      element: json['element'] as String? ?? '土',
      stem: json['stem'] as String? ?? '戊',
      score: (json['score'] as num?)?.round() ?? ghScoreMin,
      angleDeg: (json['angleDeg'] as num?)?.toDouble(),
      majorId: json['majorId'] as String?,
      resultId: json['resultId'] as String? ?? '',
      history: historyRaw is List
          ? historyRaw
                .whereType<Map<String, dynamic>>()
                .map(MapPersonHistory.fromJson)
                .toList()
          : const [],
    );
  }
}

/// `GET /gunghap/map` 응답의 `me` — 나의 일간/오행(별도 생년월일 미노출).
class MapMe {
  const MapMe({required this.stem, required this.element});
  final String? stem;
  final String? element;

  factory MapMe.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MapMe(stem: null, element: null);
    return MapMe(
      stem: json['stem'] as String?,
      element: json['element'] as String?,
    );
  }
}
