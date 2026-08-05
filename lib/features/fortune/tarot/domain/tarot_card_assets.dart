/// [카드 이미지 교체] 78장 타로카드 name → 이미지 파일명 매핑.
///
/// [tarot_model.dart]의 [TarotCardMeta]/[TarotCard]는 카드를 `name`
/// (예: 'The Fool', '에이스 of 완드')으로 식별하며, 기존 [TarotDeckData.iconFor]도
/// 이 name을 키로 이모지를 조회한다. 본 파일은 동일한 name 키를 그대로
/// 재사용해 실제 카드 이미지 경로를 조회하는 신규 lookup 테이블만 추가한다
/// (신규 id 체계/신규 아키텍처 도입 없음 - 최소 변경 원칙).
///
/// name 값은 [buildFullTarotDeckMeta]가 실제로 생성하는 문자열과 반드시
/// 정확히 일치해야 하며, 구현 시점에 콘솔 출력으로 78개 전체를 재검증했다
/// (메이저 22장: 'The Fool' 등 영문명 / 마이너 56장: '에이스 of 완드',
/// '2 of 완드' ... '킹 of 펜타클' 형태).
library;

/// 카드 원본(대형, 결과 상세용) 이미지가 위치하는 기본 경로.
const String tarotCardsBasePath = 'assets/tarot/cards';

/// 카드 축소(썸네일, 목록/작은 카드용) 이미지가 위치하는 기본 경로.
const String tarotThumbsBasePath = 'assets/tarot/thumbs';

/// 매핑이 없거나 이미지 파일이 아직 준비되지 않았을 때 사용할 기본 뒷면
/// 이미지. 실제로는 각 위젯의 `errorBuilder`가 이모지로 폴백하므로 이
/// 경로가 그림으로 노출될 일은 거의 없지만, 안전망으로 유지한다.
const String tarotDefaultBackAsset = 'assets/tarot/backs/back_default.webp';

/// name → 파일명 매핑(78장 전체).
///
/// 폴더는 파일명 접두사로 역산한다: m=majors, c=cups, w=wands, s=swords,
/// p=pentacles (`_folderForFile` 참고). 파일 포맷은 webp로 통일한다.
const Map<String, String> tarotCardImageFile = {
  // ───────────────────────── 메이저 아르카나 22장 ─────────────────────────
  'The Fool': 'm00_fool.webp',
  'The Magician': 'm01_magician.webp',
  'The High Priestess': 'm02_high_priestess.webp',
  'The Empress': 'm03_empress.webp',
  'The Emperor': 'm04_emperor.webp',
  'The Hierophant': 'm05_hierophant.webp',
  'The Lovers': 'm06_lovers.webp',
  'The Chariot': 'm07_chariot.webp',
  'Strength': 'm08_strength.webp',
  'The Hermit': 'm09_hermit.webp',
  'Wheel of Fortune': 'm10_wheel_of_fortune.webp',
  'Justice': 'm11_justice.webp',
  'The Hanged Man': 'm12_hanged_man.webp',
  'Death': 'm13_death.webp',
  'Temperance': 'm14_temperance.webp',
  'The Devil': 'm15_devil.webp',
  'The Tower': 'm16_tower.webp',
  'The Star': 'm17_star.webp',
  'The Moon': 'm18_moon.webp',
  'The Sun': 'm19_sun.webp',
  'Judgement': 'm20_judgement.webp',
  'The World': 'm21_world.webp',

  // ───────────────────────── 완드(wands) 14장 ─────────────────────────
  '에이스 of 완드': 'w01_ace.webp',
  '2 of 완드': 'w02_two.webp',
  '3 of 완드': 'w03_three.webp',
  '4 of 완드': 'w04_four.webp',
  '5 of 완드': 'w05_five.webp',
  '6 of 완드': 'w06_six.webp',
  '7 of 완드': 'w07_seven.webp',
  '8 of 완드': 'w08_eight.webp',
  '9 of 완드': 'w09_nine.webp',
  '10 of 완드': 'w10_ten.webp',
  '페이지 of 완드': 'w11_page.webp',
  '나이트 of 완드': 'w12_knight.webp',
  '퀸 of 완드': 'w13_queen.webp',
  '킹 of 완드': 'w14_king.webp',

  // ───────────────────────── 컵(cups) 14장 ─────────────────────────
  '에이스 of 컵': 'c01_ace.webp',
  '2 of 컵': 'c02_two.webp',
  '3 of 컵': 'c03_three.webp',
  '4 of 컵': 'c04_four.webp',
  '5 of 컵': 'c05_five.webp',
  '6 of 컵': 'c06_six.webp',
  '7 of 컵': 'c07_seven.webp',
  '8 of 컵': 'c08_eight.webp',
  '9 of 컵': 'c09_nine.webp',
  '10 of 컵': 'c10_ten.webp',
  '페이지 of 컵': 'c11_page.webp',
  '나이트 of 컵': 'c12_knight.webp',
  '퀸 of 컵': 'c13_queen.webp',
  '킹 of 컵': 'c14_king.webp',

  // ───────────────────────── 소드(swords) 14장 ─────────────────────────
  '에이스 of 소드': 's01_ace.webp',
  '2 of 소드': 's02_two.webp',
  '3 of 소드': 's03_three.webp',
  '4 of 소드': 's04_four.webp',
  '5 of 소드': 's05_five.webp',
  '6 of 소드': 's06_six.webp',
  '7 of 소드': 's07_seven.webp',
  '8 of 소드': 's08_eight.webp',
  '9 of 소드': 's09_nine.webp',
  '10 of 소드': 's10_ten.webp',
  '페이지 of 소드': 's11_page.webp',
  '나이트 of 소드': 's12_knight.webp',
  '퀸 of 소드': 's13_queen.webp',
  '킹 of 소드': 's14_king.webp',

  // ───────────────────────── 펜타클(pentacles) 14장 ─────────────────────────
  '에이스 of 펜타클': 'p01_ace.webp',
  '2 of 펜타클': 'p02_two.webp',
  '3 of 펜타클': 'p03_three.webp',
  '4 of 펜타클': 'p04_four.webp',
  '5 of 펜타클': 'p05_five.webp',
  '6 of 펜타클': 'p06_six.webp',
  '7 of 펜타클': 'p07_seven.webp',
  '8 of 펜타클': 'p08_eight.webp',
  '9 of 펜타클': 'p09_nine.webp',
  '10 of 펜타클': 'p10_ten.webp',
  '페이지 of 펜타클': 'p11_page.webp',
  '나이트 of 펜타클': 'p12_knight.webp',
  '퀸 of 펜타클': 'p13_queen.webp',
  '킹 of 펜타클': 'p14_king.webp',
};

/// 파일명 접두사로 실제 저장 폴더를 역산한다.
String _folderForFile(String file) {
  switch (file[0]) {
    case 'm':
      return 'majors';
    case 'c':
      return 'cups';
    case 'w':
      return 'wands';
    case 's':
      return 'swords';
    case 'p':
      return 'pentacles';
    default:
      return 'majors';
  }
}

/// 결과 상세(히어로 카드 등)용 원본 이미지 경로.
/// 매핑이 없으면 기본 뒷면 경로로 안전 폴백한다(실제 화면에서는 위젯의
/// `errorBuilder`가 이모지로 한 번 더 폴백하므로 이중 안전망 구조다).
String tarotCardImagePath(String name) {
  final file = tarotCardImageFile[name];
  if (file == null) return tarotDefaultBackAsset;
  return '$tarotCardsBasePath/${_folderForFile(file)}/$file';
}

/// 목록/작은 카드(포지션카드, 저장함 썸네일 등)용 축소 이미지 경로.
String tarotCardThumbPath(String name) {
  final file = tarotCardImageFile[name];
  if (file == null) return tarotDefaultBackAsset;
  return '$tarotThumbsBasePath/$file';
}
