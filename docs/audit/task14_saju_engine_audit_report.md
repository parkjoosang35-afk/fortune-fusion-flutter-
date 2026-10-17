# 신통방통 정통사주 엔진 15개 실행·조합 추적 검수 보고서 (Task 14)

> 작성 원칙: 모든 서술은 실제 코드 Read/Bash 조회 결과만 근거로 한다. 추측·가정은
> 전부 "미확인"으로 명시한다. 기존 계산 로직·정책은 전혀 수정하지 않았다(read-only
> 검수 — 유일한 예외는 생성→실행→즉시삭제로 생명주기가 완결된 임시 테스트 파일
> `test/_audit_temp_engine_trace_test.dart` 1개뿐이며, 삭제 후 `git status --short test/`
> 로 원복을 확인했다).
>
> 고정 테스트케이스: **personA** = 1990-03-15 08:30(양력, 남), referenceDate=2024-01-01.
> 외부 라이브러리 `lunar_python`(sect=2)으로 교차검증된 값(庚午/己卯/己卯/戊辰)을
> 사용하며, `manseryeok_external_reference_audit_test.dart`·
> `saju_engine_to_screen_pipeline_test.dart` 양쪽에서 이미 공통으로 쓰이고 있는
> 기존 테스트 데이터다(개인정보 아님).

---

## 0. 가장 먼저 확정해야 할 사실 — "3개의 완전히 다른 사주 시스템"이 공존한다

이번 검수에서 가장 중요한 발견은, "신통방통 사주"라는 이름 아래 실제로는 **서로
전혀 다른 계산 로직을 쓰는 3개의 독립 시스템**이 코드베이스에 존재한다는 점이다.
이를 먼저 구분하지 않으면 "15개 엔진"이 무엇을 가리키는지조차 혼동된다.

| # | 시스템 | 계산 주체 | 현재 Flutter 앱에서 호출 여부 | 비고 |
|---|---|---|---|---|
| ① | **PHASE1~4 신규 만세력 엔진**(`lib/features/home/domain/manseryeok/`) | **Flutter/Dart 자체 계산**(순수 로컬, 서버 호출 없음) | ✅ **현재 운영 중** — 귀인지도/DoorEngineGateway/SajuVisualAdapter 3개 경로에서 실사용 | 이번 지시서 §2가 나열한 **15개 구성요소가 전부 여기 속함**. 본 보고서의 핵심 조사 대상. |
| ② | **레거시 AI사주**(`/ai-fortune/saju/*`, `lib/features/fortune/saju/`, admin_web `POST /api/public/fortune/saju`) | admin_web 서버의 `computeChart()`(**해시 기반 가짜 명식**, 실제 역학 계산 아님) → `buildSajuJudgment()`(판정) → LLM(해석) → `checkSajuResult()`(검증) → `renderSajuLlmResult()`(표현). 내부 5단계 상세는 §5-1 참고. | ❌ **완전 제거됨** — `lib/features/fortune/saju/` 디렉토리 자체가 Flutter 코드베이스에 더 이상 존재하지 않는다(`find` 결과 0건, `SajuRepository` 클래스도 0건). `app_router.dart`가 해당 라우트를 전부 `/saju-renewal`로 강제 리다이렉트 중. | `feature_flags.dart`의 "4단계 점진 전환" 계획 문서는 과거 계획이며, 실제로는 이미 코드 자체가 삭제된 상태(계획보다 앞서 실행됨). **"엔진 코드 존재 ≠ 실제 실행"의 역방향 사례** — 즉 서버(route.ts)엔 코드가 남아있지만 호출하는 클라이언트가 없어 사실상 죽은 엔드포인트. |
| ③ | **신통방통 정통사주 리뉴얼(topic 기반, "69종"이 아니라 "29종")**(admin_web `src/lib/saju-renewal/*`, Flutter `lib/features/saju_renewal/`) | **별도의 Python FastAPI 서버**(`saju_engine_v3.3`, `/saju/v3/facts`)가 사주원국을 계산 → admin_web이 그 결과를 "Fact"로 받아 29종 주제 중 후보를 스코어링 선정 → LLM이 해석 텍스트만 생성 | ✅ **현재 운영 중** — `SajuRenewalApi`(Flutter)가 `/api/public/saju-renewal/topics/select`와 `/api/public/saju-renewal/interpret`만 호출 | **①과 ③은 완전히 다른 계산 엔진**(①=Dart `ManseryeokCoreEngine`, ③=별도 Python 프로세스 `saju_engine_v3.3`)이며 서로 데이터를 주고받지 않는다. |

**"69종"이라는 사용자의 표현에 대한 정정(가장 중요한 정정 사항)**: 코드베이스
전수 검색(`grep -rn "69"`) 결과, "69종"은 **현재 운영되지 않는 레거시 체계**를
가리키는 용어였다.
- `admin_web/src/generated/prisma/.../schema.prisma`의 주석: `"신규 topic 기반 UX
  전용 — 기존 jeontong_eighty(69종)/saju_v3 베타와는 완전히 분리된 신규 영역
  (saju_renewal)"`
- `interpret-qa-check.ts` 주석: `"기존 saju-qa-check.ts와 분리하는 이유] 기존
  모듈은 레거시 69종 '7블록'..."`, 그리고 LLM 응답에 `"69종"`이라는 문자열이
  노출되면 QA 실패 처리하는 정규식(`/\b69\s*종/i`)까지 존재한다.
- 실제 Python 파일 `category69.py`는 `/home/user/saju_engine_deploy/
  saju_engine_v3.3_최종납품/saju_engine/category69.py`에 존재하지만, 이는
  **③번 시스템이 과거에 거쳤던 중간 설계안의 흔적**으로, 현재 admin_web이 실제로
  사용하는 주제 카탈로그는 `topic-catalog-data.ts`의 **`TOPIC_CATALOG_SEED`
  (정확히 29개, 코드 내 자체 검증 `if (length !== 29) throw`로 강제)**다.

즉, **"69종 운세 주제를 선정하고 LLM이 해석하는 과정"은 현재 코드 기준으로는
"29종 주제 선정 + LLM 해석"(③번 시스템, topic-engine.ts)**이며, 사용자가
지시서에서 쓴 "69종"이라는 숫자 자체가 이미 리뉴얼 이전 레거시 설계의 잔존
표현임을 이번 검수에서 명확히 확인했다. 이 보고서는 이후 "주제선정+LLM해석
과정"을 ③번 시스템(29종 topic-engine)으로 지칭한다.

**본 보고서 §1~§4(15개 구성요소 실행여부표/흐름도/추적보고서)는 전부 ①번
시스템만을 다룬다** — 이것이 사용자가 나열한 15개 클래스/함수 이름과 정확히
일치하는 유일한 시스템이기 때문이다. ②③번은 §5(로컬 vs 서버 구분)에서 별도로
다룬다.

---

## 1. 15개 구성요소 실행 여부표

범례: 실행여부 ①=실제 호출되어 계산함 / ②=다른 모듈을 실행·조정하는 역할(오케스트레이터) / ③=코드만 존재, 호출 안됨 / ④=확인 불가

| # | 구성요소 | 실제 파일 | 호출 상위 모듈 | 실행 순서 | 입력 데이터 | 내부 계산/처리 | 반환 결과 | 다음 모듈(결과 소비처) | 실행여부 | 테스트 근거 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `ManseryeokCoreEngine` | `manseryeok/manseryeok_core_engine.dart` | `JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4()` | 1단계(최초) | `BirthInfo`(연/월/일/시/분, 양/음력, 성별, 정책) | 만세력 계산(절기/60갑자 변환), 년주·월주·일주·시주 4개 `Pillar` 산출 | `SajuProfile`(pillars만 채워진 초기 상태) | Phase2AnalysisEngine | ① | personA 추적 로그: 庚午/己卯/己卯/戊辰 산출 확인(아래 §3) |
| 2 | `Phase2AnalysisEngine` | `manseryeok/phase2_analysis_engine.dart` | `JeontongReportBuilder` | 2단계 | 1단계 `SajuProfile`(pillars) | FiveElements→HiddenStems(2회: 일반+십신용)→TwelveStages→Relationships→Sinsal **5개 하위엔진을 순서대로 호출·조합**, `copyWith()`로 누적 | `SajuProfile`(fiveElements/hiddenStems/twelveStages/relationships/sinsal 채워짐) | Phase3AnalysisEngine | ②(오케스트레이터) | `phase2_analysis_engine_test.dart` 및 §3 추적로그 |
| 3 | `FiveElementsEngine` | `manseryeok/five_elements_engine.dart` | Phase2AnalysisEngine 내부 | 2-1 | 4개 Pillar(8글자) | 오행(목화토금수) 카운트, 과다(≥3)/부족(0개) 판정 | `FiveElementsProfile` | Phase2AnalysisEngine → (최종) StrengthEngine/YongsinEngine/CrossCheckRules/SajuResultAdapter | ① | personA: {목2,화1,토4,금1,수0}, dominant=[토] |
| 4 | `HiddenStemsEngine` | `manseryeok/hidden_stems_engine.dart` | Phase2AnalysisEngine 내부(2회 호출: 지장간 상세 + 십신 매핑용) | 2-2 | 4개 Pillar | 지지별 지장간 추출(1/2/3개 지지별 고정 가중치표), 일간 기준 십신(十神) 매핑 | `HiddenStemsProfile`(지장간 목록) + `tenGods`(7키 맵) | Phase3AnalysisEngine(tenGods 입력), SajuResultAdapter(tenGods 그대로 전달) — **hiddenStems 자체는 PHASE3 내부 입력으로만 소비되고 최종 SajuResult엔 미반영** | ① | personA: 일지(卯) 지장간=[乙 정기], tenGods 7키 산출 |
| 5 | `TwelveStagesEngine` | `manseryeok/twelve_stages_engine.dart` | Phase2AnalysisEngine 내부 | 2-3 | 4개 Pillar(일간 기준) | 12운성(장생~양) 산출 | `TwelveStagesProfile`(4주 각각) | **없음(계산 후 어디서도 읽히지 않음 — 미사용 확정)** | ①(계산은 됨, but 소비처 없음) | personA: {year:건록,month:병,day:병,hour:쇠} 산출되나 전수 grep 결과 소비 코드 0건 |
| 6 | `RelationshipsEngine` | `manseryeok/relationships_engine.dart` | Phase2AnalysisEngine 내부(1차) **+ SinsalEngine 내부(2차, 원진 추출용)** | 2-4 및 7-보조 | 4개 Pillar | 천간합/충, 육합/지지충/육해/육파/원진/귀문/상형/자형(2글자 성립) + 삼합/방합/삼형(3글자 완전성립만 기록) | `List<SajuRelationship>` | Phase2AnalysisEngine(최종 profile.relationships) → `cross_check_rules.dart`(SajuCompatibilityRelationRule), `saju_visual_adapter.dart`(화면 좌표 변환) | ①(**1회 입력당 2회 실행** — Phase2 1차 + SinsalEngine 내부 2차) | personA: 4건(해2/파2) |
| 7 | `SinsalEngine` | `manseryeok/sinsal_engine.dart` | Phase2AnalysisEngine 내부 | 2-5(마지막) | 4개 Pillar + (내부에서 RelationshipsEngine 재호출) | 레거시 3종+공망+12신살+양인살+괴강살+백호대살+원진 등 14종 이상 산출 | `List<SinsalEntry>` | `SajuResultAdapter`(레거시 3종만 필터링) + `guinji_saju_adapter.dart`(전체 그대로) | ① | personA: 14건(공망/12신살전체/백호대살) |
| 8 | `Phase3AnalysisEngine` | `manseryeok/phase3_analysis_engine.dart` | `JeontongReportBuilder` | 3단계 | 2단계 `SajuProfile`(fiveElements/hiddenStems/tenGods 필수 — null이면 StateError) | StrengthEngine→YongsinEngine 2개 하위엔진 순차 호출 | `SajuProfile`(strength/yongsin 채워짐) | Phase4AnalysisEngine | ②(오케스트레이터) | §3 추적로그 |
| 9 | `StrengthEngine` | `manseryeok/strength_engine.dart` | Phase3AnalysisEngine 내부 | 3-1 | fiveElements, tenGods, hiddenStems, dayGan | 억부법: 월령가중치 2배+통근/생조/극제/설기 점수화 → score≥0.6 신강/≤0.4 신약/중간 중화 | `StrengthProfile`(verdict/score 등) | YongsinEngine(입력), SajuResultAdapter, `saju_visual_adapter.dart`(balanceLevel) | ① | personA: verdict=중화, score=0.505 |
| 10 | `YongsinEngine` | `manseryeok/yongsin_engine.dart` | Phase3AnalysisEngine 내부 | 3-2 | strength, fiveElements, 월지 | byEokbu(억부법)와 byJohu(조후법, 간이) 독립 계산 후 combine()이 "조후 우선" 원칙으로 종합 | `YongsinProfile`(yongsin/heesin/gisin/gusin) | `cross_check_rules.dart`(TarotSajuTimingRule), **SajuResultAdapter는 이 필드를 전혀 읽지 않음**(미사용 확정) | ① | personA: method=억부+조후, yongsin=금 |
| 11 | `Phase4AnalysisEngine` | `manseryeok/phase4_analysis_engine.dart` | `JeontongReportBuilder` | 4단계(최종) | 3단계 `SajuProfile`(strength/yongsin 필수) | DaewoonEngine→SewoonEngine→WolwoonEngine 3개 하위엔진 순차 호출 | `SajuProfile`(daewoon/sewoon/wolwoon 채워짐) | `sajuResultFromProfile()`(어댑터) | ②(오케스트레이터) | §3 추적로그 |
| 12 | `DaewoonEngine` | `manseryeok/daewoon_engine.dart` | Phase4AnalysisEngine 내부 | 4-1 | 연주/월주/성별, referenceDate | lunar 패키지 `eightChar.getYun()`/`getDaYunBy()` 네이티브 API 호출(재구현 없음), count=9 기본값 | `List<DaewoonEntry>` | SajuResultAdapter(`_toLuckPillars`), `saju_visual_adapter.dart`(luck 윈도우) | ① | personA: 9건, #3 age28(2017) 壬午 |
| 13 | `SewoonEngine` | `manseryeok/sewoon_engine.dart` | Phase4AnalysisEngine 내부 | 4-2 | daewoon 결과, fromYear~toYear | `LiuNian(dy, idx).getGanZhi()` 호출(배선 역할) | `List<SewoonEntry>` | `cross_check_rules.dart`(TarotSajuTimingRule) | ① | personA: 2017~2026 10건 |
| 14 | `WolwoonEngine` | `manseryeok/wolwoon_engine.dart` | Phase4AnalysisEngine 내부 | 4-3(마지막) | 특정 연도 | `LiuNian.getLiuYue()`로 12개월 획득 + 절기이름 고정배열 매핑 | `List<WolwoonEntry>` | **없음(계산 후 어디서도 읽히지 않음 — 미사용 확정)** | ①(계산은 됨, but 소비처 없음) | personA: 2024년 12개월 산출되나 소비 코드 0건 |
| 15 | `SajuResultAdapter`(**클래스 아님 — 함수**) | `manseryeok/saju_result_adapter.dart`의 최상위 함수 `sajuResultFromProfile()` | `JeontongReportBuilder`(최종 5단계) | 5단계(최종) | 4단계 완료 `SajuProfile`(fiveElements/tenGods/sinsal/strength/daewoon 필수 — null이면 StateError) | **재계산 없는 순수 매핑**(예외: `getGongmang(dayGan, dayZhi)` 1회 재호출) — hiddenStems/twelveStages/relationships/yongsin/sewoon/wolwoon **6개 필드는 전혀 읽지 않음** | 레거시 `SajuResult` 객체 | 귀인지도(`_cacheOwnerSajuSummary`), `DoorEngineGateway.getSajuResult()` | ① | §3 추적로그: dayMaster=己, luckPillars.length=9 |

**핵심 정정 사항**: "SajuResultAdapter"는 지시서가 암시하는 것과 달리 **클래스가
아니라 `saju_result_adapter.dart` 파일의 최상위 함수**다. 보고서/문서 작성 시
반드시 `sajuResultFromProfile()` 함수로 지칭해야 한다.

---

## 2. 전체 엔진 연결 흐름도 (실제 코드에 존재하는 연결만 표시)

### 2-1. 단일 호출의 내부 흐름(①번 시스템, 1회 실행 기준)

```
[입력] BirthInfo(연/월/일/시/분, 양/음력, 성별) + ManseryeokPolicy(야자시/정밀도 등)
   │
   ▼
┌─────────────────────────────────────────────────────────────┐
│ JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4() │  ← 최상위 진입점(정적 함수)
└─────────────────────────────────────────────────────────────┘
   │
   ① PHASE1  ManseryeokCoreEngine.buildProfileWithCore(BirthInfo)
   │          → SajuProfile{ pillars: [년,월,일,시] }
   ▼
   ② PHASE2  Phase2AnalysisEngine.analyze(profile)  [오케스트레이터]
   │    ├─③ FiveElementsEngine.analyze(pillars)       → fiveElements
   │    ├─④ HiddenStemsEngine.analyze(pillars) ×2      → hiddenStems, tenGods
   │    ├─⑤ TwelveStagesEngine.analyze(pillars)        → twelveStages (※미소비)
   │    ├─⑥ RelationshipsEngine.analyze(pillars)       → relationships (1차)
   │    └─⑦ SinsalEngine.analyze(pillars, ...)         → sinsal
   │           └─ (내부) RelationshipsEngine.analyze() 2차 호출(원진 추출용)
   │   → profile.copyWith(fiveElements, hiddenStems, tenGods, twelveStages,
   │                        relationships, sinsal)
   ▼
   ⑧ PHASE3  Phase3AnalysisEngine.analyze(profile)  [오케스트레이터]
   │    ※ 선행조건 가드: fiveElements/hiddenStems/tenGods null이면 StateError
   │    ├─⑨ StrengthEngine.analyze(fiveElements, tenGods, hiddenStems, dayGan)
   │    │                                                → strength
   │    └─⑩ YongsinEngine.combine(byEokbu(...), byJohu(...))
   │                                                → yongsin
   │   → profile.copyWith(strength, yongsin)
   ▼
   ⑪ PHASE4  Phase4AnalysisEngine.analyze(profile)  [오케스트레이터]
   │    ※ 선행조건 가드: strength/yongsin null이면 StateError
   │    ├─⑫ DaewoonEngine.analyze(연주,월주,성별,referenceDate) → daewoon
   │    ├─⑬ SewoonEngine.analyzeYears(daewoon, fromYear~toYear) → sewoon
   │    └─⑭ WolwoonEngine.analyzeYear(특정연도)         → wolwoon (※미소비)
   │   → profile.copyWith(daewoon, sewoon, wolwoon)
   ▼
   ⑮ sajuResultFromProfile(profile)  [레거시 변환 함수, 재계산 없는 순수 매핑]
   │    ※ 선행조건 가드: fiveElements/tenGods/sinsal/strength/daewoon null이면 StateError
   │    - 읽음: fiveElements, tenGods, sinsal(필터링), strength, daewoon, dayGan/dayZhi(공망 재계산)
   │    - 읽지 않음: hiddenStems, twelveStages, relationships, yongsin, sewoon, wolwoon
   ▼
[출력] BuiltSajuResult { profile: SajuProfile(전체), saju: SajuResult(레거시 매핑본) }
```

### 2-2. "같은 파이프라인"을 반복 재호출하는 3개의 독립 소비 경로(앱 전체 구조)

사용자가 특히 강조한 "엔진 코드 존재와 실제 실행은 다르다"는 질문에 대한 가장
중요한 답은, ①번 파이프라인 **자체는 100% 실행되지만, 그 호출 진입점이 1개가
아니라 최소 3곳(４번째 호출 포함)이고, 서로 캐시를 공유하지 않아 매번 처음부터
다시 계산된다**는 사실이다.

```
                    buildProfileAndSajuResultViaPhase1to4()
                   (= 위 2-1 전체 파이프라인, 매번 "새로" 풀실행)
                    ┌──────────────┬──────────────┬──────────────┐
                    │              │              │              │
              [경로①]          [경로②]        [경로②-b]      [경로③]
          guinji_provider.dart  door_engine_   door_engine_   saju_visual_
          (3개 메서드 각각)     gateway.dart   gateway.dart   adapter.dart
          createMapForUser()   .getSajuProfile() .getSajuResult()  .build()
          createMapWithInput()      │              │          (saju_renewal
          joinMap()                 │              │           피처 전용,
                 │                  │              │           02/03/04 화면)
                 │                  └──────┬───────┘
                 │                         ▼
                 │              FortuneOrchestrator.buildProfile()
                 │              (getSajuProfile+getSajuResult를
                 │               "각각 독립적으로" 호출
                 │               = 1회 조회에 파이프라인 2회 풀실행)
                 │                         │
                 │                         ▼
                 │              CrossCheckRules(4종)
                 │              - SajuFaceDriveRule       → fiveElements 소비
                 │              - SajuPalmTemperamentRule → fiveElements 소비
                 │              - SajuCompatibilityRelationRule → relationships 소비
                 │              - TarotSajuTimingRule     → yongsin+sewoon 소비
                 ▼
     guinjiSajuInputFromProfile(profile)   ──┐
     → dayStemHanja/stems/branches/           │ relationships/yongsin/hiddenStems/
       fiveElementsCount/sinsalIds만 추출      │ twelveStages/daewoon/sewoon/wolwoon
     _cacheOwnerSajuSummary(saju)             │ 은 귀인지도 쪽에서 전혀 사용 안 함
     → dayMaster/dayMasterStrength만 추출    ─┘
```

**해석**: 사용자가 personA 같은 특정 사용자의 사주를 한 세션 동안 "귀인지도
확인 → 다른 운세 화면 이동 → 정통사주 리뉴얼 화면 재방문"처럼 여러 화면을
오가면, **①번 파이프라인(15개 구성요소 전체)이 캐시 없이 매번 처음부터
재계산된다.** 이는 §4(미사용·중복 목록)의 핵심 증거다.

### 2-3. "변환되지 않는 데이터"와 "소비되지 않는 데이터"의 구분 (전수 grep 확정)

| 필드 | PHASE2~4에서 계산됨 | `sajuResultFromProfile()`이 읽는가 | 실제 앱 어딘가에서 소비되는가 | 결론 |
|---|---|---|---|---|
| `fiveElements` | ✅ | ✅ | ✅(CrossCheckRules 2곳, guinji_saju_adapter, saju_visual_adapter, saju_result_adapter) | 정상 소비 |
| `hiddenStems` | ✅ | ❌ | ❌(PHASE3 내부 입력으로만 쓰이고 최종 결과엔 미반영) | 어댑터 미변환 + 외부 미소비 |
| `twelveStages` | ✅ | ❌ | ❌(전수 grep 결과 0건) | **완전 미사용** |
| `relationships` | ✅(2회 계산) | ❌ | ✅(cross_check_rules.dart, saju_visual_adapter.dart) — **SajuProfile 직접 소비, 어댑터 경유 안함** | 어댑터 미변환이지만 실사용됨 |
| `sinsal` | ✅ | ✅(레거시 3종만 필터링) | ✅(guinji_saju_adapter는 전체 그대로 소비) | 정상 소비(단, 경로별로 소비 범위 다름) |
| `strength` | ✅ | ✅ | ✅(saju_visual_adapter의 balanceLevel, yongsin_engine 내부 입력) | 정상 소비 |
| `yongsin` | ✅ | ❌ | ✅(cross_check_rules.dart TarotSajuTimingRule) — **SajuProfile 직접 소비** | 어댑터 미변환이지만 실사용됨 |
| `daewoon` | ✅ | ✅(`_toLuckPillars`) | ✅(saju_visual_adapter의 luck 윈도우) | 정상 소비 |
| `sewoon` | ✅ | ❌ | ✅(cross_check_rules.dart TarotSajuTimingRule) — **SajuProfile 직접 소비** | 어댑터 미변환이지만 실사용됨 |
| `wolwoon` | ✅ | ❌ | ❌(전수 grep 결과 0건) | **완전 미사용** |

---

## 3. 실제 계산 결과 추적 보고서 (personA 테스트케이스)

### ①입력 및 적용 계산정책
```
생년월일시: 1990-03-15 08:30 (양력, 남성)
referenceDate: 2024-01-01
ZiHourPolicy: lateZiSameDay (기본값)
DaewoonStartPrecision: traditionalApprox (기본값)
```

### ②만세력 사주원국 (PHASE1, ManseryeokCoreEngine)
```
년주 = 庚午(경오)   월주 = 己卯(기묘)   일주 = 己卯(기묘)   시주 = 戊辰(무진)
```
→ 외부 라이브러리 `lunar_python`(sect=2) 교차검증 완료(`manseryeok_external_reference_audit_test.dart`).

### ③각 분석엔진 중간결과 (PHASE2)
```
FiveElementsEngine   : {목:2, 화:1, 토:4, 금:1, 수:0}, dominant=[토], deficient=[수], isImbalanced=true
HiddenStemsEngine    : 일지(卯) 지장간=[乙(정기, 십신=편관)]
                       tenGods={year_gan:상관, month_gan:비견, hour_gan:겁재,
                                year_zhi:정인, month_zhi:편관, day_zhi:편관, hour_zhi:겁재}
TwelveStagesEngine   : {year:건록, month:병, day:병, hour:쇠}
RelationshipsEngine  : 4건 — [해:卯-辰@월지-시지, 해:卯-辰@일지-시지,
                               파:午-卯@년지-월지, 파:午-卯@년지-일지]
SinsalEngine         : 14건 — 공망 + 12신살 전체(겁살~화개살) + 백호대살
                       (양인살·괴강살·원진은 이 케이스에선 미발동)
```

### ④단계별 전달과정 (PHASE3)
```
StrengthEngine : verdict=중화, score=0.505
                 (monthOrderScore=-1.00, rootScore=1.60,
                  supportScore=4.00, controlScore=3.00, drainScore=1.00)
YongsinEngine  : method=억부+조후, yongsin=금, heesin=토, gisin=화, gusin=목
                 (월지=卯, 봄철이라 조후 불요 → 억부법 결과 채택)
```

### ⑤중간결과 종합방식 (PHASE4)
```
DaewoonEngine(9건) : #1 age8(1997) 庚辰, #2 age18(2007) 辛巳, #3 age28(2017) 壬午 ...
                     (2024-01-01 기준 세는나이=35 → 현재대운 index=3, 구간 2017~2026)
SewoonEngine(10건, 2017~2026) : 2023:癸卯, 2024:甲辰, 2025:乙巳 ...
WolwoonEngine(12건, 2024년)   : 1월(입춘) 丙寅, 2월(경칩) 丁卯 ...
```

### ⑥최종 SajuProfile/SajuResult (sajuResultFromProfile)
```
dayMaster=기(己), dayMasterStrength=中和(중화)
fiveElementsCount={목:2,화:1,토:4,금:1,수:0}
tenGods={동일 7키}
sinsal(원본14건 → 레거시3종 필터링 → 0건, 이 케이스엔 레거시 3종 해당 없음)=[]
gongmang=申酉(신유)
luckPillars.length=9, currentAge=35, currentLuck=壬午

⚠ SajuResult로 변환되지 않는 필드: hiddenStems, twelveStages, relationships,
   yongsin, sewoon, wolwoon (§2-3 표 참고 — 이 중 relationships/yongsin/sewoon은
   SajuProfile을 직접 소비하는 다른 경로(CrossCheckRules/SajuVisualAdapter)에서
   별도로 쓰이므로 "미변환"≠"미사용")
```

### ⑦테스트 기대값과 실제값 일치 여부
`flutter test test/manseryeok/ test/manseryeok_external_reference_audit_test.dart
test/saju_engine_to_screen_pipeline_test.dart` 실행 결과:
```
107개 테스트 전부 통과 (All tests passed!)
```
임시 검수 전용 테스트(`_audit_temp_engine_trace_test.dart`, 위 로그를 생성한 뒤
즉시 삭제)의 모든 `expect()` 역시 전부 통과했다. 기존 코드를 전혀 수정하지
않은 상태에서 15개 구성요소의 실제 실행과 값 전달이 테스트로 재확인되었다.

---

## 4. 미사용·중복·연결 누락 목록

### 4-1. 완전 미사용(계산되지만 앱 어디서도 읽지 않음)
| 필드/엔진 | 근거 |
|---|---|
| `SajuProfile.twelveStages`(TwelveStagesEngine 결과) | 전수 grep(`\.twelveStages\b`) 결과 PHASE2 내부 계산·할당 외 읽는 코드 0건 |
| `SajuProfile.wolwoon`(WolwoonEngine 결과) | 전수 grep(`\.wolwoon\b`) 결과 PHASE4 내부 계산·할당 외 읽는 코드 0건 |

→ 이 2개 엔진은 "①실제 호출되어 계산함"은 맞지만, 그 **결과값이 화면이나 다른
로직 어디에도 전달되지 않고 버려진다.** CPU/메모리를 소비하지만 사용자 경험에는
영향을 주지 않는 순수 낭비 연산이다.

### 4-2. 어댑터 미변환이지만 실제로는 소비되는 데이터(오해 소지가 있어 명시)
`relationships`, `yongsin`, `sewoon`은 `sajuResultFromProfile()`(레거시 SajuResult
변환)을 거치지 않지만, `SajuProfile` 객체 자체를 직접 전달받는 `CrossCheckRules`
(4종 중 3종)와 `SajuVisualAdapter`에서 실제로 소비된다. **"SajuResultAdapter가
변환하지 않은 데이터 = 앱에서 안 쓰이는 데이터"라고 단정하면 틀린 결론**이다.

### 4-3. 교차 의존성(단순 "1엔진 1회 실행" 가정이 깨지는 지점)
`SinsalEngine.analyze()`가 내부에서 "⑦ 원진" 처리를 위해 `RelationshipsEngine
.analyze()`를 **2차로 재호출**한다(Phase2AnalysisEngine의 1차 호출과 별개). 즉
RelationshipsEngine은 PHASE2 1회 실행당 **정확히 2회** 호출된다.

### 4-4. 파이프라인 전체의 중복 재실행(캐시 부재 — 경로별로 상황이 다름, 추가 확인 완료)
§2-2에서 확인한 대로, 동일 사용자·동일 출생정보라도 ①귀인지도(3개 메서드),
②DoorEngineGateway(getSajuProfile/getSajuResult 각각), ③SajuVisualAdapter가
서로 캐시를 공유하지 않고 **각자 독립적으로 `buildProfileAndSajuResultViaPhase1to4()`
전체(15개 구성요소 전부)를 처음부터 재실행**한다. 특히 `FortuneOrchestrator
.buildProfile()`은 **단 1회의 조회에서도 getSajuProfile+getSajuResult를 각각
호출**하므로 파이프라인이 2회 풀실행된다.

**[추가 조사로 확정] ③번 경로(SajuVisualAdapter)만은 화면 레벨에서 이미 메모리
캐시가 적용되어 있다** — `saju_renewal_provider.dart`의 `SajuRenewalProvider
.visualProfileFor(user)`가 `_cachedVisualProfile`/`_cachedVisualProfileKey`
(생년월일/시간/음양력/윤달/시간모름/성별 6개 필드 조합 키)로 메모이제이션하여,
02(`birth_input_screen`)~07 화면이 동일 세션 내에서 같은 출생정보를 반복 조회해도
`SajuVisualAdapter.build()`(=PHASE1~4 풀파이프라인)는 **최초 1회만 실행**되고
이후는 캐시를 반환한다. 코드 주석에 `"반복 실행되고 있었다(교차검증 조사에서
확인)"`라는 기록이 남아있어, **과거 한 시점엔 이 경로도 중복 재실행 문제가
있었으나 이미 수정되어 현재는 해결된 상태**임을 확인했다. 단, `birth_input_screen`
의 `_livePreview`(실시간 입력 프리뷰, 사용자가 키 입력할 때마다 갱신)는 이
캐시를 거치지 않고 `SajuVisualAdapter.build()`를 직접 호출하므로, 날짜 선택
단계에서는 캐시와 무관하게 매 입력마다 재계산된다(이는 "아직 저장되지 않은
입력값의 실시간 미리보기"라는 의도된 동작이다).

**①귀인지도(3개 메서드)와 ②DoorEngineGateway 경로에는 이런 메모이제이션이
없다**(`guinji_provider.dart`/`door_engine_gateway.dart`/`fortune_orchestrator.dart`
전수 확인 결과 `_cached*` 패턴 0건 — `guinji_provider.dart`의
`_cacheOwnerSajuSummary`는 PHASE1~4 결과 자체가 아니라 `dayMaster`/
`dayMasterStrength` 2개 필드만 담은 "요약 데이터"를 저장하는 별개 메커니즘이라
재계산 방지 캐시가 아니다). 따라서 **①②경로는 여전히 호출할 때마다 PHASE1~4
전체를 처음부터 재계산하며, 이것이 §4-4의 실질적으로 유효한 결론**이다.
`OrchestratorProvider`(`FortuneOrchestrator`를 감싸는 유일한 Provider,
`app.dart`에서 전역 등록)는 `cross_check_result_screen.dart` 1곳에서만
소비되므로, 이 중복 재계산은 **사용자가 "교차검증 결과" 화면에 진입할 때마다**
(그리고 그 화면 안에서 `.load()`가 재호출될 때마다) 발생한다.

### 4-5. 예상과 다른 호출 경로(명칭상 오해 소지)
"SajuResultAdapter"라는 이름은 클래스를 연상시키지만 실제로는
`saju_result_adapter.dart`의 최상위 함수 `sajuResultFromProfile()`이다. 지시서나
문서에서 "SajuResultAdapter 클래스가 ~한다"는 식으로 서술하면 실제 코드 구조와
불일치한다.

### 4-6. [추가 조사로 해소] DoorEngineGateway의 상위 소비처 — 4번째 독립 경로는 없음
이전 보고서 초안에서 "④확인 불가"로 남겼던 항목을 추가 조사로 확정했다.
`grep -rln "DoorEngineGateway\|FortuneOrchestrator\b" lib/` 결과,
`DoorEngineGateway`/`FortuneOrchestrator`를 참조하는 파일은
`unified_fortune_profile.dart`, `cross_check_rules.dart`,
`cross_check_engine.dart`, `door_engine_gateway.dart`, `fortune_orchestrator.dart`,
`orchestrator_provider.dart`, `app.dart` 7개뿐이며, 그중 실제 인스턴스를
생성·등록하는 곳은 `app.dart`(전역 Provider 트리, `OrchestratorProvider(
FortuneOrchestrator(gateway: DefaultDoorEngineGateway(...)))`) **단 1곳**이다.
그리고 `OrchestratorProvider`를 구독하는 화면은 `cross_check_result_screen.dart`
**1곳뿐**이다(`interpretation_narrator.dart`는 `cross_check_engine.dart`가
생성한 `CrossCheckResult`를 문구로 가공하는 하위 유틸일 뿐, 별도로
DoorEngineGateway를 호출하지 않음). 즉 **②번 경로(DoorEngineGateway)는 추가
소비처 없이 "교차검증 결과 화면" 단일 진입점으로 귀결**되며, 사용자가 우려한
"4번째 독립 호출 경로"는 존재하지 않는 것으로 확정한다.

---

## 5. 로컬 계산(Flutter)과 서버 기능(FACT/주제선정/LLM) 구분

사용자가 가장 강하게 요구한 구분이다. §0에서 정리한 ①②③ 시스템을 기준으로
기능별 수행 위치를 명확히 매핑한다.

| 기능 | 수행 위치 | 코드 근거 |
|---|---|---|
| **사주 원국(만세력) 계산 — 귀인지도/도어게이트웨이/SajuVisualAdapter 경로** | **Flutter 앱 내부**(①번 시스템, `ManseryeokCoreEngine`~`Phase4AnalysisEngine`, 순수 Dart 로직, 서버 호출 없음) | §1~§3 전체 |
| **사주 원국(만세력) 계산 — 정통사주 리뉴얼(topic 기반) 경로** | **별도 Python FastAPI 서버**(`saju_engine_v3.3`, `POST /saju/v3/facts`) — admin_web `saju-engine-client.ts`가 HTTP로 호출, `X-Free-Pass` 토큰 인증, 응답을 `SajuFactsCache`(DB)에 `birthKey`(입력 8개값 해시) 기준 캐시 | `saju-engine-client.ts`: `fetch(`${baseUrl}/saju/v3/facts`, ...)`, `computeBirthKey()` |
| **사주 원국(만세력) 계산 — 레거시 AI사주 경로(`/api/public/fortune/saju`)** | admin_web 서버의 `computeChart()` 함수가 **"결정론적 해시 시드" 기반으로 가짜 pillars/fiveElements를 생성**(실제 역학 계산이 아님, 코드 주석에 명시) — **단, 이 경로는 Flutter 앱에서 더 이상 호출되지 않는 완전 레거시**(§0 참고) | `route.ts` L1~120: `computeChart(birthDate, hasBirthTime)`, 주석 "saju-output-spec.pdf 대응] 3단계 파이프라인" |
| **69종(→실제로는 29종) 주제 선정 및 필터링** | **admin_web 서버**(순수 TS 함수, LLM 미사용 — `topic-engine.ts`의 `selectTopics()`), `POST /api/public/saju-renewal/topics/select` | `topics/select/route.ts` 주석: "[LLM 호출 절대 금지]...LLM 클라이언트는 이 파일에서 import조차 하지 않는다"; `topic-engine.ts`: Fact존재확인→조건검증(≥2 근거+confidence)→점수화(E/I/T/N/B/P 가중합)→노출이력필터→시기형1개제한→폴백보장→최종선정 |
| **LLM 해석(결과 텍스트 생성)** | **admin_web 서버**, `POST /api/public/saju-renewal/interpret` — `interpret-service.ts`가 `completeText()`(LLM) 호출, `interpret-qa-check.ts`로 QA검증, 실패시 `interpret-fallback.ts` 폴백, 최대 2회 재시도(`MAX_LLM_ATTEMPTS=2`) | `interpret-service.ts`, `interpret-prompt.ts`(buildFactDigest — "생년월일을 그대로 LLM에 넘겨 재판단시키지 않는다"는 명시적 원칙 확인) |
| **결과 변환 및 화면 표시** | **Flutter 앱**(`SajuRenewalApi` → `TopicCard`/`InterpretResult` 모델 → `story_detail_screen.dart` 등 화면 렌더링). 단, ①번 시스템 결과는 `SajuVisualAdapter`/`sajuResultFromProfile()`이 화면용 모델로 변환 | `saju_renewal_api.dart`, `saju_visual_adapter.dart` |

### 핵심 결론
- **①번(앱 내부 PHASE1~4)과 ③번(서버 Python saju_engine_v3.3 + topic-engine)은
  완전히 독립적인 2개의 계산 시스템**이며, 서로 데이터를 주고받지 않는다. 같은
  "사주"라는 단어를 쓰지만 ①은 Dart로 직접 구현한 만세력/오행/신살/용신/대운
  로직이고, ③은 별도 Python 프로세스가 계산한 Fact를 서버가 받아와 캐싱한다.
- ③번 내부에서도 **"Fact 계산"(Python 엔진 호출)**, **"주제 선정"(순수 TS
  스코어링, LLM 미사용)**, **"LLM 해석"(실제 텍스트 생성)**이 **3개의 분리된
  단계**로 명확히 구현되어 있으며, 코드 주석 수준에서도 "LLM이 사주를 계산하지
  않는다"는 원칙이 여러 번 명시적으로 강제되고 있다(토픽 엔진 파일에 LLM
  클라이언트 import 자체가 없음으로 구조적 보장).
- ②번(레거시, 해시 기반 가짜 명식 + LLM)은 서버 코드는 남아있으나 Flutter
  클라이언트 쪽 호출부(`lib/features/fortune/saju/`)가 완전히 삭제되어 있어
  **사실상 실행되지 않는 데드 엔드포인트**다 — "코드 존재 ≠ 실제 서비스 실행"의
  가장 명확한 사례.

---

## 5-1. [추가 조사] 레거시 경로(②번)의 판정·검증·표현 3단계 상세
  (`saju-judgment.ts` / `saju-qa-check.ts` / `saju-render.ts`)

사용자 지시에 따라 이 3개 파일을 **"코드가 존재한다"가 아니라 "실제 호출
경로"** 기준으로 전수 재조사했다. 결론부터 말하면, 이 3개 파일은 **②번
레거시 시스템(`POST /api/public/fortune/saju`) 전용 내부 모듈**이며,
①번(PHASE1~4)·③번(29종 topic-engine) 어느 쪽과도 코드 수준에서 전혀
연결되지 않는다.

### 5-1-1. 호출 관계 — 상위 호출자와 import 그래프 (grep 전수 확인)

```
src/app/api/public/fortune/saju/route.ts
  ├─ import buildSajuJudgment  ←── src/lib/saju-judgment.ts
  ├─ import checkSajuResult,
  │         type SajuLlmResult ←── src/lib/saju-qa-check.ts
  └─ import parseSajuLlmJson,
            renderSajuLlmResult ←── src/lib/saju-render.ts
                                      └─ import type SajuLlmResult
                                            (from ./saju-qa-check)  ← saju-render.ts가
                                                                       saju-qa-check.ts의
                                                                       "타입"만 가져옴
```

`grep -rn "import.*saju-qa-check\|import.*saju-judgment\|import.*saju-render" src/`
전수 검색 결과, **이 3개 파일을 import하는 곳은 `route.ts`(사주 전용)와
`saju-render.ts`→`saju-qa-check.ts`(타입 재사용) 단 2곳뿐**이다. 사용자가
의심한 "다른 경로에서도 쓰이는지"에 대한 답은 **아니오**다.

- `face-judgment.ts`/`palm-judgment.ts`/`face-palm-qa-check.ts`도 이름이
  유사해 혼동될 수 있으나, 실제 import 구문은 **0건**이다. 대신
  `face-palm-qa-check.ts` 2행 주석에 `"saju-qa-check.ts의 핵심 검사(금지어/
  확정 단정 표현)만 재사용해 적용 범위를..."`라고 명시되어 있는데, 이는
  **import를 통한 코드 공유가 아니라 "동일한 검사 패턴을 별도 파일에
  복제·재구현"한 것**이다(관상·손금은 사주와 다른 금칙어/허용예외 목록을
  쓰므로 독립 구현이 합리적인 선택이며, 사주 결과에 영향을 주지 않는다).
- `interpret-qa-check.ts`(③번 시스템, `saju-renewal/` 하위)는 이름이
  `saju-qa-check.ts`와 비슷하지만 **완전히 별개의 신규 파일**이며 import
  관계가 없다. 오히려 그 파일 주석에 `"[기존 saju-qa-check.ts와 분리하는
  이유] 기존 모듈은 레거시 69종 '7블록'..."`이라고 명시되어 있어, **③번을
  설계할 때 ②번(saju-qa-check.ts)을 의도적으로 분리해 새로 작성했음**이
  코드 주석 수준에서 확정된다.

**Flutter 클라이언트 쪽 호출 여부**: `grep -rn "SajuRepository" lib/`
10건 전부가 `feature_flags.dart`/`ai_call_counter.dart`/
`cross_check_rules.dart`/`pass_repository.dart` 내 **주석(과거 설계
언급) 뿐**이며, 실제 `SajuRepository` 클래스 정의나 인스턴스화 코드는
0건이다. `lib/features/fortune/saju/` 디렉토리 자체도 `find` 결과 0건.
→ **route.ts(결과적으로 이 3개 파일 전부)는 Flutter 앱에서 더 이상 호출할
방법이 없는 코드**다(§0에서 이미 확정한 사실의 재확인).

### 5-1-2. 입력/출력 데이터 및 역할 — "계산/판정/검증/표현" 구분

| 파일 | 역할(5단계 중) | 입력 | 출력 |
|---|---|---|---|
| `computeChart()`(route.ts 내부, 이 3개 파일 밖) | **①계산** | `birthDate`, `hasBirthTime` | `pillars`(년/월/일/시 간지 **문자열**), `fiveElements`, `seed` — **해시 기반, 실제 역학 계산 아님**(주석 "결정론적 규칙으로 계산(범위 밖)") |
| `saju-judgment.ts`의 `buildSajuJudgment()` | **②판정** | `birthDate/birthTime/gender/isLunar/pillars/seed`(= computeChart 출력) | `SajuJudgment`(day_master/ten_gods_count/elements_ratio/verdict 4종/flow.daewoon·sewoon) |
| LLM 호출(`completeText()`, route.ts L408 `tryGenerateSajuSection` 내부) | **④해석** | `buildUserPrompt()`가 `judgment`를 `JSON.stringify`해 프롬프트에 "[계산값] ... 절대로 사주를 다시 계산하거나 ... 새로 만들지 마세요"로 주입 | LLM 원본 텍스트(JSON 섞인 자유 텍스트) |
| `saju-render.ts`의 `parseSajuLlmJson()` | **표현 전처리**(파싱) | LLM 원본 텍스트 | `SajuLlmResult`(headline/sections/actions/closing/evidence_used) 또는 실패 시 `null` |
| `saju-qa-check.ts`의 `checkSajuResult()` | **③검증** | `SajuLlmResult` | `string[]`(실패 사유 목록, 빈 배열=통과) |
| `saju-render.ts`의 `renderSajuLlmResult()` | **⑤표현**(최종 변환) | `SajuLlmResult`(QA 통과분) | Flutter `topicResults[topic]`에 그대로 들어가는 하나의 긴 텍스트 문자열 |

**`buildSajuJudgment()`가 하는 일의 정확한 성격**: pillars(이미 가짜 간지
문자열)를 받아 `STEM_ELEMENT`/`BRANCH_ELEMENT`(오행 고정표)로 8글자를
오행 분류하고, `classifyTenGod(dmElement, targetElement)`로 **실제
십신(비겁/식상/재성/관성/인성) 분류 규칙**을 적용해 `ten_gods_count`를
센 뒤, 재물(재성·비겁)/관계(관성·인성)/직업(식상·인성)/건강(오행 편중)
4개 카테고리를 조건식(`grade: good/caution/neutral`)으로 판정한다.
세운(`flow.sewoon`)은 `yearGanji(year)` — `(year-4)%10`/`%12`를 쓰는
**실제 60갑자 달력 공식**(1984년=갑자년 기준)으로 계산되어 해시가 아니다.
반면 대운(`flow.daewoon`)은 코드 주석에 **"[범위 밖 — 근사치] 실제
대운수(절입일수÷3, 순역 규칙)를 계산할 만세력 인프라가 없어 seed로
그럴듯한 시작 나이만 생성한다"**고 명시적으로 자인하는 근사값이다
(`startAge = 3 + (seed % 7)`, 간지도 `seed` 기반).

→ **핵심 한계**: `buildSajuJudgment()` 내부 로직(오행 분류·십신 분류·
세운 공식) 자체는 실제 역학 규칙을 쓰지만, **그 입력값인 `pillars`가
이미 `computeChart()`의 해시 기반 가짜 간지이므로, 아무리 그 이후
처리가 "진짜 규칙"이어도 결과 전체가 허구인 입력 위에 세워진
판정**이다. "판정 로직은 진짜, 계산 결과는 가짜"라는 이중구조가
이 레거시 경로의 본질이다.

### 5-1-3. PHASE1~4(①번) 및 29종 주제선정(③번)과의 연결 여부 — **연결 없음(확정)**

- `pillars` 변수명이 PHASE1(`ManseryeokCoreEngine`)의 출력과 같은 이름을
  쓰고 있어 혼동되기 쉬우나, **코드 상 아무 관계가 없다**. ②번 경로의
  `pillars`는 `route.ts`의 `computeChart()`가 자체적으로 생성하는 로컬
  변수이고, PHASE1 결과는 Dart(`manseryeok_core_engine.dart`)에서만
  존재하며 서버로 전송되지 않는다. 두 "pillars"는 동명이인이다.
- 29종 주제선정(`topic-engine.ts`)은 `SajuFactsCache`(Python
  `saju_engine_v3.3`가 계산한 Fact)만 입력으로 받으며, `saju-judgment.ts`의
  `SajuJudgment`나 `computeChart()`의 `pillars`를 참조하는 코드는
  `topic-engine.ts`/`saju-engine-client.ts` 어디에도 없다(grep 0건).
- 결론: **②번(saju-judgment/qa-check/render)은 PHASE1~4(①)와도 29종
  topic-engine(③)과도 데이터를 공유하지 않는, 완전히 고립된 세 번째
  파이프라인 내부 모듈**이다.

### 5-1-4. route.ts 호출 순서 — 정확한 라인번호로 확정한 전체 흐름

```
route.ts POST 핸들러(L170~)
  │
  ├─ L344: const { pillars, fiveElements, seed } = computeChart(birthDate, !!birthTime)
  │         ── ①계산(해시 기반, 이 3개 파일 밖)
  │
  ├─ L349: const judgment = buildSajuJudgment({ birthDate, birthTime, gender,
  │                                             isLunar, pillars, seed })
  │         ── ②판정 ( saju-judgment.ts )
  │         "모든 topic이 동일한 judgment를 공유한다(사람은 한 명, 판정도 하나)"
  │
  ├─ 주제별 활성 프롬프트 템플릿 병렬 조회(Promise.all, DB)
  │
  ├─ L401: buildUserPrompt({ name, birthDate, isLunar, birthTime, topic, judgment })
  │         judgment를 JSON.stringify해 "[계산값] ... 절대로 사주를 다시
  │         계산하지 마세요"로 프롬프트에 주입
  │
  ├─ withTemplate.map(...) → Promise.allSettled (주제별 병렬, 최대 MAX_LLM_ATTEMPTS=2 재시도)
  │     │
  │     └─ L408: tryGenerateSajuSection(template.templateBody, userPrompt)
  │           │  (L150~168 함수 본문)
  │           ├─ L156: completeText(...)              ── ④해석(LLM 호출)
  │           ├─ L157: parseSajuLlmJson(raw)           ── 표현 전처리(파싱), 실패시 null 반환→재시도
  │           ├─ L162: checkSajuResult(parsed)         ── ③검증(QA), 실패시 null 반환→재시도
  │           └─ L167: renderSajuLlmResult(parsed)     ── ⑤표현(최종 텍스트)
  │
  ├─ 실패(allSettled rejected) 시: FALLBACK_TEXT_BY_TOPIC으로 폴백(동일 topic)
  │
  └─ DB 트랜잭션(L420~): fortuneRequest/fortuneResult 기록
        "[무료 광고형 구조 재정비] 사주 운세는 완전 무료 — 차감/환급 없음"
        (cost = 0, pointSpent = 0으로 명시적 고정)
```

이 흐름은 **①계산 → ②판정 → ④해석(LLM) → 표현전처리(파싱) → ③검증(QA)
→ ⑤표현(렌더링)** 순서로, 사용자가 요구한 5단계 구분(계산/판정/검증/
해석/표현)이 **route.ts 단일 함수 안에 코드 레벨로 명확히 분리**되어
있음을 확정한다. 단, 검증(③)이 해석(④) *이후*에 일어나는 구조이므로
"LLM이 생성한 결과를 사후 검증"하는 방식이며 "생성 전에 미리 걸러주는"
방식은 아니다(실패 시 최대 2회까지 전체를 다시 생성).

### 5-1-5. 현재 사용 여부 최종 판정

| 항목 | 판정 | 근거 |
|---|---|---|
| admin_web 서버 코드(route.ts, 3개 lib 파일) | **코드는 존재하고 내부적으로 서로 정상 연결됨** | import 그래프, 라인별 호출관계 확정(5-1-1, 5-1-4) |
| 이 경로의 엔드포인트(`POST /api/public/fortune/saju`)가 외부(Flutter)에서 실제로 호출되는가 | **아니오 — 호출 코드 없음** | `lib/features/fortune/saju/` 0건, `SajuRepository` 클래스 정의 0건(§0, 5-1-1 재확인) |
| 종합 결론 | **"②번 레거시 전체 파이프라인(계산→판정→해석→검증→표현)이 서버 안에서는 완결된 형태로 살아있으나, 그것을 트리거할 클라이언트가 없어 실질적으로 휴면 상태"** | 코드 존재와 실행 여부를 분리해서 판단해야 한다는 지시서 원칙의 교과서적 사례 |

### 5-1-6. 기존 경로와의 중복·결과 상이 가능성

- **코드 중복**: `face-palm-qa-check.ts`가 `saju-qa-check.ts`의 검사
  패턴(금지어/단정표현)을 복제했지만, **import 관계가 아니라 별도
  파일로 독립 구현**되어 있어 한쪽을 고쳐도 다른 쪽이 깨지지 않는다
  (유지보수 시 "따로 고쳐야 함"이라는 비용은 있으나, **실행 중
  상호 간섭이나 결과 혼선 위험은 없다**).
- **결과 상이 가능성**: ②번(해시 기반) vs ①번(PHASE1~4 실제 만세력)
  vs ③번(Python saju_engine_v3.3 실제 만세력)은 **같은 생년월일을
  넣어도 서로 다른 pillars/오행 결과를 낼 수 있다**(②는 해시이므로
  실제 명식과 무관). 다만 ②번이 현재 호출되지 않으므로, **사용자가
  실제로 접하는 결과는 ①번 또는 ③번 중 하나로 고정**되어 있어 "한
  사람이 두 가지 다른 사주 결과를 동시에 보게 되는" 문제는 현재
  발생하지 않는다(단, 향후 ②번 라우트가 실수로 다시 연결되면 이
  불일치가 현실화될 수 있으므로 코드 삭제가 아닌 "휴면 확인"만으로
  남겨둔 것에 대한 리스크로 기록해 둔다).

---

## 5-2. 통합 전체 흐름도 — ①②③ 세 시스템과 Flutter↔서버 경계

사용자가 요청한 "각 경로가 어떻게 연결되는지 보여주는 전체 흐름도"를
하나로 모은 것이다. **③개의 화살표 다발은 서로 교차하지 않는다** —
이것이 이번 전체 검수의 가장 중요한 결론이다.

```
                         [ 사용자 생년월일시 입력 ]
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────────┐   ┌─────────────────────────┐   ┌──────────────────────┐
│ ①번: PHASE1~4      │   │ ②번: 레거시 AI사주        │   │ ③번: 정통사주 리뉴얼    │
│ (Flutter 로컬 계산)  │   │ (admin_web 서버, 휴면)    │   │ (topic 기반, 운영중)    │
├───────────────────┤   ├─────────────────────────┤   ├──────────────────────┤
│ [Flutter 내부, 서버  │   │ [admin_web 서버 내부]     │   │ [Flutter] SajuRenewalApi│
│  호출 없음]         │   │                         │   │   │                  │
│ ManseryeokCoreEngine│   │ computeChart()           │   │   ▼                  │
│  (PHASE1, 만세력)   │   │  └ 해시 기반 가짜 pillars  │   │ POST .../topics/select│
│   │                │   │                         │   │   │ (admin_web)        │
│   ▼                │   │ buildSajuJudgment()      │   │   ▼                  │
│ Phase2AnalysisEngine│   │  saju-judgment.ts        │   │ topic-engine.ts      │
│ (5개 하위엔진)       │   │  └ 오행/십신 실제 규칙    │   │  selectTopics()       │
│   │                │   │     (입력 pillars는 가짜)  │   │  (29종, LLM 미사용)   │
│   ▼                │   │   │                      │   │   │   ↑ 입력          │
│ Phase3AnalysisEngine│   │   ▼                      │   │   │  SajuFactsCache   │
│ (2개 하위엔진)       │   │ buildUserPrompt()         │   │   │  (DB 캐시)        │
│   │                │   │  judgment를 "[계산값]"으로 │   │   │   ↑              │
│   ▼                │   │  프롬프트에 주입            │   │   │ saju-engine-client│
│ Phase4AnalysisEngine│   │   │                      │   │   │  .ts(HTTP)        │
│ (3개 하위엔진)       │   │   ▼                      │   │   │   ↑              │
│   │                │   │ LLM 호출(completeText)     │   │   │  [별도 Python     │
│   ▼                │   │   │                      │   │   │   FastAPI 서버]   │
│ sajuResultFromProfile│  │   ▼                      │   │   │  saju_engine_v3.3 │
│ (SajuResultAdapter) │   │ saju-render.ts            │   │   │  POST /saju/v3/   │
│   │                │   │  parseSajuLlmJson()        │   │   │       facts       │
│   ▼                │   │   │                      │   │   ▼                  │
│ 3개 독립 소비 경로    │   │   ▼                      │   │ POST .../interpret    │
│ (§2-2)             │   │ saju-qa-check.ts           │   │  interpret-service.ts │
│ · 귀인지도(캐시없음)  │   │  checkSajuResult()         │   │  └ LLM 해석 생성      │
│ · DoorEngineGateway │   │   │ 실패시 최대 2회 재시도    │   │  interpret-qa-check.ts│
│   (캐시없음)         │   │   ▼                      │   │  └ QA 검증(별도 모듈,   │
│ · SajuVisualAdapter │   │ saju-render.ts             │   │     saju-qa-check.ts와 │
│   (메모캐시 있음)    │   │  renderSajuLlmResult()      │   │     import 관계 없음) │
└───────────────────┘   │   │                        │   └──────────────────────┘
                         │   ▼                        │
                         │ topicResults[topic]         │
                         │  = 렌더링된 텍스트            │
                         └─────────────────────────┘
                              │
                              ▼
                   [ Flutter 쪽 호출 코드 없음 — 0건 ]
                   SajuRepository 클래스 정의 없음,
                   lib/features/fortune/saju/ 디렉토리 없음
                   → 서버 파이프라인은 완결돼 있으나 트리거 불가(휴면)
```

**이 그림에서 확정되는 3가지**:
1. ①(Flutter 로컬)과 ③(서버 Python 엔진 + topic-engine)은 화살표가
   전혀 교차하지 않는다 — 입력(생년월일시)만 같고 계산 주체·결과·API가
   완전히 분리되어 있다.
2. ②(레거시)는 서버 내부에서는 계산→판정→해석→검증→표현 5단계가
   코드로 완결되어 있지만, 맨 아래 화살표가 끊겨 있다(Flutter 호출
   코드 0건) — "코드 존재 ≠ 실행"의 핵심 증거.
3. ③ 내부에서도 "Fact 계산"(별도 Python 프로세스) → "주제 선정"(순수
   TS, LLM 미사용) → "LLM 해석"(실제 텍스트 생성) → "QA 검증"
  (`interpret-qa-check.ts`, `saju-qa-check.ts`와 무관한 별도 파일)이
   명확히 분리된 4단계로 구현되어 있다.

---

## 6. 검수 방법 및 한계

- 모든 발견은 실제 소스코드 Read/Bash(`grep`/`sed -n`/`find`) 조회와, 기존
  테스트 스위트 실행(107개 전부 통과) + 검수 전용 임시 테스트 1개(생성→실행→
  로그캡처→즉시삭제, `git status --short test/` 무출력으로 원복 확인)로
  뒷받침된다.
- 운영 데이터/사용자 과금에 영향을 주는 코드는 전혀 수정하지 않았다.
- 최초 보고서 초안에서 "④확인 불가"로 남겼던 `orchestrator_provider.dart`,
  `interpretation_narrator.dart`, `story_detail_screen.dart`/
  `story_preview_screen.dart`/`saju_renewal_provider.dart`는 이어지는 추가
  조사에서 전수 확인을 완료했다(§4-4, §4-6 갱신 내용 참고). 결론: ②번 경로
  (DoorEngineGateway)는 `cross_check_result_screen.dart` 단일 진입점으로
  귀결되어 추가 독립 호출 경로는 없으며, ③번 경로(SajuVisualAdapter)는
  `SajuRenewalProvider.visualProfileFor()`에 이미 메모이제이션 캐시가 적용되어
  동일 세션 내 재계산이 방지되고 있음을 확인했다(단, ①귀인지도·②DoorEngineGateway
  경로에는 이런 캐시가 없어 호출할 때마다 PHASE1~4 전체가 재계산된다).
- [갱신 — 추가 조사 완료] admin_web `saju-judgment.ts`/`saju-qa-check.ts`/
  `saju-render.ts` 3개 파일은 이번 턴에서 **전체 내용을 Read로 전수 확인**
  했고, `route.ts`의 정확한 호출 라인번호(L344/L349/L401/L408, 함수 내부
  L156/L157/L162/L167)까지 추적을 완료했다(§5-1 신규 섹션). 결론은 §0에서
  이미 확정한 대로 **Flutter 클라이언트가 더 이상 호출하지 않는 ②번 레거시
  경로(`/api/public/fortune/saju`) 전용 내부 모듈**이며, ①번 시스템(이
  보고서의 핵심 대상)과는 변수명만 같을 뿐("pillars") 코드상 데이터를 주고
  받지 않는다. `SajuRepository` 클래스 정의가 Flutter 코드베이스에 0건임을
  grep으로 재확인해, "서버 코드는 완결되어 있으나 호출할 클라이언트가 없는
  휴면 파이프라인"이라는 판정을 뒷받침했다.
