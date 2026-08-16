/// [정통사주 69종 개인화 해석 엔진 — A01/A03 검증 TEST1] 결정론 검증.
///
/// 사용자 지시 §2: "동일 입력을 최소 10회 반복. 동일생년월일시→PHASE1~4→
/// SajuProfile→Analyzer→NarrativeGenerator 파이프라인에서 analysis JSON/
/// evidence/interpretation/headline/summary/sections/timing/advice 모두
/// 동일해야 한다. headline만 같은 것은 불충분."
///
/// [현재 구현 범위] NarrativeGenerator 구현체(headline/summary/advice 등
/// 완성 문장을 만드는 단계)는 아직 없다(추상 인터페이스만 존재). 따라서
/// 이 테스트는 "SajuProfile 생성 → CategoryAnalysis(JSON)" 구간, 즉 현재
/// 실제로 존재하는 파이프라인 전체를 10회 반복해 완전동일성을 검증한다.
/// CategoryAnalysis.toJson()에는 coreEvidence/supportingEvidence/
/// interpretationContext/favorableConditions/cautionConditions/timing/
/// confidence 및 카테고리 고유 필드가 모두 포함되므로, 사용자가 나열한
/// "analysis JSON/evidence/timing" 요구는 이 범위에서 완전히 커버된다.
/// "headline/summary/advice"는 NarrativeGenerator 구현 이후 별도 테스트로
/// 추가되어야 한다(TodoWrite에 후속 작업으로 남긴다).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final wealthAnalyzer = const WealthAnalyzer();
  final refDate = DateTime.utc(2026, 8, 13);

  /// 동일 입력을 [times]회 반복해서 PHASE1~4 → SajuProfile → Analyzer
  /// 전체 파이프라인을 새로 태우고, 매번 나온 결과가 완전히 동일한지
  /// 확인한다. (하나의 profile 객체를 재사용하는 게 아니라, 매번 처음부터
  /// 다시 계산해야 "결정론"을 제대로 검증한 것이 된다.)
  void checkDeterminism(String label, JeontongInput input, {int times = 10}) {
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));

    final lifeJsons = <String>[];
    final wealthJsons = <String>[];
    final profileSnapshots = <String>[];

    for (var i = 0; i < times; i++) {
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final p = built.profile;
      // PHASE1~4 계산값 자체가 매 회 동일한지도 함께 확인(§ "PHASE1~4
      // 계산값 불변" — 여기서는 "매번 재계산해도 같은 값"이라는 결정론
      // 관점의 불변성을 검증한다. "값 자체를 바꾸지 않았다"는 것은 코드
      // 리뷰(§8 회귀테스트)에서 별도 확인).
      profileSnapshots.add(
        '${p.dayPillar.stemHanja}${p.dayPillar.branchHanja}|'
        '${p.strength?.verdict}|${p.strength?.score}|'
        '${p.yongsin?.yongsin}|${p.yongsin?.gisin}|'
        '${p.fiveElements?.dominant}|${p.fiveElements?.deficient}',
      );

      final lifeAnalysis = lifeAnalyzer.analyze(p, referenceDate: refDate);
      final wealthAnalysis = wealthAnalyzer.analyze(p, referenceDate: refDate);
      lifeJsons.add(lifeAnalysis.toJson().toString());
      wealthJsons.add(wealthAnalysis.toJson().toString());
    }

    expect(profileSnapshots.toSet().length, equals(1),
        reason: '[$label] PHASE1~4 재계산 결과 자체가 매회 달라짐(결정론 위반)');
    expect(lifeJsons.toSet().length, equals(1),
        reason: '[$label] A01 CategoryAnalysis.toJson()이 $times회 중 서로 다름');
    expect(wealthJsons.toSet().length, equals(1),
        reason: '[$label] A03 CategoryAnalysis.toJson()이 $times회 중 서로 다름');
  }

  group('TEST1 결정론 — seed 3명(골든 픽스처)', () {
    for (final input in kJeontongTestInputs) {
      test('${input.userId}: 10회 반복 결과가 완전히 동일하다', () {
        checkDeterminism(input.userId, input);
      });
    }
  });

  group('TEST1 결정론 — 120명 표본 중 대표 5명(전체 실행 시간 고려)', () {
    // 120명 전원 × 10회 = 1200회 계산은 무겁다. 신강/신약/중화가 섞이도록
    // 대표 5명(인덱스 0/24/59/89/119)만 뽑아 10회씩 반복 검증한다.
    final sampleIndices = [0, 24, 59, 89, 119];
    for (final idx in sampleIndices) {
      final input = kJeontongSample120[idx];
      test('${input.userId}(idx=$idx): 10회 반복 결과가 완전히 동일하다', () {
        checkDeterminism(input.userId, input);
      });
    }
  });
}
