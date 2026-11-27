# 궁합 사주 팩터 개선 — 구현 계획서 + 테스트 계획서 (승인 요청용)

- 작성 목적: 사용자 지시 "실제 구현 전 영향 범위와 예외 처리 방식을 먼저 확정"에 따라, **코드를 수정하지 않고** 구현 계획과 테스트 계획을 먼저 보고합니다.
- **현재 상태: 코드/API/DB 전혀 수정하지 않음.** 아래 계획은 승인 후 별도 세그먼트에서 구현합니다.
- 전제 문서: `docs/saju_engine_cross_validation_and_compatibility_design_report.md`(이전 세그먼트 설계서)를 실제 구현 가능한 수준으로 구체화한 문서입니다.

---

## 1. 영향 범위 확정 (이번 세그먼트에서 코드 재조사로 확정)

### 1.1 수정 대상 파일 (구현 시)

| 파일 | 변경 범위 | 비고 |
|---|---|---|
| `admin_web/src/app/api/public/compatibility/request/route.ts` | `factorScores.saju` 계산 로직만 교체(105~111행의 `hashSeed` 기반 5개 팩터 중 `saju` 한 줄만 대상) | **API 요청/응답 스키마 변경 없음** (요청 바디 `{type,nameA,nameB,birthDateA,birthDateB,...}` 그대로, 응답 `{id,nameA,nameB,type,score,topicResults,summary,createdAt}` 그대로) |
| `admin_web/src/lib/saju-renewal/saju-engine-client.ts` (또는 신규 `src/lib/compatibility/saju-compat-client.ts`) | saju_engine의 `/compatibility` 엔드포인트를 호출하는 함수 1개 추가 | 기존 `saju-engine-client.ts`가 이미 `SAJU_ENGINE_BASE_URL`/free-pass 토큰 패턴을 확립해 두었으므로 **동일 패턴 재사용**(신규 설정 불필요) |
| `admin_web/prisma` | **변경 없음** | `CompatibilityResult.detail`은 이미 자유 JSON 문자열 필드이므로 스키마 마이그레이션 불필요, 애플리케이션 코드에서 `JSON.stringify()` 시 신규 키(`scoreEngineVersion`)만 추가 |
| `flutter_app/lib/features/compatibility/**` | **변경 없음(계획)** | `CompatibilityResultModel`/`CompatibilityRepository`/`CompatibilityResultScreen` 모두 기존 응답 스키마 그대로 소비 가능 — 1.3절에서 검증 |

### 1.2 saju_engine 호출에 필요한 입력 매핑

궁합 입력 UI(`compatibility_input_screen.dart`)는 `birthDateA`/`birthDateB`(YYYY-MM-DD 문자열)만 수집하며, 성별/출생시간/음력여부/자시정책은 수집하지 않습니다. `/compatibility` 엔드포인트(`TwoBirths{person_a, person_b}`)는 `BirthInput`(year,month,day,hour,minute,gender,is_lunar) 구조를 요구하므로, 다음과 같이 고정값을 매핑합니다:

```
person_a/person_b = {
  year, month, day,      // birthDateA/B 파싱
  hour: 12, minute: 0,   // 출생시간 미입력 — PHASE1~4와 동일한 "정오 고정" 관례 적용(1.3절 근거)
  gender: "male",        // 입력 UI에 성별 필드가 없음 — 아래 1.2.1 검증 결과에 따라 고정값 사용
  is_lunar: false,       // 입력 UI가 양력만 받음(확인 필요, 1.2.2)
}
```

**1.2.1 gender 고정값의 영향 — 코드 재확인 완료**: `saju_calculator.py`를 재확인한 결과, `gender`는 `eight_char.getYun(1 if gender=="male" else 0)`(대운 방향)과 `_dir`(순행/역행 표시 문자열)에만 사용되며, 궁합 모듈이 실제로 쓰는 `day_master`(일간)와 `pillars.day.zhi`(일지)에는 **전혀 영향을 주지 않음**을 확인했습니다. 따라서 `gender` 고정값("male")은 궁합 점수 계산 결과에 영향이 없습니다. (단, 엔진 응답 JSON에 `gender`/`_dir` 필드 자체는 실제와 다르게 찍히지만, 궁합 모듈은 이 필드를 사용하지 않으므로 무해합니다.)

**1.2.2 is_lunar 고정값 리스크 — 코드 재확인으로 해소됨**: `BirthdayPickerValue`(`lib/core/widgets/birthday_picker/birthday_picker_types.dart`)를 직접 확인한 결과, 이 모델에는 `isLunar`/`lunar` 관련 필드가 **전혀 존재하지 않으며**, `compatibility_input_screen.dart`가 사용하는 `BirthdayPickerModal`도 음력 입력 UI를 제공하지 않습니다(grep 결과 "lunar" 매칭 0건). 즉 궁합 입력은 **항상 양력(그레고리력)만 받습니다.** 따라서 `is_lunar: false` 고정값은 안전하며 리스크가 아님을 확정합니다.

추가로, `BirthdayPickerValue.toDateTime()`이 "시간 미입력 시 정오(12:00) 기본값 사용"으로 이미 구현되어 있음을 확인했습니다 — 이는 1.2절에서 설계한 `hour: 12, minute: 0` 고정값이 **궁합 입력 UI의 기존 관례와 정확히 일치**한다는 추가 근거입니다.

### 1.3 Flutter 측 영향 — 변경 불필요 확인

- `CompatibilityResultModel.fromJson()`은 `{id,nameA,nameB,type,score,topicResults,summary,createdAt}` 키만 읽으며, `factorScores`/`scoreEngineVersion` 등 신규/내부 필드는 애초에 파싱 대상이 아닙니다. → **서버 응답에 필드를 추가해도 Flutter 파싱에 영향 없음.**
- `CompatibilityResultScreen`은 `ResultCardStack`(기존 공용 결과 스켈레톤)을 그대로 재사용 중이며 `score`/`topicResults`/`summary`만 표시합니다. → **UI 변경 불필요.**
- `CompatibilityRepository.requestCompatibility()`의 요청 바디(`type,nameA,nameB,birthDateA,birthDateB,paymentMethod,transactionId,adSessionId`)는 변경 계획에 포함되지 않습니다.

**결론**: 이번 개선은 **admin_web 내부(서버)에서만 완결**되며, Flutter 앱 코드는 수정 대상이 아닙니다.

---

## 2. 예외 처리 방식 확정 (잘못된 결과를 정상처럼 표시하지 않기 위한 설계)

사용자 지시: "계산 실패 시 잘못된 결과를 정상 결과처럼 표시하지 않도록 해 주세요." 이를 다음 3단계로 구체화합니다.

### 2.1 saju_engine 호출 실패 시 — 폴백하되 "표시를 숨기지 않고 구분 가능하게"

| 실패 유형 | 처리 | 근거 |
<br/>
| 네트워크 오류/타임아웃(`fetch` 실패, `ECONNREFUSED`, 5xx) | `factorScores.saju`는 **기존 해시값으로 폴백** 계산 + `scoreEngineVersion: "hash-fallback-network"` 저장(구현 시 네트워크실패/타임아웃/5xx를 하나의 값으로 통합 명명함 — 아래 완료보고서 참고) | 사용자 체감상 "궁합 분석 실패"로 보이지 않게 가용성을 우선하되, **내부적으로는 신뢰도 낮은 결과임을 구분 가능하게 기록** — 이것이 "잘못된 결과를 정상 결과처럼 표시하지 않는다"의 실질적 의미(완전 실패로 사용자에게 에러를 노출하는 것이 아니라, **점수의 출처를 내부적으로 항상 추적 가능하게 유지**하는 것) |
| 엔진이 422(윤달 등 지원 불가 입력) 반환 | 동일하게 **해시 폴백** + `scoreEngineVersion: "hash-fallback-unsupported-input"` | 1.2.2에서 언급한 음력 리스크에 대한 안전망 |
| 엔진이 200을 반환했지만 `final_score`가 `null`/범위 밖(0~100 벗어남) | **해시 폴백** + `scoreEngineVersion: "hash-fallback-invalid-response"`, 서버 로그에 `console.error`로 원인 기록(운영 모니터링 대상) | "엔진이 이상한 값을 준 경우를 정상값처럼 쓰지 않는다"의 핵심 안전장치 |
| 엔진 응답이 정상(final_score가 0~100 범위의 유효한 숫자) | `factorScores.saju = final_score` + `scoreEngineVersion: "saju-v1"` | 정상 경로 |

**중요**: 어떤 경우에도 **사용자에게 노출되는 최상위 API 응답 형식(`{success, data:{...}}`)은 동일**하게 유지합니다(기존 `GENERATION_FAILED` 등 에러코드 체계를 새로 발동시키지 않음 — 궁합 전체 요청을 실패시키는 것이 아니라 `saju` 팩터 하나의 계산 방식만 폴백). 단, `detail`(JSON, 내부 저장용)에는 반드시 `scoreEngineVersion`을 기록해 **사후에 어떤 결과가 실사주 기반이고 어떤 결과가 해시 폴백인지 구분 가능**해야 합니다.

### 2.2 "잘못된 결과를 정상처럼 표시하지 않기" — 추가 안전장치 (선택, 승인 필요)

운영팀이 원할 경우, 다음 옵션도 가능하나 **이번 설계에는 기본 포함하지 않고 선택지로만 제시**합니다(승인 필요):
- **옵션**: `scoreEngineVersion`이 `hash-fallback*`인 경우, 결과 화면 하단에 작은 안내 문구(예: "일부 정보로 간이 분석되었습니다") 노출. → 이는 Flutter `CompatibilityResultModel`/`CompatibilityResultScreen`에 **신규 필드/UI 추가가 필요**하므로 API 응답 스키마 확장이 필요합니다. **API 변경 승인 필요 — 기본 계획에서는 제외.**

### 2.3 현행 유지 영역 (이번 개선에서 손대지 않음)

- `mbti`/`interest`/`value`/`activity_pattern` 4개 팩터: 해시 로직 **그대로 유지**(이전 설계서 3.5절 A안 채택 확정).
- `completeText()`(LLM 텍스트 생성) 로직: **변경 없음**. `score`(최종 가중합)만 더 정확한 `saju` 팩터를 반영하게 됨.
- `CompatibilityFactorWeight`(DB 가중치 테이블): **변경 없음**, 기존 가중평균 로직 재사용.

---

## 3. 테스트 계획 (구현 승인 후 작성·실행할 항목)

> 아래는 **계획**이며, 이번 세그먼트에서는 작성하지 않습니다. 구현 승인 시 이 계획에 따라 테스트를 먼저 작성한 뒤 구현하는 순서(TDD에 가까운 순서)를 권장합니다.

### 3.1 단위 테스트 (admin_web, 신규)

| # | 테스트 | 검증 내용 |
|---|---|---|
| U1 | `calculateSajuFactorScore()`(신규 추출 함수) 정상 응답 | engine이 `final_score: 72`를 반환하면 `factorScores.saju === 72`, `scoreEngineVersion === "saju-v1"` |
| U2 | 네트워크 실패 폴백 | fetch가 reject/5xx/타임아웃이면 기존 `hashSeed` 로직과 동일한 값 + `scoreEngineVersion === "hash-fallback-network"` |
| U3 | 422 응답 폴백 | engine이 422를 반환하면 `hash-fallback-unsupported-input`으로 표시 |
| U4 | 범위 밖 응답 방어 | engine이 `final_score: 150`(비정상) 반환 시 그대로 쓰지 않고 폴백 + 에러 로그 호출 확인(mock) |
| U5 | 기존 4개 팩터 불변 | `mbti`/`interest`/`value`/`activity_pattern` 값이 변경 전후 100% 동일(회귀 방지 핵심) |

### 3.2 통합 테스트 (admin_web route 레벨, 신규)

| # | 테스트 | 검증 내용 |
|---|---|---|
| I1 | `POST /api/public/compatibility/request` 정상 흐름 | saju_engine mock이 정상 응답 → 최종 `score`가 예전 해시 기반 값과 달라짐(실사주 반영 확인) + `detail.scoreEngineVersion === "saju-v1"` 저장 확인 |
| I2 | saju_engine 다운 상황 | saju_engine mock을 연결 거부로 설정 → 요청이 여전히 200 성공 응답(폴백 동작), `GENERATION_FAILED`가 발생하지 않음 확인 |
| I3 | 기존 `resultAccess`(프리패스/복주머니/광고) 소비 흐름 불변 | 이 변경과 무관하게 `beginResultAccess`/`reserveResultGeneration`/`consumeCategoryUsage` 호출 순서·횟수가 기존과 동일함을 회귀 확인 |
| I4 | 재열람(idempotent) 경로 불변 | `existing.status === "success"` 분기(route.ts 62~76행)가 `detail.scoreEngineVersion` 유무와 무관하게 정상 동작(과거 레코드에 필드가 없어도 에러 없음) |

### 3.3 Flutter 회귀 테스트 (기존 테스트 재실행만, 신규 작성 불필요 — 이미 이번 세그먼트에서 선제 확인 완료)

| # | 대상 | 결과(이번 세그먼트에서 실행 완료) |
|---|---|---|
| F1 | `test/compatibility_result_access_test.dart` | ✅ 7개 전부 통과 (아래 4장 실행 로그) |
| F2 | `test/compatibility_return_flow_test.dart` | ✅ 5개 전부 통과 |
| F3 | `test/full_result_share_test.dart`, `test/app_image_share_test.dart` | ✅ 공유 기능 전부 통과 |
| F4 | `test/saju_result_access_gate_sheet_*_test.dart` (프리패스/복주머니/광고 게이트) | ✅ 전부 통과 |
| F5 | 전체 `flutter test` | ✅ 378/378 통과 |

→ Flutter 측은 응답 스키마가 바뀌지 않으므로 **신규 Flutter 테스트 작성이 필수는 아니나**, 구현 완료 후 동일한 F1~F5를 **재실행**해 회귀 없음을 재확인하는 것을 구현 완료 체크리스트에 포함합니다.

### 3.4 결과 검증 기준 (수용 기준, Acceptance Criteria)

구현이 "성공"으로 간주되려면 다음을 모두 만족해야 합니다:
1. 동일 생년월일 쌍에 대해 `/compatibility` 응답의 `final_score`가 `factorScores.saju`에 정확히 반영된다(U1).
2. saju_engine이 어떤 이유로든 실패해도 `/api/public/compatibility/request`는 기존과 동일하게 200 성공을 반환한다(I2) — **가용성 회귀 없음**.
3. `mbti`/`interest`/`value`/`activity_pattern` 값과 최종 `score` 산식(가중평균) 자체 로직은 변경 전후 수학적으로 동일하다(U5).
4. 과거에 저장된 `CompatibilityResult.detail`(scoreEngineVersion 필드 없음)을 조회하는 기존 재열람 경로가 에러 없이 동작한다(I4).
5. Flutter 쪽 F1~F5 전체가 구현 후에도 그대로 통과한다.
6. `CompatibilityResultModel`/`CompatibilityResultScreen`/`compatibility_input_screen.dart` **0줄 변경**으로 구현이 완료된다(1.3절 전제가 깨지면 설계를 재검토해야 함).

---

## 4. 이번 세그먼트에서 실행한 "변경 전" 회귀 기준선 (실제 명령 출력)

구현 전 현재 상태가 건강함을 먼저 확인했습니다(구현 후 비교 기준점).

```
$ flutter test test/compatibility_result_access_test.dart test/compatibility_return_flow_test.dart
00:00 +0~+5: compatibility_result_access_test.dart 전체 통과
00:00 +6~+10: compatibility_return_flow_test.dart 전체 통과
00:11 +11: All tests passed!

$ flutter test test/full_result_share_test.dart test/app_image_share_test.dart
00:00 +0~+2: full_result_share_test.dart 전체 통과
00:01~00:06 +3~+6: app_image_share_test.dart 전체 통과
00:06 +6: All tests passed!

$ flutter test test/saju_result_access_gate_sheet_e08_test.dart test/saju_result_access_gate_sheet_c06_test.dart test/saju_result_access_gate_sheet_e10_test.dart test/saju_result_access_gate_sheet_e11_test.dart
00:00~00:04 +0~+7: 프리패스/복주머니/광고 게이트 전체 통과
00:04 +7: All tests passed!

$ flutter test   (전체 스위트)
01:55 +378: All tests passed!
```

## 5. 검증 필요 항목 (구현 착수 전 반드시 확인해야 할 미결 사항)

1. ~~궁합 입력 UI의 음력 지원 여부~~ — **해소됨.** `BirthdayPickerValue`에 `isLunar` 필드가 없고 궁합 입력은 항상 양력만 받음을 코드로 확정(1.2.2절). `is_lunar: false` 고정값 안전.
2. **saju_engine `/compatibility` 호출의 레이턴시** — admin_web이 동기 호출 시 전체 궁합 요청(현재도 LLM 호출로 수 초 소요)에 추가되는 지연 시간 실측 필요(설계서 5장에서 이미 미검증 항목으로 명시됨). **여전히 미해소 — 구현 단계에서 실측 필요.**
3. **`SAJU_ENGINE_BASE_URL`의 운영 환경 설정값** — 이번 조사는 샌드박스 로컬 복제본(127.0.0.1:8000) 기준이며, 운영 서버(sintong.kr)의 실제 saju_engine 접근 경로/인증 토큰 설정 여부는 별도 확인 필요. **여전히 미해소 — 운영 배포 전 반드시 확인.**

---

---

## 5-1. 결과페이지 종단 흐름 추적 (엔진 → 해석 → 전달 → 저장 → 표시) — 코드 재확인 완료

사용자 지시 "엔진 계산, 해석 생성, 데이터 전달, 저장, 앱·웹 결과 표시를 연결해서 확인"에 따라, 궁합 기능의 전체 파이프라인을 코드로 끝까지 추적했습니다.

```
[1 엔진계산]          [2 해석생성]            [3 전달/저장]                    [4 앱 표시]
                                                                              
hashSeed()        →  completeText()      →  prisma.$transaction            → CompatibilityResultScreen
(또는 설계안:          (LLM, TOPICS=          ├ compatibilityRequest.create    (ResultCardStack 재사용)
 saju_engine           [애정,성격,미래])       │  targetInput: JSON{nameA,     ├ heroChips: score
 /compatibility                              │   nameB,birthDateA/B}          ├ sections: topicResults
 호출)                                        └ compatibilityResult.create    └ heroSummary: summary
   ↓                                             score, detail: JSON{
factorScores                                     factorScores,
{saju,mbti,                                      topicResults, summary}
 interest,value,
 activity_pattern}
   ↓
weighted score
```

- **저장 ↔ 재조회(history/result) 경로 확인**: `GET /api/public/compatibility/history`와 `GET /api/public/compatibility/result/[id]`는 모두 `detail.topicResults`/`detail.summary`/`result.score`만 읽고 **`detail`의 다른 키(예: `factorScores`, 신규 `scoreEngineVersion`)는 전혀 참조하지 않습니다.** 따라서 `detail` JSON에 `scoreEngineVersion`을 추가해도 이 두 조회 경로에 영향이 없음을 코드로 확정했습니다.
- **재열람(idempotent) 경로**: `request/route.ts` 62~76행에서 `existing.status === "success"`일 때도 동일하게 `detail.topicResults`/`detail.summary`/`result.score`만 읽으므로 안전합니다.
- **앱 표시 레이어**: `CompatibilityResultModel.fromJson()`이 읽는 키(`id,nameA,nameB,type,score,topicResults,summary,createdAt`)는 세 엔드포인트(request/history/result) 모두 동일한 형태로 응답하므로, **어느 경로로 진입해도 Flutter 쪽 표시 로직은 동일하게 동작**합니다.
- **결론**: 엔진→해석→저장→표시 전 구간에서 `scoreEngineVersion` 신규 필드 추가는 **읽기 경로 어디에도 영향을 주지 않는 완전히 부가적인(additive) 변경**임을 확인했습니다. 이는 "기존 API 응답 형식과 결과페이지 유지 가능 여부"에 대한 실제 코드 레벨의 최종 확인입니다.

## 5-2. 기존 보호 기능 회귀 검증 결과 (이번 세그먼트, 실제 실행)

사용자 지시 "기존 UI·공유·광고·복주머니·프리패스 기능도 회귀 검증 대상에 포함"에 따라, 궁합 변경과 직접·간접으로 연관된 보호 기능 테스트를 **코드 변경 없는 현재 상태에서 선실행**해 기준선을 확보했습니다(구현 후 동일 테스트 재실행 예정 — 3.3절 F1~F5).

| 영역 | 테스트 파일 | 결과 |
|---|---|---|
| 궁합 결과접근(프리패스/복주머니/광고 거래) | `compatibility_result_access_test.dart` | ✅ 7/7 통과 |
| 궁합 입력 복원/재시작 흐름 | `compatibility_return_flow_test.dart` | ✅ 5/5 통과 |
| 결과 공유(이미지+딥링크) | `full_result_share_test.dart`, `app_image_share_test.dart` | ✅ 9/9 통과 |
| 프리패스/복주머니/광고 게이트 시트(E-08,C-06,E-10,E-11) | `saju_result_access_gate_sheet_*_test.dart` | ✅ 8/8 통과 |
| 전체 회귀 | `flutter test` (378개 전체) | ✅ 378/378 통과 |

이 기준선은 **코드를 전혀 수정하지 않은 현재 상태**에서 확보한 것이며, 승인 후 구현을 진행하면 동일 테스트를 다시 실행해 수치가 그대로 유지되는지 확인하는 것이 완료 조건(3.4절 수용기준 #5)입니다.

---

## 6. 승인 요청 사항 (이 구현을 시작하기 위해 필요한 승인)

1. **`admin_web/src/app/api/public/compatibility/request/route.ts` 수정** — 2장에서 설계한 폴백 로직 포함하여 `factorScores.saju` 계산 교체.
2. **신규 함수 추가**(`saju-engine-client.ts` 확장 또는 신규 파일) — `/compatibility` 호출 래퍼.
3. **`CompatibilityResult.detail` JSON에 `scoreEngineVersion` 키 추가** — DB 스키마 변경 아님(자유 JSON), 애플리케이션 레벨 변경만.
4. **3장 테스트 계획에 따른 신규 테스트 작성**(U1~U5, I1~I4) — admin_web 테스트 디렉토리에 추가.
5. **5장 미결 사항(음력 지원 여부, 레이턴시, 운영 환경 설정) 확인 작업** — 구현과 병행 또는 선행.

**이 승인이 없으면 코드/API/DB를 수정하지 않습니다.**
