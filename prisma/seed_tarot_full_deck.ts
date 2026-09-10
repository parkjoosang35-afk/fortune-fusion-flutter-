// [신통방통 타로 65종 주제 연동 - 78장 풀덱 시딩]
// Flutter lib/features/fortune/tarot/domain/tarot_model.dart의
// majorArcana(22장) + minorSuits(4) x minorRanks(14) = 56장 데이터를
// 그대로 서버 DB(tarot_cards)에 반영한다. 기존 22행(메이저, 로컬 name이
// "The Fool (광대)" 형태로 한글 병기됨)은 name을 Flutter와 동일한 영문
// 순수 표기("The Fool")로 정규화하고 name_kr/basic_meaning을 채운다.
// 마이너 56장은 신규 insert.
//
// [card_basic_meaning] 설계: 정/역방향과 무관한 카드 고유 기본의미.
// Flutter TarotCardMeta에는 up/down만 있고 "방향 무관 기본의미" 필드가
// 없으므로, 여기서는 각 카드의 정방향 키워드를 기반으로 "이 카드가 상징
// 하는 핵심 테마"를 한 문장으로 새로 작성한다(신규 데이터, 최초 작성).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

interface CardSeed {
  name: string;
  nameKr: string;
  basicMeaning: string;
  upright: string;
  reversed: string;
  arcanaType: "major" | "minor";
  suit?: string;
  sortOrder: number;
}

// ── 메이저 아르카나 22장 (Flutter majorArcana와 동일 순서/의미) ──
const MAJOR: Omit<CardSeed, "arcanaType" | "sortOrder">[] = [
  { name: "The Fool", nameKr: "바보", basicMeaning: "순수한 가능성과 시작 그 자체를 상징하는 카드", upright: "두려움 없는 새로운 시작과 순수한 도전", reversed: "무모한 행동이나 준비 부족을 주의" },
  { name: "The Magician", nameKr: "마법사", basicMeaning: "가진 자원을 실제 행동으로 옮기는 창조적 의지를 상징하는 카드", upright: "가진 능력과 자원으로 원하는 것을 이루는 힘", reversed: "재능을 낭비하거나 자만하는 태도 주의" },
  { name: "The High Priestess", nameKr: "여사제", basicMeaning: "언어로 설명되지 않는 직관과 내면의 지혜를 상징하는 카드", upright: "내면의 직관과 감춰진 진실에 대한 통찰", reversed: "직관을 무시하거나 혼란스러운 판단" },
  { name: "The Empress", nameKr: "여황제", basicMeaning: "풍요, 돌봄, 창조적 결실을 상징하는 카드", upright: "풍요와 창조, 따뜻한 결실이 찾아오는 흐름", reversed: "과잉보호나 나태함으로 인한 정체" },
  { name: "The Emperor", nameKr: "황제", basicMeaning: "체계, 권위, 안정적 질서를 상징하는 카드", upright: "체계와 안정, 확고한 리더십으로 나아가는 힘", reversed: "고집이나 지나친 통제로 인한 갈등" },
  { name: "The Hierophant", nameKr: "교황", basicMeaning: "전통, 제도, 검증된 가르침을 상징하는 카드", upright: "전통과 배움, 신뢰할 수 있는 조언이 도움이 되는 때", reversed: "관습에 얽매이거나 융통성 부족" },
  { name: "The Lovers", nameKr: "연인", basicMeaning: "관계 속의 선택과 결합, 가치관의 합일을 상징하는 카드", upright: "관계 속 조화와 의미 있는 선택의 순간", reversed: "관계의 불균형이나 우유부단한 선택" },
  { name: "The Chariot", nameKr: "전차", basicMeaning: "의지력으로 상반된 힘을 통제해 나아가는 추진력을 상징하는 카드", upright: "강한 의지로 장애물을 돌파하는 추진력", reversed: "방향을 잃거나 통제력을 상실할 위험" },
  { name: "Strength", nameKr: "힘", basicMeaning: "부드러움으로 다스리는 내면의 용기를 상징하는 카드", upright: "부드러움 속에 담긴 단단한 내면의 힘", reversed: "자신감 부족이나 감정 조절의 어려움" },
  { name: "The Hermit", nameKr: "은둔자", basicMeaning: "홀로 있는 시간 속에서 얻는 내면의 통찰을 상징하는 카드", upright: "잠시 멈춰 스스로를 돌아보는 성찰의 시간", reversed: "고립감이나 지나친 회피 성향 주의" },
  { name: "Wheel of Fortune", nameKr: "운명의 수레바퀴", basicMeaning: "삶의 순환과 통제할 수 없는 운의 흐름을 상징하는 카드", upright: "피할 수 없는 변화의 흐름이 유리하게 작용", reversed: "뜻하지 않은 변수나 불운한 타이밍" },
  { name: "Justice", nameKr: "정의", basicMeaning: "인과와 균형, 공정한 심판을 상징하는 카드", upright: "공정한 판단과 균형 잡힌 결과", reversed: "불공정함이나 왜곡된 판단에 대한 경계" },
  { name: "The Hanged Man", nameKr: "매달린 사람", basicMeaning: "멈춤과 관점의 전환을 통한 깨달음을 상징하는 카드", upright: "관점을 바꾸면 보이는 새로운 답", reversed: "정체되거나 희생이 헛되이 느껴지는 시기" },
  { name: "Death", nameKr: "죽음", basicMeaning: "하나의 끝이 곧 다른 시작임을 상징하는 변형의 카드", upright: "묵은 것을 끝내고 새롭게 태어나는 전환점", reversed: "변화에 대한 저항이나 미련이 발목을 잡음" },
  { name: "Temperance", nameKr: "절제", basicMeaning: "상반된 요소의 조화와 균형을 상징하는 카드", upright: "균형과 조화를 통한 안정적인 흐름", reversed: "과유불급, 극단으로 치우칠 위험" },
  { name: "The Devil", nameKr: "악마", basicMeaning: "집착, 속박, 스스로 만든 제약을 상징하는 카드", upright: "집착이나 유혹의 실체를 직시해야 할 때", reversed: "억눌린 욕망에서 벗어나는 해방의 신호" },
  { name: "The Tower", nameKr: "탑", basicMeaning: "예고 없이 찾아오는 급격한 붕괴와 각성을 상징하는 카드", upright: "갑작스러운 붕괴 뒤에 찾아오는 근본적 각성", reversed: "충격을 최소화하려는 방어적 태도가 필요" },
  { name: "The Star", nameKr: "별", basicMeaning: "고난 이후에 찾아오는 희망과 치유를 상징하는 카드", upright: "희망과 치유, 회복에 대한 밝은 기대", reversed: "자신감 상실이나 막막함이 느껴질 수 있음" },
  { name: "The Moon", nameKr: "달", basicMeaning: "불확실함과 무의식 속에 숨겨진 진실을 상징하는 카드", upright: "불확실함 속에서도 직관을 믿어야 하는 시기", reversed: "불안과 혼란, 숨겨진 진실에 대한 경계" },
  { name: "The Sun", nameKr: "태양", basicMeaning: "명료함, 성취, 가장 밝은 활력을 상징하는 카드", upright: "성공과 활력, 가장 밝고 긍정적인 에너지", reversed: "지나친 낙관이나 과시욕을 주의" },
  { name: "Judgement", nameKr: "심판", basicMeaning: "지난 시간의 정리와 새로운 소명의 각성을 상징하는 카드", upright: "지난 시간을 정리하고 새로운 소명을 깨닫는 순간", reversed: "자기 비판에 갇히거나 결단을 미루는 상태" },
  { name: "The World", nameKr: "세계", basicMeaning: "하나의 여정이 완성되는 성취와 완결을 상징하는 카드", upright: "하나의 여정이 완성되고 성취를 맞이하는 순간", reversed: "마무리가 지연되거나 미완성으로 남는 아쉬움" },
];

// ── 마이너 아르카나 4수트 x 14랭크 = 56장 (Flutter minorSuits/minorRanks 동일 로직) ──
const SUITS = [
  { id: "wands", nameKr: "완드", domain: "열정과 행동" },
  { id: "cups", nameKr: "컵", domain: "감정과 관계" },
  { id: "swords", nameKr: "소드", domain: "생각과 갈등" },
  { id: "pentacles", nameKr: "펜타클", domain: "현실과 물질" },
];

const RANKS = [
  { id: "ace", nameKr: "에이스", up: "{domain}의 새로운 시작을 알리는 신호가 나타났어요", down: "{domain}에서 시작이 늦어지거나 주저함이 느껴져요", basic: "{domain} 영역에서 새로운 씨앗이 뿌려지는 출발점" },
  { id: "two", nameKr: "2", up: "{domain} 안에서 균형과 선택의 순간이 찾아왔어요", down: "{domain}에서 결정을 미루거나 우유부단해질 수 있어요", basic: "{domain} 안에서 두 갈래 선택의 균형을 맞추는 지점" },
  { id: "three", nameKr: "3", up: "{domain}이(가) 조금씩 결실을 맺기 시작해요", down: "{domain}에서 계획이 지연되거나 협업에 어려움이 생겨요", basic: "{domain}에서 첫 협력과 성장이 나타나는 단계" },
  { id: "four", nameKr: "4", up: "{domain}에서 안정과 잠시의 휴식이 필요한 때예요", down: "{domain}이(가) 정체되거나 권태로움이 느껴질 수 있어요", basic: "{domain}에서 잠시 멈춰 안정을 다지는 단계" },
  { id: "five", nameKr: "5", up: "{domain}에서 갈등이나 경쟁을 통해 배움을 얻어요", down: "{domain}에서의 다툼이나 손실을 주의해야 해요", basic: "{domain}에서 갈등과 시련을 통해 시험받는 단계" },
  { id: "six", nameKr: "6", up: "{domain}에서 협력과 나눔으로 좋은 결과를 얻어요", down: "{domain}에서 과거에 얽매이거나 균형을 잃을 수 있어요", basic: "{domain}에서 조화와 회복이 찾아오는 단계" },
  { id: "seven", nameKr: "7", up: "{domain}을(를) 향한 인내와 노력이 결실로 이어져요", down: "{domain}에서 방향을 잃거나 노력이 흩어질 수 있어요", basic: "{domain}에서 인내와 재정비가 필요한 단계" },
  { id: "eight", nameKr: "8", up: "{domain}에서 꾸준한 발전과 숙련이 이루어져요", down: "{domain}에서 제약이나 스스로 만든 한계가 느껴져요", basic: "{domain}에서 속도와 숙련이 쌓이는 단계" },
  { id: "nine", nameKr: "9", up: "{domain}에서 거의 완성 단계에 다다랐어요", down: "{domain}에서 불안이나 피로가 쌓여있을 수 있어요", basic: "{domain}에서 완성을 앞두고 홀로 버텨내는 단계" },
  { id: "ten", nameKr: "10", up: "{domain}의 한 사이클이 완성되고 다음 단계로 넘어가요", down: "{domain}에서 부담과 과부하를 느낄 수 있어요", basic: "{domain} 한 사이클의 완결과 그 무게를 상징하는 단계" },
  { id: "page", nameKr: "페이지", up: "{domain}에 대한 호기심과 배움의 자세가 필요해요", down: "{domain}에서 미숙함이나 성급한 판단을 조심하세요", basic: "{domain}을 처음 배우는 순수한 호기심을 상징" },
  { id: "knight", nameKr: "나이트", up: "{domain}을(를) 향해 적극적으로 나아갈 때예요", down: "{domain}에서 성급하거나 무모한 행동을 주의하세요", basic: "{domain}을 향해 행동으로 돌진하는 추진력을 상징" },
  { id: "queen", nameKr: "퀸", up: "{domain}을(를) 성숙하고 너그럽게 다루는 지혜가 있어요", down: "{domain}에서 감정 기복이나 과도한 예민함을 조심하세요", basic: "{domain}을 성숙하게 품어내는 내면의 지혜를 상징" },
  { id: "king", nameKr: "킹", up: "{domain}을(를) 주도적으로 이끌어갈 힘이 있어요", down: "{domain}에서 독단적이거나 경직된 태도를 주의하세요", basic: "{domain}을 완숙하게 주관하는 권위와 통제력을 상징" },
];

function buildMinorDeck(): CardSeed[] {
  const deck: CardSeed[] = [];
  let order = 22;
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({
        name: `${rank.nameKr} of ${suit.nameKr}`,
        nameKr: `${suit.nameKr} ${rank.nameKr}`,
        basicMeaning: rank.basic.replaceAll("{domain}", suit.domain),
        upright: rank.up.replaceAll("{domain}", suit.domain),
        reversed: rank.down.replaceAll("{domain}", suit.domain),
        arcanaType: "minor",
        suit: suit.id,
        sortOrder: order++,
      });
    }
  }
  return deck;
}

// 기존 DB에 이미 존재하는 "The Fool (광대)" 형태의 레거시 name을 새 정규화된
// name("The Fool")으로 매핑하기 위한 테이블(순서가 sort_order와 1:1 대응).
const LEGACY_NAME_BY_SORT_ORDER: Record<number, string> = {};

async function main() {
  console.log("[seed_tarot_full_deck] 시작...");

  // 1) 기존 22개 메이저 레코드를 sort_order 기준으로 조회해 name을 정규화한다.
  const existingMajors = await prisma.tarotCard.findMany({
    where: { arcanaType: "major" },
    orderBy: { sortOrder: "asc" },
  });
  console.log(`[seed_tarot_full_deck] 기존 메이저 레코드 ${existingMajors.length}개 발견`);

  for (const existing of existingMajors) {
    const seed = MAJOR[existing.sortOrder];
    if (!seed) {
      console.warn(`[seed_tarot_full_deck] sort_order=${existing.sortOrder}에 대응하는 시드 데이터 없음, 스킵: ${existing.name}`);
      continue;
    }
    await prisma.tarotCard.update({
      where: { id: existing.id },
      data: {
        name: seed.name,
        nameKr: seed.nameKr,
        basicMeaning: seed.basicMeaning,
        uprightMeaning: seed.upright,
        reversedMeaning: seed.reversed,
        updatedBy: "system_seed_tarot_full_deck",
      },
    });
  }
  console.log("[seed_tarot_full_deck] 메이저 22장 name/nameKr/basicMeaning 정규화 완료");

  // 2) 마이너 56장 신규 insert (이미 존재하면 스킵, 재실행 안전성 보장)
  const minorDeck = buildMinorDeck();
  let insertedCount = 0;
  for (const card of minorDeck) {
    const existing = await prisma.tarotCard.findUnique({ where: { name: card.name } });
    if (existing) continue;
    await prisma.tarotCard.create({
      data: {
        name: card.name,
        nameKr: card.nameKr,
        basicMeaning: card.basicMeaning,
        uprightMeaning: card.upright,
        reversedMeaning: card.reversed,
        arcanaType: card.arcanaType,
        suit: card.suit,
        sortOrder: card.sortOrder,
        createdBy: "system_seed_tarot_full_deck",
        updatedBy: "system_seed_tarot_full_deck",
      },
    });
    insertedCount++;
  }
  console.log(`[seed_tarot_full_deck] 마이너 아르카나 신규 삽입 ${insertedCount}건 (총 56장 대상)`);

  const total = await prisma.tarotCard.count();
  console.log(`[seed_tarot_full_deck] 완료. tarot_cards 총 레코드 수: ${total}`);
}

main()
  .catch((e) => {
    console.error("[seed_tarot_full_deck] 실패:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
