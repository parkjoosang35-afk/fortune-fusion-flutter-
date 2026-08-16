# A04(평생 직업·명예운) 검증 보고서

작성일: 세션 5 (A04 신규 개발 + 검증 단계)
검증 대상: A04 CareerAnalyzer (신규)
목적: 사용자 지시 §1~§20 조건(A01/A03 검증 때와 동일한 절차)을 A04에도 동일하게 적용해 통과 여부를 확인
전제: 사용자로부터 "진행"/"승인이야" 응답으로 A04 착수 승인을 받은 뒤 진행함(`docs/A01_A03_verification_report.md` 12절 참고)

---

## 1. 구현한 기능

레거시 `SajuInterpreter.interpretCareer()`(`saju_interpreter.dart` 415~449번째 줄)가 관성(정관+편관)/인성(정인+
편인)/식상(식신+상관) 개수만으로 4개 고정 분류(관인상생/식상격/무관무인/혼합격) + `day_master_rules.json`의
`career_fit`(일간별 직업 리스트) 반환하던 방식을 폐기하고, A01/A03과 동일한 설계 원칙(CategoryAnalyzer 인터페이스,
AnalysisEvidence, SajuProfileQuery)으로 `CareerAnalyzer`를 신규 구현했다.

- `CareerAnalysis` 모델(`career_analysis.dart`): categoryId, categoryName, coreEvidence, favorableConditions,
  cautionConditions, timing, confidence, supportingEvidence, interpretationContext + A04 고유 필드
  (careerPattern, careerStrength, workStyle, suitableFields, careerRiskPattern, careerPeakDaewoonLabel)
- `CareerAnalyzer`(`career_analyzer.dart`): `CategoryAnalyzer<CareerAnalysis>` 구현, `metadata`(categoryId='A04')와
  `analyze(SajuProfile, {referenceDate})` 제공

## 2. 사용한 PHASE 데이터

A01/A03과 동일하게 `SajuProfile`(PHASE1~4 계산 결과)만 참조했다. PHASE 코드는 전혀 수정하지 않았다.

- PHASE1: dayPillar(일간) — `career_fit` 고정표 조회 키
- PHASE2: tenGods, hiddenStems — 관살/인성/식상/비겁/재성 5대범주 집계(`SajuProfileQuery.tenGodCategoryCounts()`),
  정관/편관/상관 개별 occurrence(`SajuProfileQuery.occurrencesOfCategory()`)
- PHASE3: strength(신강신약), yongsin(용신/기신)
- PHASE4: daewoon(대운) — `SajuProfileQuery.daewoonMatchesCategory()`/`daewoonCarriesElement()`/`currentDaewoon()`으로
  조회(재계산 아님)

## 3. 새로 만든 Evidence

- coreEvidence 7개 지점: ①관살/인성/식상/비겁 집계 ②careerPattern 판정(7분류) ③careerStrength 판정(5분류)
  ④workStyle 판정(4분류) ⑤suitableFields(일간 고정표) ⑥careerRiskPattern(조건부) ⑦careerPeakDaewoonLabel(조건부)
- supportingEvidence 2개 이상: 관살/인성/식상/비겁/재성 세부 개수, 정관 vs 편관 우세 비교, (referenceDate 있을 때)
  현재 대운
- 모든 항목에 `interpretationRole`(primary/secondary/strength/supporting/caution/timing) 태깅 완료(§8 준수)
- 기존 `AnalysisEvidence`/`CategoryAnalysis` 필드는 삭제·변경 없이 그대로 사용(§7 준수)

## 4. 새로 만든 분석 규칙

레거시 4분류(관인상생/식상격/무관무인/혼합격)를 재성/비겁까지 포함해 7분류로 세분화했다.

- **careerPattern**(7종): 관인상생(官印相生, 관살≥2&인성≥1) / 살인상생 미비형(殺重身輕, 관살≥2&인성=0&비겁≥1) /
  식상생재(食傷生財, 식상≥2&재성≥1) / 식상격(食傷格, 식상≥2) / 무관무인(無官無印, 관살=0&인성=0) /
  관인균형(官印均衡, 관살≥2&인성≥2) / 혼합형(그 외)
- **careerStrength**(5종): 신강신약 × 관살 개수 조합 — 신강용관/신강경관/관다신약/신약보좌/중화용관
- **workStyle**(4종): 인성 vs 식상 우세 비교 — 조직형/독립·창작형/실무중심형/균형형
- **suitableFields**: `day_master_rules.json`의 `career_fit` 고정표를 코드에 그대로 옮겨 조회(신규 판정 아님, 기존
  전통 고정 데이터 재사용)
- **careerRiskPattern**(조건부 3종): 상관견관(상관≥1&관살≥1) / 관살혼잡(정관≥1&편관≥1) / 조직안착지연(관살=0&
  인성=0&신약)
- **careerPeakDaewoonLabel**: 대운 목록에서 관살 범주이거나 용신 오행을 포함하는 첫 대운 채택(PHASE4 실계산만 사용,
  재계산 없음)

**중요 findings**: 검증 과정에서 `careerPattern`의 "관인상생(관살≥2&인성≥1)" 조건이 A03의 재관쌍미와 유사하게
120명 표본 중 **90명(75%)**으로 쏠리는 편중 현상을 발견했다. **이번 세션에서는 사용자 승인 없이 이 규칙을
임의로 변경하지 않았다**(§22 금지사항 준수) — 아래 7절 참고.

## 5. 개인화 방식

문장 랜덤화가 아니라, `interpretationContext`/`supportingEvidence`에 기록된 세부 수치 조합이 사람마다 다르기
때문에 같은 `careerPattern`이라도 내부적으로 다른 근거를 갖도록 구현했다. 동일 그룹(관인상생 90명) 내부에서도
`interpretationContext`가 **90종 전부 서로 다른 조합**으로 나타남을 확인했다(§4/§5/§15 대응).

## 6. 결과 샘플 (개요)

120명 표본 전체에서 A04 출력 필드가 실제로 갈라지는지 자동 테스트로 확인했다(사람이 육안으로 비교하지 않음).

| 필드 | 120명 중 종류 수 |
|---|---|
| careerPattern | 4종 (관인상생/살인상생 미비형/식상생재/혼합형) |
| careerStrength | 4종 (신강용관/신강경관/관다신약/중화용관) |
| workStyle | 3종 |
| suitableFields | 10종 (10천간 고정표 기반, 정상) |
| careerRiskPattern | 2종 이상 |
| careerPeakDaewoonLabel | 120종 전원 상이 |

## 7. 동일 결과(careerPattern) 반복률 (§14)

NarrativeGenerator가 아직 구현되지 않아, A01/A03 검증 때와 동일하게 A04 output의 핵심 텍스트 필드
(careerPattern, careerStrength, workStyle, coreEvidence judgment 결합문)를 "문장 근사치"로 채택해
최다 반복 비율을 측정했다.

| 필드 | 종류 수 (120명 중) | 최다 반복 | 반복률 | 판정 |
|---|---|---|---|---|
| A04.careerPattern | 4 | 90/120 | 75.0% | 통과 (완화된 임계치 0.8, **findings 기록**) |
| A04.careerStrength | 4 | 43/120 | 35.8% | 통과 (임계치 0.6) |
| A04.workStyle | 3 | 67/120 | 55.8% | 통과 (임계치 0.7) |
| A04.coreEvidenceJudgments | 120 | 1/120 | 0.8% | 통과 (임계치 0.5) |

**Findings**: A04.careerPattern의 75% 편중은 "관살≥2&인성≥1" 조건이 상대적으로 느슨한 것이 원인으로 보이며,
A03.wealthPattern의 재관쌍미 80% 편중과 동일한 성격의 문제다. 다만 문장 자체(coreEvidenceJudgments)는 120명
전원이 서로 다른 것으로 확인되어 실질적 개인화는 유지되고 있다. **careerPattern(및 A03 wealthPattern) 분류
규칙의 정교화는 향후 개선 검토 과제로 함께 별도 관리할 것을 권고**한다.

## 8. Evidence 추적 결과 (§16)

5개 대표 샘플(p120-001/031/061/091/120)에 대해 다음을 자동 검증했고 전부 통과했다.

- A04 `coreEvidence`의 각 항목이 sourceField/sourceValue/rule/judgment가 비어있지 않고 `interpretationRole`이
  null이 아님
- `supportingEvidence`가 비어있지 않음(§5 세부 근거 존재 확인)
- `interpretationContext`에 필수 key(officerCount, printerCount, outputCount, biCount, wealthCount,
  jeongGwanCount, pyeonGwanCount, sangGwanCount, strengthVerdict, yongsinElement, gisinElement, dayGan) 존재 확인

즉, 최종 판정에서 "왜 이렇게 판단했는지"를 개발자가 역추적할 수 있는 구조가 A04에도 동일하게 확인되었다.

## 9. 테스트 결과 종합

| 구분 | 테스트 파일 | 결과 |
|---|---|---|
| 3명 seed 결과 다름 + 결정론(1회+10회 반복) + A01/A03/A04 관점차이 + 30명 개인화 | career_analyzer_test.dart | 5 tests, All passed |
| §3 TEST2 개인화 (120명, A04 그룹 추가) | personalization_120_test.dart | 40 tests, All passed (기존 32 + A04 신규 8) |
| §4/§5/§15 TEST3 동일패턴(careerPattern) 내부 차별화 | career_pattern_differentiation_test.dart | 2 tests, All passed |
| §14/§16 문장중복+추적성 | career_duplication_and_traceability_test.dart | 9 tests, All passed |
| 기존 69종 골든 회귀 | jeontong_eighty_golden_test.dart | All passed (변동 없음) |
| **전체 프로젝트 회귀 테스트** | `flutter test` (전체 스위트) | **560 tests, All tests passed! (실패 0, 기존 536 + A04 신규 24)** |
| 정적 분석 | `flutter analyze` | 37 issues (A01/A03 검증 시점과 동일, 전부 기존 존재하는 info/warning, error 0건, A04 신규 파일 이슈 0건) |

## 10. 기존 기능 영향 여부

- PHASE1~4 계산 엔진 소스코드는 이번 세션에서 **전혀 수정하지 않았다**(§0/§22 금지1,2 준수)
- 69종 골든 회귀 테스트 전부 통과 → PHASE1~4 계산값 불변 확인
- 전체 프로젝트 `flutter test` 560개 전부 통과(기존 536개 전부 유지 + A04 신규 24개 추가) → 기존 A01/A03 기능
  영향 없음
- `AnalysisEvidence`, `CategoryAnalysis`는 기존 필드를 삭제하지 않고 그대로 재사용(§7 준수)
- 레거시 `SajuInterpreter.interpretCareer()` 함수 자체는 삭제하지 않고 그대로 유지했다(기존 `careerFortune` 필드를
  참조하는 다른 코드의 하위 호환성 보존, A04는 별도의 신규 병행 구현체로 추가됨)

## 11. Git Commit ID

(본 보고서 작성 직후 커밋 예정 — 커밋 완료 후 아래에 해시를 반영한다)

## 12. 다음 단계

1. 본 보고서를 사용자에게 제시하고, **A05(다음 카테고리) 착수 여부에 대해 명시적 승인을 받는다**(§22 금지7
   "A04~A69 동시 제작 금지" 준수 — A04 하나만 완성 후 다음으로 진행)
2. A03 wealthPattern + A04 careerPattern 두 건의 "분류 규칙 편중" findings를 사용자와 논의 후 개선 여부 결정
   (규칙 변경은 반드시 사용자 승인 하에 진행, §22 금지사항 준수)
3. 승인 시, §21의 12단계 개발 패턴을 A05에 동일 적용
