# [인수인계] 신통방통 Flutter 앱 전체 검수 — 버그 정리 및 담당 분류

- **작성일**: 2026-11-14
- **작성자**: Flutter 방(앱)
- **검수 대상**: Flutter 앱 (`/flutter_app`)
- **검수 기준 커밋**: `4cc497c` (branch `fix/zoom-persist-on-pinch`)
- **목적**: 앱 검수 중 발견된 결함을 **앱 담당 / 서버(admin_web) 담당**으로 분리하여, 서버 담당 방에 작업을 넘긴다.
- **중요**: 이 문서는 **보고서이며, 이 문서 작성 시점에 앱 코드는 한 줄도 수정하지 않았다.** (아래 "미수정 원칙" 참고)

---

## 0. 미수정 원칙 (반드시 읽어주세요)

이 검수는 **"버그가 있는지 확인만"** 요청받은 작업이다.
과거 시키지 않은 수정이 **정상 작동하던 기능을 망가뜨린 이력**이 있어, 발견만 하고 **고치지 않았다.**

따라서 이 문서의 모든 항목은:
- **발견 기록**이며,
- 수정을 하려면 **운영정책(OPERATIONS_POLICY.md) §3 대표 승인**이 먼저 필요하다.

---

## 1. 검수 범위와 방법

| 항목 | 값 |
|---|---|
| 기능 폴더 | 38개 |
| 화면 파일 | 159개 (`*_screen.dart`) |
| 라우트 | 91개 |
| 테스트 파일 | 149개 |
| 정적 분석 | `flutter analyze` |
| 자동 테스트 | `flutter test` (전체) |
| 회귀 비교 | `git worktree`로 변경 전 시점(`ce0509d`) 복원 후 동일 실행 |

### 검수 결과 요약

| 구분 | 결과 |
|---|---|
| 컴파일 에러 | **0건** (`flutter analyze` errors: 0) |
| 치명적 결함(크래시/결제 오류) | **없음** |
| 실제 사용자 체감 UI 결함 | **1건** (§3-A) |
| 테스트 시스템 결함 | **12개 파일 무력화** (§3-B) |
| 서버 계약 관련 위험 | **3건** (§4) |
| 정적 위험(잠재) | 강제 형변환 1,218건 (§5) |

### "내 변경 탓인가?" — 검증 완료

자동 테스트 **48건 실패**가 나왔으므로, 변경 전 시점(`ce0509d`)을 별도 작업공간에 복원해 똑같이 실행했다.

| 시점 | 실패 건수 |
|---|---|
| 변경 전 `ce0509d` | **48건** |
| 변경 후 `4cc497c` | **48건 (동일)** |

→ **앱 검수자의 최근 변경과 무관한, 원래부터 있던 결함**이다.

---

## 2. 담당 경계 정의

| 영역 | 담당 | 내용 |
|---|---|---|
| Flutter 앱 UI/상태/라우팅 | **앱 방** | 화면 레이아웃, 위젯, 로컬 상태 |
| 서버 API 응답/DB/어드민 입력값 | **서버(admin_web) 방** | 광고/배너 데이터, API 계약, OG 이미지 |
| 앱–서버 계약 동시 수정 필요 | **양쪽 협의** | 아래 §4 |

---

## 3. 앱 담당 항목

### 3-A. [실제 버그] 결과보기 게이트 시트가 작은 화면에서 넘침

| 항목 | 내용 |
|---|---|
| **파일** | `lib/features/result_access/presentation/result_access_gate_sheet.dart` |
| **위치** | `build()`의 `SafeArea > Padding > Column` (**421행** `child: Column(`) |
| **증상** | 320×568 화면 + 글씨 160%에서 **아래로 5.0px 오버플로** |
| **원인** | 시트가 `Column(mainAxisSize: min)`만 있고 **`SingleChildScrollView`(스크롤)가 없음**. 화면이 작거나 글씨가 크면 내용을 밀어낼 방법이 없어 넘친다. |
| **확인된 재현 범위** | 아래 표 참고 |

#### 실측 결과 (앱에서 실제 선택 가능한 배율만)

> 앱의 글씨 확대는 `lib/core/theme/text_scale_provider.dart`의 `steps = [1.0, 1.15, 1.3, 1.45, 1.6]`로 **최대 1.6배**다.
> 기존 테스트는 **2.0·2.5배**까지 검사하는데, 이는 **사용자가 도달할 수 없는 값**이다.

| 화면 크기 | 1.0배 | 1.3배 | **1.6배(앱 최대)** |
|---|---|---|---|
| 360×780 (일반 폰) | OK | OK | **OK** |
| 320×568 (초소형 폰) | OK | OK | ⚠️ **5.0px 초과** |

#### 참고: 기존 테스트에 찍힌 "272px"는 과장된 수치

기존 테스트 로그의 `RenderFlex overflowed by 272 pixels on the bottom`은 **2.5배(도달 불가)** 조건에서 나온 값이다.
실제 도달 가능한 최대치(1.6배)로 다시 측정하면 **5.0px**다. → **심각도는 "낮음"으로 재분류 필요.**

#### 수정 방법 (참고 — 아직 적용하지 않음)

같은 앱의 **쿠팡 프리패스 시트는 이미 올바른 패턴**을 쓰고 있다. 그대로 따라 하면 된다.

- **참조 파일**: `lib/features/pass/presentation/coupang_pass_sheet.dart` (276~278행)
  ```dart
  return SafeArea(
    top: false,
    child: SingleChildScrollView(   // ← 이게 있음 (278행)
      child: Padding(...),
  ```
- **수정 대상**: `result_access_gate_sheet.dart`의 `SafeArea > Padding > Column` 구조에서
  `Padding` **바깥**을 `SingleChildScrollView`로 감싼다 (쿠팡 시트와 동일한 순서: `SafeArea > SingleChildScrollView > Padding > Column`).
- **위험도**: 낮음 (레이아웃 1줄 추가, 로직 변경 없음)
- **수정 후 필수**: 운영정책 §9-3 프리뷰 검증 + §9-4 실기기 검증

#### 관련 테스트

| 파일 | 상태 |
|---|---|
| `test/result_access_gate_sheet_overflow_test.dart` | 가로 오버플로는 이미 수정됨(주석에 기록). 세로 5px만 남음 |
| `test/saju_result_access_gate_sheet_overflow_test.dart` | `Provider` 미주입으로 별도 실패 (§3-B) |

---

### 3-B. [테스트 시스템 결함] 결과화면 테스트 12개 파일이 무력화 상태

이건 **앱 화면 버그는 아니지만, 앞으로의 버그를 못 잡게 만드는 결함**이라 우선순위가 높다.

| 항목 | 내용 |
|---|---|
| **증상** | `ProviderNotFoundException: Could not find the correct Provider<TextScaleProvider> above this ResultTextScaleOverlay` |
| **원인** | 결과 페이지들이 "글씨 확대 캡슐"(`ResultTextScaleOverlay`)을 쓰는데, 테스트 코드가 그 부품을 감싸주지 않아 **첫 렌더링에서 즉시 실패**한다. |
| **도입 시점** | 커밋 `345332a` (글씨 확대 캡슐을 **전역 오버레이 → 결과페이지별 배치**로 변경) 때 테스트를 함께 고치지 않음 |
| **핵심 위험** | 결과화면 **overflow(화면 깨짐) 테스트들이 아무것도 검사하지 못하고 있다.** 향후 결과 페이지에 진짜 깨짐이 생겨도 테스트가 통과해버린다. |

#### 영향받는 테스트 파일 (12개 / 39건)

| 테스트 파일 | 실패 건수 |
|---|---|
| `shared_result_screen_overflow_test.dart` | 10 |
| `guinji_map_screens_smoke_test.dart` | 6 |
| `saju_result_access_gate_sheet_overflow_test.dart` | 4 |
| `cross_check_cta_navigation_test.dart` | 4 |
| `story_preview_screen_c05_test.dart` | 3 |
| `story_detail_screen_c07_test.dart` | 3 |
| `analysis_complete_screen_c04_test.dart` | 2 |
| `result_access_gate_sheet_overflow_test.dart` | (일부) |
| `original_result_capture_test.dart` | 2 |
| `story_preview_screen_e06_test.dart` | 1 |
| `story_detail_screen_e07_test.dart` | 1 |
| `share_system_contract_test.dart` | 1 |
| `guinji_owner_face_regression_test.dart` | 1 |

#### 수정 방법 (참고 — 아직 적용하지 않음)

테스트에서 화면을 그릴 때 `TextScaleProvider`를 위에 넣어준다.

```dart
await tester.pumpWidget(
  ChangeNotifierProvider(
    create: (_) => TextScaleProvider(),
    child: /* 기존 위젯 */,
  ),
);
```

- **앱 코드 변경 없음** (테스트 파일만 수정) → **앱 동작에 영향 0**
- **위험도**: 매우 낮음
- 단, 12개 파일을 한 번에 고치면 "테스트가 갑자기 새 버그를 잡아낼" 수 있다. **파일별로 1개씩 고치고 결과를 확인**할 것을 권장.

---

### 3-C. [낡은 테스트] 기대 문구가 옛날 것 (앱 버그 아님, 테스트만 정리하면 됨)

| 테스트 | 찾는 문구 | 실제 화면 |
|---|---|---|
| `tarot_ui_verification_test.dart` | "카드 풀이", "과거" | 문구 변경됨 |
| `story_preview_screen_*` | "테스트 이야기 제목" 등 | 화면 구조 변경됨 |
| `original_result_capture_test.dart` | — | `Bad state: No element` |
| `guinji_owner_face_regression_test.dart` | — | `Bad state: No element` |

**판단**: 앱은 정상. 테스트만 낡았다. **우선순위 낮음.**

---

## 4. 🔴 서버(admin_web) 담당 항목 — 이쪽 방에 요청

> 이 3건은 **Flutter 앱에서 고칠 수 없거나, 고쳐도 근본 해결이 안 되는** 항목이다.

### 4-1. [요청] 광고 제목 길이 제한이 서버에 없음

| 항목 | 내용 |
|---|---|
| **증거** | `test/fortune_ad_watch_dialog_overflow_test.dart` 상단 주석: *"제목에 길이 제한이 없어, 아주 긴 제목(관리자가 임의로 입력 가능) + textScale 1.5배 이상 조합에서 overflow"* |
| **서버 책임** | 어드민에서 **광고 제목을 관리자가 자유 입력**하는데, 길이 제한이 없다. |
| **요청** | 어드민 광고 등록/수정 API에서 `title` **최대 길이 검증(권장 30자)** + DB 컬럼 길이 제한 |
| **앱 측 현재 상태** | 테스트의 긴 제목은 **실제 광고 화면(`_WatchingView`)에서 렌더링되지 않는다.** 해당 화면은 `'광고 보고\n복주머니 받기'` **고정 문구**를 쓴다 (`fortune_ad_watch_dialog.dart:491`).<br>→ 즉 **현재는 실제로 터지지 않는다.** 다만 `_buildAdmobWaitingView()`(620행)는 `ad.title`을 `maxLines: 2`로 그리므로, **admob 타입 + 극단적 긴 제목**이면 잠재 위험은 남아 있다. |
| **우선순위** | 중간 (현재 무해, 예방 조치) |

### 4-2. [요청] 카카오 로그인 Redirect URI 등록 확인 — **운영자 직접 확인 필요**

| 항목 | 내용 |
|---|---|
| **파일** | `lib/core/config/social_auth_config.dart:36` |
| **원문** | *"⚠️ TODO(운영자 조치 필요): 카카오 로그인 > Redirect URI에 `https://sintong.kr/app/`(또는 실제 배포 경로)가 등록되어 있는지 별도로 확인이 필요하다"* |
| **문제** | 앱 코드로는 **검증 불가**. 카카오 디벨로퍼스 콘솔 등록 상태에 달려 있다. |
| **요청** | 카카오 디벨로퍼스 > 신통방통(App ID 1571801) > 카카오 로그인 > Redirect URI 목록에 실제 배포 경로가 등록돼 있는지 확인 |
| **왜 서버 쪽인가** | 배포 도메인/경로(`sintong.kr/app/`)를 결정·관리하는 주체가 서버/배포 담당이기 때문 |
| **우선순위** | **높음** — 잘못되면 카카오 로그인 자체가 실패할 수 있음 |

### 4-3. [요청] OG 이미지 경로 계약 유지 확인 (귀인지도 카카오 공유)

| 항목 | 내용 |
|---|---|
| **앱 코드** | `lib/features/guinji/share/guinji_share_kakao.dart` |
| **앱이 기대하는 서버 경로** | `/g/[token]/page.tsx` (초대 랜딩)<br>`/og/guinji/[token]/[shareCode].png` (초대 OG, 1200×630)<br>`/og/guinji/[token]/result.png` (결과 OG) |
| **과거 이력** | 앱 주석에 *"과거 `sintong.app/g/{token}` (미등록 도메인) 하드코딩이 카톡 인앱 브라우저에서 **404를 유발한 버그**가 있었다"* 고 기록됨 |
| **요청** | 위 3개 경로가 **admin_web에 실제로 존재하고 200을 반환하는지** 확인 |
| **이유** | 카톡 공유는 OG 이미지가 없으면 **미리보기가 깨져서 공유 자체를 안 하게 된다.** 앱만으로는 검증 불가. |
| **우선순위** | 중간 |

---

## 5. 양쪽 협의 필요 — 잠재 위험 (지금 터지지 않음)

### 5-1. 서버 응답 형식이 하나만 달라도 앱이 죽는 구조

| 항목 | 수치 |
|---|---|
| 강제 형변환 `as Type` | **1,218건** |
| 안전한 형변환 `as Type?` | **0건** |
| 널 단언 `!` | 22건 |
| 빈 `catch (_) {}` | 24건 / 전체 catch 386건 |

**의미**: 서버가 필드 하나를 `null`로 보내거나 타입을 바꾸면 **앱이 즉시 크래시**한다. 그리고 빈 `catch`가 에러를 삼켜서 "왜 안 되지?"만 남는다.

**제안**:
- **서버 방**: API 응답 스키마를 **절대 필드 삭제/타입 변경 없이** 하위 호환으로만 변경
- **앱 방**: 서버 응답을 받는 `*_repository.dart` 계층 상위 3~4곳만 `as?` + null 기본값으로 보강

**우선순위**: 낮음 (지금 문제없음, 예방)

---

## 6. 부록 — 운영자 참고 사항 (버그 아님)

### 6-1. APK 용량 285.9MB 중 폰트가 52MB

| 폰트 | 크기 | pubspec 선언 |
|---|---|---|
| NotoSerifKR-Bold | 8.3MB | ✅ |
| NotoSerifKR-Black | 8.3MB | ✅ |
| GowunBatang-Regular | 8.2MB | ✅ |
| GowunBatang-Bold | 7.9MB | ✅ |
| Pretendard 5종 + Black | 13.4MB | ✅ |
| **NotoSansKR-Black** | **6.2MB** | ❌ **미선언** (assets에 파일만 등록) |
| IBMPlexMono 2종 | 47KB | ✅ |

- `NotoSansKR-Black.ttf`는 **폰트 패밀리로 선언되지 않았는데 APK에 포함**되어 6.2MB를 낭비 중. (`pubspec.yaml:233`에서 assets로만 등록)
- **앱 담당 항목**이나 급하지 않음. 정리 시 약 6MB 절감.

### 6-2. 앱이 의존하는 서버 API 개수

앱은 **`/api/public/*`, `/api/ads/*`, `/api/pouch-box/*` 계열 40여 개 엔드포인트**에 의존한다.
(전체 목록은 `grep -rhoE 'adminApiBaseUrl\}/api/...' lib --include=*.dart`로 추출 가능)

**서버 방 참고**: 이 엔드포인트들 중 하나라도 경로가 바뀌면 해당 기능 전체가 죽는다. 경로 변경 시 **앱 방에 사전 통보 필수**.

---

## 7. 작업 우선순위 요약

| 순위 | 항목 | 담당 | 위험도 | 비고 |
|---|---|---|---|---|
| **1** | 카카오 Redirect URI 등록 확인 (§4-2) | **서버/운영자** | 높음 | 앱 검증 불가 |
| **2** | 결과화면 테스트 12개 복구 (§3-B) | **앱** | 중간 | 앱 코드 무관, 안전 |
| **3** | OG 경로 3종 200 확인 (§4-3) | **서버** | 중간 | 카톡 공유 품질 |
| **4** | 결과보기 시트 5px 넘침 (§3-A) | **앱** | 낮음 | 스크롤 1줄 |
| **5** | 광고 제목 길이 제한 (§4-1) | **서버** | 낮음 | 예방 |
| **6** | 낡은 테스트 문구 정리 (§3-C) | **앱** | 낮음 | 정리 |
| **7** | `as` → `as?` 보강 (§5-1) | 양쪽 협의 | 낮음 | 예방 |
| **8** | 미선언 폰트 정리 (§6-1) | 앱 | 낮음 | 용량 6MB |

---

## 8. 재현 방법 (검증하는 사람이 그대로 실행 가능)

```bash
# 1) 정적 분석 (에러 0 확인)
cd /home/user/flutter_app && flutter analyze

# 2) 전체 테스트 (48건 실패 확인)
cd /home/user/flutter_app && flutter test

# 3) 결과화면 테스트 무력화 확인 (§3-B)
flutter test test/shared_result_screen_overflow_test.dart 2>&1 | grep -c ProviderNotFoundException

# 4) 결과보기 시트 5px 넘침 확인 (§3-A)
flutter test test/result_access_gate_sheet_overflow_test.dart

# 5) 변경 탓인지 확인 — 변경 전 시점 복원 후 비교
git worktree add /tmp/base_check ce0509d
cd /tmp/base_check && flutter test 2>&1 | tail -1
# → 동일하게 48건 실패하면 원래 있던 결함
cd /home/user/flutter_app && git worktree remove --force /tmp/base_check
```

---

## 9. 이 문서에 대한 문의

- 수정 착수 시 **OPERATIONS_POLICY.md §3 대표 승인** → §9-3 프리뷰 검증 → §9-4 실기기 검증 순서를 반드시 지킬 것
- §10에 따라 **운영 도메인(`sintong.kr`)으로 테스트 요청을 보내면 안 됨**. 테스트는 반드시 로컬/샌드박스 API로.
- 본 문서는 **검수 결과 보고**이며, 어떤 수정도 대표 승인 없이 진행하지 않는다.
