/// [오늘의 운세 — Flutter 클라이언트] 서버 API
/// `GET /api/public/fortune-period/today` 응답을 그대로 반영하는 DTO.
///
/// [2026-11 전면 개편] 기존 "오늘·주간·월간" 3종 체계를 폐기했다(주간/월간은
/// 엔진 전용 계산 로직 없이 일진을 짜깁기한 수준이라는 사용자 피드백).
/// 이제 "오늘의 운세"만 남았고, 서버는 이미 구축된 사주 FACT 엔진 +
/// AI 해석("무당체" — 반말/단정체)으로 매일 새로운 하나의 이어지는 글(단일
/// 서사, 섹션/카드 구분 없음)을 생성한다
/// (`saju_engine` `POST /fortune/today/mudang`,
/// `admin_web` `GET /api/public/fortune-period/{kind}` → `okResponse()`).
///
/// [절대 원칙] 이 파일은 서버 응답 JSON 구조를 1:1로 옮긴 것이며, 클라이언트
/// 쪽에서 문장 생성/가공 로직을 재구현하지 않는다.
library;

/// 운세 종류 — 이제 `today` 하나만 유효하다. 과거에는 `week`/`month`도
/// 있었으나 전면 삭제되었다(서버도 해당 kind를 410 Gone으로 응답한다).
/// enum 자체는 API 호출 시그니처 호환을 위해 유지한다.
enum FortuneKind { today }

extension FortuneKindX on FortuneKind {
  String get apiValue => 'today';

  static FortuneKind fromApiValue(String v) {
    if (v == 'today') return FortuneKind.today;
    throw ArgumentError('알 수 없는 fortune kind: $v');
  }
}

/// `period: { label, main, sub, until }` — 기간 표시 정보.
class FortunePeriodInfo {
  final String label; // "TODAY" (mono 라벨)
  final String main; // "11월 4일 화요일" 등 큰 타이틀
  final String sub; // "오늘 자정까지 같은 풀이가 유지돼요" 등 보조 설명
  final String? until; // 이 기간이 유지되는 종료 시각(ISO), 과거 조회 시 null일 수 있음

  const FortunePeriodInfo({
    required this.label,
    required this.main,
    required this.sub,
    this.until,
  });

  factory FortunePeriodInfo.fromJson(Map<String, dynamic> json) =>
      FortunePeriodInfo(
        label: json['label'] as String? ?? '',
        main: json['main'] as String? ?? '',
        sub: json['sub'] as String? ?? '',
        until: json['until'] as String?,
      );
}

/// `GET /api/public/fortune-period/today` 성공 응답의 `data` 전체.
///
/// [스키마 변경 — 2026-11] 기존 `seal/title/summary/flow/fields/caution`
/// (카드·섹션 분할 구조)을 전부 폐기하고, `headline`(한 줄 제목) +
/// `text`(두세 문단으로 이어지는 하나의 글)로 단순화했다. 같은 엔진 계산값을
/// 여러 섹션에 중복 노출하던 기존 버그도 구조적으로 사라진다(텍스트 블록이
/// 하나뿐이므로).
class FortunePeriodResult {
  final FortuneKind kind;
  final String periodKey;
  final FortunePeriodInfo period;
  final String headline; // 4~12자 강렬한 한 줄 제목 (예: "말 한마디 독")
  final String text; // 두세 문단으로 이어지는 하나의 글 (섹션/카드 구분 없음)
  final String? dayGanZhi; // "乙酉 (을유)" 등 오늘의 일진
  final List<String> luckyColor;
  final List<String> luckyDirection;
  final List<int> luckyNumber;
  final String source; // "llm" | "rule_fallback" | "cache"
  final bool isNew;
  final bool hasPrevious;

  /// 과거 결과 열람 API(`/{kind}/{periodKey}`) 응답에만 있는 플래그.
  final bool isPast;

  const FortunePeriodResult({
    required this.kind,
    required this.periodKey,
    required this.period,
    required this.headline,
    required this.text,
    this.dayGanZhi,
    required this.luckyColor,
    required this.luckyDirection,
    required this.luckyNumber,
    required this.source,
    required this.isNew,
    required this.hasPrevious,
    this.isPast = false,
  });

  factory FortunePeriodResult.fromJson(Map<String, dynamic> json) {
    final periodJson = json['period'] as Map<String, dynamic>?;
    return FortunePeriodResult(
      kind: FortuneKindX.fromApiValue(json['kind'] as String? ?? 'today'),
      periodKey: json['periodKey'] as String? ?? '',
      // [과거 결과 열람] `/{kind}/{periodKey}`는 `period` 필드를 내려주지
      // 않으므로(조회 전용, 기간 메타는 재계산하지 않음), 비어있는 기본값으로
      // 대체한다 — 화면은 이 경우 PastBanner로 과거임을 안내한다.
      period: periodJson != null
          ? FortunePeriodInfo.fromJson(periodJson)
          : const FortunePeriodInfo(label: '', main: '', sub: ''),
      headline: json['headline'] as String? ?? '',
      text: json['text'] as String? ?? '',
      dayGanZhi: json['dayGanZhi'] as String?,
      luckyColor: (json['luckyColor'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      luckyDirection: (json['luckyDirection'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      luckyNumber: (json['luckyNumber'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      source: json['source'] as String? ?? 'rule_fallback',
      isNew: json['isNew'] as bool? ?? false,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
      isPast: json['isPast'] as bool? ?? false,
    );
  }
}

/// `GET /today/history?limit=6` 응답의 `items[]` 1건 — `ArchiveList`용.
class FortuneArchiveItem {
  final String periodKey;
  final String headline;
  final String createdAt; // ISO

  const FortuneArchiveItem({
    required this.periodKey,
    required this.headline,
    required this.createdAt,
  });

  factory FortuneArchiveItem.fromJson(Map<String, dynamic> json) =>
      FortuneArchiveItem(
        periodKey: json['periodKey'] as String? ?? '',
        headline: json['headline'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}
