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

- **PHASE 12 — 실제 LLM 연결**: `SAJU_LLM_API_KEY`/`SAJU_LLM_BASE_URL`/`SAJU_LLM_MODEL` 3개 환경변수
  설정 후 `verify_live_llm.py` PASS 확인 → `llm_call=make_llm_call()` 주입. 비용이 발생하는 항목이라
  소유자 승인 및 예산 확인이 필요하다.
- rate limit 기본값(시간당 6·일일 20·IP 일일 200·기기 5계정·LLM 일일 1000회)은 이미 owner 승인된
  값으로, 운영 반영 시 그대로 유지하면 된다.
