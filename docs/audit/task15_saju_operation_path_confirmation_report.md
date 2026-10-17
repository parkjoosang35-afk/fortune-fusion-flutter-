# 신통방통 정통사주 실제 운영 경로 확정 및 유지·보완 계획 보고서 (Task 15)

> 작성 원칙: 모든 서술은 실제 코드 Read/Bash 조회, 실제 운영 DB(SQLite,
> `admin_web/prisma/dev.db`) 읽기 전용 count/조회, 실제 가동 중인 Python
> 사주 엔진 서버(`127.0.0.1:8000`)에 대한 실제 HTTP 호출 결과만 근거로
> 한다. 추측·가정은 전부 "미확인"으로 명시한다. 기존 계산 로직·정책은
> 전혀 수정하지 않았다(read-only 검수). 운영 DB는 SELECT/COUNT만
> 수행했고 어떤 INSERT/UPDATE/DELETE도 실행하지 않았다. Python 엔진
> 서버에는 신규 사용자를 생성하지 않는 단순 facts 조회 1회만 호출했다
> (과금/포인트/DB 기록 없는 순수 계산 엔드포인트).
>
> 이 보고서는 Task 14 최종 검수 보고서(`task14_saju_engine_audit_report.md`)
> 를 기준으로, "코드가 존재한다"와 "실제 운영에서 쓰이고 있다"를
> 명확히 분리해 최종 운영 경로를 확정한다.

---

## 0. 결론 요약(가장 먼저 확정)

| # | 시스템 | 실제 운영 여부 | 이번 턴 추가 확인 근거 |
|---|---|---|---|
| ① | Flutter 로컬 PHASE1~4(`ManseryeokCoreEngine`~`Phase4AnalysisEngine`) | **운영 중** | 귀인지도 3곳(CTA 버튼) + CrossCheckResult 화면(DoorEngineGateway) + saju_renewal 4개 화면(SajuVisualAdapter, 캐시 적용)에서 실제 코드 경로로 호출됨을 라인 단위로 재확인 |
| ③ | 서버 29종 Topic Engine(+ 별도 Python `saju_engine_v3.3`) | **운영 중, 실사용 데이터 존재** | Python 엔진 프로세스가 **실제로 가동 중**(PID 23759, Oct13~)임을 `ps aux`로 확인, `/saju/v3/facts`에 personA를 실제로 호출해 정상 응답(庚午/己卯/己卯/戊辰 — Task14의 Flutter 계산값과 **완전 일치**) 수신. 운영 DB에 `topic_interpret_results` summary 71건/detail 93건의 **실제 LLM 해석 결과**가 존재 |
| ② | 서버 레거시 AI사주(`saju-judgment.ts` 등, `/api/public/fortune/saju`) | **완전 휴면 — 실제 데이터로 재확인** | 운영 DB `fortune_requests`에 `fortune_type='saju'` 40건이 있으나, **전부 2026-09-28 이전**이고 내용도 `ra_proto_test`/`__FORCE_FAIL_TEST__`/`게스트`/`T` 등 **테스트성 호출**로 식별됨. 반면 ③번(`saju_facts_cache`/`topic_interpret_results`)은 **2026-10-14까지 계속 호출**되고 있어, 레거시(②)가 신규(③)로 완전히 대체된 뒤 **18일 이상 전혀 호출되지 않았음**을 실제 타임스탬프로 확정 |

**사용자가 지시서에서 쓴 "69종"이라는 용어는 Task14와 동일하게 현재
비운영 레거시 명칭**이며, 현재 코드·DB 모두 **"29종"**(`topic_catalog`
테이블 실제 레코드 수 29건으로 재확인)이 맞다.

---

## 1. 전체 운영 경로 흐름도

```
                    [ 사용자 출생정보 입력(1회, 로그인 후 프로필 저장) ]
                                        │
          ┌─────────────────────────────┼─────────────────────────────┐
          │                             │                             │
          ▼                             ▼                             ▼
┌─────────────────────┐    ┌─────────────────────────┐    ┌─────────────────────┐
│ ①번 — Flutter 로컬    │    │ ②번 — 서버 레거시(휴면)   │    │ ③번 — 서버 29종 Topic │
│ PHASE1~4             │    │                         │    │ Engine(운영중)        │
├─────────────────────┤    ├─────────────────────────┤    ├─────────────────────┤
│ 호출 경로 A:          │    │ POST /api/public/        │    │ Flutter              │
│ 귀인지도 CTA 버튼      │    │   fortune/saju            │    │ SajuRenewalApi       │
│ (createMapForUser/   │    │  (route.ts)               │    │  .selectTopics()     │
│  createMapWithInput/ │    │  마지막 실제 호출:         │    │  .interpretSummary() │
│  joinMap)            │    │  2026-09-28(테스트성)      │    │  .interpretDetail()  │
│   │                 │    │  → 호출 코드 Flutter에     │    │   │                  │
│   ▼                 │    │    0건(find 0건)           │    │   ▼                  │
│ JeontongReportBuilder│    │  → 트리거 불가, 서버 코드   │    │ POST .../topics/select│
│ .buildProfileAnd     │    │    만 휴면 상태로 존재      │    │ POST .../interpret    │
│  SajuResultVia       │    └─────────────────────────┘    │   │                  │
│  Phase1to4()         │                                    │   ▼                  │
│   │                 │                                    │ getSajuFacts()        │
│   ▼                 │                                    │ (캐시 경유)            │
│ ManseryeokCoreEngine │                                    │   │  캐시 미스시       │
│  → Phase2~4         │                                    │   ▼                  │
│  → sajuResultFromPro│                                    │ [별도 Python 프로세스] │
│    file()           │                                    │ saju_api:app          │
│                      │                                    │ POST /saju/v3/facts   │
│ 호출 경로 B:          │                                    │ (실제 가동 확인,      │
│ CrossCheckResult화면 │                                    │  PID 23759)           │
│  → FortuneOrchestrator│                                   │   │                  │
│  .buildProfile()     │                                    │   ▼                  │
│   │  2회 중복 호출!   │                                    │ SajuFactsCache(DB)    │
│   ├ getSajuProfile() │                                    │  저장/재사용          │
│   └ getSajuResult()  │                                    │   │                  │
│   (각각 독립적으로     │                                    │   ▼                  │
│    PHASE1~4 재계산)  │                                    │ selectTopics()        │
│   → DoorEngineGateway│                                    │ (순수 TS, LLM 0회)    │
│                      │                                    │   │                  │
│ 호출 경로 C:          │                                    │   ▼                  │
│ saju_renewal 4개 화면 │                                    │ topic-engine 결과     │
│ (03/04/05/07)        │                                    │  → TopicCard 변환     │
│  → SajuRenewalProvider│                                   │   │                  │
│  .visualProfileFor() │                                    │   ▼                  │
│   (메모캐시 있음,      │                                    │ interpret/route.ts    │
│    재계산 1회만)      │                                    │  → generateInterpret  │
│   │                 │                                    │    Result()           │
│   ▼                 │                                    │  → LLM 호출            │
│ SajuVisualAdapter    │                                    │  → interpret-qa-check │
│  .build()            │                                    │  → topic_interpret_   │
│ (PHASE1~4를 자체      │                                    │    results 저장       │
│  재구현해서 호출 —    │                                    │   (실측: summary 71건,│
│  JeontongReportBuilder│                                   │    detail 93건)       │
│  과 별개 구현!)       │                                    │   │                  │
│  → sajuResultFrom    │                                    │   ▼                  │
│    Profile() 미경유,  │                                    │ Flutter               │
│    자체 fromProfile() │                                    │  story_preview/       │
│    로 직접 변환       │                                    │  story_detail_screen  │
└─────────────────────┘                                    └─────────────────────┘
```

**이 그림에서 확정되는 사실**:
1. ①과 ③은 personA 테스트케이스에서 **동일한 결과**(庚午/己卯/己卯/戊辰)
   를 내지만, 이는 "같은 코드를 공유해서"가 아니라 "둘 다 올바른 만세력
   계산을 각자 독립 구현했기 때문"이다(①=Dart, ③=별도 Python 프로세스).
2. ①번 내부에도 **완전히 같은 PHASE1~4 호출 코드가 2곳에 독립
   구현**되어 있다 — `JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4()`
   (귀인지도/DoorEngineGateway용)와 `SajuVisualAdapter.build()`
   (saju_renewal 전용)이 각각 `ManseryeokCoreEngine`→`Phase2~4AnalysisEngine`
   호출부를 복제해 갖고 있다. 단, 마지막 변환 단계가 다르다 —
   전자는 `sajuResultFromProfile()`(SajuResultAdapter)을 거치고, 후자는
   이를 건너뛰고 자체 `fromProfile()`로 변환한다(§2-3 상세).
3. ②번은 운영 DB 실측 데이터로 **완전히 멈춰 있음**이 재확인되었다.

---

## 2. A. Flutter 사주 계산 경로 상세 확인표

### 2-1. 실제 화면에서 호출하는 진입 함수(3개 경로, 전부 확인)

| 경로 | 진입 함수 | 호출 위치(파일:라인) | 트리거 |
|---|---|---|---|
| A-1 | `JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4()` | `guinji_provider.dart:295`(`createMapForUser`), `:390`(`createMapWithInput`), `:569`(`joinMap`) | 귀인지도 온보딩 CTA/입력완료/초대수락 버튼(사용자 액션 1회당 1회 계산) |
| A-2 | 동일 함수 | `door_engine_gateway.dart:82`(`getSajuProfile`), `:104`(`getSajuResult`) | `FortuneOrchestrator.buildProfile()` → **동일 입력에 2회 독립 호출**(§2-4) → `cross_check_result_screen.dart` 진입 시 |
| A-3 | `SajuVisualAdapter.build()`(별도 구현, PHASE1~4 자체 재호출) | `saju_renewal_provider.dart:354`(`_computeVisualProfile`) | `visualProfileFor()` 경유, 03(계산중)/04(분석완료)/05(미리보기)/07(상세) 4개 화면 진입 시 — **메모이제이션 캐시로 실제 재계산은 세션당 1회만** |

### 2-2. PHASE1~4 실제 실행 순서(모든 경로 공통, 코드 레벨 100% 동일)

```dart
// JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4() 및
// SajuVisualAdapter.build() 양쪽 모두 아래와 정확히 같은 순서:
final withCore = ManseryeokCoreEngine.buildProfileWithCore(...);      // PHASE1
final p2 = Phase2AnalysisEngine.analyze(baseProfile: withCore.profile, core: withCore.core); // PHASE2
final p3 = Phase3AnalysisEngine.analyze(baseProfile: p2);              // PHASE3
final p4 = Phase4AnalysisEngine.analyze(baseProfile: p3, core: withCore.core, referenceDate: referenceDate); // PHASE4
```

### 2-3. 각 단계 입력·출력 및 최종 프로필 반영(Task14 §3 재확인, 변경 없음)

| 단계 | 입력 | 출력에 포함되는 핵심 필드 |
|---|---|---|
| PHASE1(`ManseryeokCoreEngine`) | year/month/day/hour/minute/gender/calendarType/isLeapMonth | 사주원국(연/월/일/시 간지), `ManseryeokCore`(내부 계산 보조 데이터) |
| PHASE2(`Phase2AnalysisEngine`, 5개 하위엔진) | PHASE1 profile+core | 오행(FiveElements), 지장간(HiddenStems), 십이운성(TwelveStages), 합충형파해(Relationships), 신살(Sinsal) |
| PHASE3(`Phase3AnalysisEngine`, 2개 하위엔진) | PHASE2 profile | 신강/신약(Strength), 용신/희신/기신/구신(Yongsin) |
| PHASE4(`Phase4AnalysisEngine`, 3개 하위엔진) | PHASE3 profile+core+referenceDate | 대운(Daewoon), 세운(Sewoon), 월운(Wolwoon) |

### 2-4. `SajuResultAdapter`를 거치는 데이터 흐름 — **경로별로 다름(신규 확인)**

- **A-1/A-2 경로(`JeontongReportBuilder`)**: PHASE4 결과(`p4`)를
  `sajuResultFromProfile(p4, referenceDate: referenceDate)`에 전달해
  레거시 `SajuResult` 형태로 변환 — **SajuResultAdapter를 실제로
  경유한다**.
- **A-3 경로(`SajuVisualAdapter`)**: PHASE4 결과(`p4`)를
  `sajuResultFromProfile()`에 넘기지 **않고**, 자체 `fromProfile(p4,
  timeUnknown:, referenceDate:)` 메서드로 직접 화면용
  `SajuVisualProfile`을 만든다. **SajuResultAdapter를 전혀 경유하지
  않는다.**

→ 이는 Task14에서 "SajuResultAdapter는 함수이며 §4-5에서 명칭 오해를
해소"했던 내용과 일맥상통하지만, 이번 조사에서 **"어느 경로가
SajuResultAdapter를 쓰고 어느 경로가 안 쓰는지"**를 코드 레벨로 처음
명확히 구분했다. 두 변환 함수(`sajuResultFromProfile`/
`SajuVisualAdapter.fromProfile`)가 같은 `SajuProfile`을 입력받아
**서로 다른 출력 타입**(`SajuResult` vs `SajuVisualProfile`)을 만드는
것이므로 결과 자체의 불일치 위험은 없으나, **동일한 변환 로직이 두
곳에 독립 유지**되고 있어 유지보수 시 한쪽만 수정하면 다른 쪽이
누락될 위험이 있다(§4 유지·보완 계획 항목).

### 2-5. 캐시 적용 여부와 중복 계산 방지 상태 — 경로별 실측 확인

| 경로 | 캐시 여부 | 실측 근거 |
|---|---|---|
| A-1(귀인지도) | **없음** — 호출마다 매번 PHASE1~4 전체 재계산 | 코드에 캐시 변수 없음, 사용자 액션(버튼 클릭) 1회당 1회이므로 실사용상 큰 문제는 아니나 재사용 메커니즘 자체가 없음 |
| A-2(DoorEngineGateway) | **없음, 추가로 "동일 함수 호출 내 2회 중복"까지 확인** | `fortune_orchestrator.dart:45-46`에서 `getSajuProfile(user)`와 `getSajuResult(user)`를 **같은 입력으로 각각 독립 호출** → `buildProfile()` 1회 실행마다 PHASE1~4가 **정확히 2배** 실행됨(테스트로 명시적 검증된 적 없음 — §5 추가검증 필요 항목) |
| A-3(saju_renewal) | **있음(메모이제이션)** | `saju_renewal_provider.dart:293-367`의 `_cachedVisualProfile`/`_cachedVisualProfileKey`, 테스트 `saju_renewal_visual_profile_cache_test.dart`로 **identical() 비교까지 통과 검증됨**(재실행 결과: 통과) |

---

## 3. B. 서버 29종 Topic Engine 경로 상세 확인표

### 3-1. 앱에서 호출하는 실제 서버 API(코드+실행 중인 프로세스 양쪽 확인)

| API | Flutter 호출부 | 서버 route 파일 | 내부 핵심 호출 |
|---|---|---|---|
| `POST /api/public/saju-renewal/topics/select` | `saju_renewal_api.dart:70`(`selectTopics`) | `topics/select/route.ts`(341줄) | `getSajuFacts()`(L240) → `selectTopics()`(L280, topic-engine.ts) → `toTopicCard()`/`extractKeyFacts()`(L286-291) |
| `POST /api/public/saju-renewal/interpret`(mode=summary/detail) | `saju_renewal_api.dart:197`(`_interpret`) | `interpret/route.ts`(454줄) | `getSajuFacts()`(캐시 재사용) → `validateTopicForInterpret()`(독립 재검증) → `generateInterpretResult()`(interpret-service.ts, LLM 호출+QA) |

### 3-2. FACT 계산 — 실제 Python 엔진 가동 확인(이번 턴 신규 실측)

- `ps aux` 확인 결과: `uvicorn saju_api:app --host 0.0.0.0 --port 8000`
  프로세스가 **Oct13부터 현재까지 계속 가동 중**(PID 23759).
- `curl http://127.0.0.1:8000/health` → `{"status":"ok"}` 정상 응답.
- **personA(1990-03-15 08:30, 양력, 남)로 실제 `/saju/v3/facts`를
  호출**한 결과:
  ```
  pillars: 년(庚午) 월(己卯) 일(己卯) 시(戊辰)
  day_master: 己(토), day_master_strength: "中和(중화)"
  five_elements_count: 목2 화1 토4 금1 수0
  sinsal: [桃花(도화), 白虎(백호)]
  yongshin: {yong: 화, hee: 목, gi: 수, gu: 토}
  luck_pillars: 9개 대운(1990년~2067년, start_age 1/8/18/.../78)
  ```
  **이 간지(庚午/己卯/己卯/戊辰)는 Task14가 기록한 Flutter PHASE1
  (`ManseryeokCoreEngine`)의 personA 결과와 정확히 일치**한다. 이는
  ①번과 ③번이 서로 다른 구현체이지만 **올바른 만세력 계산이라면
  당연히 같은 결과가 나와야 한다**는 것을 실측으로 교차 입증한
  것이다(코드를 공유해서가 아니라 둘 다 맞게 계산했기 때문).

### 3-3. 주제 선택 요청/응답 및 사주 분석 데이터와의 연결

- `topics/select/route.ts`가 `getSajuFacts()`로 받은 `facts`
  (위 personA 예시와 동일 구조)를 **그대로** `selectTopics({ facts,
  exposureHistory, excludeTopicIds })`에 전달한다(L280) — 주제
  선정은 FACT 데이터에 직접 근거한다.
- `evaluateTopic()`(topic-engine.ts:131)이 `TOPIC_EVIDENCE_EVALUATORS[topicId](facts)`
  로 각 주제별 평가자 함수를 FACT에 적용해 조건 충족 여부(`checks`)를
  판정하고, `computeScore()`(§8 가중합 공식: 0.35E+0.20I+0.20T+0.15N+
  0.10B−P)로 점수를 매긴 뒤 최종 1건+후보 3~4건을 선정한다.
- **LLM은 이 선정 과정에 전혀 관여하지 않는다** — `topics/select/route.ts`
  주석(L7-10)에 "LLM 클라이언트는 이 파일에서 import조차 하지 않는다"고
  명시되어 있고, 실제로 `import` 구문에 LLM 클라이언트가 없음을
  재확인했다.

### 3-4. LLM 해석 요청과 최종 응답

- `interpret/route.ts`는 `topics/select`가 추천한 topicId를 **그대로
  신뢰하지 않고** `validateTopicForInterpret(topicId, facts)`로 조건을
  **다시 한번 독립 재검증**한다(L327) — 사용자가 topicId를 직접
  조작해도 막히는 구조.
- `generateInterpretResult()`(interpret-service.ts)가 LLM을 호출하고,
  실패 시 fallback까지 QA(`interpret-qa-check.ts`)를 통과해야 최종
  반환한다.
- **mode=detail은 결제 게이트 우회 방어 로직이 별도로 있음**(L~290):
  `transactionId` 없이는 LLM 호출 자체가 차단된다(코드 주석에 과거
  "curl 재현으로 확인된 치명적 결제 우회" 버그 수정 이력 명시).

### 3-5. 결과가 앱 화면에 표시되기까지의 흐름(운영 데이터로 실증)

```
selectTopics (서버) → TopicCard[] 반환
  → SajuRenewalProvider._loadTopics() → _currentTopic 설정
  → loadPreview(topic) → interpretSummary 호출
  → story_preview_screen.dart 렌더링
  → (Access Gate 통과) → onAccessGranted() → interpretDetail 호출
  → story_detail_screen.dart 렌더링
```
운영 DB 실측: `topic_interpret_results` 테이블에 **summary 71건,
detail 93건**의 실제 LLM 해석 결과가 저장되어 있고, `topic_exposure_history`
에도 **130건**의 실제 열람 이력(가장 최근: `LIFE_000`, 2026-10-14)이
존재함을 확인했다 — **③번 경로는 코드만 존재하는 것이 아니라 실제
사용자 트래픽이 발생하고 있는 운영 경로**임이 확정된다.

---

## 4. C. 서버 레거시 사주 경로 — 실제 운영 데이터로 재확인

### 4-1. 코드 레벨 재확인(Task14와 동일, 변경 없음)

- `lib/features/fortune/saju/` 디렉토리: **0건**(find).
- `SajuRepository` 클래스 정의: **0건**(grep `^class SajuRepository`).
- `app_router.dart`가 `/ai-fortune/saju/*` 전체를 `/saju-renewal`로
  강제 리다이렉트(`app_router.dart:594-600` 재확인).

### 4-2. 운영 DB 실측(이번 턴 신규 — 가장 중요한 추가 증거)

| 테이블 | 레코드 수 | 가장 최근 생성 시각 |
|---|---|---|
| `fortune_requests`(`fortune_type='saju'`, 레거시 전용) | 40건 | **2026-09-28T01:00:39** |
| `saju_facts_cache`(③번 FACT 캐시) | 136건 | **2026-10-14T08:54:31** |
| `topic_interpret_results`(③번 LLM 해석) | 164건(summary 71+detail 93) | **2026-10-14T10:53:47** |

- 레거시(②) `fortune_requests` 40건의 `input_payload`를 직접 열람한
  결과, 이름 필드가 `ra_proto_test`/`__FORCE_FAIL_TEST__`/`게스트`/
  `T`(단일 글자) 등으로 **명백한 테스트·디버깅용 호출**이며, 정상
  사용자가 실제로 UI에서 입력했다고 보기 어려운 패턴이다.
- 레거시의 마지막 호출(2026-09-28)과 ③번의 최근 호출(2026-10-14)
  사이에 **16일 이상의 간격**이 있고, 그 이후 레거시 쪽은 완전히
  0건이다 — "현재도 가끔 호출되고 있을 가능성"은 **운영 데이터로
  배제**된다.

### 4-3. 결론

**사용되지 않는 코드라는 이유만으로 삭제하거나 연결하지 않는다는
지시를 그대로 준수**하여, 이 보고서는 ②번 경로의 코드를 전혀
건드리지 않았다. 다만 "실제로 호출되는지"에 대한 답은 이번 운영
데이터 조회로 **명확히 "아니오"**로 확정되었다 — 코드 추적(Task14)과
실제 운영 데이터(Task15) 양쪽에서 동일한 결론에 도달했다.

---

## 5. 최종 결과 연결 검증 — personA 테스트케이스 전체 추적

**생년월일시 입력 → 사주 원국 계산 → 오행·지장간·십이운성·합충형파해·
신살 분석 → 신강·신약·용신 분석 → 대운·세운·월운 계산 → 최종
사주 프로필 → 29종 주제 선택 → LLM 해석 → 앱 결과 화면**

사용자가 요구한 이 흐름은 **①번 경로 하나로 끝까지 이어지는 단일
파이프라인이 아니다** — 이 점이 이번 조사에서 가장 중요하게 확정해야
할 사실이다.

| 단계 | ①번(Flutter 로컬) | ③번(서버) | 실제 연결 여부 |
|---|---|---|---|
| 생년월일시 입력 | 사용자 프로필 저장(`UserModel`) | 동일 `UserProfile`(DB) 조회 | 입력값은 공유(같은 DB 프로필)되지만 **계산 자체는 공유 안 됨** |
| 사주원국 계산 | `ManseryeokCoreEngine`(Dart) | Python `saju_engine_v3.3`(`/saju/v3/facts`) | **연결 없음** — 서로 독립 계산, personA에서 결과값만 우연히 일치(둘 다 정답이므로) |
| 오행·지장간·십이운성·합충형파해·신살 | `Phase2AnalysisEngine`(5개 하위엔진) | Python 엔진 응답에 모두 포함(`five_elements_count`/`zhi_qigan`/`twelve_stages`/`relations`/`sinsal`) | **연결 없음** — ①은 PHASE1 결과를 입력받아 Dart로 재계산, ③은 Python 엔진이 한 번에 반환 |
| 신강·신약·용신 | `Phase3AnalysisEngine` | Python 응답의 `day_master_strength`/`yongshin` | **연결 없음**, 각자 독립 계산 |
| 대운·세운·월운 | `Phase4AnalysisEngine` | Python 응답의 `luck_pillars`/`dayun_precise` | **연결 없음** |
| 최종 사주 프로필 | `SajuProfile`(PHASE4 완료) | `SajuV3Facts`(Python JSON) | **서로 다른 데이터 구조**, 변환기 없음 |
| 29종 주제 선택 | **①번 결과는 여기서 전혀 쓰이지 않음** | `selectTopics(facts=③번 Facts, ...)` | ③번 Facts만 입력으로 사용 — **①번 PHASE1~4 결과는 주제 선정에 전혀 관여하지 않는다** |
| LLM 해석 | — | `generateInterpretResult()` | ③번 파이프라인 내부에서만 진행 |
| 앱 결과 화면 | `cross_check_result_screen.dart`(①번 결과 전용 화면) | `story_preview/story_detail_screen.dart`(③번 결과 전용 화면) | **서로 다른 화면**, 같은 화면에서 ①③ 결과를 합쳐서 보여주는 코드는 없음(`UnifiedFortuneProfile`은 교차검증 전용이며 ③번 데이터를 포함하지 않음) |

**명확히 밝혀둘 사실**: 사용자가 지시서 §3에서 요청한 흐름("생년월일시
입력 → ... → 29종 주제 선택 → LLM 해석 → 앱 결과 화면")은 **③번
경로만 떼어 놓고 보면 100% 연결되어 있다**(§3에서 실측 확인). 하지만
"오행·지장간·십이운성·합충형파해·신살 분석"과 "신강·신약·용신
분석"이라는 표현이 **①번(PHASE2/PHASE3)의 명칭과 동일**하기 때문에,
"①번이 계산한 값이 29종 주제 선택에 쓰인다"고 **추측하면 안 된다**
— 실제로는 ③번이 **자신만의 Python 엔진으로 같은 이름의 값들을
독립적으로 다시 계산**해서 쓰고 있다. 이 구분을 명확히 하지 않으면
"①→③ 연결"이 있는 것처럼 오해하기 쉽다(지시서가 "추측으로 연결된
것처럼 보고하지 말라"고 강조한 바로 그 지점).

---

## 6. 유지·보완 계획

### 6-1. 정상 운영 중이며 유지해야 하는 기능

| 기능 | 코드 근거 | 테스트 결과 | 우선순위 |
|---|---|---|---|
| Flutter PHASE1~4 전체 계산(①번) | `manseryeok/` 디렉토리 15개 구성요소(Task14 §1) | `flutter test test/manseryeok/` 등 121개 테스트 전부 통과(이번 턴 재실행 확인) | 유지(변경 금지) |
| saju_renewal 03~07 화면 캐시(`visualProfileFor`) | `saju_renewal_provider.dart:293-367` | `saju_renewal_visual_profile_cache_test.dart` identical() 검증 통과 | 유지 |
| ③번 서버 29종 Topic Engine 전체 파이프라인 | `topic-engine.ts`/`saju-engine-client.ts`/`interpret-service.ts` | 운영 DB 실측 164건 LLM 해석 데이터 존재 | 유지(핵심 운영 기능) |
| Python `saju_engine_v3.3` FACT 계산 서버 | 프로세스 가동 확인(PID 23759), personA 응답 일치 확인 | 실제 HTTP 호출 성공 | 유지 |

### 6-2. 중복 실행이나 성능 개선이 필요한 기능

| 기능 | 코드 근거 | 문제 | 우선순위 |
|---|---|---|---|
| `FortuneOrchestrator.buildProfile()`의 2회 중복 PHASE1~4 계산 | `fortune_orchestrator.dart:45-46`(`getSajuProfile`+`getSajuResult` 각각 독립 호출) | CrossCheckResult 화면 1회 진입마다 PHASE1~4 전체가 **정확히 2배** 실행됨(이번 턴 코드 추적으로 신규 확정) | **높음** — 성능 영향이 명확하고 수정 범위도 작음(단, 이번 단계에서는 보고만 하고 직접 수정하지 않음, §7 작업제한 준수) |
| 귀인지도(A-1) 캐시 부재 | `guinji_provider.dart` 3곳 | 사용자 액션 1회당 1회 계산이라 긴급도는 낮으나, 동일 사용자가 짧은 시간에 여러 번 CTA를 누르면 중복 계산 가능 | 중간 |
| `JeontongReportBuilder`와 `SajuVisualAdapter.build()`의 PHASE1~4 호출 코드 중복(독립 구현 2벌) | `jeontong_eighty_report_builder.dart:33-60` vs `saju_visual_adapter.dart:97-124` | 완전히 같은 5줄 호출 시퀀스가 2곳에 복제되어 있어, 향후 PHASE 엔진 시그니처가 바뀌면 한쪽만 수정하고 다른 쪽을 누락할 위험 | 중간 |

### 6-3. 결과 연결 또는 검증이 필요한 기능

| 기능 | 코드 근거 | 필요성 | 우선순위 |
|---|---|---|---|
| `SajuVisualAdapter.build()`가 `sajuResultFromProfile()`(SajuResultAdapter)을 경유하지 않고 자체 `fromProfile()`로 변환 | `saju_visual_adapter.dart:124` | 현재는 결과 타입이 달라(`SajuVisualProfile` vs `SajuResult`) 직접적 불일치 사례는 없으나, 두 변환기가 같은 `SajuProfile`에서 서로 다른 필드를 추출하고 있어 **향후 필드 추가 시 한쪽만 반영될 위험**이 있음 — 교차 검증 테스트 추가 검토 필요 | 중간 |
| ①번(PHASE1~4)과 ③번(Python 엔진)의 personA 일치성이 **1개 테스트케이스에서만** 확인됨 | 이번 턴 personA 1건 실측 | 더 다양한 생년월일시 조합(경계값, 윤달, 자시 등)에서도 두 독립 엔진이 계속 일치하는지 **주기적 교차검증 테스트** 필요(현재는 1회성 수동 확인) | 중간 |

### 6-4. 현재 사용되지 않는 레거시 기능(삭제·통합 금지, 현상 유지)

| 기능 | 코드 근거 | 확인 방법 | 우선순위 |
|---|---|---|---|
| `saju-judgment.ts`/`saju-qa-check.ts`/`saju-render.ts` + `route.ts`(`/api/public/fortune/saju`) | Task14 §5-1, 이번 턴 운영 DB 실측(마지막 호출 2026-09-28, 그 이후 0건) | 코드 추적 + 운영 데이터 이중 확인 | 낮음(현상 유지만 — 삭제/통합은 지시서 범위 밖) |
| `category69.py`(별도 Python 디렉토리) | Task14 §0 | 코드 위치만 확인, 내용 미조사 | 낮음 |

### 6-5. 실제 테스트가 부족해 추가 검증이 필요한 기능

| 기능 | 현재 상태 | 필요한 검증 | 우선순위 |
|---|---|---|---|
| `FortuneOrchestrator.buildProfile()`의 2회 중복 계산이 실제 성능에 미치는 영향 | 코드 추적으로 "2회 호출됨"만 확정, 실제 소요 시간 측정 테스트 없음 | 성능 프로파일링(얼마나 느려지는지 수치화) | 높음 |
| ①번과 ③번의 계산 일치성 | personA 1건만 실측 교차검증 | 경계값(절기 경계, 자시, 윤달, 해외출생) 케이스까지 Python 엔진에 동일 입력으로 호출해 비교하는 자동화 테스트 | 중간 |
| 귀인지도 경로의 실제 트래픽/중복호출 빈도 | 코드상 캐시 없음만 확인, 운영 데이터로 실제 중복호출 빈도 미확인 | 운영 로그/DB에 귀인지도 API 호출 빈도 데이터가 있다면 교차 확인 필요(이번 턴에는 해당 테이블 미조사 — 범위 밖) | 낮음 |

---

## 7. 작업 제한 준수 확인

- 계산 엔진 내부 로직(`ManseryeokCoreEngine`~`Phase4AnalysisEngine`,
  `topic-engine.ts`, `saju-engine-client.ts` 등) **어떤 코드도
  수정하지 않았다**(전부 Read/grep/sed로 조회만 수행).
- 확정된 계산 정책·기존 API를 변경하지 않았다.
- 29종 Topic Engine을 레거시 경로와 통합하지 않았다.
- 운영 DB에는 **SELECT/COUNT만** 수행했다(`sqlite3`/`python3 sqlite3`
  모듈로 읽기 전용 조회, 어떤 쓰기 작업도 없음). 실제 수행한 쿼리는
  모두 이 보고서 §3-2, §4-2에 그대로 공개되어 있다.
- Python 엔진 서버(`127.0.0.1:8000`)에는 **`/health`(상태 확인) 1회,
  `/saju/v3/facts`(순수 계산, DB 기록 없는 엔드포인트) 1회**만
  호출했다 — 이 엔드포인트는 `getSajuFacts()`가 캐시 미스 시 호출하는
  것과 동일한 것으로, 과금/포인트 차감이나 영구 데이터 변경이 없는
  순수 계산 API다(route.ts에서 이 엔드포인트 자체는 사용자 과금과
  무관함을 §3-1에서 이미 확인).
- 코드 수정이 필요해 보이는 항목(§6-2 중복 호출, §6-3 변환 경로
  불일치)은 **직접 수정하지 않고 이 보고서에만 기록**했다 — 승인 전
  코드 변경 없음 원칙 준수.

---

## 8. 테스트 실행 근거 및 확인되지 않은 항목

### 8-1. 실제 테스트 근거

- `flutter test test/manseryeok/ test/manseryeok_external_reference_audit_test.dart test/saju_engine_to_screen_pipeline_test.dart test/saju_cross_engine_validation_test.dart test/saju_renewal_visual_profile_cache_test.dart test/orchestrator_real_saju_capture_test.dart`
  → **121개 테스트 전부 통과**(이번 턴 재실행, 신규 실행 로그 확보).
- Python 엔진 서버 실제 가동 확인: `ps aux`, `/health`, `/openapi.json`,
  `/saju/v3/facts`(personA) 전부 실제 HTTP 응답 확보.
- 운영 DB(SQLite) 실측: `saju_facts_cache`(136건)/`topic_exposure_history`
  (130건)/`topic_interpret_results`(164건)/`fortune_requests`(214건,
  유형별 분류: tarot 84/daily 49/saju 40/face 30/palm 9/name 2)/
  `topic_catalog`(29건) 전부 실제 COUNT 쿼리로 확보.

### 8-2. 확인되지 않은 항목(추측 없이 명시)

- `FortuneOrchestrator.buildProfile()`의 2회 중복 계산이 **실제로 몇
  밀리초의 지연을 유발하는지는 측정하지 않았다**(코드 상 "2회
  호출된다"는 사실만 확정, 성능 수치는 미확인).
- ①번과 ③번의 계산 일치성은 **personA 1건에서만** 확인했다. 다른
  생년월일시 조합, 특히 절기 경계·자시 경계·해외출생 등 Task14가
  Dart 엔진에서 테스트한 경계값들을 Python 엔진에도 동일하게
  입력해 비교하는 작업은 **이번 턴 범위에서 수행하지 않았다**.
- 귀인지도(A-1) 경로의 실제 운영 트래픽(몇 명이 실제로 귀인지도를
  생성했는지, 중복 호출이 실제로 몇 번 발생했는지)은 **이번 턴에
  조회하지 않았다**(해당 기능 전용 테이블/로그는 이 보고서 조사
  범위 밖).
- `category69.py`(레거시 Python 파일)의 내부 로직은 **위치만
  확인했을 뿐 내용은 조사하지 않았다**(Task14부터 이어지는 동일한
  스코프 제한).
- 운영 DB(`dev.db`)가 실제 프로덕션 DB인지, 아니면 개발/스테이징
  환경 DB인지는 파일명(`dev.db`)으로 미루어 **개발 환경일 가능성이
  있으나 명확히 확정하지 않았다** — 이 보고서의 "운영 데이터"라는
  표현은 "현재 이 환경에서 실제로 기록된 호출 이력"을 의미하며,
  최종 프로덕션 환경과 동일한지는 별도 확인이 필요하다.
