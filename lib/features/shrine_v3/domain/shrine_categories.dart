/// 9개 카테고리 표시 순서(README/HTML 프로토타입 `CATS` 배열과 동일) —
/// admin_web DB의 `sortOrder`는 카테고리 "안" 항목 순서만 보장하고 카테고리
/// "탭" 순서는 보장하지 않으므로(수능은 시딩 스크립트에서 맨 마지막에
/// upsert되어 sortOrder가 가장 크다), 화면의 필터 칩 순서는 이 상수를
/// 기준으로 한다.
const List<String> kShrineCategoryOrder = [
  'wealth',
  'biz',
  'love',
  'harmony',
  'exam',
  'suneung',
  'health',
  'ward',
  'wish',
];

/// 06 추천받기 화면의 6개 "마음에 걸리는 것" 버튼(README/HTML `WISHES` 배열).
/// [hanja, label, mappedCategory]
const List<(String, String, String)> kShrineWishes = [
  ('財', '돈과 일', 'wealth'),
  ('緣', '사람 · 인연', 'love'),
  ('試', '시험 · 합격', 'suneung'),
  ('康', '건강 · 평안', 'health'),
  ('厄', '불안 · 걱정', 'ward'),
  ('願', '마음속 소원', 'wish'),
];
