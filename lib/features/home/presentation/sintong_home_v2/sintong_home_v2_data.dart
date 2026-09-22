// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_v2_data.dart
// [신통방통 홈 v2] README.md "카피(히어로 슬라이드)" 표 + "시트 카드"
// + 5개 카테고리 라우팅 매핑을 위한 정적 데이터.
// ═══════════════════════════════════════════════════════════════
library;

/// 5개 카테고리 식별자 — 히어로 슬라이드/칩/서브 화면이 공유하는 순서.
enum SHomeV2Category { guide, saju, tarot, wish, palm }

extension SHomeV2CategoryX on SHomeV2Category {
  /// 칩 라벨 — README "칩 라벨" 표.
  String get chipLabel => switch (this) {
    SHomeV2Category.guide => '귀인지도',
    SHomeV2Category.saju => '정통사주',
    SHomeV2Category.tarot => '타로',
    SHomeV2Category.wish => '소원방',
    SHomeV2Category.palm => '손금·관상',
  };

  /// 히어로 슬라이드 배경 이미지.
  String get heroAsset => switch (this) {
    SHomeV2Category.guide => 'assets/images/sintong_home_v2/hero.jpg',
    SHomeV2Category.saju => 'assets/images/sintong_home_v2/card-saju.jpg',
    SHomeV2Category.tarot => 'assets/images/sintong_home_v2/card-tarot.jpg',
    SHomeV2Category.wish => 'assets/images/sintong_home_v2/card-wish.jpg',
    SHomeV2Category.palm => 'assets/images/sintong_home_v2/card-palm.jpg',
  };

  /// 서브 화면 히어로 스트립 이미지(귀인지도는 card-guide.jpg 별도 사용).
  String get subHeroAsset => switch (this) {
    SHomeV2Category.guide => 'assets/images/sintong_home_v2/card-guide.jpg',
    SHomeV2Category.saju => 'assets/images/sintong_home_v2/card-saju.jpg',
    SHomeV2Category.tarot => 'assets/images/sintong_home_v2/card-tarot.jpg',
    SHomeV2Category.wish => 'assets/images/sintong_home_v2/card-wish.jpg',
    SHomeV2Category.palm => 'assets/images/sintong_home_v2/card-palm.jpg',
  };

  String get heroEyebrow => switch (this) {
    SHomeV2Category.guide => '오늘 · 火 · 吉',
    SHomeV2Category.saju => '사주 · 四柱八字',
    SHomeV2Category.tarot => '타로 · 오늘의 한 장',
    SHomeV2Category.wish => '소원 · 願',
    SHomeV2Category.palm => '관상 · 觀相 手相',
  };

  String get heroTitle => switch (this) {
    SHomeV2Category.guide => '오늘의 귀인',
    SHomeV2Category.saju => '오늘의 운',
    SHomeV2Category.tarot => '오늘의 카드',
    SHomeV2Category.wish => '오늘의 소원',
    SHomeV2Category.palm => '오늘의 결',
  };

  String get heroSub => switch (this) {
    SHomeV2Category.guide => '동남쪽, 물의 기운을 가진 이를 만나면\n조용히 길이 열려요.',
    SHomeV2Category.saju => '네 기둥에 새겨진 여덟 글자로\n오늘의 흐름을 읽어드려요.',
    SHomeV2Category.tarot => '눈을 감고 마음속 질문을 떠올려보세요.\n지금 뽑은 한 장이 답이 됩니다.',
    SHomeV2Category.wish => '간절한 마음을 종이에 담고\n촛불 위에 조용히 봉인합니다.',
    SHomeV2Category.palm => '얼굴에 흐르는 기운, 손에 새겨진 선.\n사진 한 장으로 결을 읽어드려요.',
  };

  /// 서브 화면 헤더 타이틀(hdr-title, 상단 작은 라벨).
  String get subHeaderTitle => switch (this) {
    SHomeV2Category.guide => '귀인지도 · 貴人之圖',
    SHomeV2Category.saju => '정통사주 · 四柱八字',
    SHomeV2Category.tarot => '타로 · 오늘의 한 장',
    SHomeV2Category.wish => '소원방 · 願',
    SHomeV2Category.palm => '관상 · 손금',
  };

  /// 서브 화면 히어로 스트립 캡션 eyebrow.
  String get subHeroEyebrow => switch (this) {
    SHomeV2Category.guide => '오늘 · 火 · 吉',
    SHomeV2Category.saju => '사주 · 四柱八字',
    SHomeV2Category.tarot => '타로 · 오늘의 카드',
    SHomeV2Category.wish => '소원 · 願',
    SHomeV2Category.palm => '觀相 · 手相',
  };

  /// 서브 화면 히어로 스트립 타이틀(2줄, \n으로 줄바꿈).
  String get subHeroTitle => switch (this) {
    SHomeV2Category.guide => '나를 도와줄 사람은\n어느 방향에 있을까요',
    SHomeV2Category.saju => '네 기둥에 새겨진\n여덟 글자',
    SHomeV2Category.tarot => '지금 뽑은 한 장이\n답이 됩니다',
    SHomeV2Category.wish => '간절한 마음을\n촛불에 봉인합니다',
    SHomeV2Category.palm => '얼굴과 손에 새겨진\n지금까지의 이야기',
  };

  /// 서브 화면 인용구(quote) — em(강조) 부분은 [quoteEmphasis]로 분리.
  String get quotePrefix => switch (this) {
    SHomeV2Category.guide => '오늘 당신의 곁으로 ',
    SHomeV2Category.saju => '태어난 ',
    SHomeV2Category.tarot => '눈을 감고 ',
    SHomeV2Category.wish => '',
    SHomeV2Category.palm => '',
  };
  String get quoteEmphasis => switch (this) {
    SHomeV2Category.guide => '동남쪽 · 물의 기운',
    SHomeV2Category.saju => '해 · 달 · 날 · 시각',
    SHomeV2Category.tarot => '마음속 질문',
    SHomeV2Category.wish => '이루어질 때까지',
    SHomeV2Category.palm => '사진 한 장',
  };
  String get quoteMiddle => switch (this) {
    SHomeV2Category.guide => '을 가진 이가 다가옵니다.',
    SHomeV2Category.saju => '에 하늘이 새겨둔 여덟 글자로',
    SHomeV2Category.tarot => '을 떠올려보세요.',
    SHomeV2Category.wish => ' 함께 밝혀둘게요.',
    SHomeV2Category.palm => '이면 됩니다.',
  };
  String get quoteSuffix => switch (this) {
    SHomeV2Category.guide => '조용한 눈빛으로 알아보게 될 거예요.',
    SHomeV2Category.saju => '오늘의 흐름과 평생의 결을 읽어드려요.',
    SHomeV2Category.tarot => '준비가 되면 카드를 한 장 골라주세요.',
    SHomeV2Category.wish => '마음속 소원을 조용히 담아두세요.',
    SHomeV2Category.palm => '지금까지의 삶과 앞으로의 결을 조용히 읽어드려요.',
  };

  String get sectionHead => switch (this) {
    SHomeV2Category.guide => '방향으로 살펴보기',
    SHomeV2Category.saju => '사주 풀이 종류',
    SHomeV2Category.tarot => '주제로 골라보기',
    SHomeV2Category.wish => '소원을 담는 법',
    SHomeV2Category.palm => '읽는 방법 고르기',
  };

  String get sectionSub => switch (this) {
    SHomeV2Category.guide => '각 방향의 귀인 성향과 만나는 법을 확인하세요.',
    SHomeV2Category.saju => '궁금한 결부터 천천히 들여다보세요.',
    SHomeV2Category.tarot => '묻고 싶은 결에 맞춰 덱을 선택하세요.',
    SHomeV2Category.wish => '종류에 맞게 촛불을 켜고 봉인하세요.',
    SHomeV2Category.palm => '얼굴 또는 손바닥 사진을 준비해주세요.',
  };

  String get ctaLabel => switch (this) {
    SHomeV2Category.guide => '내 귀인지도 열기',
    SHomeV2Category.saju => '생년월시 입력하기',
    SHomeV2Category.tarot => '한 장 뽑기',
    SHomeV2Category.wish => '촛불 켜고 봉인하기',
    SHomeV2Category.palm => '사진 올리기',
  };
}

/// 서브 화면 옵션 리스트 1개 항목(README "opt-list" 구조).
class SHomeV2Option {
  const SHomeV2Option({
    required this.glyph,
    required this.title,
    required this.sub,
    this.glyphIsLatin = false,
  });

  /// 한자 1글자(Noto Serif KR) 또는 라틴 숫자/기호(예: '1장', '♡', '✦').
  final String glyph;
  final String title;
  final String sub;

  /// true면 optGlyph 대신 Inter 600 13px로 렌더링(README saju.html의
  /// "1장"/"3장" 처럼 한자가 아닌 라틴 텍스트 glyph).
  final bool glyphIsLatin;
}

/// 카테고리별 옵션 리스트 — README.md 각 서브 화면 "옵션 리스트" 섹션.
const Map<SHomeV2Category, List<SHomeV2Option>> sHomeV2Options = {
  SHomeV2Category.guide: [
    SHomeV2Option(glyph: '東', title: '동쪽 · 나무의 사람', sub: '성장을 도와주는 스승형 귀인'),
    SHomeV2Option(glyph: '南', title: '남쪽 · 불의 사람', sub: '따뜻한 응원을 주는 벗형 귀인'),
    SHomeV2Option(glyph: '西', title: '서쪽 · 쇠의 사람', sub: '단단한 조언을 주는 어른형 귀인'),
    SHomeV2Option(
      glyph: '北',
      title: '북쪽 · 물의 사람',
      sub: '지혜를 나눠주는 조력자형 귀인 · 오늘의 방향',
    ),
  ],
  SHomeV2Category.saju: [
    SHomeV2Option(glyph: '日', title: '오늘의 운세', sub: '오늘 하루의 기운을 짧게 · 무료'),
    SHomeV2Option(glyph: '月', title: '신년 · 월간 사주', sub: '한 해와 한 달의 큰 결'),
    SHomeV2Option(glyph: '緣', title: '인연 · 궁합', sub: '두 사람 사주를 나란히 놓고'),
    SHomeV2Option(glyph: '財', title: '재물 · 직업', sub: '일과 돈의 흐름을 자세히'),
    SHomeV2Option(glyph: '康', title: '건강 · 평생운', sub: '평생을 관통하는 큰 결'),
  ],
  SHomeV2Category.tarot: [
    SHomeV2Option(
      glyph: '1장',
      title: '오늘의 한 장',
      sub: '지금 이 순간의 메시지',
      glyphIsLatin: true,
    ),
    SHomeV2Option(
      glyph: '3장',
      title: '과거 · 현재 · 미래',
      sub: '시간의 흐름으로 풀기',
      glyphIsLatin: true,
    ),
    SHomeV2Option(glyph: '♡', title: '연애 · 관계 리딩', sub: '두 사람 사이의 결'),
    SHomeV2Option(glyph: '✦', title: '10장 · 켈틱 크로스', sub: '깊이 있는 상황 전개 리딩'),
  ],
  SHomeV2Category.wish: [
    SHomeV2Option(glyph: '康', title: '건강 · 康', sub: '가족과 나의 몸과 마음'),
    SHomeV2Option(glyph: '合', title: '인연 · 合', sub: '사랑, 우정, 만남'),
    SHomeV2Option(glyph: '財', title: '재물 · 財', sub: '일과 살림의 결'),
    SHomeV2Option(glyph: '成', title: '시험 · 성취 · 成', sub: '준비하는 마음, 이루는 마음'),
    SHomeV2Option(glyph: '福', title: '일상의 복 · 福', sub: '이름 붙일 수 없는 소소한 바람'),
  ],
  SHomeV2Category.palm: [
    SHomeV2Option(glyph: '相', title: '관상 · 얼굴 읽기', sub: '정면 사진 1장 · 기운의 결을 살핌'),
    SHomeV2Option(glyph: '手', title: '손금 · 세 개의 선', sub: '생명선 · 감정선 · 두뇌선'),
    SHomeV2Option(glyph: '合', title: '관상 + 손금 통합 리딩', sub: '두 결을 나란히 놓고 깊이 읽기'),
  ],
};

/// 홈 하단 시트 3카드(소원방/타로/정통사주) — README index.html 순서 그대로.
class SHomeV2SheetCard {
  const SHomeV2SheetCard({
    required this.category,
    required this.thumbAsset,
    required this.title,
  });

  final SHomeV2Category category;
  final String thumbAsset;
  final String title;
}

const List<SHomeV2SheetCard> sHomeV2SheetCards = [
  SHomeV2SheetCard(
    category: SHomeV2Category.wish,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-1-wish.jpg',
    title: '소원방',
  ),
  SHomeV2SheetCard(
    category: SHomeV2Category.tarot,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-2-tarot.jpg',
    title: '타로',
  ),
  SHomeV2SheetCard(
    category: SHomeV2Category.saju,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-3-saju.jpg',
    title: '정통사주',
  ),
];
