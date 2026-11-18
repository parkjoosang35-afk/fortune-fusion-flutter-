// [v5 S2 — CHECKLIST.md "⋯ 소원방 돌보기 메뉴 10줄 + 안내창(menuinfo.js)"]
// app3/menuinfo.js `INFO` 객체 1:1 포팅. 순서와 문구는 원본 그대로이며(사용자
// 지시 "순서와 문구는 menuinfo.js 원본 그대로"), 「그 밖에」 묶음(소원방 쓰는 법·
// 움직임 줄이기)은 원본에 없는 Flutter 전용 추가 항목이라 이 리스트에는 포함하지
// 않는다(CareSheet가 별도 섹션으로 그린다).
//
// 이미지 경로 중 'assets/outfits2/O_free_01.png'(옷 갈아입기)는 현재 Flutter
// assets/wishroom/ 에 outfits2 폴더가 없어, 기존에 존재하는
// 'assets/wishroom/outfits/O_free_01.png'로 대체했다(동일 캐릭터 기본 의상
// 썸네일이라 의미상 차이 없음 — outfits2는 원본 프로토타입의 신규 의상 세트
// 폴더였고 Flutter는 아직 신규 의상을 연결하지 않았다).
class CareMenuStep {
  const CareMenuStep(this.icon, this.title, this.sub);
  final String icon;
  final String title;
  final String sub;
}

class CareMenuInfo {
  const CareMenuInfo({
    required this.key,
    required this.title,
    required this.img,
    this.isBg = false,
    required this.tag,
    required this.steps,
    required this.note,
    this.lockKey,
    this.unimplemented = false,
  });

  /// Row 식별자(한글 제목 그대로 — menuinfo.js의 `t` 키와 1:1).
  final String key;
  final String title;
  /// `assets/wishroom/` 기준 상대 경로.
  final String img;
  /// true면 img를 배경(cover)으로, false면 중앙 하단에 contain으로 띄운다.
  final bool isBg;
  final String tag;
  final List<CareMenuStep> steps;
  final String note;
  /// null이면 항상 열림(잠금 없음). 값이 있으면 WrCatalog UNLOCK[lockKey] 일째에 열림.
  final String? lockKey;
  /// [v5 S2 — 사용자 확정 "API가 없는 3줄 → 기능 미구현이면 항상 잠김"] true면
  /// Flutter에 대응 API/화면이 아직 없어(entrust·visitor·updateWish) 서버
  /// unlocked[] 날짜와 무관하게 항상 잠긴 것으로 취급한다. 안내창 문구도 날짜
  /// 대신 "곧 열려요"로 바뀐다(_careRow에서 처리). 수호자에게 맡기기·찾아온
  /// 수호자는 S3에서, 소원·목표 고쳐 쓰기는 S6에서 기능이 생기면 이 플래그를
  /// false로 되돌린다.
  final bool unimplemented;
}

// app3/menuinfo.js INFO 객체 순서 그대로(10개).
const List<CareMenuInfo> kCareMenuInfos = [
  CareMenuInfo(
    key: '수호자',
    title: '수호자',
    img: 'chars/F00.png',
    tag: '내 소원을 함께 지켜 줄 단짝',
    steps: [
      CareMenuStep('👤', '함께할 수호자를 골라요', '하린 · 준은 처음부터 무료예요'),
      CareMenuStep('🙏', '내가 빌 때 옆에서 두 손을 모아요', '방 안에서 늘 곁을 지켜요'),
      CareMenuStep('✨', '누르면 성격 · 이야기를 볼 수 있어요', '마음에 드는 수호자로 언제든 바꿔요'),
    ],
    note: '다른 수호자 20명은 소원 상점에서 만나요. 이벤트 수호자는 이벤트로만 와요.',
    lockKey: 'guardian',
  ),
  CareMenuInfo(
    key: '수호자에게 맡기기',
    title: '수호자에게 맡기기',
    img: 'poses/F00_free_pray.png',
    tag: '못 오는 날엔 수호자가 대신 빌어요',
    steps: [
      CareMenuStep('📅', '바쁜 날을 미리 골라요', '하루 · 사흘 · 이레 중에서'),
      CareMenuStep('🙏', '수호자가 내 방에서 대신 기도해요', '돌아오면 기도 일지를 보여줘요'),
      CareMenuStep('🔥', '연속 기도와 촛불 밝기를 지켜 줘요', '쉬어도 촛불이 약해지지 않아요'),
    ],
    note: '방이 자라는 건 내가 직접 빈 날만 세어요. 맡긴 날은 촛불과 연속 기록만 지켜요.',
    lockKey: 'guardian',
  ),
  CareMenuInfo(
    key: '찾아온 수호자',
    title: '찾아온 수호자',
    img: 'items/lotus.png',
    tag: '다른 분의 수호자가 내 소원을 빌러 왔어요',
    steps: [
      CareMenuStep('☾', '누가 다녀갔는지 볼 수 있어요', '이름 대신 지역 · 나이대만 보여요'),
      CareMenuStep('💌', '남기고 간 한마디를 읽어요', '받은 마음은 보관돼요'),
      CareMenuStep('🎁', '고마우면 답례를 보내요', '작은 복주머니나 한마디로'),
    ],
    note: '원하지 않으면 공개 설정에서 수호자 방문을 끌 수 있어요.',
    lockKey: 'together',
    // S3에서 찾아온 수호자(visitor) API/화면이 생기면 해제한다.
    unimplemented: true,
  ),
  CareMenuInfo(
    key: '옷 갈아입기',
    title: '옷 갈아입기',
    img: 'outfits/O_free_01.png',
    tag: '수호자에게 어울리는 옷을 입혀요',
    steps: [
      CareMenuStep('👗', '옷을 눌러 미리 입어 봐요', '위에서 크게 보여요'),
      CareMenuStep('🧧', '새 옷은 복주머니로', '한 번 사면 영원히 내 옷장에'),
      CareMenuStep('✨', '고르면 반짝이며 갈아입어요', '방에서도 바로 보여요'),
    ],
    note: '기본 옷 4벌(사복 · 예배복 · 법복 · 신당복)은 무료예요. 「방 분위기에 맞춰 자동」으로 둘 수도 있어요.',
    lockKey: 'wardrobe',
  ),
  CareMenuInfo(
    key: '방 꾸미기',
    title: '방 꾸미기',
    img: 'items/d_rabbit.png',
    tag: '빈 방을 내 마음대로 채워요',
    steps: [
      CareMenuStep('✿', '장식 · 꽃 · 촛불 · 창밖을 골라요', '종류마다 놓이는 자리가 정해져 있어요'),
      CareMenuStep('🧧', '복주머니로 사요', '사기 전에 한 번 더 물어봐요'),
      CareMenuStep('🏠', '방에 쏙 놓여요', '장식은 3개까지 · 다시 누르면 빼요'),
    ],
    note: '꽉 차면 하나를 빼고 놓아 주세요. 산 물건은 빼도 사라지지 않아요.',
    lockKey: 'decor',
  ),
  CareMenuInfo(
    key: '방 분위기',
    title: '방 분위기',
    img: 'room-empty.jpg',
    isBg: true,
    tag: '믿는 마음에 맞는 방을 골라요',
    steps: [
      CareMenuStep('🌸', '자유 방 · 누구나 편하게', '처음엔 모두 자유 방이에요'),
      CareMenuStep('⛪', '하나님 · 부처님 · 무속인 방', '기도 버튼과 한마디도 함께 바뀌어요'),
      CareMenuStep('🔁', '언제든 다시 바꿀 수 있어요', '기도 기록은 그대로예요'),
    ],
    note: '바꾸지 않고 그대로 두셔도 괜찮아요.',
    lockKey: 'theme',
  ),
  CareMenuInfo(
    key: '배경화면으로 쓰기',
    title: '배경화면으로 쓰기',
    img: 'room-empty.jpg',
    isBg: true,
    tag: '내 소원방을 휴대폰 배경으로',
    steps: [
      CareMenuStep('▣', '지금 방 모습 그대로', '꾸민 물건 · 수호자까지'),
      CareMenuStep('📱', '잠금 화면 · 홈 화면에 설정', '안드로이드는 움직이는 배경'),
      CareMenuStep('🔄', '방이 자라면 배경도 함께', '레벨업 · 꾸미기 때 새로 그려져요'),
    ],
    note: '배경화면에는 버튼이나 광고가 없어요. 방만 조용히 보여요.',
    // [명세 보강] app3/shop.jsx Row 호출부(k="wallpaper")는 이 항목에 잠금을
    // 걸지만, menuinfo.js INFO 원문 note/steps에는 그대로 두고 lockKey만 보강.
    lockKey: 'wallpaper',
  ),
  CareMenuInfo(
    key: '소원 상점',
    title: '소원 상점',
    img: 'items/chest.png',
    tag: '수호자 · 옷 · 꾸밈을 한 곳에서',
    steps: [
      CareMenuStep('🛍', '구경은 언제든 마음껏', '잠긴 물건도 미리 볼 수 있어요'),
      CareMenuStep('🧧', '사기 전에 꼭 한 번 더 확인', '지금 → 쓴 뒤 남는 양을 보여줘요'),
      CareMenuStep('🧾', '산 것은 내역에 남아요', '복주머니 1개 = 10원'),
    ],
    note: '모자라면 활동으로 모으거나 신통방통에서 충전할 수 있어요.',
    lockKey: 'shop',
  ),
  CareMenuInfo(
    key: '함께 빌어달라고 하기',
    title: '함께 빌어달라고 하기',
    img: 'items/lotus.png',
    tag: '내 소원을 다른 분들과 나눠요',
    steps: [
      CareMenuStep('🔒', '처음엔 나만 봐요', '공개는 내가 정해요'),
      CareMenuStep('☾', '공개하면 다른 분이 함께 빌어 줘요', '응원 메시지 · 복주머니도 받아요'),
      CareMenuStep('🛡', '이름은 보이지 않아요', '나쁜 말 · 연락처는 걸러져요'),
    ],
    note: '언제든 다시 비공개로 돌릴 수 있어요. 수호자 방문을 받을지도 여기서 정해요.',
    lockKey: null,
  ),
  CareMenuInfo(
    key: '소원 · 목표 고쳐 쓰기',
    title: '소원 · 목표 고쳐 쓰기',
    img: 'items/c_basic.png',
    tag: '소원 문장과 기도 목표를 다듬어요',
    steps: [
      CareMenuStep('✎', '오타 · 표현을 고쳐요', '날짜와 기도 횟수는 그대로'),
      CareMenuStep('🎯', '기도 목표를 정해요', '21일 · 49일 · 100일 · 목표 없음'),
      CareMenuStep('📜', '고친 기록이 남아요', '공개 중이면 하루 1번까지'),
    ],
    note: '전혀 다른 소원이 되었다면 이 소원을 마무리하고 새로 담는 걸 권해요.',
    lockKey: null,
    // S6에서 소원·목표 고쳐 쓰기(updateWish) API/화면이 생기면 해제한다.
    unimplemented: true,
  ),
];
