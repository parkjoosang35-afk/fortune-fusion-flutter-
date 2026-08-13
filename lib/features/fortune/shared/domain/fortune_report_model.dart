/// [오늘의 운세 표준 플로우] 결과 리포트 데이터 스키마.
///
/// 사용자 확정 스펙 §9(확장 대비 데이터 스키마)의
/// `{ hero: {...}, sections: [ {type, ...}, ... ] }` 구조를 Dart로 표현한다.
/// 사주/궁합/타로/관상/손금은 이 파일의 클래스를 그대로 재사용하거나,
/// [FortuneSection]을 상속한 새 타입을 추가하는 것만으로 확장 가능해야 한다.
library;

/// 섹션 종류 판별자(discriminator) — JSON `type` 필드에 대응.
enum FortuneSectionType { overview, timeline, aspect, avoid, recommend, lucky }

/// 모든 결과 섹션의 공통 상위 타입.
///
/// [requiresPass]가 true인 섹션은 결과 화면에서 열림패스 정책(§5)에 따라
/// 잠금 카드(요약 1줄 + 담백한 유도 문구)로 표시된다.
abstract class FortuneSection {
  const FortuneSection({
    required this.type,
    required this.title,
    required this.requiresPass,
  });

  final FortuneSectionType type;
  final String title;
  final bool requiresPass;
}

/// 섹션 2. 전체 흐름 카드 — 무료 노출.
class OverviewSection extends FortuneSection {
  const OverviewSection({required super.title, required this.body})
    : super(type: FortuneSectionType.overview, requiresPass: false);

  final String body;
}

/// 시간대별 흐름 카드의 한 구간(오전/오후/저녁/밤).
class TimelineSlot {
  const TimelineSlot({required this.label, required this.body});

  final String label;
  final String body;
}

/// 섹션 3. 시간대별 흐름 카드 — 열림패스 필요.
class TimelineSection extends FortuneSection {
  const TimelineSection({required super.title, required this.slots})
    : super(type: FortuneSectionType.timeline, requiresPass: true);

  final List<TimelineSlot> slots;
}

/// 섹션 4~8. 세부 운세(연애/금전/인간관계/건강/일·학업) — 열림패스 필요.
class AspectSection extends FortuneSection {
  const AspectSection({
    required super.title,
    required this.index,
    required this.body,
  }) : super(type: FortuneSectionType.aspect, requiresPass: true);

  /// 0~100 지수.
  final int index;
  final String body;
}

/// 섹션 9/10. 피해야 할 것 · 추천 행동 카드 — 열림패스 필요.
class ListSection extends FortuneSection {
  const ListSection({
    required super.title,
    required this.items,
    required FortuneSectionType listType,
  }) : super(type: listType, requiresPass: true);

  final List<String> items;

  bool get isAvoid => type == FortuneSectionType.avoid;
}

/// 행운 요소 그리드의 한 항목(색/숫자/시간/방향/아이템/키워드).
class LuckyItem {
  const LuckyItem({
    required this.label,
    required this.value,
    this.requiresPass = false,
  });

  final String label;
  final String value;

  /// true면 열림패스가 없을 때 값 대신 잠금 표시(§5 "행운 요소 일부").
  final bool requiresPass;
}

/// 섹션 11. 행운 요소 카드 — 카드 자체는 무료 노출, 일부 항목만 열림패스 필요.
class LuckySection extends FortuneSection {
  const LuckySection({required super.title, required this.items})
    : super(type: FortuneSectionType.lucky, requiresPass: false);

  final List<LuckyItem> items;

  bool get hasLockedItem => items.any((e) => e.requiresPass);
}

/// 섹션 1. 히어로 요약 — 이름/날짜/점수/한줄총평/상태뱃지/키워드.
///
/// [statusLabel]은 "보통/상승/주의" 같은 담백한 한 단어 상태 표시,
/// [keywords]는 오늘의 흐름을 압축한 2~3개의 짧은 태그다(§6-1 예시 구조).
class FortuneHero {
  const FortuneHero({
    required this.score,
    required this.headline,
    required this.name,
    required this.date,
    this.statusLabel,
    this.keywords = const [],
    this.subDescription,
  });

  final int score;
  final String headline;
  final String name;
  final DateTime date;
  final String? statusLabel;
  final List<String> keywords;
  final String? subDescription;
}

/// 결과 리포트 전체 — hero + sections[] (§9 스키마).
class FortuneReport {
  const FortuneReport({required this.hero, required this.sections});

  final FortuneHero hero;
  final List<FortuneSection> sections;

  List<T> sectionsOfType<T extends FortuneSection>() =>
      sections.whereType<T>().toList();
}

/// [진입~입력 화면] 사용자가 입력한 오늘의 운세 프로필.
/// 이름/생년월일/성별은 필수, 태어난시간/양력음력은 선택.
class FortuneInputModel {
  const FortuneInputModel({
    required this.name,
    required this.birthDate,
    required this.gender,
    this.birthTime,
    this.birthTimeUnknown = false,
    this.isLunar = false,
  });

  final String name;
  final DateTime birthDate;

  /// '남' | '여'
  final String gender;

  /// 태어난 시간(선택). null이거나 [birthTimeUnknown]이면 "모름"으로 표시.
  final DateTime? birthTime;
  final bool birthTimeUnknown;
  final bool isLunar;

  bool get hasBirthTime => !birthTimeUnknown && birthTime != null;

  String get birthTimeLabel {
    if (birthTimeUnknown || birthTime == null) return '모름';
    final h = birthTime!.hour.toString().padLeft(2, '0');
    final m = birthTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'birthDate': birthDate.toIso8601String(),
    'gender': gender,
    'birthTime': birthTimeUnknown ? null : birthTime?.toIso8601String(),
    'birthTimeUnknown': birthTimeUnknown,
    'isLunar': isLunar,
  };

  factory FortuneInputModel.fromJson(Map<String, dynamic> json) {
    return FortuneInputModel(
      name: json['name'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      gender: json['gender'] as String,
      birthTime: json['birthTime'] != null
          ? DateTime.parse(json['birthTime'] as String)
          : null,
      birthTimeUnknown: json['birthTimeUnknown'] as bool? ?? false,
      isLunar: json['isLunar'] as bool? ?? false,
    );
  }
}
