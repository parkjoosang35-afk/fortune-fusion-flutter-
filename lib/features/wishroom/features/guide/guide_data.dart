// app2/guide2.jsx › GUIDE + GUIDE_ORDER 1:1 이식.
// 소원방 안내서(GuideBook)와 한 바퀴 둘러보기(Tour)가 공유하는 정적 콘텐츠.
class GuideItem {
  const GuideItem({required this.icon, required this.title, required this.sub, required this.body, required this.tip});
  final String icon; // assets/wishroom/items/$icon.png
  final String title, sub;
  final List<String> body;
  final String tip;
}

const Map<String, GuideItem> kGuide = {
  'candle': GuideItem(icon: 'c_basic', title: '촛불', sub: '소원방의 심장', body: [
    '정성을 들일 때마다 불꽃이 한 뼘씩 커져요.',
    '4일 넘게 비우면 조금씩 약해지지만, 걱정 마세요. 절대 꺼지지는 않아요.',
    '다시 와서 한 번 톡 누르면 방 전체가 환하게 되살아나요.',
  ], tip: '촛불 모양은 꾸미기에서 연꽃·달빛·별빛 촛불로 바꿀 수 있어요'),
  'devotion': GuideItem(icon: 'spark', title: '정성 들이기', sub: '하루 10번, 마음 보태기', body: [
    '버튼을 누르면 촛불이 흔들리고 빛가루와 꽃잎이 흩날려요.',
    '한 번 누른 뒤에는 촛불이 30초 동안 정성을 머금어요. 잠깐 숨 고르기.',
    '하루 10번을 다 채우면 복주머니 20개가 선물로 와요.',
  ], tip: '정성 1번 = 성장 1점. 방을 키우는 가장 확실한 방법이에요'),
  'level': GuideItem(icon: 'star', title: '성장 단계', sub: 'Lv.1 → Lv.10', body: [
    '정성·응원·받은 복주머니가 쌓이면 방이 자라요.',
    'Lv.2 벚꽃 화병 · Lv.3 향로 · Lv.4 꽃등불 · Lv.5 소원함이 빛나고',
    'Lv.7 천장에 별 · Lv.8 복주머니 · Lv.10엔 달창에 금빛 마법진이 떠요.',
  ], tip: '성장 점수 = 정성 + 응원 × 0.5 + 받은 복주머니 × 10'),
  'pouch': GuideItem(icon: 'pouch', title: '복주머니', sub: '신통방통 공용 재화', body: [
    '신통방통 앱 어디서나 함께 쓰는 복주머니예요. 소원방에서 모은 것도, 쓴 것도 모두 같은 주머니예요.',
    '출석 · 정성 10회 · 짧은 영상 · 미션으로 모으고',
    '캐릭터 · 꾸미기 · 다른 분께 선물하는 데 써요.',
  ], tip: '복주머니는 돈으로 살 수 없어요. 복은 사고파는 게 아니니까요'),
  'ad': GuideItem(icon: 'gift', title: '짧은 영상', sub: '하루 10번 · 복주머니 +30', body: [
    '짧은 영상을 끝까지 보면 복주머니 30개가 담겨요.',
    '하루 10번까지, 자정이 지나면 다시 채워져요.',
    '복주머니가 조금 모자랄 때 가장 빠른 방법이에요.',
  ], tip: '영상을 중간에 닫으면 복주머니는 담기지 않아요'),
  'character': GuideItem(icon: 'lotus', title: '수호자', sub: '방을 지켜주는 분', body: [
    '당신이 없는 동안 소원방을 대신 지켜주는 분이에요.',
    '여성 10분, 남성 10분. 처음 두 분은 무료로 함께해요.',
    '저마다 촛불 바라보기, 두 손 모으기 같은 작은 버릇이 있어요.',
  ], tip: '일반 300 · 레어 500 복주머니 · 이벤트 수호자는 미션으로 만나요'),
  'wish': GuideItem(icon: 'vase', title: '오늘의 소원', sub: '한 번 담으면 끝까지', body: [
    '한 번 담은 소원은 이루어질 때까지 이 방에 머물러요.',
    '봉인한 날이 오기 전에 이루어졌다면, 소원방 돌보기에서 "소원이 이루어졌어요"를 눌러주세요.',
    '방이 황금빛으로 물들고, 기록관에 영원히 남아요.',
  ], tip: '완료 후 7일 안에는 되돌릴 수 있어요. 실수해도 괜찮아요'),
  'seal': GuideItem(icon: 'chest', title: '소원 봉인', sub: '미래의 나에게 맡기는 소원', body: [
    '소원을 적고 봉인할 날을 고르면, 그날까지 소원을 조용히 간직해요.',
    '봉인 날짜는 내일부터 3년 안에서 고를 수 있어요.',
    '기다리는 동안에도 소원방은 그대로예요. 촛불을 밝히고, 정성을 들이고, 방을 꾸밀 수 있어요.',
    '봉인한 날이 오면 알림을 보내드려요. 두루마리를 펼쳐 그때의 마음을 다시 만나보세요.',
    '열어본 뒤에는 이루어졌는지, 아직 진행 중인지 고르면 돼요. 다시 빌고 싶다면 새 날짜로 한 번 더 봉인할 수 있어요.',
  ], tip: '봉인 날짜는 한 번 정하면 바꿀 수 없어요. 천천히 골라주세요'),
  'support': GuideItem(icon: 'petal', title: '응원', sub: '하루 한 번, 마음 보내기', body: [
    '다른 분의 소원방에 하루 한 번 응원을 보낼 수 있어요.',
    '응원을 받으면 방이 자라고, 10 · 30 · 50 · 100번이 쌓일 때마다',
    '꽃잎 효과, 빛가루, 특별 장식이 하나씩 열려요.',
  ], tip: '응원 메시지와 복주머니 선물도 함께 보낼 수 있어요'),
  'decor': GuideItem(icon: 'lantern', title: '꾸미기', sub: '나만의 소원방', body: [
    '촛불 1 · 꽃 1 · 장식 5 · 배경 1 · 특별 효과 1개를 고를 수 있어요.',
    '사기 전에 눌러보면 방에 미리 입혀서 보여드려요.',
    '마음에 들면 복주머니로 방에 들이면 끝.',
  ], tip: '장식은 최대 5개까지 동시에 놓을 수 있어요'),
  'archive': GuideItem(icon: 'chest', title: '소원 기록관', sub: '이루어진 소원의 집', body: [
    '봉인한 소원방은 절대 사라지지 않아요.',
    '그날의 촛불, 꽃, 수호자, 받은 응원까지 그대로 담겨요.',
    '카드를 누르면 그때의 방을 다시 볼 수 있어요.',
  ], tip: '봉인하고 나면 새로운 소원방을 열 수 있어요'),
};

const List<String> kGuideOrder = ['seal', 'candle', 'devotion', 'level', 'pouch', 'ad', 'character', 'wish', 'support', 'decor', 'archive'];

/// app2/guide2.jsx › TOUR — 메인 화면(SCR-03) 좌표 기준 6단계 코치마크.
class TourStep {
  const TourStep({required this.id, required this.x, required this.y, required this.r, required this.line});
  final String id;
  final double x, y, r;
  final String line;
}

const List<TourStep> kTour = [
  TourStep(id: 'candle', x: 204, y: 318, r: 90, line: '먼저, 이 촛불이 소원방의 심장이에요'),
  TourStep(id: 'devotion', x: 195, y: 712, r: 70, line: '하루 10번, 여기를 눌러 정성을 보태요'),
  TourStep(id: 'level', x: 195, y: 112, r: 70, line: '정성이 쌓이면 방이 Lv.10까지 자라요'),
  TourStep(id: 'character', x: 108, y: 470, r: 95, line: '당신 대신 방을 지켜주는 수호자예요'),
  TourStep(id: 'pouch', x: 66, y: 72, r: 46, line: '신통방통 공용 복주머니. 누르면 모으는 곳이 열려요'),
  TourStep(id: 'wish', x: 195, y: 632, r: 80, line: '이루어질 때까지 머무는 당신의 소원'),
];
