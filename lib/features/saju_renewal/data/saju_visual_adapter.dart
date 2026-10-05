import '../../home/domain/manseryeok/manseryeok_core_engine.dart';
import '../../home/domain/manseryeok/manseryeok_policy.dart';
import '../../home/domain/manseryeok/phase2_analysis_engine.dart';
import '../../home/domain/manseryeok/phase3_analysis_engine.dart';
import '../../home/domain/manseryeok/phase4_analysis_engine.dart';
import '../../home/domain/manseryeok/saju_profile.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프 시각화 어댑터]
///
/// 02(출생정보 입력 프리뷰)·03(분석중 세레모니)·04(분석완료) 화면이 보여주는
/// "원국/오행/음양균형/대운" 시각화는 실제 사용자의 생년월일로 계산된 값을
/// 써야 한다(기획 원칙 — 가짜 데모 사주를 보여주지 않음). 이미 검증된
/// `home/domain/manseryeok/*` 엔진(PHASE1~4)을 그대로 호출하고, 그 결과를
/// 디자인 핸드오프 컴포넌트(PillarGrid/ElementBars/BalanceGauge/LuckStream)가
/// 요구하는 단순 시각화 모델로 변환하기만 한다 — 계산 로직은 재구현하지
/// 않는다.

/// 화면 표시 순서: 0=時 1=日 2=月 3=年 (docs/11_API_계약서.md PillarIndex).
class SajuVisualPillar {
  const SajuVisualPillar({required this.stemHanja, required this.branchHanja});
  final String stemHanja;
  final String branchHanja;
}

class SajuVisualRelation {
  const SajuVisualRelation({
    required this.isHap,
    required this.columnA,
    required this.columnB,
  });
  final bool isHap;
  final int columnA; // 0..3, 화면 순서
  final int columnB;
}

class SajuVisualLuckEntry {
  const SajuVisualLuckEntry({
    required this.pillarHanja,
    required this.startYear,
  });
  final String pillarHanja;
  final int startYear;
}

/// 02/03/04 화면이 그리는 데 필요한 전체 시각화 모델.
class SajuVisualProfile {
  const SajuVisualProfile({
    required this.pillars,
    required this.elementsWeighted,
    required this.relations,
    required this.balanceLevel,
    required this.luck,
    required this.luckCurrentIndex,
    required this.timeUnknown,
  });

  /// 길이 4, 화면 순서(0=時 1=日 2=月 3=年). 시간 모름이면 [0]=null.
  final List<SajuVisualPillar?> pillars;

  /// 키: wood/fire/earth/metal/water (영문) — 상대값(≥0), 화면엔 크기로만.
  final Map<String, double> elementsWeighted;

  final List<SajuVisualRelation> relations;

  /// 5단 게이지(0~4).
  final int balanceLevel;

  /// 표시용 6개(현재 대운 중심으로 앞뒤 슬라이스).
  final List<SajuVisualLuckEntry> luck;
  final int luckCurrentIndex;

  final bool timeUnknown;
}

const Map<String, String> _koToEnElement = {
  '목': 'wood',
  '화': 'fire',
  '토': 'earth',
  '금': 'metal',
  '수': 'water',
};

int? _positionToColumn(String label) {
  if (label.startsWith('시')) return 0;
  if (label.startsWith('일')) return 1;
  if (label.startsWith('월')) return 2;
  if (label.startsWith('년')) return 3;
  return null;
}

class SajuVisualAdapter {
  SajuVisualAdapter._();

  /// [kst]는 이미 KST 벽시계 시각으로 정규화된 값(02 화면이 직접 호출할
  /// 때는 보통 보정 불필요 — 02/03은 국내 출생만 다룬다). [timeUnknown]이면
  /// hour=0으로 임시 계산하되 결과 시주는 화면에서 숨긴다(noHour).
  static SajuVisualProfile build({
    required DateTime kst,
    required String gender,
    required bool isLunar,
    required bool timeUnknown,
    required DateTime referenceDate,
    bool isLeapMonth = false,
  }) {
    final withCore = ManseryeokCoreEngine.buildProfileWithCore(
      year: kst.year,
      month: kst.month,
      day: kst.day,
      hour: timeUnknown ? 0 : kst.hour,
      minute: timeUnknown ? 0 : kst.minute,
      gender: gender,
      calendarType: isLunar ? CalendarInputType.lunar : CalendarInputType.solar,
      isLeapMonth: isLunar ? isLeapMonth : false,
    );
    final p2 = Phase2AnalysisEngine.analyze(
      baseProfile: withCore.profile,
      core: withCore.core,
    );
    final p3 = Phase3AnalysisEngine.analyze(baseProfile: p2);
    final p4 = Phase4AnalysisEngine.analyze(
      baseProfile: p3,
      core: withCore.core,
      referenceDate: referenceDate,
    );
    return fromProfile(p4, timeUnknown: timeUnknown, referenceDate: referenceDate);
  }

  static SajuVisualProfile fromProfile(
    SajuProfile p, {
    required bool timeUnknown,
    required DateTime referenceDate,
  }) {
    // 화면 순서: 0=時 1=日 2=月 3=年.
    final pillars = <SajuVisualPillar?>[
      timeUnknown
          ? null
          : SajuVisualPillar(
              stemHanja: p.hourPillar.stemHanja,
              branchHanja: p.hourPillar.branchHanja,
            ),
      SajuVisualPillar(
        stemHanja: p.dayPillar.stemHanja,
        branchHanja: p.dayPillar.branchHanja,
      ),
      SajuVisualPillar(
        stemHanja: p.monthPillar.stemHanja,
        branchHanja: p.monthPillar.branchHanja,
      ),
      SajuVisualPillar(
        stemHanja: p.yearPillar.stemHanja,
        branchHanja: p.yearPillar.branchHanja,
      ),
    ];

    final elementsWeighted = <String, double>{
      'wood': 0,
      'fire': 0,
      'earth': 0,
      'metal': 0,
      'water': 0,
    };
    final totalCount = p.fiveElements?.totalCount;
    if (totalCount != null) {
      for (final entry in totalCount.entries) {
        final en = _koToEnElement[entry.key];
        if (en != null) {
          elementsWeighted[en] = entry.value.toDouble();
        }
      }
    }

    final relations = <SajuVisualRelation>[];
    for (final r in p.relationships ?? const <SajuRelationship>[]) {
      if (r.positions.length < 2) continue;
      final a = _positionToColumn(r.positions[0]);
      final b = _positionToColumn(r.positions[1]);
      if (a == null || b == null || a == b) continue;
      relations.add(
        SajuVisualRelation(isHap: r.type.contains('합'), columnA: a, columnB: b),
      );
    }

    // StrengthProfile.score(0.0~1.0) → 5단 게이지(docs/09 Q-05 미확정이므로
    // 균등 임계치로 매핑 — 수치 자체는 화면에 노출하지 않으므로 UX에 영향
    // 없는 안전한 보간).
    final score = p.strength?.score ?? 0.5;
    final balanceLevel = (score * 4).round().clamp(0, 4);

    final daewoon = p.daewoon ?? const <DaewoonEntry>[];
    final luckAll = daewoon
        .map(
          (d) => SajuVisualLuckEntry(
            pillarHanja: d.pillar.hanja,
            startYear: d.startYear,
          ),
        )
        .toList();

    // 현재 연도 기준 "지금" 대운 인덱스를 찾고, 화면 표시용 6개 창을 만든다
    // (현재 대운이 가운데쯔음 오도록 앞 2 + 현재 + 뒤 3 슬라이스).
    final nowYear = referenceDate.year;
    int currentIdx = 0;
    for (var i = 0; i < luckAll.length; i++) {
      if (luckAll[i].startYear <= nowYear) currentIdx = i;
    }
    var windowStart = currentIdx - 2;
    if (windowStart < 0) windowStart = 0;
    var windowEnd = windowStart + 6;
    if (windowEnd > luckAll.length) {
      windowEnd = luckAll.length;
      windowStart = (windowEnd - 6).clamp(0, windowEnd);
    }
    final luckWindow = luckAll.sublist(windowStart, windowEnd);
    final luckCurrentIndex = (currentIdx - windowStart).clamp(
      0,
      luckWindow.isEmpty ? 0 : luckWindow.length - 1,
    );

    return SajuVisualProfile(
      pillars: pillars,
      elementsWeighted: elementsWeighted,
      relations: relations,
      balanceLevel: balanceLevel,
      luck: luckWindow,
      luckCurrentIndex: luckCurrentIndex,
      timeUnknown: timeUnknown,
    );
  }
}
