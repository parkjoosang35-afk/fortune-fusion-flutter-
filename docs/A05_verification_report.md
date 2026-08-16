# A05(평생 건강운) 검증 보고서

작성일: 세션 6 (A05 신규 개발 + 검증 단계)
검증 대상: A05 HealthAnalyzer (신규)
목적: 사용자 지시 §1~§20 조건(A01/A03/A04 검증 때와 동일한 절차)을 A05에도 동일하게 적용해 통과 여부를 확인
전제: 직전 세션에서 사용자가 "2"(A03/A04 분류규칙 편중 문제는 별도 과제로 남기고 A05 먼저 진행)를 선택한 데 따라 착수함

---

## 1. 구현한 기능

레거시 `SajuInterpreter.interpretHealth()`(`saju_interpreter.dart` 486~511번째 줄)가 오행 카운트
(`fiveElementsCount`)만 단순 순회하며 "개수≥3이면 과다 경고, 개수=0이면 부재 경고" 문자열을 생성하고
신강신약/용신/신살/대운을 전혀 참조하지 않던 방식(`HealthInterpretation` 클래스 — coreOrgans/warnings/
recommendedFood 3개 필드만 반환)을 폐기하고, A01/A03/A04와 동일한 설계 원칙(CategoryAnalyzer 인터페이스,
AnalysisEvidence, SajuProfileQuery)으로 `HealthAnalyzer`를 신규 구현했다.

- `HealthAnalysis` 모델(`health_analysis.dart`): categoryId, categoryName, coreEvidence,
  favorableConditions, cautionConditions, timing, confidence, supportingEvidence, interpretationContext +
  A05 고유 필드(healthConstitutionPattern, healthVitality, vulnerableOrgans, healthRiskPattern,
  recommendedCare, healthCautionDaewoonLabel)
- `HealthAnalyzer`(`health_analyzer.dart`): `CategoryAnalyzer<HealthAnalysis>` 구현, `metadata`
  (categoryId='A05')와 `analyze(SajuProfile, {referenceDate})` 제공

## 2. 사용한 PHASE 데이터

A01/A03/A04와 동일하게 `SajuProfile`(PHASE1~4 계산 결과)만 참조했다. PHASE 코드는 전혀 수정하지 않았다.

- PHASE1: dayPillar(일간) — 부족 오행이 없을 때 보양 음식 조회 기준
- PHASE2: fiveElements(dominant/deficient/isImbalanced), sinsal(양인살/백호대살/육해살/겁살)
- PHASE3: strength(신강신약), yongsin(용신/기신)
- PHASE4: daewoon(대운) — `SajuProfileQuery.daewoonCarriesElement()`/`currentDaewoon()`으로 조회
  (재계산 아님)

## 3. 새로 만든 Evidence

- coreEvidence 최대 7개 지점: ①오행 과다/부족/편중 집계 ②healthConstitutionPattern 판정(7분류)
  ③healthVitality 판정(5분류) ④vulnerableOrgans(organ 고정표 매핑, 조건부) ⑤건강신살 발견(조건부)
  ⑥healthRiskPattern 종합(조건부) ⑦recommendedCare(food_good 고정표, 조건부) ⑧healthCautionDaewoonLabel
  (조건부, PHASE4 실계산)
- supportingEvidence 2개 이상 고정 + 조건부 2개: 과다 오행별 excess 세부증상, 부족 오행별 lack 세부증상,
  (referenceDate 있을 때) 현재 대운, (용신 있을 때) 용신 뿌리 여부
- 모든 항목에 `interpretationRole`(primary/strength/supporting/caution/timing) 태깅 완료(§8 준수)
- 기존 `AnalysisEvidence`/`CategoryAnalysis` 필드는 삭제·변경 없이 그대로 사용(§7 준수)

## 4. 새로 만든 분석 규칙

레거시의 오행별 개별 경고 나열 방식을 폐기하고, "오행 과다/부족 개수의 조합"을 하나의 체질 유형으로
종합 판정하는 방식으로 재설계했다.

- **healthConstitutionPattern**(7종): 과다≥2&부족≥2→복합편중형 / 과다≥2→다중과다형 / 과다=1&부족≥1→
  단일편중형 / 과다=1→단일과다형 / 부족≥2→복합결핍형 / 부족=1→단일결핍형 / 그외→오행균형형
- **healthVitality**(5종): 신강신약 × 오행편중 여부 조합 — 신강균형/신강편중/신약편중/신약보양/중화안정
- **vulnerableOrgans**: dominant+deficient 오행을 `five_elements_rules.json`의 organ 고정표에 매핑한
  합집합(신규 판정 아님, 기존 전통 고정 데이터 재사용 — A04의 `career_fit` 조회와 동일한 성격)
- **healthRiskPattern**(조건부 조합): 건강 관련 신살(양인살/백호대살/육해살/겁살, `sinsal_engine.dart`
  실계산 대조) + 기신 오행 개수≥2 + 오행 과다 여부를 종합해 리스크 문구를 조합
- **recommendedCare**: 부족 오행(우선) 또는 일간 오행 기준 `food_good` 고정표 조회
- **healthCautionDaewoonLabel**: 대운 목록에서 기신 오행을 포함하는 첫 대운 채택(PHASE4 실계산만 사용,
  재계산 없음)

**중요 findings(긍정적 결과)**: A03(재관쌍미 80%)/A04(관인상생 75%)와 달리, A05의
`healthConstitutionPattern` 최다 그룹(단일편중형)은 120명 표본 중 **54명(45.0%)**으로 상대적으로 훨씬
고르게 분포했다(전체 분포: 단일편중형 54, 단일과다형 23, 복합편중형 15, 오행균형형 14, 다중과다형 13,
단일결핍형 1 — 6종류 모두 등장). 오행 dominant/deficient 개수 조합이 재성/관성 카운트 기반 분류보다
자연히 더 다양하게 갈라지는 것으로 보인다.

## 5. 개인화 방식

문장 랜덤화가 아니라, `interpretationContext`/`supportingEvidence`에 기록된 세부 수치 조합이 사람마다
다르기 때문에 같은 `healthConstitutionPattern`이라도 내부적으로 다른 근거를 갖도록 구현했다. 동일 그룹
(단일편중형 54명) 내부에서도 `interpretationContext`와 `supportingEvidence` 모두 **54종 전부 서로 다른
조합**으로 나타남을 확인했다(§4/§5/§15 대응). 오행균형형(14명) 그룹에서도 세부 조성이 갈라짐을 확인했다.

## 6. 결과 샘플 (개요)

120명 표본 전체에서 A05 출력 필드가 실제로 갈라지는지 자동 테스트로 확인했다(사람이 육안으로 비교하지
않음).

| 필드 | 120명 중 종류 수 |
|---|---|
| healthConstitutionPattern | 6종 (복합편중형/다중과다형/단일편중형/단일과다형/복합결핍형/단일결핍형/오행균형형 중 6종 등장) |
| healthVitality | 5종 (신강균형/신강편중/신약편중/신약보양/중화안정) |
| vulnerableOrgans | 52종 (organ 고정표 조합 기반) |
| healthRiskPattern | 44종 이상 |
| recommendedCare | 5종 (5오행 고정표 기반, 정상 — 종류 수가 5를 넘으면 오류) |
| healthCautionDaewoonLabel | 54종 이상(대운 실계산 기반, 기신 없는 경우 공백 포함) |

## 7. 동일 결과(healthConstitutionPattern) 반복률 (§14)

NarrativeGenerator가 아직 구현되지 않아, A01/A03/A04 검증 때와 동일하게 A05 output의 핵심 텍스트 필드
(healthConstitutionPattern, healthVitality, vulnerableOrgans, coreEvidence judgment 결합문)를 "문장
근사치"로 채택해 최다 반복 비율을 측정했다.

| 필드 | 종류 수 (120명 중) | 최다 반복 | 반복률 | 판정 |
|---|---|---|---|---|
| A05.healthConstitutionPattern | 6 | 54/120 | 45.0% | 통과 (완화된 임계치 0.8, A03/A04보다 크게 개선된 수치) |
| A05.healthVitality | 5 | 54/120 | 45.0% | 통과 (임계치 0.6) |
| A05.vulnerableOrgans | 52 | 14/120 | 11.7% | 통과 (임계치 0.7) |
| A05.coreEvidenceJudgments | 120 | 1/120 | 0.8% | 통과 (임계치 0.5) |

**Findings**: A05.healthConstitutionPattern의 45% 반복률은 A03.wealthPattern(80%)·A04.careerPattern
(75%)에 비해 현저히 낮다. 이는 오행 과다/부족 개수 조합이라는 판정 축이 십신(재성/관성) 카운트 기반
판정 축보다 자연히 더 고르게 갈라지기 때문으로 추정된다. 문장 자체(coreEvidenceJudgments)는 120명
전원이 서로 다른 것으로 확인되어 개인화가 정상적으로 유지되고 있다. **A05는 별도의 규칙 편중 개선
과제 없이 현재 설계를 그대로 유지해도 무방하다고 판단된다.**

## 8. Evidence 추적 결과 (§16)

5개 대표 샘플(p120-001/031/061/091/120)에 대해 다음을 자동 검증했고 전부 통과했다.

- A05 `coreEvidence`의 각 항목이 sourceField/sourceValue/rule/judgment가 비어있지 않고
  `interpretationRole`이 null이 아님
- `supportingEvidence`가 비어있지 않음(§5 세부 근거 존재 확인)
- `interpretationContext`에 필수 key(dominantElements, deficientElements, isImbalanced,
  strengthVerdict, yongsinElement, yongsinRooted, gisinElement, gisinCount, foundHealthSinsal,
  careBaseElement, dayGan) 존재 확인

즉, 최종 판정에서 "왜 이렇게 판단했는지"를 개발자가 역추적할 수 있는 구조가 A05에도 동일하게
확인되었다.

## 9. 테스트 결과 종합

| 구분 | 테스트 파일 | 결과 |
|---|---|---|
| 3명 seed 결과 다름 + 결정론(1회+10회 반복) + A01/A03/A04/A05 관점차이 + 30명 개인화 | health_analyzer_test.dart | 5 tests, All passed |
| §3 TEST2 개인화 (120명, A05 그룹 추가) | personalization_120_test.dart | 48 tests, All passed (기존 40 + A05 신규 8) |
| §4/§5/§15 TEST3 동일패턴(healthConstitutionPattern) 내부 차별화 | health_pattern_differentiation_test.dart | 2 tests, All passed |
| §14/§16 문장중복+추적성 | health_duplication_and_traceability_test.dart | 9 tests, All passed |
| 기존 69종 골든 회귀 | jeontong_eighty_golden_test.dart | All passed (변동 없음) |
| **전체 프로젝트 회귀 테스트** | `flutter test` (전체 스위트) | **583 tests, 582 passed / 1 fail(무관 플레이키), A05 관련 실패 0건** |
| 정적 분석 | `flutter analyze` | 37 issues (A04 검증 시점과 동일, 전부 기존 존재하는 info/warning, error 0건, A05 신규 파일 이슈 0건) |

**전체 회귀 테스트 실패 1건에 대한 조사**: `jeontong_report_cache_bench_test.dart`의 "cache hit is at
least 2x faster than miss" 테스트가 실패했다. 이 테스트는 실행 시점의 시스템 부하에 따라 결과가 달라질
수 있는 **타이밍 기반 벤치마크 테스트**이며, A05 개발과는 무관한 기존 파일(최종 수정 커밋 `20dae03`,
C/D그룹 소카테고리 작업 당시)이다. 단독 재실행 시 3 tests 전부 통과함을 확인했다(플레이키 테스트,
A05로 인한 회귀 아님).

## 10. 기존 기능 영향 여부

- PHASE1~4 계산 엔진 소스코드는 이번 세션에서 **전혀 수정하지 않았다**(§0/§22 금지1,2 준수)
- 69종 골든 회귀 테스트 전부 통과 → PHASE1~4 계산값 불변 확인
- G03~G10(사주체질/건강 관련 레거시 vs 신규 비교), E08~E10 등 기존 회귀 테스트 전부 정상 → 기존
  A01/A03/A04 및 레거시 병행 구현체 영향 없음
- 전체 프로젝트 `flutter test` 583개 중 582개 통과(1건은 A05와 무관한 기존 타이밍 벤치마크 플레이키) →
  기존 기능 영향 없음
- `AnalysisEvidence`, `CategoryAnalysis`는 기존 필드를 삭제하지 않고 그대로 재사용(§7 준수)
- 레거시 `SajuInterpreter.interpretHealth()` 함수 자체는 삭제하지 않고 그대로 유지했다(기존
  `healthFortune` 필드를 참조하는 다른 코드의 하위 호환성 보존, A05는 별도의 신규 병행 구현체로
  추가됨)

## 11. Git Commit ID

(본 절은 커밋 완료 후 업데이트 예정)

## 12. 다음 단계

1. 본 보고서를 사용자에게 제시하고, **A06(다음 카테고리) 착수 여부에 대해 명시적 승인을 받는다**
   (§22 금지7 "A04~A69 동시 제작 금지" 준수 — A05 하나만 완성 후 다음으로 진행)
2. A03 wealthPattern + A04 careerPattern 두 건의 "분류 규칙 편중" findings는 여전히 별도 과제로
   보류 상태(사용자가 재논의를 요청할 때까지 액션 없음). A05는 편중 문제가 상대적으로 적어 별도
   개선 과제에서 제외한다.
3. 승인 시, §21의 12단계 개발 패턴을 A06(잠정: '평생 배우자·결혼운' — `jeontong_eighty_matrix.dart`
   A그룹 목록 재확인 필요)에 동일 적용
