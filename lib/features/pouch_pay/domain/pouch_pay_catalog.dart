// 복주머니 결제(S5) · 가격 정책 데이터 — design_handoff_pouch_payment.zip
// (README.md §4 가격 정책 / 기획서.md §가격 원칙 / design_files/PayComponents.jsx
// `PAY_PACKS`/`PAY_SUBS`)를 1:1 포팅한 순수 데이터 모델. 서버 `policy_versions`
// 테이블이 아직 없으므로(이번 라운드는 PAYMENT_MODE.mock), 지금은 이 상수가
// 유일한 출처다 — 실제 서버 정책 테이블이 생기면 이 파일을 그 응답으로 교체한다.
library;

/// 1개(복주머니) = ₩10 고정. README §4 / 기획서 §가격 원칙 1:1.
const int kPouchUnitPrice = 10;

/// 구독자가 "한 번 담기"를 추가로 살 때 더 얹어주는 구독 덤(%).
/// design_files/PayComponents.jsx `SUB_EXTRA_PCT = 5` 1:1.
const int kPouchSubExtraPct = 5;

/// 한 번 담기(소모성) 패키지 1개.
class PouchPack {
  final String id;
  final String name;
  final int base;
  final int bonus;
  final int price; // KRW
  final String? tag;

  const PouchPack({
    required this.id,
    required this.name,
    required this.base,
    required this.bonus,
    required this.price,
    this.tag,
  });

  int get total => base + bonus;
  int get bonusPct => base == 0 ? 0 : ((bonus / base) * 100).round();
}

/// PayComponents.jsx `PAY_PACKS` 1:1 — 6종.
const List<PouchPack> kPouchPacks = [
  PouchPack(id: 'p100', name: '한 줌', base: 100, bonus: 0, price: 1000),
  PouchPack(id: 'p300', name: '한 아름', base: 300, bonus: 15, price: 3000),
  PouchPack(id: 'p500', name: '한 바구니', base: 500, bonus: 50, price: 5000),
  PouchPack(
    id: 'p1000',
    name: '한 꾸러미',
    base: 1000,
    bonus: 150,
    price: 10000,
    tag: '가장 많이 담아요',
  ),
  PouchPack(id: 'p3000', name: '한 궤짝', base: 3000, bonus: 600, price: 30000),
  PouchPack(
    id: 'p5000',
    name: '곳간 하나',
    base: 5000,
    bonus: 1250,
    price: 50000,
    tag: '가장 넉넉해요',
  ),
];

/// 매달 받기(구독) 1개 길(tier).
class PouchSubTier {
  final String id;
  final String hanja;
  final String name;
  final String en;
  final String tagline;
  final int month; // KRW/월
  final int bonusPct;
  final String? tag;
  final bool premium;
  final List<String> perks;

  const PouchSubTier({
    required this.id,
    required this.hanja,
    required this.name,
    required this.en,
    required this.tagline,
    required this.month,
    required this.bonusPct,
    this.tag,
    this.premium = false,
    required this.perks,
  });
}

/// PayComponents.jsx `PAY_SUBS` 1:1 — 3종(초심/정성/신통).
const List<PouchSubTier> kPouchSubs = [
  PouchSubTier(
    id: 'chosim',
    hanja: '初',
    name: '초심',
    en: 'CHOSIM',
    tagline: '매일 아침, 작은 복 하나',
    month: 3900,
    bonusPct: 10,
    perks: ['광고 없이 조용한 소원방'],
  ),
  PouchSubTier(
    id: 'jeongseong',
    hanja: '誠',
    name: '정성',
    en: 'JEONGSEONG',
    tagline: '하루도 거르지 않는 마음',
    month: 9900,
    bonusPct: 30,
    tag: '가장 많이 함께해요',
    perks: ['보름달 밤 적립 두 배', '광고 없이 조용한 소원방'],
  ),
  PouchSubTier(
    id: 'sintong',
    hanja: '神',
    name: '신통',
    en: 'SINTONG',
    tagline: '온 마음을 다해 밝히는 이에게',
    month: 19900,
    bonusPct: 40,
    premium: true,
    perks: ['매달 金 금박 인장 한 개', '전용 팔레트 · 금박 신전', '보름달 밤 적립 두 배 · 광고 없음'],
  ),
];

/// 한 해 결제 금액 = 월 요금 × 10(두 달 무료). PayComponents.jsx `subYearPrice` 1:1.
int pouchSubYearPrice(PouchSubTier s) => s.month * 10;

/// 결제 1회(월 1회)당 지급되는 기본 복주머니 개수(원화 ÷ 단가).
int pouchSubBase(PouchSubTier s) => (s.month / kPouchUnitPrice).round();

/// 구독 덤(%) 적용분.
int pouchSubBonus(PouchSubTier s) =>
    (pouchSubBase(s) * s.bonusPct / 100).round();

/// 결제 1회당 실제로 한 번에 지급되는 총량(기본 + 덤).
int pouchSubGrant(PouchSubTier s) => pouchSubBase(s) + pouchSubBonus(s);

/// 모자란 만큼을 채우는 가장 작은 꾸러미 + 그 다음 두 개.
/// design_files/PayEntry.jsx `suggestPacks(short)` 1:1.
List<PouchPack> suggestPouchPacks(int short) {
  var idx = kPouchPacks.indexWhere((p) => p.total >= short);
  if (idx < 0) idx = 0;
  final end = (idx + 3).clamp(0, kPouchPacks.length);
  return kPouchPacks.sublist(idx, end);
}

/// PAYMENT_MODE 개발 스위치 — README.md §6 / 개발 가이드.html 공통 언급.
/// 지금은 mock만 실제로 동작한다(Wallet/PointHistory 원장에 진짜로 적립하되
/// 스토어 결제창은 거치지 않음). sandbox/live로 전환하려면 `in_app_purchase`
/// 패키지 연동 + 서버 영수증 검증(RTDN/Voided Purchases, Apple Server
/// Notifications v2)이 먼저 구현되어야 한다 — 자세한 내용은
/// `pouch_pay_service.dart` 상단 주석 참고.
enum PouchPaymentMode { mock, sandbox, live }

const PouchPaymentMode kPouchPaymentMode = PouchPaymentMode.mock;
