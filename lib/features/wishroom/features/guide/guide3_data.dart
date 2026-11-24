// [C1-C11 신규 — 46개 안내 팝업 전수 대조 최대 공백 보완]
// app3/guide3.jsx `GUIDE3` 딕셔너리(11개 키) 1:1 이식. "처음 하는 동작마다
// 아래에서 올라오는 그림 안내" — 동작별로 평생 딱 1번만(GuidePrefs._seen,
// wr_hint_seen) 뜨고, 「다시 보지 않기」 없이 「알겠어요」 한 번으로 닫는다.
//
// 이미지 경로는 원본 'assets/xxx' 접두사를 이 프로젝트의 실제 자산 루트
// 'assets/wishroom/'로 치환했다. 'wardrobe' 항목만 원본이 아직 없는
// outfits2/ 세트를 가리켜(care_menu_info.dart와 동일한 선례), 이미 존재하는
// outfits/O_free_01.png(같은 캐릭터 기본 의상 썸네일)로 대체했다 — 의미상
// 차이 없음.
class Guide3Step {
  const Guide3Step(this.icon, this.text);
  final String icon;
  final String text;
}

class Guide3Item {
  const Guide3Item({
    required this.img,
    this.isBg = false,
    required this.title,
    required this.steps,
    required this.promise,
  });

  /// `assets/wishroom/` 기준 상대 경로.
  final String img;

  /// true면 img를 배경(cover)으로, false면 중앙 하단에 contain으로 띄운다
  /// (원본 `isBg = G.img.endsWith('.jpg')`와 동일 판정 — 데이터에 고정값으로 미리 박아 둠).
  final bool isBg;
  final String title;
  final List<Guide3Step> steps;
  final String promise;
}

// app3/guide3.jsx GUIDE3 객체 순서·문구 그대로(11개).
const Map<String, Guide3Item> kGuide3 = {
  'pray': Guide3Item(
    img: 'items/c_basic.png',
    title: '두 손 모아 빌어요',
    steps: [
      Guide3Step('👆', '분홍 버튼을 꾹 눌러요'),
      Guide3Step('🌬', '3초 동안 숨을 쉬며 소원을 떠올려요'),
      Guide3Step('✨', '빛이 올라가면 오늘 기도 끝'),
    ],
    promise: '하루에 한 번이면 충분해요. 매일 빌면 방이 조금씩 환해져요.',
  ),
  'guardians': Guide3Item(
    img: 'chars/F00.png',
    title: '수호자는 내 소원 친구',
    steps: [
      Guide3Step('👤', '함께할 수호자를 골라요'),
      Guide3Step('🙏', '내가 빌 때 같이 두 손을 모아요'),
      Guide3Step('🌙', '바쁜 날엔 대신 빌어 줄 수도 있어요'),
    ],
    promise: '하린과 준은 무료예요. 다른 수호자는 2주 뒤 상점에서 만나요.',
  ),
  'decor': Guide3Item(
    img: 'items/d_rabbit.png',
    title: '방을 꾸며요',
    steps: [
      Guide3Step('✿', '물건을 하나 골라요'),
      Guide3Step('🧧', '복주머니로 사요'),
      Guide3Step('🏠', '방에 쏙 놓여요 · 3개까지'),
    ],
    promise: '다시 누르면 빼요. 바꾸고 싶을 때 언제든 바꿀 수 있어요.',
  ),
  'together': Guide3Item(
    img: 'items/lotus.png',
    title: '다른 사람 소원도 빌어 줘요',
    steps: [
      Guide3Step('☾', '마음 가는 소원을 눌러요'),
      Guide3Step('🙏', '함께 빌기 · 응원 한마디'),
      Guide3Step('💌', '받은 분 방이 따뜻해져요'),
    ],
    promise: '이름은 보이지 않아요. 지역과 나이대만 보여요.',
  ),
  // [대표님 판정 — "잠김 안내는 한 가지 모양으로"] 원본 GUIDE3엔 '찾아온
  // 수호자'(다른 사람이 내 소원을 빌러 온 것 — 'together'와 반대 방향)에 맞는
  // 키가 없었다('together'는 "내가 남의 소원을 빌어 줌" 쪽). care_menu_info.dart
  // '찾아온 수호자' 항목의 기존 안내문을 그대로 가져와 신규로 추가했다.
  'visitor': Guide3Item(
    img: 'items/lotus.png',
    title: '찾아온 수호자',
    steps: [
      Guide3Step('☾', '누가 다녀갔는지 볼 수 있어요'),
      Guide3Step('💌', '남기고 간 한마디를 읽어요'),
      Guide3Step('🎁', '고마우면 답례를 보내요'),
    ],
    promise: '이름 대신 지역 · 나이대만 보여요.',
  ),
  'wardrobe': Guide3Item(
    img: 'outfits/O_free_01.png',
    title: '수호자 옷을 갈아입혀요',
    steps: [
      Guide3Step('👗', '옷을 눌러 입어 봐요'),
      Guide3Step('🧧', '새 옷은 복주머니로'),
      Guide3Step('✨', '갈아입으면 반짝'),
    ],
    promise: '기본 옷 4벌은 무료예요.',
  ),
  'shop': Guide3Item(
    img: 'items/chest.png',
    title: '소원 상점',
    steps: [
      Guide3Step('🛍', '구경은 마음껏'),
      Guide3Step('🧧', '사기 전에 꼭 한 번 더 물어봐요'),
      Guide3Step('🧾', '산 것은 내역에 남아요'),
    ],
    promise: '복주머니 1개는 10원이에요. 보호자와 함께 써요.',
  ),
  'pay': Guide3Item(
    img: 'items/pouch.png',
    title: '복주머니로 결제해요',
    steps: [
      Guide3Step('👀', '얼마인지, 얼마 남는지 확인'),
      Guide3Step('🧧', '결제하기를 눌러요'),
      Guide3Step('🧾', '영수증이 나오면 끝'),
    ],
    promise: '모자라면 활동으로 모으거나 귀인지도에서 충전해요.',
  ),
  'entrust': Guide3Item(
    img: 'poses/F00_free_pray.png',
    title: '수호자에게 맡겨요',
    steps: [
      Guide3Step('📅', '못 오는 날을 골라요'),
      Guide3Step('🙏', '수호자가 내 방에서 대신 빌어요'),
      Guide3Step('🔥', '연속 기도와 촛불을 지켜 줘요'),
    ],
    promise: '방이 자라는 건 내가 직접 빈 날만이에요.',
  ),
  'theme': Guide3Item(
    img: 'room-empty.jpg',
    isBg: true,
    title: '방 분위기를 골라요',
    steps: [
      Guide3Step('🌸', '자유 방은 누구나 편하게'),
      Guide3Step('⛪', '믿는 종교가 있다면 그 방으로'),
      Guide3Step('🔁', '언제든 다시 바꿀 수 있어요'),
    ],
    promise: '그대로 두셔도 괜찮아요.',
  ),
  'share': Guide3Item(
    img: 'items/lotus.png',
    title: '함께 빌어달라고 해요',
    steps: [
      Guide3Step('🔒', '처음엔 나만 봐요'),
      Guide3Step('☾', '공개하면 다른 분이 빌어 줘요'),
      Guide3Step('🛡', '나쁜 말은 오지 않아요'),
    ],
    promise: '수호자 방문을 받을지도 여기서 정해요.',
  ),
  // [대표님 판정 — "잠김 안내는 한 가지 모양으로"] 원본 app3/guide3.jsx GUIDE3엔
  // 'wallpaper' 키가 없었다(⋯ 메뉴의 "배경화면으로 쓰기"는 menuinfo.js 전용
  // 안내만 갖고 있었음). ⋯ 메뉴의 잠금 안내도 하단 탭 · 상점과 같은 모양으로
  // 통일하기 위해, care_menu_info.dart의 '배경화면으로 쓰기' 안내(이미지 ·
  // 문구)를 그대로 가져와 신규로 추가했다 — 의미상 새 기능이 아니라 같은
  // 기존 안내문을 다른 틀(Guide3Sheet)에 담은 것뿐이다.
  'wallpaper': Guide3Item(
    img: 'room-empty.jpg',
    isBg: true,
    title: '배경화면으로 써요',
    steps: [
      Guide3Step('▣', '지금 방 모습 그대로 담아요'),
      Guide3Step('📱', '잠금 화면 · 홈 화면에 설정해요'),
      Guide3Step('🔄', '방이 자라면 배경도 함께 바뀌어요'),
    ],
    promise: '배경화면에는 버튼이나 광고가 없어요. 방만 조용히 보여요.',
  ),
  'vault': Guide3Item(
    img: 'items/gift.png',
    title: '이루어진 소원 보관함',
    steps: [
      Guide3Step('成', '소원이 이루어지면 도장을 찍어요'),
      Guide3Step('◈', '그때 방 모습 그대로 담겨요'),
      Guide3Step('🕯', '새 소원은 1일째부터 다시'),
    ],
    promise: '이룬 소원은 지워지지 않아요.',
  ),
};
