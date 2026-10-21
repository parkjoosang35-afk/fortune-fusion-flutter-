// [귀인지도 결과카드 "이미지 저장" 버그수정 — 2026-11] 플랫폼별 구현을
// 연결하는 진입점. Web에서는 브라우저 다운로드
// (`image_gallery_saver_web.dart`)를, 그 외(Android 등)에서는 `gal`
// 패키지로 실제 갤러리 저장(`image_gallery_saver_io.dart`)을 사용한다.
//
// [배경] 기존 "이미지 저장" 버튼은 실제로는 공유하기와 동일한
// `Share.shareXFiles()`만 호출해서, 눌러도 OS 공유 시트가 뜰 뿐 갤러리에
// 곧바로 저장되지 않았다("이미지 저장 버튼이 뭘 하는지 모르겠다"는 사용자
// 불만의 원인 중 하나). 이제 "이미지 저장"과 "공유하기"가 실제로 서로
// 다른 동작을 하도록 분리한다.
//
// [REQ-04 1차 수정 — 폐기됨] 플랫폼 분기를 `if (dart.library.html)` 조건부
// export에서 `kIsWeb` 런타임 판정(무조건부 import)으로 교체했었다.
//
// 1차 수정이 해결하려던 문제(P-03):
//   export 'image_gallery_saver_io.dart'
//       if (dart.library.html) 'image_gallery_saver_web.dart';
// `dart.library.html` 조건은 **컴파일 타임**에 평가되며, dart2js
// 컴파일에서만 참이 된다. Flutter Web을 `--wasm`(dart2wasm)으로 빌드하면
// 이 조건이 거짓으로 평가되어 io 구현(gal 기반)이 선택되는데, `gal`은
// 웹 플랫폼을 지원하지 않으므로(pub.dev platforms 목록에 web 없음) 웹
// 저장이 전면 실패한다.
//
// [REQ-04 재수정 — 2026-10-21, 신통방통_저장기능_정상화_개발지시서_v1.0]
// ⚠️ 1차 수정(kIsWeb 무조건부 import)은 위 P-03을 없앴지만, 더 심각한
// 신규 회귀를 유발했다: `image_gallery_saver_web.dart`(`package:web`,
// dart:js_interop 기반)가 **모든 컴파일 타겟(Android/iOS VM, `flutter test`
// 포함)에서 항상 컴파일**되게 되었다. `package:web`의 JS-interop 전용 API
// (`.toJS`, `.jsify()` 등)는 VM(Dart Kernel) 컴파일에서 해석 불가능해,
// `flutter build apk`·`flutter build appbundle`·`flutter test`가 전부
// 커널 컴파일 단계에서 즉시 실패하는 상태였다(에러: "The getter 'toJS'
// isn't defined", "StandardFileSystem only supports file:* and data:*
// URIs" 등). `flutter analyze`는 조건부 컴파일 경로를 검증하지 않으므로
// 이 회귀를 잡아내지 못해 그간 "0 errors"로 보고되었으나 실제로는 Android
// 빌드 자체가 불가능한 상태였다.
//
// 올바른 수정: `dart.library.html` 대신 **`dart.library.io`**를 조건으로
// 쓰는 조건부 export로 되돌린다(본 프로젝트의 `ad_script_view.dart`에서
// 이미 검증된 동일 패턴). `dart:io`는 Android/iOS/desktop/VM
// 테스트에서는 존재하고, dart2js·dart2wasm 웹 컴파일 양쪽에서는 모두
// 존재하지 않는다. 따라서:
//   - VM(Android/iOS/`flutter test`): dart.library.io 참 →
//     image_gallery_saver_io.dart(gal 기반)만 컴파일됨. package:web이
//     애초에 컴파일 대상에서 제외되어 VM 빌드가 깨지지 않는다.
//   - dart2js(web, `flutter build web --release` 기본): dart.library.io
//     거짓 → image_gallery_saver_web.dart 선택.
//   - dart2wasm(web, `--wasm`): dart.library.io 거짓(dart:io 없음) →
//     image_gallery_saver_web.dart 선택 — 기존 P-03
//     (`dart.library.html`이 wasm에서 거짓이 되어 오분기)이 재발하지
//     않는다.
// 즉 kIsWeb 런타임 분기 없이, 컴파일 타임 조건부 export만으로 두 플랫폼
// 모두에서 올바른 구현이 선택되며, VM 컴파일도 깨지지 않는다.
export 'gallery_save_result.dart';
export 'image_gallery_saver_web.dart'
    if (dart.library.io) 'image_gallery_saver_io.dart';
