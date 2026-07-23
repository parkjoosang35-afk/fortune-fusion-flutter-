// Phase18-2 AI 콘텐츠 관리 목업 데이터 시딩
// 04A G-3(ai_prompt_templates) + G-4(ai_request_logs) + E-5/E-6(tarot_cards/tarot_spreads)
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

// ── 1) ai_prompt_templates: 6개 기능 × 버전이력(v1은 비활성 과거버전, v2가 최신 활성버전) ──
const PROMPT_DOMAINS = [
  { domain: "saju", label: "사주풀이" },
  { domain: "daily", label: "오늘의 운세" },
  { domain: "tarot", label: "타로" },
  { domain: "face", label: "관상" },
  { domain: "palm", label: "손금" },
  { domain: "consultation", label: "AI 상담" },
];

const PROMPT_V1_BODY: Record<string, string> = {
  saju: "당신은 사주 명리학 전문가입니다. 아래 생년월일시 정보를 바탕으로 사주를 풀이해주세요.\n생년월일: {{birthDate}}\n출생시간: {{birthTime}}\n성별: {{gender}}",
  daily: "오늘의 운세를 알려주세요. 생년월일: {{birthDate}}, 오늘 날짜: {{today}}",
  tarot: "타로 카드 리딩을 해주세요. 뽑힌 카드: {{cards}}, 스프레드: {{spread}}, 질문: {{question}}",
  face: "관상 분석을 해주세요. 업로드된 얼굴 이미지를 바탕으로 이마/눈/코/입/턱 순서로 분석합니다.",
  palm: "손금 분석을 해주세요. 업로드된 손바닥 이미지를 바탕으로 생명선/두뇌선/감정선을 분석합니다.",
  consultation: "당신은 따뜻하고 공감능력이 뛰어난 운세 상담사입니다. 사용자의 고민에 공감하며 답변해주세요.\n고민: {{userMessage}}",
};

const PROMPT_V2_BODY: Record<string, string> = {
  saju: "당신은 30년 경력의 사주 명리학 전문가입니다. 아래 생년월일시 정보를 바탕으로 사주팔자를 정확히 산출하고, 오행의 균형과 십신을 고려하여 상세히 풀이해주세요.\n생년월일: {{birthDate}}\n출생시간: {{birthTime}}\n성별: {{gender}}\n양/음력: {{isLunar}}\n\n반드시 아래 형식으로 답변하세요:\n1) 사주팔자 원국\n2) 오행 분석\n3) 총운/애정운/재물운/건강운\n4) 이번 달 조언",
  daily: "당신은 오늘의 운세 전문가입니다. 생년월일: {{birthDate}}, 오늘 날짜: {{today}}, 별자리: {{zodiac}}를 바탕으로 애정운/금전운/건강운/행운의 숫자를 포함한 오늘의 운세를 200자 이내로 간결하게 작성해주세요.",
  tarot: "당신은 숙련된 타로 마스터입니다. 뽑힌 카드: {{cards}}, 스프레드: {{spread}}, 질문: {{question}}을 바탕으로 각 카드의 정/역방향 의미를 스프레드 위치에 맞게 해석하고, 종합적인 조언을 제공해주세요.",
  face: "당신은 관상학 전문가입니다. 업로드된 얼굴 이미지를 바탕으로 이마(초년운)/눈(대인관계)/코(재물운)/입(말년운)/턱(의지력) 순서로 분석하고, 전체 인상에 대한 총평을 제공해주세요. 외모 비하성 표현은 절대 사용하지 마세요.",
  palm: "당신은 손금 분석 전문가입니다. 업로드된 손바닥 이미지를 바탕으로 생명선(건강)/두뇌선(사고방식)/감정선(애정운)/운명선(직업운)을 분석하고 종합 조언을 제공해주세요.",
  consultation: "당신은 따뜻하고 공감능력이 뛰어난 운세 상담사입니다. 사용자의 고민에 깊이 공감하며, 명리학/타로 관점에서 조언을 곁들여 답변해주세요.\n이전 대화: {{history}}\n고민: {{userMessage}}\n\n답변은 300자 이내로 작성하고, 마지막에는 항상 희망적인 메시지로 마무리하세요.",
};

async function seedPromptTemplates() {
  console.log("[seed_ai_content] 1) ai_prompt_templates 시딩...");
  let count = 0;
  for (const { domain } of PROMPT_DOMAINS) {
    const existing = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: domain },
    });
    if (existing) continue;

    // v1: 과거 버전(비활성)
    await prisma.aiPromptTemplate.create({
      data: {
        fortuneTypeOrDomain: domain,
        version: 1,
        templateBody: PROMPT_V1_BODY[domain],
        isActive: false,
        createdBy: "system",
        updatedBy: "system",
      },
    });
    // v2: 최신 버전(활성)
    await prisma.aiPromptTemplate.create({
      data: {
        fortuneTypeOrDomain: domain,
        version: 2,
        templateBody: PROMPT_V2_BODY[domain],
        isActive: true,
        createdBy: "system",
        updatedBy: "system",
      },
    });
    count += 2;
  }
  console.log(`[seed_ai_content]    -> ${count}건 프롬프트 템플릿(버전 포함) 생성 완료`);
}

// ── 2) tarot_cards: 메이저 아르카나 22장 ──
const MAJOR_ARCANA: Array<{
  name: string;
  upright: string;
  reversed: string;
  order: number;
}> = [
  { name: "The Fool (광대)", upright: "새로운 시작, 순수함, 자유로운 영혼, 모험", reversed: "무모함, 경솔한 판단, 위험한 선택", order: 0 },
  { name: "The Magician (마법사)", upright: "의지력, 창조력, 능력 발휘, 자원 활용", reversed: "속임수, 능력 오용, 준비 부족", order: 1 },
  { name: "The High Priestess (여사제)", upright: "직관, 신비, 내면의 지혜, 잠재의식", reversed: "비밀, 단절된 직관, 표면적 지식", order: 2 },
  { name: "The Empress (여황제)", upright: "풍요, 모성, 창조성, 자연과의 조화", reversed: "의존, 창조력 결핍, 과잉보호", order: 3 },
  { name: "The Emperor (황제)", upright: "권위, 안정, 구조, 통제력", reversed: "독단, 융통성 부족, 지배욕", order: 4 },
  { name: "The Hierophant (교황)", upright: "전통, 신념, 제도, 정신적 스승", reversed: "경직된 사고, 관습에 대한 반발", order: 5 },
  { name: "The Lovers (연인)", upright: "사랑, 조화, 관계, 선택", reversed: "불균형, 관계의 갈등, 잘못된 선택", order: 6 },
  { name: "The Chariot (전차)", upright: "의지, 결단력, 승리, 자기통제", reversed: "방향 상실, 통제력 부족, 공격성", order: 7 },
  { name: "Strength (힘)", upright: "내면의 힘, 용기, 인내, 자비", reversed: "자기 의심, 나약함, 감정 통제 실패", order: 8 },
  { name: "The Hermit (은둔자)", upright: "내적 성찰, 고독, 탐구, 지혜", reversed: "고립, 외로움, 소통 단절", order: 9 },
  { name: "Wheel of Fortune (운명의 수레바퀴)", upright: "운명, 순환, 전환점, 행운", reversed: "불운, 통제 불가능한 변화, 저항", order: 10 },
  { name: "Justice (정의)", upright: "공정함, 균형, 진실, 인과응보", reversed: "불공정, 편견, 책임 회피", order: 11 },
  { name: "The Hanged Man (매달린 사람)", upright: "새로운 관점, 희생, 기다림, 깨달음", reversed: "정체, 저항, 무의미한 희생", order: 12 },
  { name: "Death (죽음)", upright: "끝과 시작, 변화, 전환, 해방", reversed: "변화에 대한 저항, 정체, 두려움", order: 13 },
  { name: "Temperance (절제)", upright: "균형, 조화, 절제, 인내", reversed: "불균형, 과잉, 인내심 부족", order: 14 },
  { name: "The Devil (악마)", upright: "속박, 유혹, 물질주의, 집착", reversed: "해방, 속박으로부터의 자유, 자각", order: 15 },
  { name: "The Tower (탑)", upright: "급격한 변화, 붕괴, 각성, 혼란", reversed: "변화에 대한 두려움, 재난 회피", order: 16 },
  { name: "The Star (별)", upright: "희망, 영감, 치유, 평온", reversed: "실망, 자신감 결여, 방향 상실", order: 17 },
  { name: "The Moon (달)", upright: "불안, 환상, 직관, 무의식", reversed: "혼란 해소, 두려움 극복, 명료함", order: 18 },
  { name: "The Sun (태양)", upright: "성공, 활력, 자신감, 긍정", reversed: "일시적 우울, 성공의 지연", order: 19 },
  { name: "Judgement (심판)", upright: "각성, 부활, 심판, 새로운 국면", reversed: "자기비판, 후회, 결단력 부족", order: 20 },
  { name: "The World (세계)", upright: "완성, 성취, 통합, 여행", reversed: "미완성, 지연, 목표 상실", order: 21 },
];

async function seedTarotCards() {
  console.log("[seed_ai_content] 2) tarot_cards 시딩...");
  let count = 0;
  for (const c of MAJOR_ARCANA) {
    const existing = await prisma.tarotCard.findUnique({ where: { name: c.name } });
    if (existing) continue;
    await prisma.tarotCard.create({
      data: {
        name: c.name,
        imageUrl: null,
        uprightMeaning: c.upright,
        reversedMeaning: c.reversed,
        arcanaType: "major",
        sortOrder: c.order,
        createdBy: "system",
        updatedBy: "system",
      },
    });
    count++;
  }
  console.log(`[seed_ai_content]    -> ${count}건 타로카드(메이저 아르카나) 생성 완료`);
}

// ── 3) tarot_spreads ──
const SPREADS = [
  { name: "원 카드", cardCount: 1, isPremium: false, layout: { positions: [{ x: 0, y: 0, meaning: "핵심 답변" }] } },
  { name: "쓰리 카드 (과거-현재-미래)", cardCount: 3, isPremium: false, layout: { positions: [{ x: 0, y: 0, meaning: "과거" }, { x: 1, y: 0, meaning: "현재" }, { x: 2, y: 0, meaning: "미래" }] } },
  { name: "켈틱 크로스", cardCount: 10, isPremium: true, layout: { positions: Array.from({ length: 10 }, (_, i) => ({ x: i, y: 0, meaning: `포지션${i + 1}` })) } },
  { name: "연애운 스프레드", cardCount: 5, isPremium: true, layout: { positions: [{ x: 0, y: 0, meaning: "나의 마음" }, { x: 1, y: 0, meaning: "상대의 마음" }, { x: 2, y: 0, meaning: "관계의 현재" }, { x: 3, y: 0, meaning: "장애물" }, { x: 4, y: 0, meaning: "전망" }] } },
];

async function seedTarotSpreads() {
  console.log("[seed_ai_content] 3) tarot_spreads 시딩...");
  let count = 0;
  for (const s of SPREADS) {
    const existing = await prisma.tarotSpread.findUnique({ where: { name: s.name } });
    if (existing) continue;
    await prisma.tarotSpread.create({
      data: {
        name: s.name,
        cardCount: s.cardCount,
        isPremium: s.isPremium,
        layoutMeta: JSON.stringify(s.layout),
        createdBy: "system",
        updatedBy: "system",
      },
    });
    count++;
  }
  console.log(`[seed_ai_content]    -> ${count}건 타로 스프레드 생성 완료`);
}

// ── 4) ai_request_logs: 최근 14일간 도메인별 호출 로그(비용 대시보드 시연용) ──
const AI_MODELS = ["gpt-4o-mini", "gpt-4o", "gemini-1.5-flash"];
const DOMAINS = ["saju", "daily", "tarot", "face", "palm", "consultation"];

function randomBetween(min: number, max: number) {
  return Math.random() * (max - min) + min;
}

async function seedRequestLogs() {
  console.log("[seed_ai_content] 4) ai_request_logs 시딩...");
  const existingCount = await prisma.aiRequestLog.count();
  if (existingCount > 0) {
    console.log(`[seed_ai_content]    -> 이미 ${existingCount}건 존재, 스킵`);
    return;
  }

  const rows: Array<{
    domain: string;
    aiModel: string;
    latencyMs: number;
    tokenUsage: number;
    costEstimate: number;
    status: string;
    createdAt: Date;
  }> = [];

  const now = Date.now();
  for (let day = 0; day < 14; day++) {
    const dayStart = now - day * 86400000;
    // 하루에 도메인별로 5~15건씩 생성
    for (const domain of DOMAINS) {
      const callsPerDay = Math.floor(randomBetween(5, 15));
      for (let i = 0; i < callsPerDay; i++) {
        const model = AI_MODELS[Math.floor(Math.random() * AI_MODELS.length)];
        const isFailed = Math.random() < 0.05; // 5% 실패율
        const tokenUsage = Math.floor(randomBetween(300, 2500));
        const costPerToken = model === "gpt-4o" ? 0.00001 : model === "gpt-4o-mini" ? 0.0000015 : 0.000001;
        rows.push({
          domain,
          aiModel: model,
          latencyMs: Math.floor(randomBetween(800, 6000)),
          tokenUsage,
          costEstimate: Number((tokenUsage * costPerToken).toFixed(6)),
          status: isFailed ? (Math.random() < 0.5 ? "failed" : "timeout") : "success",
          createdAt: new Date(dayStart - Math.floor(randomBetween(0, 86400000))),
        });
      }
    }
  }

  // 대량 삽입 (createMany, SQLite adapter 지원)
  await prisma.aiRequestLog.createMany({ data: rows });
  console.log(`[seed_ai_content]    -> ${rows.length}건 AI 호출 로그(최근 14일) 생성 완료`);
}

async function main() {
  await seedPromptTemplates();
  await seedTarotCards();
  await seedTarotSpreads();
  await seedRequestLogs();
  console.log("[seed_ai_content] 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
