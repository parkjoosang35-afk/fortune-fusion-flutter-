/// [신통방통 오늘·주간·월간 운세 — Flutter 클라이언트] 서버 API
/// `GET /api/public/fortune-period/{kind}` 응답을 그대로 반영하는 DTO.
///
/// [절대 원칙] 이 파일은 서버(`admin_web/src/app/api/public/fortune-period/
/// [kind]/route.ts`)의 `okResponse()`가 내려주는 JSON 구조를 1:1로 옮긴
/// 것이며, 클라이언트 쪽에서 기간/문장 생성 로직을 재구현하지 않는다
/// (디자인 핸드오프 `fortune-period.js`의 `Period`/`generateFortune()`는
/// 서버가 이미 TypeScript로 재구현했으므로 Flutter는 API만 소비한다).
library;

/// 운세 종류 — `today`(오늘)/`week`(주간)/`month`(월간).
enum FortuneKind { today, week, month }

extension FortuneKindX on FortuneKind {
  String get apiValue {
    switch (this) {
      case FortuneKind.today:
        return 'today';
      case FortuneKind.week:
        return 'week';
      case FortuneKind.month:
        return 'month';
    }
  }

  /// 디자인 `PeriodTabs`의 탭 라벨("오늘"/"주간"/"월간").
  String get tabLabel {
    switch (this) {
      case FortuneKind.today:
        return '오늘';
      case FortuneKind.week:
        return '주간';
      case FortuneKind.month:
        return '월간';
    }
  }

  /// 디자인 `v2-fields` 섹션 헤더("오늘의 분야별 운세" 등, fortune-v2.jsx
  /// 그대로).
  String get fieldsSectionTitle {
    switch (this) {
      case FortuneKind.today:
        return '오늘의 분야별 운세';
      case FortuneKind.week:
        return '이번 주 분야별 운세';
      case FortuneKind.month:
        return '이번 달 분야별 운세';
    }
  }

  /// 디자인 `v2-caution` 섹션 헤더(주간/월간만 노출, today는 null).
  String? get cautionSectionTitle {
    switch (this) {
      case FortuneKind.today:
        return null;
      case FortuneKind.week:
        return '이번 주 주의할 점';
      case FortuneKind.month:
        return '이번 달 주의할 점';
    }
  }

  static FortuneKind fromApiValue(String v) {
    switch (v) {
      case 'today':
        return FortuneKind.today;
      case 'week':
        return FortuneKind.week;
      case 'month':
        return FortuneKind.month;
      default:
        throw ArgumentError('알 수 없는 fortune kind: $v');
    }
  }
}

/// `period: { label, main, sub, until }` — 기간 표시 정보.
class FortunePeriodInfo {
  final String label; // "TODAY" / "THIS WEEK" / "THIS MONTH" (mono 라벨)
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

/// `flow[]` 항목 — 오전/오후/저녁 또는 초반/중반/후반 또는 초순/중순/하순.
class FortuneFlowItem {
  final String k; // "morning" 등 key
  final String t; // "오전" 등 표시 라벨
  final String text;

  const FortuneFlowItem({required this.k, required this.t, required this.text});

  factory FortuneFlowItem.fromJson(Map<String, dynamic> json) =>
      FortuneFlowItem(
        k: json['k'] as String? ?? '',
        t: json['t'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}

/// `fields[]` 항목 — 재물운/애정운/사업직장운 3종.
class FortuneFieldItem {
  final String id; // "wealth" | "love" | "work"
  final String name; // "재물운" 등
  final String text;

  const FortuneFieldItem({
    required this.id,
    required this.name,
    required this.text,
  });

  factory FortuneFieldItem.fromJson(Map<String, dynamic> json) =>
      FortuneFieldItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  /// 디자인 `FIELD_GLYPH = { money: '財', love: '緣', work: '業' }`.
  /// 서버 응답의 id는 `wealth`지만 디자인 glyph 매핑 키는 `money` —
  /// 둘 다 포괄하도록 처리한다.
  String get glyph {
    switch (id) {
      case 'wealth':
      case 'money':
        return '財';
      case 'love':
        return '緣';
      case 'work':
        return '業';
      default:
        return '◈';
    }
  }
}

/// `GET /api/public/fortune-period/{kind}` 성공 응답의 `data` 전체.
class FortunePeriodResult {
  final FortuneKind kind;
  final String periodKey;
  final FortunePeriodInfo period;
  final String seal; // 吉/平/新 등 한 글자
  final List<String> title; // 2줄 타이틀 [0], [1]
  final String summary; // 총평
  final List<FortuneFlowItem> flow;
  final List<FortuneFieldItem> fields;
  final List<String>? caution; // week/month만, today는 null
  final bool isNew;
  final bool hasPrevious;
  /// 과거 결과 열람 API(`/{kind}/{periodKey}`) 응답에만 있는 플래그.
  final bool isPast;

  const FortunePeriodResult({
    required this.kind,
    required this.periodKey,
    required this.period,
    required this.seal,
    required this.title,
    required this.summary,
    required this.flow,
    required this.fields,
    required this.caution,
    required this.isNew,
    required this.hasPrevious,
    this.isPast = false,
  });

  factory FortunePeriodResult.fromJson(Map<String, dynamic> json) {
    final periodJson = json['period'] as Map<String, dynamic>?;
    return FortunePeriodResult(
      kind: FortuneKindX.fromApiValue(json['kind'] as String),
      periodKey: json['periodKey'] as String? ?? '',
      // [과거 결과 열람] `/{kind}/{periodKey}`는 `period` 필드를 내려주지
      // 않으므로(README: 조회 전용, 기간 메타는 재계산하지 않음), 비어있는
      // 기본값으로 대체한다 — 화면은 이 경우 PastBanner로 과거임을 안내하고
      // period 헤더 자체는 그대로 숨기거나 periodKey 문자열만 보여준다.
      period: periodJson != null
          ? FortunePeriodInfo.fromJson(periodJson)
          : FortunePeriodInfo(label: '', main: '', sub: ''),
      seal: json['seal'] as String? ?? '吉',
      title: (json['title'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      summary: json['summary'] as String? ?? '',
      flow: (json['flow'] as List<dynamic>? ?? const [])
          .map((e) => FortuneFlowItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      fields: (json['fields'] as List<dynamic>? ?? const [])
          .map((e) => FortuneFieldItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      caution: (json['caution'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isNew: json['isNew'] as bool? ?? false,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
      isPast: json['isPast'] as bool? ?? false,
    );
  }

  /// 디자인 `v2-summary-title`의 2줄 타이틀 — 인덱스 안전 접근.
  String get titleLine1 => title.isNotEmpty ? title[0] : '';
  String get titleLine2 => title.length > 1 ? title[1] : '';
}

/// `GET /{kind}/history?limit=6` 응답의 `items[]` 1건 — `ArchiveList`용.
class FortuneArchiveItem {
  final String periodKey;
  final List<String> title;
  final String seal;
  final String createdAt; // ISO

  const FortuneArchiveItem({
    required this.periodKey,
    required this.title,
    required this.seal,
    required this.createdAt,
  });

  factory FortuneArchiveItem.fromJson(Map<String, dynamic> json) =>
      FortuneArchiveItem(
        periodKey: json['periodKey'] as String? ?? '',
        title: (json['title'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        seal: json['seal'] as String? ?? '吉',
        createdAt: json['createdAt'] as String? ?? '',
      );
}
