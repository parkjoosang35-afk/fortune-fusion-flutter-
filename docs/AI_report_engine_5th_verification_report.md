# AI 정통사주 해석 엔진 v1.0 (5차 지시서) 검증 + 9 PART 리포트 화면 신규 구현 완료 보고서

작성일: 세션 (5차 지시서 대응 단계)
검증 대상: `SINTONGBANGTONG_AI_SAJU_FINAL_v1.0.zip` (개발자 5차 전달분) + Flutter 클라이언트 신규 화면
목적: 개발자가 "487항목 전부 통과"라고 주장한 신규 AI 해석 엔진 패키지를 코드 레벨로 직접 재검증하고,
      배포 서버에 반영한 뒤, 이를 사용하는 Flutter 신규 화면("AI 장문 리포트 보기")을 구현·검증한다.

---

## Phase A — 5차 지시서 패키지 검증 및 배포

### 1. 검증 범위
개발자 진행보고서(`AI해석엔진_진행보고서_20260926.md`)가 주장한 내용을 각각 코드 레벨로 재확인했다.
"개발자 주장 → 신뢰"가 아니라 "개발자 주장 → 실측 검증"을 원칙으로 진행했다.

| 개발자 주장 | 검증 방법 | 결과 |
|---|---|---|
| 계산 엔진(`saju_facts.py`·`saju_calculator.py`·`category69.py`) 1줄도 수정 없음 | `diff` 파일 단위 전수 비교 (핵심 4파일 + `modules/`·`rules/`·`access_control/`·`flutter_integration/` 전체) | **100% 동일 확인** |
| ai_layer 신규 8모듈(입력정제/시간문맥/프롬프트/중복검사/QA/어뷰징가드/오케스트레이터) 구현 | 8개 모듈 전체 코드 리뷰 (`report_service.py` 153줄 전문 포함) | 지시서(§15~§31) 대응 로직 확인 |
| `/saju/v3/report` 신규 라우트, 기존 `/saju/v3/interpret`·`/saju/v3/facts` 계약 무변경 | `saju_api.py` diff | 기존 라우트 무변경, 신규 라우트만 추가됨을 확인 |
| 487항목 전부 통과 | 전체 테스트 스위트 재실행 | **487/487 통과** |

### 2. 발견 및 수정 — month=13 버그
개발자가 "422 검증에서 month=13이 BirthInput validation을 통과해 계산 예외를 유발한다"고 보고한 현상을
직접 재현했다.

- **재현**: `calculate_saju(1990, 13, 15, ...)` 호출 시 실제로는 422가 아니라 **500 미처리 예외**
  (`Exception: wrong month 13`, lunar_python 내부에서 발생)가 원인이었음 — 개발자 보고보다 한 단계
  정밀한 진단.
- **수정 원칙**: 계산 파일(`saju_calculator.py` 등)은 무변경 원칙을 유지하고, **API 계약 계층
  (Pydantic 스키마)에만** 패치를 적용했다.
  ```python
  class BirthInput(BaseModel):
      # [배포 사본 전용 패치 - 계산 로직 무관, API 계약(Pydantic 스키마)만 강화]
      year: int = Field(ge=1900, le=2100)
      month: int = Field(ge=1, le=12)
      day: int = Field(ge=1, le=31)
      hour: int = Field(default=12, ge=0, le=23)
      minute: int = Field(default=0, ge=0, le=59)
  ```
- **검증**: curl로 month=13 → 422, 정상 입력 → 200 확인.

### 3. 배포 반영
- 배포 서버(포트 8000, 이전 v3.3 최종납품)를 신규 v1.0 ai_layer 8모듈 + 신규 `saju_api.py` +
  신규 테스트 전체로 교체했다. 교체 전 전체 백업(`saju_engine_v3.3_최종납품.bak_*`)을 남겼다.
- 신규본 `saju_api.py`로 덮어쓰면서 사라진 개발용 CORS 미들웨어(4차 지시서 근거로 이전에 적용했던 것)를
  동일 원칙으로 재적용했다. 계산 로직과는 무관한 조치다.
- 배포 후 해당 위치에서 487항목 전체 재실행 → 전부 통과 확인.
- curl 실측: month=13→422 / 정상 입력→200(source=rule_fallback) / OPTIONS→200(CORS 헤더 확인).

### 4. 기존 화면 회귀 확인
Flutter 앱을 신규 배포 서버 기준으로 재빌드하고, 기존 계산결과 탭 / AI해석 탭이 그대로 동작하는지
스크린샷으로 확인했다. 두 탭 모두 정상.

---

## Phase B — 9 PART 장문 리포트 화면 신규 구현

### 1. 배경
5차 지시서로 신규 제공된 `POST /saju/v3/report`는 LLM 키가 없어도 즉시 테스트 가능하고
(`source=rule_fallback`), 402(프리패스 없음)/429(rate limit)/422(입력오류) 응답까지 규격화되어 있어
클라이언트(Flutter) 쪽에서 먼저 화면을 구현해도 서버의 실제 LLM 연결(PHASE 12, 비용 발생 항목이라
별도 승인 필요) 여부와 무관하게 동작을 완성할 수 있는 상태였다. 사용자 승인("진행")에 따라 기존
"Option 2" 클라이언트 아키텍처(ChangeNotifier + provider, Navigator, riverpod/go_router 미사용)를
그대로 따라 신규 화면을 구현했다.

### 2. 구현 내역

| 파일 | 유형 | 내용 |
|---|---|---|
| `lib/features/fortune/saju_v3/domain/saju_report.dart` | 신규 | `SajuReportPart`/`SajuReportBody`/`SajuReportPersonalization`/`SajuReportResult` 모델, `source`(llm/rule_fallback/cache) 판별 getter |
| `lib/features/fortune/saju_v3/data/saju_v3_api.dart` | 수정 | `getSajuV3Report()` 추가, `SajuV3ApiException`에 `isRateLimited`(429) 필드 추가, 402/429 응답 메시지 파싱 |
| `lib/features/fortune/saju_v3/application/saju_v3_provider.dart` | 수정 | 질문 텍스트를 key로 하는 `Map<String, LoadState<SajuReportResult>>` 캐시, `loadReport()`/`retryReport()` |
| `lib/features/fortune/saju_v3/presentation/saju_v3_report_screen.dart` | 신규 | 질문 입력 폼(300자 상한) + 9 PART 결과 렌더링 + fallback/cache 배너 + 402/429/기타 에러 분기 UI |
| `lib/features/fortune/saju_v3/presentation/saju_v3_home_screen.dart` | 수정 | "AI 장문 리포트 보기 (베타)" 진입 버튼 추가 |

- 402/429 에러 UI는 5차 지시서 "img2·주의" 항목 요구대로 문구를 구분했다: 402는 "열림패스가 필요해요"
  (🔒 아이콘), 429는 "요청 한도를 초과했어요"(⏳ 아이콘), 그 외는 일반 오류 문구 + 재시도 버튼.

### 3. 검증 — Playwright 클릭스루

이전 시도에서 "정통사주 v3 (베타)" 칩 클릭이 동일 좌표에서도 성공/실패가 불규칙했던 문제가 있었으나,
클릭 후 대기시간을 늘리고 전체 흐름을 하나의 연속 스크립트로 통합하자 안정적으로 재현되었다.

**정상 플로우 (rule_fallback)**
1. 전체보기 → "정통사주 v3 (베타)" 칩 클릭 → 생년월일시 8자리 키패드 입력 → 축시 선택 → 저장
2. "AI 장문 리포트 보기 (베타)" 버튼 클릭 → 질문 입력 폼 진입 확인
3. 질문("올해 재물운이 궁금해요") 입력 → "리포트 만들기" 제출
4. 네트워크 로그: `POST /saju/v3/report → 200`
5. 화면에 9 PART 전체(1.한눈에 보는 나 ~ 9.종합 분석) + rule_fallback 안내 배너
   ("AI 해석 준비 중입니다 — 검증된 룰 기반 해석으로 보여드려요") + summary + evidence chip 12개
   (pillars, day_master, strength, ten_gods, five_elements, yongshin, relations, daewoon, sewoon,
   weolwoon, question, time_context) 정상 렌더링 확인 (스크롤 포함 전체 확인)

**캐시 (source=cache)**
- 서버 레벨 curl로 동일 요청 재전송 시 `source: cache` 확인 (idempotency §16 동작 확인)

**402 (프리패스 없음)**
- `X-Free-Pass` 헤더 없이 요청 → 402, 서버 메시지에 "프리패스" 포함 → Flutter 매칭 로직 정상 동작 확인

**429 (rate limit)**
- 동일 프리패스 토큰으로 짧은 시간 내 4회 이상 요청 → 시간당 6회 한도 실제 트리거 → 429 확인
- Flutter 화면에서 ⏳ 아이콘 + "요청 한도를 초과했어요" + 서버 실제 메시지
  ("[rate] 시간당 6회 초과 — 잠시 후 다시 시도해 주세요") + "다시 시도" 버튼까지 스크린샷으로 확인

### 4. 정적 분석 / 빌드
- `flutter analyze`: 47 issues (기존 baseline과 동일, 신규 파일로 인한 이슈 0건)
- `flutter build web --release`: 성공

### 5. Git 반영
- `git status` 확인 결과 작업 트리 clean — 신규/수정 5개 파일은 세션 자동 백업
  (`genspark auto-backup`, commit `2a84160`, 5 files changed, 607 insertions)으로 이미 반영되어
  있음을 확인했다.

---

## 종합 결론

| 구분 | 결과 |
|---|---|
| 계산 엔진 무변경 원칙 | 파일 diff로 100% 실측 확인 (개발자 주장 신뢰 아닌 검증) |
| 487항목 회귀 테스트 | 배포 서버 재실행 기준 487/487 통과 |
| month=13 버그 | 원인 정밀 진단(500 미처리 예외) + API 계약 계층 한정 패치로 해결 |
| 기존 화면(계산결과/AI해석 탭) 영향 | 없음 (회귀 확인) |
| 신규 9 PART 리포트 화면 | 정상 플로우/캐시/402/429 전부 실기 검증 완료 |
| Git 반영 | 자동 백업 완료 |

## 다음 단계 (사용자 승인 필요, 이번 턴에서 진행하지 않음)

- rate limit 기본값(시간당 6·일일 20·IP 일일 200·기기 5계정·LLM 일일 1000회)은 이미 owner 승인된
  값으로, 운영 반영 시 그대로 유지하면 된다.

---

## PHASE 12 — 실제 LLM 연결 (사용자 승인 후 진행, 완료)

> 승인 경위: 위 "다음 단계"에 비용 발생 항목으로 보류되어 있었으나, 사용자가 명시적으로
> "연결" → (모델 제안 확인 후) "진행"을 지시하여 이번 턴에서 실제 LLM 연결 및 검증을 완료했다.

### 1. 모델 선정

- 개발자 스펙 기본값 `gpt-4o-mini`는 이 샌드박스의 Genspark 내부 LLM 프록시
  (`OPENAI_API_KEY` → `https://www.genspark.ai/api/llm_proxy/v1`, OpenAI 호환)에서 **제공되지
  않음**을 `/v1/models` 조회로 확인했다.
- 후보 모델(gpt-5-nano, gpt-5.4-nano, gpt-5.4-mini, claude-haiku-4-5)을 비용(`genspark_usage.
  credits`)·응답속도·`reasoning_tokens` 오버헤드·JSON 모드 호환·한국어 품질 기준으로 직접 비교
  테스트했다.
  - `gpt-5-nano`: 응답 전 숨은 reasoning에 토큰을 과다 소모(응답 지연·불필요 비용).
  - `gpt-5.4-nano`: reasoning 오버헤드 0, 이 샌드박스 기준 크레딧 비용 0, 응답 4~15초, 한국어
    품질 양호, `response_format: json_object` 정상 호환 → **최종 선정**.
- 선정 결과를 사용자에게 제시하고, 이 키가 **샌드박스 개발용 키이며 실제 운영 키가 아님**을
  명확히 고지한 뒤 확인("진행")을 받고서야 검증 스크립트를 실행했다.

### 2. `verify_live_llm.py` 공식 검증 스크립트

- 환경변수: `SAJU_LLM_API_KEY=$OPENAI_API_KEY`,
  `SAJU_LLM_BASE_URL=https://www.genspark.ai/api/llm_proxy/v1`, `SAJU_LLM_MODEL=gpt-5.4-nano`
- 골든 샘플(박주상, 1972-02-13 02시생 남, 질문 "내 재물운이 궁금해")로 실행
- 결과: `source: llm | qa_passed: True | PART: 9 | 본문: 1116자` → **PASS**

### 3. `saju_api.py` 패치 — 회귀 안전성 우선 설계

- 배포 서버(`api/saju_api.py`, git 미관리 배포 디렉터리)에 조건부 헬퍼 추가:
  - `SAJU_LLM_API_KEY` 또는 `OPENAI_API_KEY` 환경변수가 **없으면** `None` 반환 → 기존
    `rule_fallback` 동작 100% 그대로 유지
  - 있으면 `make_llm_call()`을 호출해 실 LLM 주입
  - `/saju/v3/report` 라우트의 `llm_call=None` 하드코딩을 `llm_call=_get_report_llm_call()`로 교체
- 이 설계로 **환경변수 유무만으로 자동 분기**되며, 기존 487항목 회귀 테스트 스위트(환경변수 미설정
  상태로 실행)에 영향이 없도록 보장했다.

### 4. 회귀 재검증 (환경변수 미설정 기준)

- 패치 후 전체 11개 테스트 파일 재실행 → **487/487 통과**
  (ai_layer 25 + interpret_service 14 + ai_report_v2 27 + llm_adapter 6 + phase13_bulk 8 +
  api_v3 54 + dart_contract 35 + dart_static_v31 23 + categories69 130 + engine_suite 115 +
  precision 50)
- `test_park_joosang.py` 스모크 테스트: "모든 테스트 통과 · LLM 호출 0회 · 비용 0원" 재확인

### 5. 실 서버(포트 8000) 라이브 LLM curl 검증

- 라이브 LLM 환경변수를 적용해 엔진 서버 재기동 후 curl로 4가지 케이스 확인:
  1. **QA 게이트 정상 차단 사례**: 실 LLM이 생성한 문장 중 "확실히"(단정 표현) 포함 →
     `source: rule_fallback`, `fallback_reason: "QA 미통과: ['[단정] ...확실히...']"` 로 자동
     안전 폴백. **버그가 아니라 §25/§27/§29 안전장치가 실 LLM 출력에도 정상 작동함을 증명**하는
     결과.
  2~4. 이후 3건은 서로 다른 생년월일로 재요청 → 모두 `source: llm`, `qa_passed: True`,
     9 PART 정상 생성 확인.
- **idempotency 캐시 확인**: 동일 요청 재전송 → `source: cache`, 약 1초 내 응답
  (캐시 레이어가 LLM 호출 위에 그대로 얹혀 정상 동작, LLM 재호출 없음)

### 6. Flutter 클라이언트 End-to-End 검증 (Playwright)

- 라우트가 모든 요청에 `ctx={"user_id": "freepass"}`를 고정 사용하는 구조상, 이번 턴의 curl
  테스트들과 Flutter 클라이언트 테스트가 **동일한 시간당 6회 한도 버킷을 공유**하게 되어, 첫
  Flutter 클라이언트 시도에서 429가 발생함 → 화면에 ⏳ "요청 한도를 초과했어요" 에러 UI가
  라이브 LLM 활성 상태에서도 정상 표시됨을 재확인(기존 검증의 재확인 성격).
- 엔진 서버를 재기동해 인메모리 `AbuseGuard` 상태(시간당 카운터)를 초기화한 뒤 재시도:
  - 생년월일 1998-09-16, 질문 "올해 취업운 재검증"으로 전체 클릭스루 진행
  - 네트워크 로그: `POST /saju/v3/report` 요청 후 약 15초 뒤 `[response] 200
    http://localhost:8000/saju/v3/report` 확인 (curl로 측정한 4~15초 레이턴시와 일치)
  - 15초·20초 시점 스크린샷을 직접 열어 시각 확인: 로딩 스피너·에러 배너 없이 9 PART 리포트
    본문(PART 1 "한눈에 보는 나", PART 2 "타고난 성향", PART 3 "숨겨진 성향" 등)이 실 LLM이
    생성한 자연스러운 서술형 한국어 문장으로 정상 렌더링됨을 확인
    (예: "병화 일간(태양)이라, 결과를 '보이게' 만드는 타입이에요.")

### 7. 결론 및 운영 참고사항

| 구분 | 결과 |
|---|---|
| 모델 선정 | `gpt-5.4-nano` (샌드박스 프록시 기준), 근거 문서화 완료 |
| 공식 검증 스크립트 (`verify_live_llm.py`) | PASS |
| 회귀 안전성 (487항목, 환경변수 미설정) | 487/487 통과, 영향 없음 |
| 실 서버 curl 검증 | QA 게이트 차단 1건 + 성공 3건 + 캐시 1건, 모두 기대 동작 |
| Flutter 클라이언트 E2E (Playwright) | 429 UI 재확인 + 200 성공 시 9 PART 리포트 정상 렌더링 시각 확인 |

- **중요**: 이번 턴에 사용한 API 키는 **샌드박스 개발용 Genspark 내부 프록시 키**이며, 실제
  운영 배포 시에는 개발자 스펙(`docs/환경변수설정방법.md`)에 따라 소유자가 **실제 OpenAI(또는
  호환) API 키**를 `SAJU_LLM_API_KEY`로 발급·설정해야 한다. 모델명도 운영 키가 지원하는 모델
  (예: `gpt-4o-mini` 등)로 재확인이 필요하다.
- 배포 디렉터리(`saju_engine_deploy/...`)는 git 미관리 상태이므로, 이번 패치(`_get_report_llm_
  call()` 조건부 주입)는 파일 시스템 변경으로만 존재한다. 향후 정식 배포 시 이 패치를 소스
  패키지에도 반영해야 한다.
