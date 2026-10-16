// [엔진 통합 지시문 STEP 3 §6] 교차검증 오케스트레이터 핵심 로직에 대한
// 6개 지정 테스트 케이스.
//
// 이 테스트는 네트워크/Repository/LLM을 전혀 호출하지 않는다 —
// [UnifiedFortuneProfile]을 직접 구성해 [CrossCheckEngine]/
// [CrossCheckRule] 순수 로직만 검증한다(결정론적 규칙 코드 자체의
// 정확성/안정성을 보장하는 것이 이 테스트의 목적).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/orchestrator/cross_check_engine.dart';
import 'package:flutter_app/core/orchestrator/cross_check_rule.dart';
import 'package:flutter_app/core/orchestrator/cross_check_rules.dart';
import 'package:flutter_app/core/orchestrator/unified_fortune_profile.dart';
import 'package:flutter_app/features/compatibility/domain/compatibility_model.dart';
import 'package:flutter_app/features/fortune/face/domain/face_model.dart';
import 'package:flutter_app/features/fortune/palm/domain/palm_model.dart';
import 'package:flutter_app/features/fortune/tarot/domain/tarot_model.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';

/// 테스트용 최소 [Pillar] 생성 헬퍼. 한자/한글 값은 테스트 가독성을 위한
/// 더미이며, 규칙 로직이 실제로 읽는 것은 [stemElement]/[branchElement]
/// 뿐이다.
Pillar _pillar({
  required String stemElement,
  required String branchElement,
  String stemHanja = '甲',
  String branchHanja = '子',
}) {
  return Pillar(
    stemHanja: stemHanja,
    branchHanja: branchHanja,
    stemKr: '갑',
    branchKr: '자',
    stemElement: stemElement,
    stemYinYang: '양',
    branchElement: branchElement,
    branchYinYang: '양',
    jiaZiIndex: 0,
  );
}

/// 테스트용 최소 [SajuProfile] 생성 헬퍼 — 8글자 자체는 교차검증 규칙이
/// 직접 읽지 않으므로(오행 카운트/관계/용신/세운만 읽음) 더미 8글자로
/// 고정하고, 필요한 분석 필드만 테스트별로 주입한다.
SajuProfile _sajuProfile({
  FiveElementsProfile? fiveElements,
  List<SajuRelationship>? relationships,
  YongsinProfile? yongsin,
  List<SewoonEntry>? sewoon,
}) {
  final dummyPillar = _pillar(stemElement: '목', branchElement: '목');
  return SajuProfile(
    engineVersion: 'test-v1',
    birthInfo: const BirthInfo(
      calendarType: CalendarInputType.solar,
      year: 1990,
      month: 1,
      day: 1,
      hour: 12,
      minute: 0,
      isLeapMonth: false,
      gender: 'male',
    ),
    solarDate: '1990-01-01 12:00',
    lunarDate: '1989-12-05',
    lunarLeapMonth: false,
    utcOffsetMinutes: kstUtcOffsetMinutes,
    ziHourPolicy: ZiHourPolicy.lateZiSameDay,
    daewoonStartPrecision: DaewoonStartPrecision.traditionalApprox,
    yearPillar: dummyPillar,
    monthPillar: dummyPillar,
    dayPillar: dummyPillar,
    hourPillar: dummyPillar,
    fiveElements: fiveElements,
    relationships: relationships,
    yongsin: yongsin,
    sewoon: sewoon,
  );
}

FiveElementsProfile _fiveElements(Map<String, int> totalCount) {
  return FiveElementsProfile(
    stemCount: const {},
    branchCount: const {},
    hiddenStemCount: const {},
    totalCount: totalCount,
    dominant: const [],
    deficient: const [],
    isImbalanced: false,
  );
}

FaceResultModel _face(String text) {
  return FaceResultModel(
    id: 'face_1',
    features: {'이마': text},
    topicResults: const {'종합': ''},
    summary: text,
    createdAt: DateTime(2024, 1, 1),
  );
}

PalmResultModel _palm(String text) {
  return PalmResultModel(
    id: 'palm_1',
    lines: {'생명선': text},
    topicResults: const {'종합': ''},
    summary: text,
    createdAt: DateTime(2024, 1, 1),
  );
}

CompatibilityResultModel _compat(int score) {
  return CompatibilityResultModel(
    id: 'compat_1',
    nameA: '철수',
    nameB: '영희',
    type: 'love',
    score: score,
    topicResults: const {'애정': ''},
    summary: '',
    createdAt: DateTime(2024, 1, 1),
  );
}

TarotResultModel _tarot(String summary) {
  return TarotResultModel(
    id: 'tarot_1',
    question: '테스트 질문',
    spreadType: 'one_card',
    positions: const [],
    summary: summary,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('CrossCheckEngine — STEP 3 §6 지정 테스트 케이스', () {
    // ── 테스트 1: 일부 엔진만 유효해도 동작(partial-engine validity) ──
    test(
      '1) 사주+관상만 채워져 있어도 해당 규칙은 정상 판정되고, '
      '데이터 없는 다른 규칙들은 미판정으로 분리된다',
      () {
        final profile = UnifiedFortuneProfile(
          sajuProfile: _sajuProfile(
            fiveElements: _fiveElements({
              '목': 3,
              '화': 3,
              '토': 1,
              '금': 1,
              '수': 0,
            }),
          ),
          faceResult: _face('추진력 있고 열정적인 인상입니다'),
          // 손금/궁합/타로 결과는 의도적으로 비움(아직 이용 안 함).
        );

        final outcome = CrossCheckEngine.evaluateAll(
          defaultCrossCheckRules,
          profile,
        );

        // 사주↔관상(추진력) 규칙 1건은 정상 판정되어야 한다.
        expect(
          outcome.judged.any((r) => r.ruleId == 'saju_face_drive_v1'),
          isTrue,
          reason: '사주+관상 데이터가 모두 있으므로 이 규칙은 반드시 판정되어야 함',
        );

        // 나머지 3개 규칙(사주↔손금/사주↔궁합/타로↔사주)은 미판정이어야 한다.
        expect(outcome.unjudged.length, 3);
        expect(
          outcome.unjudged.map((u) => u.ruleId).toSet(),
          {
            'saju_palm_temperament_v1',
            'saju_compatibility_relation_v1',
            'tarot_saju_timing_v1',
          },
        );
      },
    );

    // ── 테스트 2: 미판정 누락 쌍(unjudged missing pairs) ──
    test(
      '2) 아무 문도 채워지지 않은 프로필은 4개 규칙 전부가 미판정이며, '
      '각 UnjudgedRule은 어느 문이 없어서 못 정했는지(missingDoor)를 '
      '정확히 보고한다',
      () {
        const emptyProfile = UnifiedFortuneProfile();

        final outcome = CrossCheckEngine.evaluateAll(
          defaultCrossCheckRules,
          emptyProfile,
        );

        expect(outcome.judged, isEmpty);
        expect(outcome.unjudged.length, defaultCrossCheckRules.length);

        // 사주↔관상 규칙의 경우: extractA(사주)가 먼저 null이므로
        // missingDoor는 '사주'로 보고되어야 한다(둘 다 없을 때는 doorA가
        // 우선 보고된다는 evaluateRule의 결정론적 규약).
        final driveRule = outcome.unjudged.firstWhere(
          (u) => u.ruleId == 'saju_face_drive_v1',
        );
        expect(driveRule.missingDoor, '사주');
        expect(driveRule.pair, '사주↔관상');
        expect(driveRule.axis, '추진력');
      },
    );

    // ── 테스트 3: 사주+관상 판정+근거(saju+face verdict+evidence) ──
    test(
      '3) 사주(목화 과다)+관상(추진력 키워드 풍부) 조합은 match로 판정되고, '
      '두 쪽 근거 텍스트가 모두 채워진다',
      () {
        final profile = UnifiedFortuneProfile(
          sajuProfile: _sajuProfile(
            // 8글자 중 목+화 8개/8개 → score = +1.0 (극단적 추진력 성향).
            fiveElements: _fiveElements({
              '목': 4,
              '화': 4,
              '토': 0,
              '금': 0,
              '수': 0,
            }),
          ),
          faceResult: _face('매우 적극적이고 열정적이며 진취적인 추진력이 느껴집니다'),
        );

        final result =
            CrossCheckEngine.evaluateRule(const SajuFaceDriveRule(), profile)
                as CrossCheckResult;

        expect(result.ruleId, 'saju_face_drive_v1');
        expect(result.scoreA, 1.0);
        // 관상 쪽: positive 4개 중 maxHits=3로 포화 → +1.0.
        expect(result.scoreB, 1.0);
        expect(result.delta, 0.0);
        expect(result.verdict, CrossCheckVerdict.match);
        expect(result.evidence, hasLength(2));
        expect(result.evidence[0], isNotEmpty);
        expect(result.evidence[1], isNotEmpty);
        expect(result.sources, ['사주', '관상']);
      },
    );

    // ── 테스트 4: 역방향 상충(reverse-direction conflict) ──
    test(
      '4) 사주(토금 과다=추진력 극저)와 관상(추진력 키워드 과다)처럼 '
      '정반대 방향 점수는 conflict로 판정되며, '
      '두 점수의 부호를 바꿔도(역방향) 동일하게 conflict가 유지된다',
      () {
        // 방향 A: 사주 낮음(-1.0) / 관상 높음(+1.0).
        final profileA = UnifiedFortuneProfile(
          sajuProfile: _sajuProfile(
            fiveElements: _fiveElements({
              '목': 0,
              '화': 0,
              '토': 4,
              '금': 4,
              '수': 0,
            }),
          ),
          faceResult: _face('매우 적극적이고 열정적이며 진취적인 추진력'),
        );
        final resultA =
            CrossCheckEngine.evaluateRule(const SajuFaceDriveRule(), profileA)
                as CrossCheckResult;
        expect(resultA.scoreA, -1.0);
        expect(resultA.scoreB, 1.0);
        expect(resultA.verdict, CrossCheckVerdict.conflict);

        // 방향 B(역방향): 사주 높음(+1.0) / 관상 낮음(-1.0).
        final profileB = UnifiedFortuneProfile(
          sajuProfile: _sajuProfile(
            fiveElements: _fiveElements({
              '목': 4,
              '화': 4,
              '토': 0,
              '금': 0,
              '수': 0,
            }),
          ),
          faceResult: _face('매우 소극적이고 신중하며 내성적이고 위축된 인상'),
        );
        final resultB =
            CrossCheckEngine.evaluateRule(const SajuFaceDriveRule(), profileB)
                as CrossCheckResult;
        expect(resultB.scoreA, 1.0);
        expect(resultB.scoreB, -1.0);
        expect(resultB.verdict, CrossCheckVerdict.conflict);

        // 두 delta는 동일(대칭) — 방향이 바뀌어도 판정 로직은 절댓값만
        // 보므로 conflict라는 결론 자체는 역전되지 않는다.
        expect(resultA.delta, resultB.delta);
      },
    );

    // ── 테스트 5: 결정론성(same input → same verdict) ──
    test(
      '5) 동일한 프로필로 여러 번 평가해도 항상 동일한 verdict/점수를 '
      '반환한다(LLM 호출 없는 순수 함수 — 비결정성이 없어야 함)',
      () {
        final profile = UnifiedFortuneProfile(
          sajuProfile: _sajuProfile(
            fiveElements: _fiveElements({
              '목': 2,
              '화': 1,
              '토': 2,
              '금': 2,
              '수': 1,
            }),
            relationships: const [
              SajuRelationship(
                type: '육합',
                characters: ['子', '丑'],
                positions: ['년지', '월지'],
                resultElement: '토',
              ),
              SajuRelationship(
                type: '지지충',
                characters: ['子', '午'],
                positions: ['년지', '일지'],
                resultElement: '',
              ),
            ],
          ),
          compatibilityResult: _compat(72),
        );

        final run1 = CrossCheckEngine.evaluateAll(
          defaultCrossCheckRules,
          profile,
        );
        final run2 = CrossCheckEngine.evaluateAll(
          defaultCrossCheckRules,
          profile,
        );

        expect(run1.judged.length, run2.judged.length);
        for (var i = 0; i < run1.judged.length; i++) {
          final a = run1.judged[i];
          final b = run2.judged[i];
          expect(a.ruleId, b.ruleId);
          expect(a.verdict, b.verdict);
          expect(a.scoreA, b.scoreA);
          expect(a.scoreB, b.scoreB);
          expect(a.delta, b.delta);
          expect(a.evidence, b.evidence);
        }
        expect(
          run1.unjudged.map((u) => u.ruleId).toList(),
          run2.unjudged.map((u) => u.ruleId).toList(),
        );
      },
    );

    // ── 테스트 6: 판정 JSON 구조에 verdict+evidence 포함 확인 ──
    test(
      '6) CrossCheckResult.toJson()은 지시문이 요구한 정확한 스키마'
      '(ruleId/pair/axis/verdict/scoreA/scoreB/delta/evidence/sources)를 '
      '모두 포함하고, verdict는 문자열(enum.name)로 직렬화된다',
      () {
        final profile = UnifiedFortuneProfile(
          tarotResult: _tarot('지금이 좋은 때이니 적극적으로 추진하세요'),
          sajuProfile: _sajuProfile(
            yongsin: const YongsinProfile(
              method: '억부',
              yongsin: '화',
              heesin: '목',
              gisin: '수',
              gusin: '금',
              reasoning: '테스트용 더미 근거',
            ),
            sewoon: [
              SewoonEntry(
                year: DateTime.now().year,
                pillar: _pillar(stemElement: '화', branchElement: '화'),
                tenGodStem: '비견',
                tenGodBranch: '비견',
              ),
            ],
          ),
        );

        final result =
            CrossCheckEngine.evaluateRule(const TarotSajuTimingRule(), profile)
                as CrossCheckResult;
        final json = result.toJson();

        expect(
          json.keys.toSet(),
          {
            'ruleId',
            'pair',
            'axis',
            'verdict',
            'scoreA',
            'scoreB',
            'delta',
            'evidence',
            'sources',
          },
        );
        expect(json['verdict'], isA<String>());
        expect(json['verdict'], result.verdict.name);
        expect(json['evidence'], isA<List>());
        expect((json['evidence'] as List), isNotEmpty);
        // 올해 세운 천간/지지가 모두 용신(화)과 일치 → scoreA는 양(+)의
        // 타이밍 긍정 신호여야 함(지금이 좋은 때라는 타로 해석과 부합).
        expect(json['scoreB'], greaterThan(0));
      },
    );
  });

  group('CrossCheckEngine — 보조 규칙 커버리지(사주↔손금)', () {
    test(
      '사주(토금 우세=안정 성향)+손금(안정/신중 키워드)은 match로 판정된다',
      () {
        final profile = UnifiedFortuneProfile(
          sajuProfile: _sajuProfile(
            fiveElements: _fiveElements({
              '목': 0,
              '화': 0,
              '토': 4,
              '금': 4,
              '수': 0,
            }),
          ),
          palmResult: _palm('매우 안정적이고 신중하며 현실적이고 차분한 성향입니다'),
        );

        final result =
            CrossCheckEngine.evaluateRule(
                  const SajuPalmTemperamentRule(),
                  profile,
                )
                as CrossCheckResult;

        expect(result.ruleId, 'saju_palm_temperament_v1');
        expect(result.scoreA, 1.0);
        expect(result.scoreB, 1.0);
        expect(result.verdict, CrossCheckVerdict.match);
      },
    );
  });

  group('keywordBalanceScore 공용 헬퍼', () {
    test('양/음 키워드가 없으면 0.0을 반환한다(중립)', () {
      final score = keywordBalanceScore(
        text: '관련 없는 아무 텍스트',
        positiveKeywords: const ['추진력'],
        negativeKeywords: const ['소극'],
      );
      expect(score, 0.0);
    });

    test('maxHits를 넘는 긍정 키워드는 +1.0으로 포화된다', () {
      final score = keywordBalanceScore(
        text: '추진력 적극 열정 도전 활발 진취',
        positiveKeywords: const ['추진력', '적극', '열정', '도전', '활발', '진취'],
        negativeKeywords: const [],
        maxHits: 3,
      );
      expect(score, 1.0);
    });
  });
}
