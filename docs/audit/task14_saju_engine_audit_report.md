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
| ② | **레거시 AI사주**(`/ai-fortune/saju/*`, `lib/features/fortune/saju/`, admin_web `POST /api/public/fortune/saju`) | admin_web 서버의 `computeChart()`(**해시 기반 가짜 명식**, 실제 역학 계산 아님) + LLM | ❌ **완전 제거됨** — `lib/features/fortune/saju/` 디렉토리 자체가 Flutter 코드베이스에 더 이상 존재하지 않는다(`find` 결과 0건, `SajuRepository` 클래스도 0건). `app_router.dart`가 해당 라우트를 전부 `/saju-renewal`로 강제 리다이렉트 중. | `feature_flags.dart`의 "4단계 점진 전환" 계획 문서는 과거 계획이며, 실제로는 이미 코드 자체가 삭제된 상태(계획보다 앞서 실행됨). **"엔진 코드 존재 ≠ 실제 실행"의 역방향 사례** — 즉 서버(route.ts)엔 코드가 남아있지만 호출하는 클라이언트가 없어 사실상 죽은 엔드포인트. |
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

### 4-4. 파이프라인 전체의 중복 재실행(캐시 부재)
§2-2에서 확인한 대로, 동일 사용자·동일 출생정보라도 ①귀인지도(3개 메서드),
②DoorEngineGateway(getSajuProfile/getSajuResult 각각), ③SajuVisualAdapter가
서로 캐시를 공유하지 않고 **각자 독립적으로 `buildProfileAndSajuResultViaPhase1to4()`
전체(15개 구성요소 전부)를 처음부터 재실행**한다. 특히 `FortuneOrchestrator
.buildProfile()`은 **단 1회의 조회에서도 getSajuProfile+getSajuResult를 각각
호출**하므로 파이프라인이 2회 풀실행된다.

### 4-5. 예상과 다른 호출 경로(명칭상 오해 소지)
"SajuResultAdapter"라는 이름은 클래스를 연상시키지만 실제로는
`saju_result_adapter.dart`의 최상위 함수 `sajuResultFromProfile()`이다. 지시서나
문서에서 "SajuResultAdapter 클래스가 ~한다"는 식으로 서술하면 실제 코드 구조와
불일치한다.

### 4-6. 확인되었으나 이번 범위에서 상세 분석하지 않은 잠재적 4번째 소비처
`DoorEngineGateway`의 `getSajuProfile`/`getSajuResult`를 `FortuneOrchestrator`
외에 다른 곳에서도 호출하는지는 `orchestrator_provider.dart`,
`interpretation_narrator.dart` 등 상위 Provider/화면 레이어까지는 확인하지
못했다(④확인 불가로 분류). 추가 조사 시 우선 확인 대상으로 남긴다.

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

## 6. 검수 방법 및 한계

- 모든 발견은 실제 소스코드 Read/Bash(`grep`/`sed -n`/`find`) 조회와, 기존
  테스트 스위트 실행(107개 전부 통과) + 검수 전용 임시 테스트 1개(생성→실행→
  로그캡처→즉시삭제, `git status --short test/` 무출력으로 원복 확인)로
  뒷받침된다.
- 운영 데이터/사용자 과금에 영향을 주는 코드는 전혀 수정하지 않았다.
- 미확인으로 남긴 항목(④, §4-6)은 추측으로 채우지 않고 명시적으로 "확인 불가"로
  표기했다 — `orchestrator_provider.dart`, `interpretation_narrator.dart`,
  `story_detail_screen.dart`/`story_preview_screen.dart`/
  `saju_renewal_provider.dart`의 세부 내용, admin_web `saju-judgment.ts`/
  `saju-qa-check.ts`/`saju-render.ts`(레거시 ②번 경로 전용이므로 ①번 시스템
  분석에는 영향 없음)의 전체 내용은 이번 보고서 범위에서 상세 분석하지 않았다.
