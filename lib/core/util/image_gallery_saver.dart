// [귀인지도 결과카드 "이미지 저장" 버그수정 — 2026-11] 플랫폼별 구현을
// 조건부로 연결하는 진입점. Web에서는 브라우저 다운로드
// (`image_gallery_saver_web.dart`)를, 그 외(Android 등)에서는 `gal`
// 패키지로 실제 갤러리 저장(`image_gallery_saver_io.dart`)을 사용한다.
//
// [배경] 기존 "이미지 저장" 버튼은 실제로는 공유하기와 동일한
// `Share.shareXFiles()`만 호출해서, 눌러도 OS 공유 시트가 뜰 뿐 갤러리에
// 곧바로 저장되지 않았다("이미지 저장 버튼이 뭘 하는지 모르겠다"는 사용자
// 불만의 원인 중 하나). 이제 "이미지 저장"과 "공유하기"가 실제로 서로
// 다른 동작을 하도록 분리한다.
export 'image_gallery_saver_io.dart'
    if (dart.library.html) 'image_gallery_saver_web.dart';
