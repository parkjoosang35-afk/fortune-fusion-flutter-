# 전역 핀치 확대 시스템 — 적용 범위 및 제외 구역 목록

작성 기준: `lib/app.dart`의 `MaterialApp.builder` (Navigator의 모든 라우트/팝업/
모달의 공통 조상)에 `GlobalPinchZoomOverlay`가 단 한 곳에 삽입되어 있다.
**이 위치 특성상, 아래 91개 명명 라우트(`core/router/app_router.dart` 전수
조사 결과) + AppShell 내부 탭 전환 + 모든 `showDialog`/`showModalBottomSheet`
팝업은 예외 없이 구조적으로 전역 핀치 확대가 적용된다.** 즉 "화면 수만큼
개별 추가 작업"이 필요한 구조가 아니라, 신규 화면이 추가되어도 자동으로
적용 범위에 포함된다(지시서 §7 "모든 화면에 무조건 InteractiveViewer를
중복 적용하는 방식은 금지" 요구사항과 반대로, 중복 적용 없이 전역 1곳
적용으로 전체 커버).

## 1. 지시서 §5 카테고리별 적용 확인

| 카테고리 | 대표 라우트 | 적용 상태 |
|---|---|---|
| 홈 | `/home`, `/home/all-categories`, `/home/fortune-engine`, `/home/daily-fortune-detail` | ✅ 전역 적용 (AppShell 하위) |
| 운세(생년월일 등 기본) | `/fortune/today/*`, `/fortune-period/*`, `/fortune/category` | ✅ 전역 적용 |
| 정통사주 | `/jeontong/input`, `/jeontong/eighty/grid`, `/saju-renewal`, `/saju/v3`, `/ai-fortune/saju/*` | ✅ 전역 적용 |
| 프리미엄 사주 | `/ai-fortune/saju/result`(프리미엄 리포트 포함), `/ai-fortune/reading-archive` | ✅ 전역 적용 — 리포트 내 이미지/도표도 스크린샷 캡처 기반이라 동일 적용 |
| 타로 | `/ai-fortune/tarot/*`, `oz_tarot_home_screen` 등 | ✅ 전역 적용. 단 `oz_card_peek_modal.dart`의 **개별 InteractiveViewer는 제거**(이전 커밋) — 전역 엔진으로 완전 대체 |
| 귀인지도 | `/guinji`, `/guinji-map/*`, `/guinji/*` | ✅ 전역 적용. 단 **`GuinjiAnimatedRelationGraph`(interactive=true, M화면/신규생성)는 `PinchZoomDisabled`로 제외** — 이 위젯 자체가 이미 2손가락=지도 확대·이동·노드탭의 독자 의미를 가지므로 이중 해석 방지. interactive=false(게스트 미니 프리뷰)는 정적 비주얼이라 전역 엔진 그대로 적용 |
| 관상 | `/ai-fortune/face/*` | ✅ 전역 적용. 단 `face_capture_screen.dart`의 카메라 캡처 화면은 플랫폼 네이티브 카메라 뷰 특성상 §2 하단 "확인 필요" 참고 |
| 손금 | `/ai-fortune/palm/*` | ✅ 전역 적용 |
| 소원방 | `/wish-room`, `/wish-wall` 및 하위 compose/decor/room_scene 등 | ✅ 전역 적용. `room_scene.dart`는 재확인 결과 `GestureDetector`/`onTap`/`onPan` 등 자체 터치 제스처가 전혀 없는 순수 렌더링 화면이라 전역 핀치 리스너(Listener, translucent)와 충돌 여지 자체가 없음. `compose_screen.dart`/`decor_screen.dart`는 1손가락 탭/드래그(아이템 배치 등) 로직이며 2손가락 핀치가 아니므로 전역 엔진과 구조적으로 겹치지 않음 |
| 부적(신당) | `/shrine`, `shrine_v3` 전체, `talisman_zoom_overlay.dart` | ✅ 전역 적용. 기존에 자체 확대 로직이 없던 정적 오버레이라 그대로 수혜 |
| 마이페이지 | `/my/fortune-records`, `/my/notifications`, `/my/settings`, `/my/subscription*` | ✅ 전역 적용 |
| 회원가입/로그인 | `/login`, `/login/email`, `/signup`, `/signup/email`, `/onboarding`, `/intro`, `/splash` | ✅ 전역 적용 |
| 결제/리워드 | `/reward/wallet`, `/reward/giftcard*`, `/reward/coupon*`, `/reward/luckybag*`, `/my/subscription/plans` | ✅ 전역 적용. **광고/결제 "기능"과 확대 "엔진"은 완전히 분리된 코드 경로**(핀치 엔진은 RepaintBoundary 화면 캡처 기반이며 결제 API 호출을 트리거하지 않음 — §2 투명성 보고 참고) |
| 귀인지도 외 기타(관상/손금 분석 중 로딩, 랭킹, 미션, 출석) | `/reward/ranking`, `/reward/missions`, `/reward/attendance`, `/guinji/ranking` | ✅ 전역 적용 |

## 2. 제외 구역(`PinchZoomDisabled`) 적용 목록 — 전부 적용 완료

| 파일 | 사유 |
|---|---|
| `guinji_policy_webview_mobile.dart` | 네이티브 WebView(AndroidView/UiKitView)는 `RenderRepaintBoundary.toImage()` 캡처 레이어에 포함되지 않거나 빈 영역으로 나타나는 Flutter의 구조적 제약. 또한 페이지 자체가 자체 핀치줌/스크롤 보유 |
| `guinji_policy_webview_web.dart` | Flutter Web `HtmlElementView`(iframe)도 동일하게 별도 합성 레이어 — 동일 사유 |
| `ad_script_view_mobile.dart` | 광고 WebView, 동일 사유. 지시서 §6 "광고 및 결제 기능과 확대 엔진 분리" 직접 대응 |
| `ad_script_view_web.dart` | 광고 DOM 오버레이(iframe/innerHTML), 동일 사유 |
| `guinji_animated_graph.dart`(interactive=true 분기만) | 위젯 자체의 독자적 2손가락 핀치(지도 확대+이동+노드탭) 의미와 전역 엔진 제스처가 이중 해석되는 것을 방지 |

## 3. 재조사로 해소된 항목 / 추가로 확인이 필요한 항목

- **`face_capture_screen.dart`(관상 사진 촬영 화면) — 재조사 결과 문제 없음으로 확인**: `import 'package:image_picker/image_picker.dart'`만 사용하며 `ImagePicker().pickImage(source: ImageSource.camera)`로 **OS 네이티브 카메라 "앱"을 별도 화면으로 전환**해 호출하는 방식이다(Flutter 위젯 트리 내부에 인앱 `CameraPreview`를 상시 그려두는 구조가 아니다). 카메라가 실행되는 동안 Flutter 앱 자체는 포그라운드에서 완전히 벗어나므로 `GlobalPinchZoomOverlay`와 아예 공존하지 않는다(핀치 확대 자체가 걸릴 지점이 없음) — 제외 처리 불필요, 충돌 가능성 없음으로 판정.
- **`video_player` 패키지 — 전수 조사 결과 미사용 확인**: `pubspec.yaml`에도 직접 선언되어 있지 않고(다른 패키지의 전이 의존성으로만 간접 포함), `lib/` 전체에서 `VideoPlayerController`/`VideoPlayer(` 사용 0건. 즉 "동영상 재생 화면" 자체가 현재 앱에 존재하지 않아, 전역 핀치 확대와의 충돌 가능성을 점검할 대상이 없다. (`pdf`/`printing`과 동일하게, pubspec.yaml에 등장하더라도 실제 코드에서 쓰이지 않는 전이 의존성과는 구분해 기록한다.)

위 재조사로 "확인 필요"로 남겨둔 리스크 항목은 모두 해소되었다. 코드 조사로 확정 가능한 범위에서는 추가 제외 구역이 더 필요하지 않다는 결론이다.

## 4. 결론

91개 라우트 + AppShell 탭 + 모든 팝업/모달은 `app.dart` 1곳의 전역 삽입으로
구조적으로 전부 적용 대상이다. 명시적으로 제외 처리가 필요했던 5개 파일은
모두 완료했다. 다만 네이티브 카메라/비디오 레이어의 캡처 가능 여부는 코드
조사만으로 확정할 수 없는 영역이 남아 있으며, 이는 실기기 테스트로만 최종
확인 가능하다(§2 투명성 보고의 "실기기 테스트 불가" 한계와 동일 맥락).
