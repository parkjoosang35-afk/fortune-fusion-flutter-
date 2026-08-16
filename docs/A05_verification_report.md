# A05(평생 건강운) 검증 보고서

작성일: 세션 6 (A05 신규 개발 + 검증 단계)
검증 대상: A05 HealthAnalyzer (신규)
목적: 사용자 지시 §1~§20 조건(A01/A03/A04 검증 때와 동일한 절차)을 A05에도 동일하게 적용해 통과 여부를 확인
전제: 사용자로부터 A04 완료 보고 시 "A05로 우선 진행"(A03/A04 편중 문제는 별도 과제로 유보) 지시를 받아 착수함
(`docs/A04_verification_report.md` 12절 참고)

---

## 1. 구현한 기능

레거시 `SajuInterpreter.interpretHealth()`(`saju_interpreter.dart` 486~511번째 줄)가 오행 개수
(`fiveElementsCount`)만 순회하며 개수≥3이면 "과다→장기계통 주의", 개수=0이면 "부재→장기계통 약함" 경고 문자열을
생성하고, 일간 오행 하나로 `organ`/`food_good`을 반환하던 방식(신강신약/용신/신살/대운을 전혀 사용하지 않음)을
폐기하고, A01/A03/A04와 동일한 설계 원칙(CategoryAnalyzer 인터페이스, AnalysisEvidence, SajuProfileQuery)으로
`HealthAnalyzer`를 신규 구현했다.

- `HealthAnalysis` 모델(`health_analysis.dart`): categoryId, categoryName, coreEvidence, favorableConditions,
  cautionConditions, timing, confidence, supportingEvidence, interpretationContext + A05 고유 필드
  (healthConstitutionPattern, healthVitality, vulnerableOrgans, healthRiskPattern, recommendedCare,
  healthCautionDaewoonLabel)
- `HealthAnalyzer`(`health_analyzer.dart`): `CategoryAnalyzer<HealthAnalysis>` 구현, `metadata`(categoryId='A05',
  disclaimers=[DisclaimerTag.medical] 전제)와 `analyze(SajuProfile, {referenceDate})` 제공

## 2. 사용한 PHASE 데이터

A01/A03/A04와 동일하게 `SajuProfile`(PHASE1~4 계산 결과)만 참조했다. PHASE 코드는 전혀 수정하지 않았다.

- PHASE1: dayGan(일간) — 부족 오행이 없을 때 `recommendedCare` 조회 키
- PHASE2: fiveElements(dominant/deficient/isImbalanced), sinsal(양인살/백호대살/육해살/겁살 존재 여부 —
  `sinsal_engine.dart`가 실제 계산하는 nameKr 값 그대로 사용, 가짜 신살명 생성 금지)
- PHASE3: strength(신강신약 verdict), yongsin(용신 뿌리 여부), gisin(기신 오행 및 개수 — `gisinCount()`)
- PHASE4: daewoon(대운) — `SajuProfileQuery.currentDaewoon()`/`daewoonCarriesElement()`로 기신 오행을 포함하는
  첫 대운을 조회(재계산 아님)

## 3. 새로 만든 Evidence

- coreEvidence 6개 지점: ①오행 dominant/deficient/isImbalanced ②healthConstitutionPattern 판정(7분류)
  ③healthVitality 판정(5분류) ④vulnerableOrgans(오행→장기 고정표 매핑) ⑤healthRiskPattern(신살+기신+과다
  종합 판정) ⑥healthCautionDaewoonLabel(조건부)
- supportingEvidence 다수: 과다/부족 오행별 excess/lack 세부 증상(§5 개인화 강화 핵심), 건강 관련 신살 원국
  실재 여부, 기신 오행 강도, 현재 대운/용신 뿌리 여부
- 모든 항목에 `interpretationRole`(primary/secondary/strength/weakness/supporting/caution/timing) 태깅
  완료(§8 준수)
- 기존 `AnalysisEvidence`/`CategoryAnalysis` 필드는 삭제·변경 없이 그대로 사용(§7 준수)

## 4. 새로 만든 분석 규칙

레거시의 "오행 1개 카운트 임계치(≥3/=0)만으로 문장 생성" 방식을 폐기하고, 오행 편중 구조 × 신강신약 ×
건강신살 × 기신 × 대운을 조합한 다층 규칙으로 재설계했다.

- **healthConstitutionPattern**(7종): 복합편중형(과다≥2&부족≥2) / 다중과다형(과다≥2) / 단일편중형(과다=1&
  부족≥1) / 단일과다형(과다=1) / 복합결핍형(부족≥2) / 단일결핍형(부족=1) / 오행균형형(그 외)
- **healthVitality**(5종): 신강균형(신강&비편중) / 신강편중(신강&편중) / 신약편중(신약&편중) / 신약보양(신약&
  비편중) / 중화안정(중화)
- **vulnerableOrgans**: dominant+deficient 오행을 `five_elements_rules.json`의 organ 고정표에 매핑한 합집합
  (신규 판정 아님, 기존 전통 고정 데이터 재사용)
- **healthRiskPattern**(조건부 다중): 건강 관련 신살(양인살/백호대살/육해살/겁살) 원국 실재 + 기신 오행 개수
  ≥2 + 오행 과다 3개 조건을 종합 판정(복수 사유 병기 가능)
- **recommendedCare**: 부족 오행(있으면 우선) 또는 일간 오행 기준 `food_good` 고정표 조회
- **healthCautionDaewoonLabel**: 대운 목록에서 기신 오행을 포함하는 첫 대운 채택(PHASE4 실계산만 사용, 재계산
  없음)

**중요 findings(긍정적)**: 검증 과정에서 `healthConstitutionPattern`의 최다 그룹(단일편중형)은 120명 표본 중
**54명(45.0%)**으로, A03.wealthPattern(재관쌍미 80%)이나 A04.careerPattern(관인상생 75%)에 비해 편중률이
현저히 낮은 것으로 확인되었다. 이는 오행 dominant/deficient 조합이 7분류로 비교적 고르게 갈라지는 구조 특성
때문으로 판단되며, A03/A04와 달리 별도의 규칙 개선 없이도 §14 완화 임계치를 안정적으로 충족했다.

## 5. 개인화 방식

문장 랜덤화가 아니라, `interpretationContext`/`supportingEvidence`에 기록된 세부 수치 조합(어떤 오행이
과다·부족인지, 신강신약 정도, 어떤 건강신살이 있는지, 기신 오행과 개수, 대운 시점)이 사람마다 다르기 때문에
같은 `healthConstitutionPattern`이라도 내부적으로 다른 근거를 갖도록 구현했다. 동일 그룹(단일편중형 54명)
내부에서도 `interpretationContext`와 `supportingEvidence`가 **54종 전부 서로 다른 조합**으로 나타남을
확인했다(§4/§5/§15 대응). 두 번째로 큰 그룹(오행균형형 14명)에서도 동일하게 세부 조성이 갈라짐을 확인했다.

## 6. 결과 샘플 (개요)

120명 표본 전체에서 A05 출력 필드가 실제로 갈라지는지 자동 테스트로 확인했다(사람이 육안으로 비교하지 않음).

| 필드 | 120명 중 종류 수 |
|---|---|
| healthConstitutionPattern | 6종 (단일편중형/단일과다형/복합편중형/오행균형형/다중과다형/단일결핍형) |
| healthVitality | 5종 (신강균형/신강편중/신약편중/신약보양/중화안정) |
| vulnerableOrgans | 52종 |
| healthRiskPattern | 44종 이상 |
| recommendedCare | 5종 (5오행 food_good 고정표 기반, 정상) |
| healthCautionDaewoonLabel | 120종 전원 상이 |

## 7. 동일 결과(healthConstitutionPattern) 반복률 (§14)

NarrativeGenerator가 아직 구현되지 않아, A01/A03/A04 검증 때와 동일하게 A05 output의 핵심 텍스트 필드
(healthConstitutionPattern, healthVitality, vulnerableOrgans, coreEvidence judgment 결합문)를 "문장 근사치"로
채택해 최다 반복 비율을 측정했다.

| 필드 | 종류 수 (120명 중) | 최다 반복 | 반복률 | 판정 |
|---|---|---|---|---|
| A05.healthConstitutionPattern | 6 | 54/120 | 45.0% | 통과 (임계치 0.8, A03/A04 대비 개선된 결과) |
| A05.healthVitality | 5 | 54/120 | 45.0% | 통과 (임계치 0.6) |
| A05.vulnerableOrgans | 52 | 14/120 | 11.7% | 통과 (임계치 0.7) |
| A05.coreEvidenceJudgments | 120 | 1/120 | 0.8% | 통과 (임계치 0.5) |

**Findings**: A05는 A03/A04에서 발견된 "분류 규칙 편중" 문제가 상대적으로 적다. `healthConstitutionPattern`
7분류가 과다/부족 오행 개수 조합(2×2 이상 경우의 수)에 기반해 A03/A04의 단일 조건(관살≥2 등)보다 세분화되어
있는 것이 원인으로 추정된다. 문장 자체(coreEvidenceJudgments)는 120명 전원이 서로 다른 것으로 확인되어
실질적 개인화는 A03/A04와 동일하게 유지되고 있다.

## 8. Evidence 추적 결과 (§16)

5개 대표 샘플(p120-001/031/061/091/120)에 대해 다음을 자동 검증했고 전부 통과했다.

- A05 `coreEvidence`의 각 항목이 sourceField/sourceValue/rule/judgment가 비어있지 않고 `interpretationRole`이
  null이 아님
- `supportingEvidence`가 비어있지 않음(§5 세부 근거 존재 확인)
- `interpretationContext`에 필수 key(dominantElements, deficientElements, isImbalanced, strengthVerdict,
  yongsinElement, yongsinRooted, gisinElement, gisinCount, foundHealthSinsal, careBaseElement, dayGan) 존재
  확인

즉, 최종 판정에서 "왜 이렇게 판단했는지"를 개발자가 역추적할 수 있는 구조가 A05에도 동일하게 확인되었다.

## 9. 테스트 결과 종합

| 구분 | 테스트 파일 | 결과 |
|---|---|---|
| 3명 seed 결과 다름 + 결정론(1회+10회 반복) + A01/A03/A04/A05 관점차이 + 30명 개인화 | health_analyzer_test.dart | 5 tests, All passed |
| §3 TEST2 개인화 (120명, A05 그룹 추가) | personalization_120_test.dart | 48 tests, All passed (기존 40 + A05 신규 8) |
| §4/§5/§15 TEST3 동일패턴(healthConstitutionPattern) 내부 차별화 | health_pattern_differentiation_test.dart | 2 tests, All passed |
| §14/§16 문장중복+추적성 | health_duplication_and_traceability_test.dart | 9 tests, All passed |
| 기존 69종 골든 회귀 | jeontong_eighty_golden_test.dart | All passed (변동 없음) |
| **전체 프로젝트 회귀 테스트** | `flutter test` (전체 스위트) | **584 tests, All tests passed! (실패 0, 기존 560 + A05 신규 24)** |
| 정적 분석 | `flutter analyze` | 37 issues (A04 검증 시점과 동일, 전부 기존 존재하는 info/warning, error 0건, A05 신규 파일 이슈 0건) |

## 10. 기존 기능 영향 여부

- PHASE1~4 계산 엔진 소스코드는 이번 세션에서 **전혀 수정하지 않았다**(§0/§22 금지1,2 준수)
- 69종 골든 회귀 테스트 전부 통과 → PHASE1~4 계산값 불변 확인
- 전체 프로젝트 `flutter test` 584개 전부 통과(기존 560개 전부 유지 + A05 신규 24개 추가) → 기존 A01/A03/A04
  기능 영향 없음
- `AnalysisEvidence`, `CategoryAnalysis`는 기존 필드를 삭제하지 않고 그대로 재사용(§7 준수)
- 레거시 `SajuInterpreter.interpretHealth()` 함수 자체는 삭제하지 않고 그대로 유지했다(기존 `HealthInterpretation`
  필드를 참조하는 다른 코드의 하위 호환성 보존, A05는 별도의 신규 병행 구현체로 추가됨)
- 건강 관련 신살(`_healthRiskSinsalNames` = {양인살, 백호대살, 육해살, 겁살})은 `sinsal_engine.dart`(전체 283줄)를
  직접 읽어 실제 계산 로직이 반환하는 nameKr 값과 정확히 일치함을 확인한 뒤 사용했다(가짜 근거 생성 금지 원칙
  준수)

## 11. Git Commit ID

`4f9178d` — feat(jeontong-interpretation): A05 평생 건강운 HealthAnalyzer 신규 구현 + 120명 검증 스위트 (§1~§20)
(선행 커밋: `382c470` docs A04 보고서 커밋ID반영, `a77b125` A04 신규 구현 + 검증 스위트)

## 12. 다음 단계

1. 본 보고서를 사용자에게 제시하고, **A06(다음 카테고리) 착수 여부에 대해 명시적 승인을 받는다**(§22 금지7
   "A04~A69 동시 제작 금지" 준수 — A05 하나만 완성 후 다음으로 진행)
2. A03 wealthPattern + A04 careerPattern 두 건의 "분류 규칙 편중" findings는 여전히 별도 과제로 유보 상태이며,
   사용자가 논의를 재개할 때 함께 검토한다(A05는 동일 문제가 상대적으로 적어 우선순위가 낮음)
3. 승인 시, §21의 12단계 개발 패턴을 A06에 동일 적용
