# [서버 이관 요청] 귀인지도 ↔ 궁합지도 "해석 결과값 동일" 버그 조사

- **작성일**: 2026-11-14
- **작성자**: Flutter 방(앱) — **조사만 수행, 코드 수정 없음**
- **검수 기준 커밋**: `fdea7a0` (branch `fix/zoom-persist-on-pinch`)
- **대표 신고**: *"귀인지도를 구합지도를 보면 해석 결과값이 다 똑같은데 이거 버그 아니야?"*
- **결론**: **서버(admin_web) 책임이 맞습니다.** 앱에서 고칠 수 없습니다.
- **요청**: 아래 §3의 4개 항목 확인 및 수정

---

## 0. 조사 원칙

이 문서는 **조사 보고서**입니다.
앱 코드는 **한 줄도 수정하지 않았습니다.** 수정은 대표 승인(OPERATIONS_POLICY §3) 후 진행합니다.

---

## 1. 대표 신고 증상

> 귀인지도와 궁합지도에서 **관계 해석 문구가 똑같이 나온다.**

앱 코드 조사 결과 **증상은 실재하며, 원인은 서버에 있습니다.**

---

## 2. 근본 원인 (확정)

### 2-1. 한 문장 요약

> **두 기능이 같은 판정 엔진(`guinji-relation-judger.ts`)을 쓰는데,
> 서버가 궁합지도 응답에 "귀인지도 6종 라벨/설명"을 그대로 넣어서 내려주기 때문입니다.**

### 2-2. 구조 설명

```
                ┌──────────────────────────────────────┐
                │  공통 판정 엔진 (admin_web)            │
                │  guinji-relation-judger.ts           │
                │  → relationType 6종 산출              │
                │  → chemistryScore 산출                │
                └───────────────┬──────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
    ┌───────────────────────┐      ┌──────────────────────────┐
    │ 귀인지도               │      │ 궁합지도                   │
    │                       │      │                          │
    │ relationType (키)만 받음│      │ relationType +            │
    │ → 앱이 자체 6종 메타로   │      │ relationTypeLabel +      │◄── 여기!
    │   라벨·설명 그림        │      │ relationTypeDesc 를 받음   │
    │                       │      │ → 그대로 화면 출력         │
    └───────────────────────┘      └──────────────────────────┘
         독립된 해석                     귀인지도 라벨 재사용
```

### 2-3. 코드 증거 (앱 쪽 계약 주석)

**귀인지도 응답** — `lib/features/guinji/data/guinji_repository.dart`
```dart
// 100행
반환: {memberId, relationship:{relationType, chemistryScore, ohaengEvidence}}

// 298행
반환: {ownerName, relationType, chemistryScore, timeUnknown,
       dayMasterKr, dayMasterElement, joined:true, mapSummary:{total,counts}}
```
→ **`relationTypeLabel` / `relationTypeDesc` 필드가 없습니다.**
→ 라벨·설명은 **앱이 직접 생성**(`guinjiRelationTypes`, 앱 내 6종 정의)

**궁합지도 응답** — `lib/features/gunghap/data/gunghap_repository.dart`
```dart
// 221행
반환: {resultId, ownerName, guestName, relationType,
       relationTypeLabel, relationTypeDesc,      ← ★ 귀인지도엔 없는 필드
       chemistryScore, grade, gradeCode,
       categories (8개), unlocked, unlockCost, detail?}

// 165행 (게스트 join)
반환: {resultId, ownerName, guestName, relationType, relationTypeLabel,
       relationTypeDesc, chemistryScore, grade, gradeCode, timeUnknown,
       dayMasterKr, dayMasterElement, categories (8개), unlockCost, joined}
```
→ **`relationTypeLabel` / `relationTypeDesc`를 서버가 직접 내려줍니다.**

### 2-4. 화면 출력 방식 차이

| | 귀인지도 | 궁합지도 |
|---|---|---|
| 라벨/설명 출처 | **앱 하드코딩** | **서버 응답값 그대로** |
| 근거 코드 | `guinji_guest_result_screen.dart:83-87`<br>`final meta = guinjiRelationMetaOf(relationKey);`<br>`final label = meta.label;`<br>`final body = narratorText ?? meta.long;` | `gunghap_guest_result_screen.dart:46-47`<br>`final relationTypeLabel = result['relationTypeLabel'];`<br>`final relationTypeDesc = result['relationTypeDesc'];`<br>→ `_SummaryCard`에서 그대로 `Text()` 출력 |
| 궁합지도가 귀인지도 해석 파일을 import 하나? | — | ❌ **0건** (아래 검증) |

**검증 명령 및 결과**
```bash
grep -rn "guinjiDeepText|guinjiRelationTypes|guinjiRelationMetaOf|guinjiReasons" \
      lib/features/gunghap
→ 결과 0건
```

### 2-5. 정리

> 앱은 **아무것도 재사용하지 않습니다.**
> 궁합지도가 귀인지도와 **똑같은 문구**를 보여주는 유일한 경로는
> **서버가 `relationTypeLabel`/`relationTypeDesc`에 귀인지도 문구를 넣어 보내는 것**입니다.

---

## 3. 🔴 저쪽 방(admin_web) 확인·수정 요청 4건

### 3-1. [확인] `relationTypeLabel` / `relationTypeDesc`의 실제 문자열

**요청**: 궁합지도 API 4곳에서 실제로 어떤 문자열을 내려주는지 확인해 주세요.

| API | 파일(추정) |
|---|---|
| `POST /api/public/gunghap/invites` | `.../gunghap/invites/route.ts` |
| `GET /api/public/gunghap/g/{token}` | `.../gunghap/g/[token]/route.ts` |
| `POST /api/public/gunghap/g/{token}/join` | `.../gunghap/g/[token]/join/route.ts` |
| `GET /api/public/gunghap/results/{resultId}` | `.../gunghap/results/[resultId]/route.ts` |

**확인 방법**: 실제 응답의 `relationTypeLabel`, `relationTypeDesc`를 아래 표와 비교

**앱에 하드코딩된 귀인지도 6종 문구** (비교 기준 — `guinji_relation_meta.dart`)

| relationType | label | description (귀인지도) |
|---|---|---|
| `CHEON_GWII` | 천생귀인 | 타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계예요. |
| `HAP` | 인연합 | 일지가 합을 이루어 자연스럽게 끌리고 정이 깊어지는 관계예요. |
| `SANG_SAENG` | 상생동행 | 한쪽이 다른 쪽을 살리고 키워주는 상생의 관계예요. |
| `SANG_GEUK` | 상극조율 | 서로 극하는 기운으로 긴장과 조율이 공존하는 관계예요. |
| `BI_HWA` | 동류동반 | 같은 오행으로 결이 비슷해 편안하게 동행하는 관계예요. |
| `CHUNG` | 충돌극복 | 일지가 충하여 부딪히지만 그만큼 성장을 만드는 관계예요. |

> **판정 기준**: 위 문구가 `relationTypeDesc`에 **그대로** 들어 있으면 → **버그 확정**

---

### 3-2. [수정] 궁합지도 전용 해석 문구로 교체

**현재 (문제)**: 궁합지도가 **귀인지도의 "관계 해석"** 을 그대로 사용
- 예: 천생귀인 → *"타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계예요."*

**기대 (수정안)**: **궁합(2인 궁합) 맥락**의 문구로 분리

| relationType | 귀인지도 문구 (현재) | 궁합지도에 필요한 문구 (예시) |
|---|---|---|
| `CHEON_GWII` | 타고난 인연으로 서로를 살리고 크게 이끌어 주는 관계예요. | 서로의 부족함을 채워주며 함께 성장하는 최상의 궁합이에요. |
| `HAP` | 일지가 합을 이루어 자연스럽게 끌리고 정이 깊어지는 관계예요. | 이유 없이 끌리고 정이 깊어지는, 함께할수록 좋아지는 궁합이에요. |
| `SANG_SAENG` | 한쪽이 다른 쪽을 살리고 키워주는 상생의 관계예요. | 한 사람이 다른 한 사람을 살리고 키워주는 궁합이에요. |
| `SANG_GEUK` | 서로 극하는 기운으로 긴장과 조율이 공존하는 관계예요. | 부딪히지만 그만큼 배울 것이 많은, 조율이 필요한 궁합이에요. |
| `BI_HWA` | 같은 오행으로 결이 비슷해 편안하게 동행하는 관계예요. | 결이 비슷해 편안하지만, 서로 닮아 자극이 적을 수 있는 궁합이에요. |
| `CHUNG` | 일지가 충하여 부딪히지만 그만큼 성장을 만드는 관계예요. | 부딪힘이 잦지만 거리를 조절하면 오래갈 수 있는 궁합이에요. |

> 위 문구는 **예시**입니다. 실제 톤앤매너는 기획 확정 후 결정해 주세요.
> **핵심 요청**: 귀인지도와 **다른 문자열**을 쓰게 분리

**대안(권장)**: 궁합지도는 이미 **8분야 LLM 해석**을 하고 있으므로,
`relationTypeDesc`를 **궁합 맥락으로 LLM이 생성**하거나, 최소한 **별도 상수 테이블**로 분리

---

### 3-3. [확인] 등급 임계값이 양쪽 동일한지

| | 등급 정의 위치 |
|---|---|
| 귀인지도 | **앱** (`guinji_type_spec.dart:112`)<br>`S: 90+ / A: 75+ / B: 60+ / C: 45+ / D: 45미만` |
| 궁합지도 | **서버** (`grade`, `gradeCode` 문자열)<br>앱은 임계값 정의 **없음** |

**위험**: 두 기능이 같은 `chemistryScore`를 쓰는데 **등급 경계가 다르면**
- 귀인지도에서 `A`인 사람이 궁합지도에서 `B`로 나오는 **모순** 발생

**요청**: 서버 `grade` 산출 임계값을 알려주세요.
앱의 `S/A/B/C/D` 경계와 다르면 → **기획 결정 필요** (통일 or 분리)

---

### 3-4. [확인] 궁합지도 6종이 "관계 유형"인지 "궁합 등급"인지

**혼동 지점**:
- 귀인지도의 6종 = **관계의 종류** (천생귀인, 인연합 …)
- 궁합지도의 6종 = **같은 6종을 그대로 사용** + 별도로 `grade`(S/A/B/C/D)도 있음

**즉 궁합지도는 지표가 2개입니다.**

| 지표 | 의미 |
|---|---|
| `relationType` (6종) | 사주 구조상 관계 유형 |
| `grade` + `chemistryScore` | 궁합 점수 등급 |

**요청**: 이 2개 지표의 **역할 분담**을 문서화해 주세요.
(예: "천생귀인인데 C등급"이 사용자에게 어떻게 설명되어야 하는가?)

---

## 4. 참고 — 앱 쪽에서 발견한 추가 불일치 2건
> 대표 신고와 직접 관련은 없지만, 조사 중 발견해 함께 보고합니다.

### 4-1. 귀인지도 6종의 **한자 인장**이 앱 안에서 두 벌로 다름

| relationType | 파일 A: `guinji_relation_meta.dart` | 파일 B: `guinji_type_spec.dart` | 실제 화면 사용 |
|---|:--:|:--:|---|
| CHEON_GWII | 貴 | 貴 | A ✅ |
| HAP | 緣 | 緣 | A ✅ |
| SANG_SAENG | 生 | 生 | A ✅ |
| **SANG_GEUK** | **剋** | **調** | **A** (다른 화면은 B 가능) |
| **BI_HWA** | **比** | **同** | **A** |
| **CHUNG** | **沖** | **衝** | **A** |

**원인**: `guinji_relation_meta.dart`(상세 해설판)와 `guinji_type_spec.dart`(v2 경량판) 두 파일이 공존.
`guinji_type_spec.dart` 주석에도 *"이 파일은 기존 `guinji_relation_meta.dart`와는 별개의 최종 v2 경량 스펙"* 이라고 명시됨.

**위험**: 화면에 따라 다른 한자가 그려질 수 있음.
**앱 담당**이나, **서버가 한자를 내려준다면** 기준이 필요합니다.

### 4-2. 앱에 궁합이 **2벌** 존재

| 기능 | 경로 | 관계 판정 |
|---|---|---|
| **궁합(구형)** | `/compatibility/input`, `/compatibility/result` | ❌ **6종 없음** — 4유형(애정/우정/사업/가족)만 |
| **궁합지도(현행)** | `/gunghap/*` | ✅ **6종 있음** |

**사용자 혼동 위험**: 홈에서 어느 쪽으로 들어가느냐에 따라 **다른 결과 화면**을 봄.
→ **기획 확인 필요**: 구형 `/compatibility` 유지인지, 궁합지도로 통합인지

---

## 5. 요약 표

| 항목 | 귀인지도 | 궁합지도 | 판정 |
|---|---|---|---|
| 판정 엔진 | `guinji-relation-judger.ts` | **같은 것** | 공유 (정상) |
| 입력 계약 | `GuinjiSajuInput` | **같은 것** | 공유 (정상) |
| 6종 관계 | ✅ 있음 | ✅ 있음 | 공유 (정상) |
| `chemistryScore` | ✅ | ✅ | 공유 (정상) |
| **라벨 출처** | **앱** | **서버** | **불일치 → 버그** |
| **설명 출처** | **앱** | **서버** | **불일치 → 버그** |
| 해석 생성 | 고정 텍스트 150문단 | LLM 8분야×4 | 분리 (설계상 정상) |
| 오행 근거 | ✅ `ohaengEvidence` | ❌ 없음 | **비대칭** |
| 등급 | 앱 정의 S~D | 서버 문자열 | **확인 필요** |
| 한자 인장 | 貴緣生剋比沖 | 표시 안 함 | 문제 없음 |

---

## 6. 요청 사항 정리 (저쪽 방 작업 목록)

| # | 구분 | 내용 | 우선순위 |
|:--:|---|---|---|
| **1** | 확인 | 궁합지도 API 4곳의 `relationTypeLabel`/`relationTypeDesc` 실제 문자열 (§3-1) | **높음** |
| **2** | **수정** | 궁합지도 전용 해석 문구로 분리 (§3-2) | **높음** |
| **3** | 확인 | 등급 임계값이 앱(S/A/B/C/D)과 동일한지 (§3-3) | 중간 |
| **4** | 문서화 | `relationType`(6종) vs `grade`(S~D) 역할 분담 (§3-4) | 중간 |

---

## 7. 검증 명령 (저쪽 방에서 그대로 실행 가능)

```bash
# 1) 궁합지도 응답에서 라벨/설명 필드 확인
curl -s "{API_BASE}/api/public/gunghap/g/{token}" | jq '.data | {relationType, relationTypeLabel, relationTypeDesc}'

# 2) 귀인지도 응답에는 그 필드가 없는지 확인 (대조)
curl -s "{API_BASE}/api/public/guinji/g/{token}" | jq '.data | {relationType, relationTypeLabel, relationTypeDesc}'
# 기대: relationType만 있고 label/desc는 null 또는 없음

# 3) 앱이 귀인지도 해석 파일을 쓰는지 확인 (0건이어야 정상)
cd flutter_app && grep -rn "guinjiDeepText|guinjiRelationTypes|guinjiReasons" lib/features/gunghap
```

---

## 8. 문의

- 수정 착수 전 **OPERATIONS_POLICY.md §3 대표 승인** 필요
- §10에 따라 **운영 도메인(`sintong.kr`)으로 테스트 요청 금지** — 로컬/샌드박스 API 사용
- 앱 쪽 수정이 필요해지면(예: 한자 통일) **앱 방에 통보**해 주세요
