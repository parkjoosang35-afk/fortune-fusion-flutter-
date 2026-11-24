// ═══════════════════════════════════════════════════════════════
// FILE: fe_tarot_seed.dart
// [운세 엔진 디자인 핸드오프 — "같은 입력, 같은 시드라면 언제나 같은
// 결과" 섹션(REPRODUCIBLE·09) 전용 데모 셔플.]
// 출처: uploaded_files/fortune_engine_extracted/flutter/lib/data/seeded_tarot.dart
// (design_files/engine-app.jsx의 rng()/draw()를 그대로 포팅한 레퍼런스)
//
// ⚠️ 데모 전용입니다. 이 파일은 "운세 엔진" 안내 화면의 시드 재현
// 데모(화면 안에서 입력한 시드 문자열로 카드 3장을 뽑아 보여주는
// 인터랙션)에만 사용되며, 실제 타로 서비스 결과 화면
// (features/fortune/tarot/...)의 카드 추출 로직과는 완전히 분리된
// 별도 구현이다. 기존 타로 엔진을 재구현하거나 대체하지 않는다
// — 사용자 제약 "기존 엔진 재구현 금지"에 따라, 이 파일은 신규로
// 추가된 "운세 엔진" 소개 화면 전용 데모 유틸일 뿐 실제 타로 리딩
// 결과 산출에는 전혀 관여하지 않는다.
// ═══════════════════════════════════════════════════════════════

const _feMajor = [
  '바보',
  '마법사',
  '여사제',
  '여황제',
  '황제',
  '교황',
  '연인',
  '전차',
  '힘',
  '은둔자',
  '운명의 수레바퀴',
  '정의',
  '매달린 사람',
  '죽음',
  '절제',
  '악마',
  '탑',
  '별',
  '달',
  '태양',
  '심판',
  '세계',
];
const _feSuits = [
  ['완드', '✶'],
  ['컵', '♥'],
  ['소드', '⚔'],
  ['펜타클', '♦'],
];
const _feRanks = [
  '에이스',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '페이지',
  '나이트',
  '퀸',
  '킹',
];

final List<List<String>> feTarotDeck = [
  ..._feMajor.map((n) => [n, '✦']),
  for (final s in _feSuits)
    for (final r in _feRanks) ['${s[0]} $r', s[1]],
]; // 78장

int _feImul(int a, int b) => (a * b).toSigned(32);
int _feU32(int x) => x & 0xFFFFFFFF;

double Function() _feRng(String seed) {
  var h = (1779033703 ^ seed.length).toSigned(32);
  for (final cu in seed.codeUnits) {
    h = _feImul(h ^ cu, 3432918353.toSigned(32));
    h = (h << 13 | _feU32(h) >> 19).toSigned(32);
  }
  var a = _feU32(h).toSigned(32);
  return () {
    a = (a + 0x6D2B79F5).toSigned(32);
    var t = _feImul(a ^ (_feU32(a) >> 15), 1 | a);
    t = ((t + _feImul(t ^ (_feU32(t) >> 7), 61 | t)).toSigned(32) ^ t).toSigned(
      32,
    );
    return _feU32(t ^ (_feU32(t) >> 14)) / 4294967296.0;
  };
}

class FeDrawnCard {
  final int index;
  final String name, symbol;
  final bool reversed;
  const FeDrawnCard(this.index, this.name, this.symbol, this.reversed);
}

/// 과거·현재·미래 3장. Fisher–Yates 후 앞 3장, 각 카드 역방향 여부는 r() < 0.5.
List<FeDrawnCard> feDrawThree(String seed) {
  final r = _feRng(seed.isEmpty ? '0' : seed);
  final idx = List<int>.generate(feTarotDeck.length, (i) => i);
  for (var i = idx.length - 1; i > 0; i--) {
    final j = (r() * (i + 1)).floor();
    final t = idx[i];
    idx[i] = idx[j];
    idx[j] = t;
  }
  return idx
      .take(3)
      .map(
        (i) => FeDrawnCard(i, feTarotDeck[i][0], feTarotDeck[i][1], r() < 0.5),
      )
      .toList();
}
