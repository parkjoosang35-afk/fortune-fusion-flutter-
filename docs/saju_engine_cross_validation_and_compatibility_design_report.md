# 신통방통 엔진 검증 및 궁합 개선 — 최종 종합 보고서

- 작성일: 2026 (세그먼트 기준)
- 범위: (1) Dart↔Python 엔진 교차검증, (2) 해석단계 데이터 전달 구조 문서화, (3) 궁합 사주 팩터 개선 상세 설계서, (4) 최종 종합 보고
- **원칙 준수 확인**: 이 보고서 작성 과정에서 계산 엔진, 서버 API 스펙, DB 스키마, 궁합 코드, 운영 데이터는 **일체 수정하지 않았습니다.** 모든 조사는 읽기(Read/Grep) 또는 기존에 공개된 엔드포인트에 대한 외부 호출(curl, python 직접 함수호출, flutter test)로만 수행했습니다.

---

## 0. 요약 (Executive Summary)

| 항목 | 결론 |
|---|---|
| 엔진 간 계산값 불일치가 "버그"인가? | **아니오.** 진태양시 보정, 자시 정책, 윤달 지원, 출생시간 미입력 처리 4가지 모두 **설계상 의도된 정책 차이**이며, 자동화 테스트로 원인을 재현·고정했습니다. |
| 앱-서버 통합이 필요한가? | **부분적으로만 필요.** PHASE1~4(69종)와 29종 Topic Engine은 이미 완전히 분리된 별도 체계이며, 이 분리 자체는 유지하는 것을 권장합니다(아래 2장 근거). |
| 궁합 점수를 사주 기반으로 바꿀 수 있는가? | **가능.** 서버에 이미 실제 사주 기반 `/compatibility` 모듈이 존재하고 정상 작동합니다. DB 스키마가 자유 JSON이라 마이그레이션 없이 연결 가능합니다(아래 3장 설계). |
| 오늘 실행한 테스트 결과 | `test/saju_cross_engine_validation_test.dart` 10/10 통과, 전체 `flutter test` 378/378 통과 (실행 로그는 1장 하단 참조). |

---

## 1. 엔진 간 정책 차이 및 자동화 검증 결과

### 1.1 검증 대상 4가지 정책 차이

| # | 정책 | 로컬(Dart `ManseryeokCoreEngine`/`manseryeok_policy.dart`) | 서버(Python `saju_calculator.calculate_saju()`) | 차이의 성격 |
|---|---|---|---|---|
| 1 | 진태양시(true solar time) 보정 | 미적용 (정책 문서에 "Phase 1에서는 적용하지 않는다"고 명시) | 기본값 `true_solar=True`, 서울 경도 126.98° 기준 **-32분** 보정 적용 | 설계상 차이. API가 이 파라미터를 요청 바디로 노출하지 않아 **API 호출만으로는 on/off 토글 불가** (함수 직접 호출로만 분리검증 가능했음) |
| 2 | 자시(子時) 처리 | 기본값 `ZiHourPolicy.lateZiSameDay`(= sect2, 23:00~23:59를 당일로 산입) | 기본값 `zihour_policy="traditional"`(= `setSect(1)`, 23:00~23:59를 다음날로 산입) | 레이블은 다르지만 **1:1 대응 확인**: Dart `lateZiNextDay` == 서버 `traditional`, Dart `lateZiSameDay` == 서버 `legacy`. 단, **각자의 기본값이 서로 반대쪽에 매핑**되어 있어 아무 옵션도 지정하지 않으면 일주(day pillar)가 달라질 수 있음 |
| 3 | 윤달(음력) 입력 | `calculatePillars(isLeapMonth: bool)`로 정상 지원 | `BirthInput.month: Field(ge=1, le=12)`로 음수(윤달 컨벤션) 입력을 **Pydantic 레벨에서 422 거부**. 별도 `is_leap` 플래그도 없음 | 계산 알고리즘 차이가 아니라 **API 입력 스키마 자체의 기능 격차** |
| 4 | 출생시간 미입력 처리 | PHASE1~4(`JeontongReportBuilder`)는 관례값 12:00으로 8자 전체 계산, 시주 제거 안 함 | **3갈래로 서로 다름** (아래 1.2 참조) | 단순 기본값 차이가 아니라 **서로 다른 3개 메커니즘**이 각자 구현되어 있음 |

### 1.2 출생시간 미입력 처리 — 3갈래 정책 상세

| 소비처 | 엔진에 보내는 시(時) | 시주를 어떻게 숨기는가 |
|---|---|---|
| 서버 `/saju/v3/screen` (`hour_known=False`) | 계산 자체를 6자만 수행하도록 분기 | `build_screen_result.py`에서 **엔진 응답 JSON 자체**가 `pillars.hour: null` (실제 curl로 확인) |
| admin_web `/saju/v3/facts` 소비 경로 (`topics/select`, `interpret`) | 항상 12:00으로 **8자 전체 계산** | 엔진 응답을 받은 **애플리케이션 레이어**(`saju-facts-time-guard.ts`의 `applyBirthTimeUnknownGuard()`)가 사후에 `pillars.hour`, `ten_gods.hour_*`, `twelve_stages.hour`, `zhi_qigan.hour`를 제거. 엔진 코드 자체는 미수정 |
| Flutter 앱 PHASE1~4 (`JeontongReportBuilder`) | 항상 12:00으로 **8자 전체 계산** | **제거하지 않음.** `jeontong_input.dart` 주석: "계산에는 영향이 없다(관례값 12:00 그대로 사용)" |

→ 어느 쪽이 맞고 틀리다를 판단할 사안이 아니라, **같은 "모름" 입력에 세 가지 서로 다른 응답 형태**가 나온다는 사실 자체가 교차검증/통합 시 반드시 인지해야 할 리스크입니다.

### 1.3 자동화 테스트 확장 내역

`test/saju_cross_engine_validation_test.dart`에 기존 3개 그룹(5 테스트)에 더해 4개 그룹(5개 신규 테스트)을 추가했습니다.

**신규 추가 그룹**:
1. `[잔여작업 — 진태양시 보정 단독효과 분리검증]` — 1990-02-04 10:13/10:30 두 시점에서 서버·로컬을 각각 비교. 서버는 보정 때문에 두 시각 모두 "입춘 전"으로 동일 판정, 로컬은 보정이 없어 실제로 달라짐을 각각 검증 후 "정책 차이가 원인"임을 최종 분기로 문서화.
2. `[잔여작업 — 음력 윤달 지원 여부 차이]` (2개 테스트) — (a) 로컬에서 2023년 윤2월10일 vs 평달2월10일 월주가 다름을 확인, (b) 서버에 `month:-2` 요청 시 422 응답을 실제 HttpClient 호출로 확인.
3. `[잔여작업 — 출생시간 미입력 처리 정책 3갈래 차이]` (2개 테스트) — (a) 서버 `/saju/v3/screen`에 `hour_known:false`로 실제 POST해 `pillars.hour == null` 확인, (b) 로컬 엔진이 시주를 제거하지 않음을 확인.

**실행 결과 (실제 명령 출력)**:

```
$ flutter analyze test/saju_cross_engine_validation_test.dart
Analyzing saju_cross_engine_validation_test.dart...
No issues found! (ran in 2.3s)

$ flutter test test/saju_cross_engine_validation_test.dart --reporter expanded
00:00 +0: [정상 범위] ... 1990-5-15 14시
00:00 +1: [정상 범위] ... 2000-1-1 10시
00:00 +2: [정상 범위] ... 1985-8-20 6시
00:00 +3: [원인 확인 — 진태양시 보정 차이] ... 1990-05-15 13:15
00:00 +4: [원인 확인 — 자시 정책 기본값 차이] ... 1990-05-15 23:50
00:00 +5: [잔여작업 — 진태양시 보정 단독효과 분리검증] ... 1990-02-04 10:14 전후
00:00 +6: [잔여작업 — 음력 윤달 지원 여부 차이] (로컬 지원 확인)
00:00 +7: [잔여작업 — 음력 윤달 지원 여부 차이] (서버 422 거부 확인)
00:00 +8: [잔여작업 — 출생시간 미입력 처리 정책 3갈래 차이] (서버 screen null 확인)
00:00 +9: [잔여작업 — 출생시간 미입력 처리 정책 3갈래 차이] (로컬 미제거 확인)
00:00 +10: All tests passed!
```

10개 테스트 전부 **스킵 없이 실제 서버/로컬 비교를 수행하고 통과**했습니다(당시 Python 서버가 PID 23759로 가동 중이었기 때문).

**전체 회귀 테스트**:
```
$ flutter test
...
01:56 +378: All tests passed!
```
기존 373개 + 신규 5개 = 378개 **전부 통과**, 기존 기능에 대한 회귀 없음을 확인했습니다.

### 1.4 발견된 정책 차이에 대한 선택지 (수정하지 않고 보고만)

- **진태양시**: (옵션A) 로컬 엔진에도 동일 보정 추가, (옵션B) 서버 API에 `true_solar` 파라미터를 노출해 클라이언트가 선택, (옵션C) 현행 유지 + 양쪽에 "설계상 차이" 주석/문서로 고정. → **권장: 옵션C**. 69종/PHASE1~4는 이미 정통사주 계산 정책으로 운영 중이며 보호 대상이므로, 임의 변경 시 기존 사용자에게 노출된 모든 과거 결과와의 일관성이 깨질 위험이 있습니다.
- **자시 정책**: 두 엔진의 기본값이 서로 반대로 매핑되어 있다는 사실 자체가 중요한 리스크입니다. 교차검증/통합 시 반드시 **동일한 라벨("traditional"/"legacy" 또는 "당일산입"/"익일산입")로 명시적 파라미터를 맞춰서 비교**해야 하며, 묵시적 기본값 비교는 혼동을 유발합니다.
- **윤달**: API 스키마 확장(`is_leap: bool` 필드 추가 등)이 필요한 사안이나, 이는 **API 변경**이므로 이번 작업 범위 밖입니다. 필요 시 별도 승인 요청.
- **출생시간 미입력**: 3갈래 중 어느 것을 표준으로 할지는 "69종/PHASE1~4는 그대로 보호"라는 원칙상, 현재로서는 **PHASE1~4는 수정 대상이 아니며**, 29종 Topic Engine과 서버 screen 엔드포인트 간의 정책 통일 여부만 별도 논의가 필요합니다.

---

## 2. 앱과 서버 사이 데이터 전달 구조

### 2.1 두 개의 완전히 독립된 체계

코드 레벨 교차 확인 결과, Flutter 앱 내부에는 **코드도 API도 전혀 겹치지 않는 두 개의 사주 계산/표시 체계**가 공존합니다.

```
┌─────────────────────────────────┐       ┌──────────────────────────────────────┐
│   PHASE1~4 (순수 로컬 체계)        │       │   29종 Topic Engine (서버 연동 체계)     │
│                                  │       │                                       │
│ door_engine_gateway.dart          │       │ lib/features/saju_renewal/            │
│  (http 호출 없음)                  │       │  └ saju_renewal_api.dart (http 있음)   │
│       ↓                          │       │       ↓                              │
│ JeontongReportBuilder              │       │ POST /api/public/saju-renewal/        │
│  .buildProfileAndSajuResult        │       │   topics/select, /interpret           │
│    ViaPhase1to4()                 │       │       ↓ (admin_web)                   │
│       ↓                          │       │ saju-engine-client.ts                 │
│ 69종 화면                          │       │  .getSajuFacts()                      │
│ (jeontong_eighty_matrix.dart)      │       │       ↓                              │
│  → 서버 호출 전혀 없음               │       │ POST {saju_engine}/saju/v3/facts      │
└─────────────────────────────────┘       └──────────────────────────────────────┘
```

- **PHASE1~4**: `ManseryeokCoreEngine`을 로컬에서 직접 호출. 네트워크 의존성 없음. 69종 화면까지 전부 오프라인 계산.
- **29종 Topic Engine**: Flutter → admin_web(Next.js, `saju-engine-client.ts`) → Python saju_engine(`/saju/v3/facts`)로 이어지는 체인. Flutter는 생년월일을 직접 보내지 않고 `profile_id`만 전송하며, admin_web이 DB에서 프로필을 조회해 엔진을 호출합니다(`saju_renewal_api.dart` 클래스 주석: "생년월일을 요청 바디로 보내지 않는다").

grep으로 상호 참조를 확인한 결과, `lib/features/home/domain/`(PHASE1~4/69종)과 `lib/features/saju_renewal/`(29종)은 서로의 모듈을 import하지 않으며, 서버 호출 유무도 코드상 명확히 구분됩니다.

### 2.2 직접 연결된 데이터 vs 독립 재계산되는 데이터

| 구분 | 직접 연결 | 독립 재계산 |
|---|---|---|
| 생년월일시 원본 입력 | 앱 → admin_web 프로필 저장 (최초 1회) | 29종 호출 시마다 서버가 DB에서 재조회, PHASE1~4는 로컬 상태에서 재조회 — **양쪽 다 "저장된 동일 원본"을 각자 다시 계산** |
| 팔자(사주 원국) | 없음 | **100% 독립 재계산**: PHASE1~4는 로컬 lunar 라이브러리, 29종은 서버 Python 엔진이 각자 계산 |
| 해석 텍스트(토픽별 설명) | 29종만 해당 — 서버 LLM/규칙 기반 해석을 그대로 받아 표시 | PHASE1~4는 로컬 규칙(`jeontong_eighty_matrix.dart`)으로 독립 생성 |
| 교차검증 화면(타로↔사주 등) | 각 엔진의 "판정됨/미판정" 상태만 참조(원시 데이터 직접 연결 아님) | 각자 독립 수행 후 결과만 비교 |

**결론**: 현재 "직접 연결"된 구간은 사실상 "같은 사람의 생년월일시를 각자 조회해서 각자 계산한다"는 수준이며, 실제 **계산된 팔자 데이터 자체가 두 체계 간에 전달되는 지점은 없습니다.** 즉 동일 입력이라도 1장에서 발견한 정책 차이(진태양시/자시/윤달/출생시간미입력)로 인해 **PHASE1~4 결과와 29종 결과의 팔자가 다를 수 있는 구조**입니다.

### 2.3 API 변경 없이 가능한 검증 vs API 변경이 필요한 연결

| 구분 | 내용 | 예시 |
|---|---|---|
| **API 변경 없이 가능** | 기존 공개 엔드포인트에 대한 외부 호출 비교, Python 함수 직접 호출(샌드박스 내부 복제본 한정)을 통한 내부 로직 분리검증, Flutter 테스트 코드로 로컬 엔진과 서버 응답 비교 | 이번에 수행한 `saju_cross_engine_validation_test.dart` 전체가 이 범주 |
| **API 변경이 필요** | (1) 진태양시 on/off를 API 레벨에서 토글, (2) 윤달 입력(`is_leap` 등) 지원, (3) PHASE1~4 계산 결과를 29종 해석 요청 바디에 직접 전달(현재는 `profile_id`만 전송), (4) 출생시간 미입력 정책을 3갈래에서 통일 | 모두 **이번 작업 범위 밖** — 별도 승인 필요 |

### 2.4 권장 구조 (정확성 · 안정성 · 유지보수 관점)

**결론: 앱과 서버를 무조건 하나로 통합하지 말고, 현재의 분리 구조를 유지하되 "정책 차이 문서"를 공식화하는 것을 권장합니다.**

근거:
1. **정확성**: PHASE1~4(69종)는 이미 "정통사주 계산 정책"으로 검증되어 운영 중인 보호 대상입니다. 이를 서버 엔진과 강제로 일치시키려면 진태양시/자시/윤달 정책 중 최소 하나 이상을 변경해야 하며, 이는 기존 사용자에게 노출된 과거 결과와의 일관성을 깨뜨릴 위험이 있습니다.
2. **안정성**: PHASE1~4는 네트워크 의존성이 없어 서버 장애와 무관하게 동작합니다. 통합 시 69종 화면도 서버 가용성에 종속되어 장애 범위가 확대됩니다.
3. **유지보수**: 두 체계가 독립적이므로 한쪽(29종 Topic Engine)을 개선/확장해도 69종(PHASE1~4)에 회귀 위험이 없습니다. 실제로 이번 세그먼트 이전 작업("FortuneOrchestrator 중복계산 개선")도 PHASE1~4 내부에서만 완결되었고 29종에 영향이 없었습니다.
4. **단, 정책 차이는 반드시 문서화되어야 함**: 사용자가 69종 결과와 29종 해석을 같은 화면 흐름에서 연이어 볼 경우, 팔자가 미세하게 다르게 느껴질 수 있는 시(時) 경계 케이스가 존재합니다(1.3절 재현 테스트 참조). 이는 코드 수정이 아니라 **운영/고객대응 문서**로 관리하는 것을 권장합니다.

---

## 3. 궁합 사주 팩터 개선 상세 설계서

> **주의**: 이 장은 설계서이며, 실제 코드/DB/운영 데이터는 전혀 수정하지 않았습니다.

### 3.1 현재 상태: 해시 기반 점수

`admin_web/src/app/api/public/compatibility/request/route.ts`의 `POST` 핸들러는 다음과 같이 동작합니다:

```
seed = hashSeed(`${birthDateA}:${birthDateB}:${type}`)   // 단순 다항 해시
factorScores = {
  saju:             50 + (seed * 7)  % 45,
  mbti:             50 + (seed * 3)  % 45,
  interest:         50 + (seed * 11) % 45,
  value:            50 + (seed * 5)  % 45,
  activity_pattern: 50 + (seed * 13) % 45,
}
score = weighted_average(factorScores, CompatibilityFactorWeight)  // DB 가중치
```

**문제점**: `saju` 팩터조차 실제 사주 계산을 전혀 거치지 않고 생년월일 **문자열 해시값**만으로 점수를 산출합니다. 즉 "사주 기반 궁합"이라는 명칭과 실제 구현(해시)이 불일치합니다.

### 3.2 서버에 이미 존재하는 실제 사주 기반 모듈

`saju_engine/modules/compatibility.py`의 `get_compatibility(saju_a, saju_b)`는:
1. 두 사람의 `day_master`(일간)를 추출해 `compatibility_rules.json`의 `gan_to_gan`(천간 10×10=100개 조합, 각 조합마다 명리학적 근거 텍스트 포함)에서 기본 점수 조회
2. 두 사람의 `day_zhi`(일지) 관계(六合/三合/沖/刑)로 보정(+8/+5/-15/-10)
3. `final_score`(0~100, 5단계 band)로 응답

이 모듈은 `POST /compatibility` 엔드포인트(`TwoBirths{person_a, person_b}`)로 **이미 공개되어 있고 실제 호출로 정상 작동을 확인**했습니다(1990-03-15 vs 1995-11-02 → 점수 55, 沖 관계).

### 3.3 연결 방법 설계 (코드는 변경하지 않고, "어떻게" 변경할지만 제시)

```
[현재]
Flutter CompatibilityRepository
  → POST /api/public/compatibility/request { birthDateA, birthDateB, type }
       → hashSeed() 기반 factorScores.saju 계산   ← 교체 대상

[설계안]
Flutter CompatibilityRepository (변경 없음, 요청 바디도 변경 없음 가능)
  → POST /api/public/compatibility/request { birthDateA, birthDateB, type }
       → (신규) admin_web 내부에서 saju_engine의 /compatibility 호출
            POST {saju_engine}/compatibility
              { person_a: {year,month,day,hour,minute,gender,is_lunar},
                person_b: {...} }
       → 응답의 final_score를 factorScores.saju 자리에 대입
       → mbti/interest/value/activity_pattern은 3.5절 방안 적용
       → weighted_average()는 기존 로직 그대로 재사용
```

- **API 요청/응답 스키마 변경 불필요**: Flutter → admin_web 구간은 기존 `{birthDateA, birthDateB, type}` 그대로 유지 가능. 변경은 admin_web 내부 로직(`route.ts`)에서 "해시 계산" 대신 "엔진 호출"로 바뀌는 것뿐입니다.
- **admin_web → saju_engine 구간만 신규 호출 추가**: 기존 `/compatibility` 엔드포인트를 그대로 재사용하므로 **서버(saju_engine) API 변경도 불필요**합니다.

### 3.4 출생시간 미입력 정책 명시

궁합 입력 UI(`compatibility_input_screen.dart`)는 현재 의도적으로 시간을 수집하지 않습니다(주석: "시간 선택(requireTime=false)"). 따라서 설계안에서는:

- `person_a`/`person_b`의 `hour`/`minute`을 **항상 정오(12:00) 고정값으로 엔진에 전달**(PHASE1~4와 동일한 관례, 1.2절의 "출생시간 미입력 처리 3갈래" 중 세 번째 방식과 일치).
- 단, `day_master`(일간)와 `day_zhi`(일지)는 **일주(day pillar)만으로 결정되며 시주의 영향을 받지 않으므로**, 시간 미입력이 궁합 계산 모듈의 핵심 입력(`get_compatibility`는 `day_master`/`day_zhi`만 사용)에는 **영향이 없습니다.** 이는 설계상 안전한 지점입니다.
- 사주 판정 기준: 서울 경도 고정, 서버 엔진 기본값(`true_solar=True`, `zihour_policy="traditional"`)을 그대로 사용 — 이는 PHASE1~4와 다를 수 있으나(1장 참조), 궁합 기능은 서버 모듈을 "우선 활용"하라는 지시에 따라 **서버 기본 정책을 그대로 따르는 것**으로 설계합니다. 단 이 사실은 사용자/운영팀에 사전 고지 필요.

### 3.5 사주 외 4개 팩터(MBTI/관심사/가치관/활동패턴) 처리 방안 비교

이 4개 팩터는 **현재 Flutter/DB 어디에도 실제 사용자 입력 데이터가 존재하지 않습니다**(확인됨: `compatibility_repository.dart`가 전송하는 필드는 `birthDateA/B`뿐).

| 방안 | 설명 | 장점 | 단점 |
|---|---|---|---|
| **A. 현행 유지(해시)** | 4개 팩터는 그대로 해시 기반 유지, `saju`만 실사주로 교체 | 구현 범위 최소, 리스크 최소 | "사주 외 팩터는 여전히 무의미한 난수"라는 근본 문제 잔존 |
| **B. 비노출** | UI/응답에서 4개 팩터를 숨기고 `saju` 점수만 전면에 노출 | 기만적 정보 제거 | 기존 API 응답 포맷(`factorScores` 5개 키) 변경 필요 → Flutter 결과화면도 수정 필요 |
| **C. 점진적 수집** | 향후 온보딩에서 MBTI 등 실제 입력을 받는 기능 추가(차기 과제) | 근본 해결 | 이번 작업 범위를 크게 벗어남(신규 기능 개발), 별도 기획/승인 필요 |

**권장**: **A(현행 유지)**. 이유: 이번 작업 지시는 "궁합 코드와 운영 데이터는 수정하지 말고 설계서만 작성"이며, 4개 팩터 교체는 신규 데이터 수집 체계가 필요한 별도 프로젝트 규모입니다. `saju` 팩터만 우선 실사주화하는 것이 **기존 API 응답 형식을 유지하면서** 가장 리스크가 작은 개선입니다.

### 3.6 과거 저장 결과 vs 신규 계산 결과 구분 방안

`CompatibilityResult.detail`(Prisma, 자유 JSON 문자열 필드)에 **버전 메타필드**를 추가하는 방식을 제안합니다(스키마 마이그레이션 불필요, 필드 확장만):

```jsonc
// 기존 detail (예시, 실제 필드명은 기존 코드 확인 필요)
{ "factorScores": {...}, "topicResults": {...} }

// 설계안: detail에 메타 추가 (기존 키는 모두 보존)
{
  "factorScores": {...},
  "topicResults": {...},
  "scoreEngineVersion": "hash-v1" | "saju-v1"   // 신규 필드만 추가
}
```

- 과거 레코드는 `scoreEngineVersion` 키가 없으므로 **코드에서 `?? "hash-v1"`로 안전하게 기본값 처리** 가능 → 과거 데이터 마이그레이션 불필요.
- 신규 계산 결과만 `"saju-v1"`로 표시되어 추후 집계/비교/롤백 판단에 사용 가능.
- `CompatibilityRequest.targetInput`도 동일하게 자유 JSON이므로, 추후 실제 출생시간을 받게 되면(3.4절 C안과 연계) 이 필드에 `birthTimeA/B` 등을 추가하는 것도 마이그레이션 없이 가능합니다.

### 3.7 기존 API 응답 형식 / Flutter 결과페이지 유지 가능 여부

- **가능**: `CompatibilityResultModel{id,nameA,nameB,type,score,topicResults,summary,createdAt}` 고정 스키마는 **그대로 유지 가능**합니다. `score`(최상위 가중합)와 `topicResults`(텍스트)는 계산 방식이 해시→사주로 바뀌어도 **타입과 키가 동일**하므로 Flutter 쪽 코드 변경이 불필요합니다.
- 단, 4개 팩터를 3.5절 B안(비노출)으로 간다면 응답에서 `factorScores` 구조 자체가 바뀌므로 그 경우에만 Flutter 수정이 필요합니다. **A안(현행유지)을 택하면 Flutter 측 수정은 0건**입니다.

### 3.8 점수 산식 설계

```
# 기존 가중평균 로직은 그대로 재사용
factorScores.saju = get_compatibility(person_a, person_b).final_score   # 0~100, 엔진 직산출
factorScores.mbti / interest / value / activity_pattern = 기존 해시 로직 유지 (3.5 A안)

score = Σ (factorScores[f] * weight[f]) / Σ weight[f]   # CompatibilityFactorWeight DB값, 기존과 동일
```

- `final_score`는 이미 0~100 범위로 clamp되어 있으므로 기존 해시 점수(50±22.5 범위)와 **스케일이 호환**되어 가중평균 로직 수정이 불필요합니다.

### 3.9 예외 처리 설계

| 상황 | 처리 방안 |
|---|---|
| saju_engine `/compatibility` 호출 타임아웃/5xx | **폴백**: 기존 해시 로직으로 `saju` 팩터 계산(현행 유지) + `scoreEngineVersion: "hash-fallback"` 기록. 사용자에게는 실패를 노출하지 않고 기존 방식대로 응답(가용성 우선). |
| 생년월일 포맷 오류(월/일 범위 밖 등) | 기존 요청 검증 로직(route.ts의 기존 입력 검증) 그대로 유지, 엔진 호출 이전 단계에서 차단 |
| 윤달 등 엔진이 거부하는 입력(422) | 1.1절에서 확인된 바와 같이 서버가 윤달을 지원하지 않으므로, 윤달 생년월일인 경우 **해시 폴백**으로 처리(사주 계산 불가능한 입력에 대한 명시적 처리) |

### 3.10 회귀 테스트 / 결과 검증 기준 설계

구현 단계(별도 승인 후)에서 추가해야 할 테스트 항목을 다음과 같이 제안합니다(이번 세그먼트에서는 작성하지 않음, 설계만):

1. **단위 테스트**: `hashSeed()` 기반 기존 4개 팩터(mbti/interest/value/activity_pattern) 값이 **변경 전후 동일**해야 함(회귀 방지).
2. **통합 테스트**: 동일 생년월일 쌍에 대해 `/compatibility` 응답의 `final_score`가 `factorScores.saju`에 정확히 반영되는지 확인.
3. **폴백 테스트**: saju_engine 연결 실패를 모의(mock)했을 때 `scoreEngineVersion: "hash-fallback"`으로 정상 응답하는지 확인.
4. **과거 데이터 호환 테스트**: `scoreEngineVersion` 필드가 없는 기존 `CompatibilityResult.detail` 레코드를 조회했을 때 애플리케이션이 오류 없이 `"hash-v1"`로 간주하는지 확인.
5. **스케일 검증**: 다수의 생년월일 쌍 샘플에 대해 `final_score` 분포가 0~100 범위를 벗어나지 않는지 확인(엔진 자체가 clamp하지만 통합 레벨에서도 재확인).
6. **결과 검증 기준**: 사주 모듈이 제공하는 `band`/`band_desc`(5단계)와 최종 `score`가 논리적으로 일치하는지(예: band가 "최상"인데 score가 40대로 나오는 모순이 없는지) 확인.

---

## 4. 기존 기능에 미치는 영향과 위험

- **이번 세그먼트에서 실제로 변경된 파일은 `test/saju_cross_engine_validation_test.dart` 1개뿐**이며, 이는 테스트 코드 추가(+295줄)로 **런타임 동작에 영향 없음**. 전체 `flutter test` 378/378 통과로 회귀 없음을 확인했습니다.
- 본 문서(docs/*.md)는 신규 생성된 문서 파일로, **앱/서버 동작에 전혀 영향을 주지 않습니다.**
- 3장의 궁합 설계는 **미구현 상태**이며, 구현 시에도 3.9절 폴백 설계를 통해 기존 해시 기반 동작을 안전망으로 유지하도록 설계했습니다.
- 1장에서 발견된 정책 차이(진태양시/자시/윤달/출생시간미입력)는 **기존에도 이미 존재하던 차이**이며, 이번 세그먼트는 이를 "새로 만든" 것이 아니라 "발견하고 테스트로 고정"한 것입니다. 따라서 이 발견 자체로 인한 신규 위험은 없으나, 향후 PHASE1~4와 29종 Topic Engine을 더 가깝게 연동하려는 시도가 있을 경우 반드시 사전 고려해야 할 항목입니다.

## 5. 아직 검증하지 못한 항목

- **진태양시 보정의 영향 범위**: 이번 검증은 1990-02-04(입춘) 1개 절기 경계만 재현했습니다. 24절기 전체에 대한 전수 검증은 수행하지 못했습니다.
- **자시 정책 차이가 69종 해석 문구에 미치는 실질적 영향**: 일주가 바뀌는 경계 케이스가 69종 콘텐츠 중 구체적으로 어떤 항목의 텍스트를 바꾸는지까지는 조사하지 않았습니다.
- **궁합 모듈의 `gan_to_gan` 100개 조합 전체에 대한 명리학적 타당성 검수**: 서버 모듈이 이미 존재한다는 사실과 1건의 curl 테스트로 정상 작동함만 확인했으며, 100개 조합 전체의 점수/설명 텍스트를 전수 검토하지는 않았습니다.
- **3.9절 폴백 설계의 실제 응답 지연(latency) 영향**: admin_web이 매 궁합 요청마다 saju_engine을 동기 호출하게 될 경우의 응답시간 증가분은 실측하지 않았습니다(설계 단계이므로 구현 전 별도 성능 테스트 필요).
- **4개 비사주 팩터의 향후 실제 데이터 수집 방안(3.5절 C안)**: 방향만 제시했을 뿐 구체적 UX/DB 설계는 하지 않았습니다.

## 6. 구현 시 필요한 승인 사항

구현 단계로 진행하려면 다음 각각에 대해 **별도 승인**이 필요합니다(이번 세그먼트에서는 어느 것도 구현하지 않았습니다):

1. **admin_web `compatibility/request/route.ts` 코드 수정** — 해시 로직을 saju_engine 호출로 교체(3.3절).
2. **`CompatibilityResult.detail` JSON에 `scoreEngineVersion` 필드 추가** — 스키마 마이그레이션은 불필요하나 애플리케이션 코드 변경 필요(3.6절).
3. **(선택) 3.5절 B/C안 채택 시** — Flutter `CompatibilityResultModel`/`compatibility_input_screen.dart` 수정 범위 확대.
4. **(선택) 1.4절의 정책 통일 방향 중 하나 채택 시** — 진태양시/자시/윤달 정책을 양쪽 엔진 중 어느 하나라도 변경하는 것은 69종/정통사주 보호 원칙과 직결되므로 **반드시 사전 승인** 필요.
5. **(선택) 윤달 API 지원 추가 시** — `BirthInputV3`에 `is_leap` 필드 추가는 서버 API 스펙 변경이므로 승인 필요.
6. **3.10절 회귀 테스트 작성 및 실행** — 구현 승인과 함께 진행.

---

*이 문서는 코드/API/DB/운영 데이터를 변경하지 않는 순수 조사·설계 산출물입니다. 실제 구현은 위 6장의 승인 이후에만 진행됩니다.*
