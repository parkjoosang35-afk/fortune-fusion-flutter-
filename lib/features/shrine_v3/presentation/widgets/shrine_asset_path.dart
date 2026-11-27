/// 서버가 내려주는 `imagePath`/`thumbPath`(예: 'bj/talisman/wealth0.webp',
/// 'bj/suneung/suneung-01-t.webp')를 Flutter 에셋 번들 경로
/// ('assets/shrine_v3/bj/talisman/wealth0.webp')로 변환한다.
///
/// [자산 반입 메모] design_handoff_shrine_v3의 원본 JPG/PNG는 전부 WebP로
/// 재인코딩되어 `assets/shrine_v3/` 아래에 반입되어 있다(파일명/확장자는
/// seed-shrine-talismans.ts가 DB에 기록한 값과 이미 .webp로 일치한다 —
/// 별도 확장자 치환이 필요 없다).
String shrineAssetPath(String serverPath) {
  if (serverPath.isEmpty) return '';
  return 'assets/shrine_v3/$serverPath';
}

/// 07 화면(부탁 연출)이 쓰는 정적 장면 이미지(entry/give/hall/paper/talk/write).
String shrineSceneImage(String name) => 'assets/shrine_v3/img/$name.webp';

/// 07 화면 비디오(write/burn/give) — vid/ 아래 mp4.
String shrineSceneVideo(String name) => 'assets/shrine_v3/vid/$name.mp4';
