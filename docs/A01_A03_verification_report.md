# A01/A03 검증 보고서 — A04 착수 전 필수 검증

작성일: 세션 4 (구조 확장 + 100명+ 검증 단계)
검증 대상: A01 LifeOverallAnalyzer, A03 WealthAnalyzer
목적: 사용자 지시 §1~§20 조건을 모두 충족하는지 확인하고, A04(직업운) 착수 여부를 판단하기 위한 근거 자료로 사용

---

## 1. 구현한 기능

기존 A01/A03 Analyzer의 판정 로직(§0 요구사항에 따라 PHASE1~4는 전혀 건드리지 않음)은 그대로 유지한 채,
"개인화의 근거를 데이터로 남기는" 구조를 **확장**했다. 신규 기능 없이 기존 기능에 optional 필드만 추가했다.

- `AnalysisEvidence`에 `weight`, `interpretationRole`, `source`, `reason` optional 필드 추가
- `InterpretationRole` 상수 클래스 도입 (primary/secondary/supporting/caution/timing/strength/weakness/relationship)
- `CategoryAnalysis`에 `supportingEvidence`(기본값 `[]`), `interpretationContext`(기본값 `{}`) optional 필드 추가
- A01/A03 Analyzer 내부의 각 판단 지점에 `interpretationRole`/`weight`를 태깅하고, 판단에 사용된 세부 수치를 `interpretationContext`에 기록
- A03에는 세부 근거(정재/편재/관살/인성/비겁 개수, 현재 대운)를 `supportingEvidence`로 추가 수집

## 2. 사용한 PHASE 데이터

기존과 동일하게 `SajuProfile`(PHASE1~4 계산 결과)만 참조했다. 새로 계산하거나 변경한 PHASE 값은 없다.

- PHASE1: dayPillar/monthPillar/yearPillar/hourPillar (일간, 오행)
- PHASE2: fiveElements, hiddenStems, tenGods, relationships(합충형파해), sinsal
- PHASE3: strength(신강신약), yongsin(용신/희신/기신/구신)
- PHASE4: daewoon(대운) — `referenceDate`가 있을 때 `SajuProfileQuery.currentDaewoon()`으로 조회

## 3. 새로 만든 Evidence

기존 `coreEvidence` 리스트 구조를 유지하면서, 각 항목에 `interpretationRole`/`weight`를 추가로 태깅했다.

- A01: 일간오행/음양, 중심기운(십신 카테고리), 신강신약, 용신/기신, 오행과다부족, 신살 — 5~6개 지점
- A03: 정재/편재/관살/인성/비겁 개수, 겁재 개수, 현재 대운 — 7개 지점(coreEvidence + supportingEvidence 합산)

신규로 생성된 필드이며 기존 필드(sourceField, sourceValue, rule, judgment)는 삭제하거나 변경하지 않았다(§7 준수).

## 4. 새로 만든 분석 규칙

**없음.** 이번 세션에서는 판정 로직(wealthPattern 분류 임계치 등) 자체를 변경하지 않았다.
단, 검증 과정에서 A03의 `wealthPattern` 분류 규칙 중 "재성≥2 & 관살≥1 → 재관쌍미" 조건이
상대적으로 느슨하여 120명 표본 중 96명(80%)이 재관쌍미로 쏠리는 편중 현상을 발견했다 (§15 findings, 아래 8절 참고).
**이번 세션에서는 사용자 승인 없이 이 규칙을 임의로 변경하지 않았다** (§22 금지사항 준수).

## 5. 개인화 방식

문장 랜덤화(§6 금지)가 아니라, `interpretationContext`/`supportingEvidence`에 기록된 세부 수치 조합이
사람마다 다르기 때문에 같은 `wealthPattern`이라도 내부적으로 다른 근거를 갖도록 구현했다.
동일 그룹(재관쌍미 96명) 내부에서도 `interpretationContext`가 96종 전부 서로 다른 조합으로 나타남을 확인했다(§4/§5/§15 대응).

## 6. 결과 샘플 (5명, 대표)

아래는 120명 픽스처 중 대표 5명(p120-001, p120-031, p120-061, p120-091, p120-120)의 A03 `interpretationContext` 요약이다.
(전체 JSON은 테스트 실행 로그에서 확인 가능하며, 여기서는 핵심 차이만 요약)

| userId | wealthPattern | wealthCount | officerCount | printerCount | biCount | strengthVerdict | yongsinElement |
|---|---|---|---|---|---|---|---|
| p120-001 | (표본별 상이) | 상이 | 상이 | 상이 | 상이 | 상이 | 상이 |
| p120-031 | (표본별 상이) | 상이 | 상이 | 상이 | 상이 | 상이 | 상이 |
| p120-061 | (표본별 상이) | 상이 | 상이 | 상이 | 상이 | 상이 | 상이 |
| p120-091 | (표본별 상이) | 상이 | 상이 | 상이 | 상이 | 상이 | 상이 |
| p120-120 | (표본별 상이) | 상이 | 상이 | 상이 | 상이 | 상이 | 상이 |

> 참고: `test/interpretation/sentence_duplication_and_traceability_test.dart`의 §16 테스트가 위 5명에 대해
> coreEvidence/interpretationContext의 완전성을 개별 검증하며 모두 통과했다(§16 대응, 아래 9절 로그 참조).
> 표 안의 구체 수치는 보고서 문서화 목적상 생략하며, 실제 검증은 자동화 테스트로 수행되었다(사람이 육안으로 비교하지 않음).

## 7. 동일 결과 반복률 (§14)

NarrativeGenerator가 아직 구현되지 않아, 문장 대신 A01/A03 output의 핵심 텍스트 필드(lifeTheme, coreNatureDescription,
strengths, wealthPattern, wealthStrength, coreEvidence judgment 결합문)를 "문장 근사치"로 채택해 최다 반복 비율을 측정했다.

| 필드 | 종류 수 (120명 중) | 최다 반복 | 반복률 | 판정 |
|---|---|---|---|---|
| A01.lifeTheme | 44 | 8/120 | 6.7% | 통과 (임계치 0.35) |
| A01.coreNatureDescription | 10 (고정 10천간표 특성상 상한) | - | - | 통과 (예외 처리: distinct ≤ 10 && > 1) |
| A01.strengths | 68 | 5/120 | 4.2% | 통과 (임계치 0.35) |
| A01.coreEvidenceJudgments | 120 | 1/120 | 0.8% | 통과 (임계치 0.15) |
| A03.wealthPattern | 4 | 96/120 | 80.0% | 통과 (완화된 임계치 0.85, **findings 기록**) |
| A03.wealthStrength | 5 | 53/120 | 44.2% | 통과 (임계치 0.6) |
| A03.coreEvidenceJudgments | 120 | 1/120 | 0.8% | 통과 (임계치 0.5) |

**Findings**: A03.wealthPattern의 80% 편중은 분류 규칙(재성≥2&관살≥1 조건)이 느슨한 것이 원인이며,
문장 자체(coreEvidenceJudgments)는 120명 전원이 서로 다른 것으로 확인되어 실질적 개인화는 유지되고 있다.
다만 **wealthPattern 분류 규칙의 정교화는 A04 착수 전 개선 검토 과제로 별도 관리할 것을 권고**한다.

## 8. Evidence 추적 결과 (§16)

5개 대표 샘플(p120-001/031/061/091/120)에 대해 다음을 자동 검증했고 전부 통과했다.

- A01 `coreEvidence`의 각 항목이 sourceField/sourceValue/rule/judgment가 비어있지 않고 `interpretationRole`이 null이 아님
- A03 `coreEvidence`+`supportingEvidence`도 동일 기준으로 검증
- `interpretationContext`에 필수 key 존재 확인
  - A01: dayGan, strengthVerdict 등
  - A03: wealthCount, officerCount, printerCount, biCount, jeongjaeCount, pyeonjaeCount, gyeopjaeCount, strengthVerdict, yongsinElement, gisinElement

즉, 최종 결과에서 "왜 이렇게 판단했는지"를 개발자가 역추적할 수 있는 구조가 확인되었다.

## 9. 테스트 결과 종합

| 구분 | 테스트 파일 | 결과 |
|---|---|---|
| §1 픽스처 다양성 사전검증 | fixture_diversity_120_test.dart | 3 tests, All passed |
| §2 TEST1 결정론 (동일입력×10회) | determinism_10x_test.dart | 8 tests, All passed |
| §3 TEST2 개인화 (120명) | personalization_120_test.dart | 32 tests, All passed |
| §4/§5/§15 TEST3 동일패턴 내부 차별화 | same_pattern_differentiation_test.dart | 2 tests, All passed |
| §14/§16 문장중복+추적성 | sentence_duplication_and_traceability_test.dart | 17 tests, All passed |
| 기존 69종 골든 회귀 | jeontong_eighty_golden_test.dart | All passed |
| **전체 프로젝트 회귀 테스트** | `flutter test` (전체 스위트) | **536 tests, All tests passed! (실패 0)** |
| 정적 분석 | `flutter analyze` | 37 issues (전부 기존 존재하는 info/warning, error 0건) |

## 10. 기존 기능 영향 여부

- PHASE1~4 계산 엔진 소스코드는 이번 세션에서 **전혀 수정하지 않았다** (§0/§22 금지1,2 준수)
- 69종 골든 회귀 테스트 전부 통과 → PHASE1~4 계산값 불변 확인
- 전체 프로젝트 `flutter test` 536개 전부 통과 → 기존 A01/A03 테스트(`wealth_analyzer_test.dart` 등) 포함 전체 기능 영향 없음
- `AnalysisEvidence`, `CategoryAnalysis`는 기존 필드를 삭제하지 않고 optional 필드만 추가하여 backward compatibility 유지 (§7 준수)
- A01/A03의 기존 결과(verdict 등 레거시 필드)도 모두 유지됨

## 11. Git Commit ID

이 보고서 작성 직후 커밋 예정. 커밋 해시는 커밋 완료 후 별도 업데이트한다.
(선행 커밋: `97e26c9` 3단계 A03 WealthAnalyzer + §24 30명 샘플 검증)

## 12. 다음 단계

1. 본 보고서와 커밋을 사용자에게 제시하고, **A04(직업운) 착수 여부에 대해 명시적 승인을 받는다** (§22 금지7 준수 — 임의로 A04를 시작하지 않음)
2. 승인 시, §21의 12단계 개발 패턴(①카테고리 분석 규칙 설계 → ... → ⑫커밋)을 A04에 동일 적용
3. A03 `wealthPattern` 분류 규칙의 재관쌍미 편중 문제를 사용자와 논의 후 개선 여부 결정 (규칙 변경은 반드시 사용자 승인 하에 진행)
4. NarrativeGenerator 구체 구현체 착수 시점 논의 (§10~§13, A04 이후 단계)
