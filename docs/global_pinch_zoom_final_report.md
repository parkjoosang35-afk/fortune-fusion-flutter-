# 신통방통 전역 핀치 확대 시스템 — 최종 검수 보고서

지시서 §9 "최종 검수 기준(10개 체크리스트)"에 맞춰 실제 수행한 내용과
그 한계를 투명하게 기록한다. **검증하지 않은 항목은 "정상"이라고 보고하지
않는다**는 원칙에 따라, 코드 레벨/자동화 테스트로 확인한 것과 실기기에서만
확인 가능한 것을 명확히 구분한다.

---

## ① 기존 확대 기능 조사 및 제거 결과

**조사 방법**: `lib/` 전체를 `grep`으로 전수 검색(`InteractiveViewer`,
`onScaleStart/Update/End`, `pinch`/`핀치`, `pdf`/`printing` import 등).

| 발견된 기존 확대 구현 | 처리 |
|---|---|
| `zoomable_content.dart` `_ZoomableFullScreenView` — `InteractiveViewer(0.8~5배)` | **제거**. "탭→전체화면 Hero 전환" 네비게이션 자체는 확대와 무관하므로 보존 |
| `oz_card_peek_modal.dart` — `InteractiveViewer(1~4배)` | **제거**. 카드 flip 애니메이션 로직은 그대로 보존 |
| `guinji_animated_graph.dart` — 자체 `onScaleStart/Update/End`(지도 확대+이동+노드탭, 0.6~2.5배) | **제거하지 않음** — 전역 확대(화면 캡처)와는 의미가 다른 "지도 좌표 변환+노드 인터랙션" 기능이라 삭제 대상이 아니다. 대신 `PinchZoomDisabled`로 감싸 전역 엔진과의 충돌만 차단(기능 자체는 100% 보존) |
| `pdf: 3.11.3`, `printing: 5.14.3` 패키지 | **조사 결과 애초에 미사용** — `lib/` 전체 어디에서도 import 0건. "PDF 문서 출력 기능을 삭제하지 않도록 하라"는 지시가 있었으나, 그 기능 자체가 구현된 적이 없었다는 사실을 투명하게 보고한다. 패키지 선언은 삭제하지 않고 그대로 유지(향후 실제 구현 시 재사용 가능하도록) |
| `google_mobile_ads: 5.2.0` | `AdWidget`/`BannerAd`/`RewardedAd`/`InterstitialAd` 사용 0건 확인 — 실제 광고 SDK가 아직 통합되지 않은 상태. "광고 기능과 확대 엔진 분리" 요구사항은 분리할 대상(통합된 광고 코드)이 현재 없음을 보고 |

**결론**: "개별 이미지/화면별 확대 방식은 금지한다"에 해당하는 항목
2건(zoomable_content, oz_card_peek_modal)을 제거했고, 삭제가 아니라
"기능과 확대 동작을 분리"해야 하는 항목 1건(귀인지도 그래프)은 제외
처리로 공존시켰다. 이미지 원본 렌더링(`Image.asset`)·Hero 전환 UX는
전혀 건드리지 않았다.

---

## ② 통합 확대 엔진 구현

`lib/core/zoom/` 디렉토리에 4개 컨트롤러 + 통합 매니저를 분리 구현:

| 파일 | 역할 |
|---|---|
| `pinch_zoom_gesture_controller.dart` | Gesture Controller — 순수 `Listener`로 제스처 아레나 비참여, 포인터 개수만 관찰 |
| `pinch_zoom_transform_controller.dart` | Transform Controller — scale/offset 계산, min/max 하드 클램프 |
| `pinch_zoom_boundary_controller.dart` | Boundary Controller — 화면 경계 밖 이동 제한 |
| `pinch_zoom_render_controller.dart` | Render Controller — `RenderRepaintBoundary.toImage()` 캡처, 리소스 dispose |
| `global_pinch_zoom_manager.dart` | 위 4개를 통합한 `GlobalPinchZoomOverlay` |
| `pinch_zoom_exclusion.dart` | `PinchZoomExclusionRegistry` + `PinchZoomDisabled` 제외 메커니즘 |

`app.dart`의 `MaterialApp.builder`(모든 라우트/팝업/모달의 공통 조상)에
**단 1곳**에만 `GlobalPinchZoomOverlay`를 삽입 — "모든 화면에 무조건
InteractiveViewer를 중복 적용하는 방식은 금지한다" 요구사항에 정확히
대응(중복 삽입 없이 전역 1곳으로 전체 커버).

`flutter analyze`: 신규/수정 파일 전체 **No issues found**(프로젝트
전체 analyze 기준으로도 기존 113개 이슈 외 신규 이슈 0건).

---

## ③ 전체 화면 적용 목록

`docs/global_pinch_zoom_coverage.md`에 상세 기록. 요약:

- `core/router/app_router.dart` 전수 조사로 **91개 명명 라우트** 확인,
  지시서 §5 지정 13개 카테고리(홈/운세/정통사주/프리미엄사주/타로/
  귀인지도/관상/손금/소원방/부적/마이페이지/회원가입/결제)에 전부 매핑.
- 전역 삽입 구조상 91개 라우트 + AppShell 탭 + 모든 `showDialog`/
  `showModalBottomSheet` 팝업이 **구조적으로 전부 적용 대상**.
- 제외 구역 5개 파일(약관/광고 WebView 4개 + 귀인지도 그래프) 명시 및
  사유 기록.
- 재조사로 리스크가 해소된 항목(`face_capture_screen.dart`는 OS
  네이티브 카메라 앱 전환 방식이라 공존 안 함, `video_player` 패키지
  자체가 미사용)도 투명하게 기록.

---

## ④ 이미지 및 텍스트 화질 테스트

`docs/global_pinch_zoom_image_quality_review.md`에 상세 기록. 요약:

- 캡처 엔진이 저해상도 썸네일이 아닌 실제 화면 렌더링(`devicePixelRatio`
  기준)을 그대로 캡처함을 코드 레벨로 확인.
- 부적/배경/앱아이콘/홈v2 자산은 전부 고해상도(최소 572px~최대
  1360px) 확인.
- **문제 발견**: `wishroom/items`의 20개 아이콘이 200px 미만(최소
  90×102) — 3배 확대 시 체감 열화 가능성, 디자인 리소스 교체 권장
  (엔진으로 해결 불가능한 영역임을 명시).
- `guinji/chars` face 계열(256×256)도 보통 우선순위 교체 검토 대상.
- SVG 10개(하단 네비게이션) 지원 확인, 단 화면 캡처 방식 특성상 벡터
  무한확대 이점은 핀치 단계에서 활용되지 않음을 투명하게 명시.
- 텍스트가 이미지로 사전 변환되는 코드 경로 없음 확인.

**한계**: 실제 기기에서 손가락으로 3배까지 확대했을 때 육안으로 느껴지는
정확한 열화 정도는 이 샌드박스에서 측정할 수 없다 — 해상도 수치 기반
분석까지만 수행했다.

---

## ⑤ 화면별 제스처 충돌 테스트

**자동화 위젯 테스트로 확인**(`test/global_pinch_zoom_test.dart`,
`WidgetTester.createGesture()`로 다중 포인터 시뮬레이션):

| 테스트 | 결과 |
|---|---|
| 버튼 탭이 전역 오버레이 삽입 후에도 정상 동작 | ✅ 통과 |
| ListView 한 손가락 드래그 스크롤이 정상 동작 | ✅ 통과 |
| 2손가락 핀치 시작 시 확대 오버레이 등장, 손 떼면 소멸 | ✅ 통과 |
| 제외 구역(PinchZoomDisabled) 위 2손가락 입력은 확대를 켜지 않음 | ✅ 통과 |

**코드 조사로 확인**: `decor_screen.dart`/`compose_screen.dart`는
`onPanUpdate`(1손가락)만 사용, `onScale` 없음 — 전역 핀치(2손가락)와
구조적으로 겹치지 않음. `room_scene.dart`는 터치 제스처 자체가 없음.

**한계**: 이는 위젯 트리 레벨 시뮬레이션이며, 실제 안드로이드 기기의
멀티터치 하드웨어 드라이버/OS 제스처 인식 레벨에서 발생할 수 있는
미묘한 충돌(예: 특정 제조사 커스텀 UI의 엣지 제스처)은 **이 환경에서
검증 불가능**하다.

---

## ⑥ 반복 확대·축소 테스트

자동화 테스트로 **5회 연속 핀치 확대/축소를 반복**해 매 사이클마다
예외 발생 여부와 오버레이(`RawImage`) 정상 해제 여부를 확인 — **5회
전부 예외 없이 통과, 매번 깨끗하게 해제됨**을 확인(`tester.takeException()
== null`).

**한계**: 실기기에서 수십~수백 회 반복 시 발생할 수 있는 장기 누적
메모리 추세는 이 환경에서 측정 불가(아래 ⑦ 참고).

---

## ⑦ 메모리 및 성능 테스트

**코드 레벨 설계 확인**:
- `PinchZoomRenderController.capture()`는 새 캡처 전 이전 `ui.Image`를
  `.dispose()` 후 교체 — 캡처 이미지가 누적되지 않도록 설계.
- `captureRatioCap = 3.0`으로 `devicePixelRatio`가 과도하게 큰 저사양
  기기에서도 캡처 해상도 상한을 둠(과도한 메모리 사용 방지).
- `_ResetTicker`는 리셋이 필요한 순간에만 생성되는 일회용 `Ticker`이며,
  상시 `AnimationController`를 유지하지 않음.

**자동화 테스트로 확인**: 5회 반복 확대 후에도 `RawImage` 위젯이 트리에
남지 않음(이미지 레퍼런스 해제).

**한계**: 실제 GPU 메모리 사용량, 프레임 드롭(jank), 장시간 사용 시의
실제 메모리 그래프는 Flutter DevTools를 기기에 연결해 프로파일링해야
확인 가능하며, **이 샌드박스 환경에서는 측정할 수 없다**. 성능
수치(FPS, 메모리 MB)는 보고할 수 없음을 명시한다.

---

## ⑧ 안드로이드 실기기 테스트

**❌ 수행하지 못함 — 이 개발 샌드박스 환경에서 물리적으로 불가능하다.**

이 환경은 Flutter 웹 빌드 + Python HTTP 서버 기반 웹 프리뷰만 제공하며,
실제 안드로이드 기기(또는 에뮬레이터)에 APK를 설치해 손가락 멀티터치로
테스트할 수 있는 수단이 없다. 다음은 **대체 수단으로 수행했으나 실기기
테스트를 대체하지 않는** 항목이다:

- `WidgetTester.createGesture()` 기반 자동화 위젯 테스트(위 ⑤⑥) —
  위젯 트리 레벨 시뮬레이션일 뿐, 실제 터치스크린 하드웨어/OS 제스처
  해석 레이어를 거치지 않는다.
- 웹 브라우저 프리뷰(`flutter build web` + HTTP 서버) — 마우스/트랙패드
  입력이며 실제 멀티터치가 아니다.

**실기기 테스트가 필요한 항목(수행 불가, 명시적 보고)**:
- 실제 손가락 2개로 핀치했을 때의 체감 반응 속도·자연스러움
- 기종/안드로이드 버전별 멀티터치 드라이버 차이로 인한 엣지 케이스
- 실제 GPU 메모리/배터리 소모
- `face_capture_screen.dart`의 OS 네이티브 카메라 앱 전환 플로우가
  실제 기기에서 전역 핀치 엔진과 완전히 분리되어 동작하는지의 최종 확인
- 결제 SDK(아직 미통합으로 확인된 AdMob 포함)가 실제 연동된 이후의
  확대 엔진과의 상호작용

---

## ⑨ Flutter analyze 및 자동화 테스트

- **`flutter analyze`(프로젝트 전체)**: 113개 이슈 — **전부 이번 작업
  이전부터 존재하던 기존 이슈**(wishroom 상수명 컨벤션, 미사용 필드
  등)이며, 이번에 생성/수정한 핀치 확대 관련 파일에서는 **신규 이슈
  0건**. 신규 생성 파일만 별도 analyze 시 "No issues found" 확인.
- **`flutter build web --release`**: 빌드 성공, Flutter 프리뷰 서버
  HTTP 200 응답 확인.
- **자동화 테스트(`flutter test test/global_pinch_zoom_test.dart`)**:
  **11개 테스트 전부 통과**(1손가락 보존 2건, 2손가락 핀치 시작/종료
  1건, 반복확대 1건, 제외구역 1건, 변환 컨트롤러 단위 테스트 3건,
  경계 컨트롤러 단위 테스트 2건, 제외 레지스트리 1건).

---

## ⑩ 기존 기능 회귀 테스트

| 항목 | 상태 |
|---|---|
| `flutter build web --release` 빌드 | ✅ 성공 |
| 프리뷰 서버 기동 및 HTTP 200 응답 | ✅ 확인 |
| 자동화 테스트: 버튼 탭 정상 | ✅ 통과 |
| 자동화 테스트: 리스트 스크롤 정상 | ✅ 통과 |
| 로그인/회원가입 화면 라우팅(코드 조사) | ✅ `/login`, `/signup` 등 라우트 정의 확인, 전역 오버레이 하위에 정상 포함 |
| 사주 계산/결과 화면 | ✅ 라우트 구조 확인, `ZoomableContent` 사용처(`saju_story_widgets.dart` 등)는 개별 InteractiveViewer 제거 후에도 Hero 전환 로직 자체는 변경하지 않아 기존 네비게이션 동작 그대로 |
| 프리미엄 사주 리포트 | ✅ 라우트 확인(`/ai-fortune/saju/result`), 별도 PDF 렌더링 기능은 애초에 없었음(①에서 확인) |
| 소원방 봉인/애니메이션(`room_scene.dart` 등) | ✅ 코드 조사로 핀치 엔진과 제스처 레벨 충돌 없음 확인 |
| 광고 시청, 프리패스, 복주머니, 월구독 결제 | ⚠️ **실제 사용자 플로우(로그인 → 결제 버튼 클릭 → 서버 응답)까지의 end-to-end 동작은 이 샌드박스에서 실제 서버/결제 SDK 연동 없이는 수행할 수 없다**(OPERATIONS_POLICY §10 — 운영 서버로 테스트 트래픽 전송 금지). 코드 레벨에서는 핀치 확대 엔진이 결제/서버 API를 호출하는 코드 경로가 전혀 없음(확대 엔진은 `RenderRepaintBoundary` 캡처 + 로컬 `setState`만 수행)을 확인했다 |

**결론**: 빌드 가능성, 코드 레벨 비간섭성, 자동화 가능한 범위의 제스처
동작은 확인했다. 그러나 **서버/결제 연동이 필요한 플로우의 end-to-end
동작과, 실제 안드로이드 기기에서의 멀티터치 체감은 검증하지 못했다** —
이를 "정상"이라고 보고하지 않는다.

---

## 종합 결론 및 다음 단계 권고

**완료**: 개별 확대 기능 제거/통합(①), 4개 컨트롤러 기반 전역 엔진
구현(②), 적용 범위 문서화(③), 화질 수치 검수(④), 자동화 가능 범위의
제스처 충돌·반복 테스트(⑤⑥), 코드 레벨 메모리 설계 확인(⑦),
analyze+자동화 테스트(⑨), 코드/빌드 레벨 회귀 확인(⑩ 일부).

**미완료/불가능 — 투명하게 보고**:
- ⑧ 안드로이드 실기기 테스트: 이 샌드박스 환경의 근본적 한계로 수행
  불가능. **대표/개발팀의 실기기 검수가 반드시 필요**하다.
- ⑩ 결제/광고 SDK가 연동된 이후의 end-to-end 결제 플로우 회귀 테스트:
  운영 서버 접근 제한(OPERATIONS_POLICY §10)과 테스트 환경 한계로 수행
  불가능.
- wishroom 아이콘 20개, guinji face 이미지의 디자인 리소스 교체는
  이번 작업 범위(확대 엔진 구현)와 별개로 디자인팀의 재작업이 필요하다.

**권고**: 본 보고서와 커밋 이력(`feature/pouch-expansion-phase01`
브랜치)을 기준으로, 실제 안드로이드 기기에 빌드해 ⑤~⑧ 항목을
재검증한 뒤 최종 승인 여부를 결정할 것을 권고한다.
