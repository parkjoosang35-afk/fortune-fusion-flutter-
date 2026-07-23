// Phase18-FortuneCore-1: 04A 도메인 E-1/E-2 (fortune_requests/fortune_results) 시딩
// 사용자별로 최근 14일간 saju/daily/tarot/face/palm 요청을 생성하고, 대부분은
// 결과(success)까지 생성한다. 일부는 pending 상태로 남겨 대시보드 🟢 위젯
// ("지금 운세 보는 사람 수") 및 AI콘텐츠 관리 화면의 "진행중" 필터 시연에 사용한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

const FORTUNE_TYPES = ["saju", "daily", "tarot", "face", "palm"] as const;
const AI_MODELS = ["gpt-4o-mini", "gpt-4o", "gemini-1.5-flash"];

function randomBetween(min: number, max: number) {
  return Math.random() * (max - min) + min;
}

function samplePayload(type: string): Record<string, unknown> {
  switch (type) {
    case "saju":
      return { birthDate: "1990-05-14", birthTime: "14:30", gender: "female", isLunar: false };
    case "daily":
      return { birthDate: "1990-05-14", today: new Date().toISOString().slice(0, 10) };
    case "tarot":
      return { cards: ["The Fool", "The Star", "The Sun"], spread: "쓰리 카드", question: "이번 달 연애운이 궁금해요" };
    case "face":
      return { imageFileId: null, consentToStore: true };
    case "palm":
      return { imageFileId: null, consentToStore: true };
    default:
      return {};
  }
}

function sampleResultText(type: string): string {
  switch (type) {
    case "saju":
      return "당신의 사주는 목(木) 기운이 강하며, 이번 달은 재물운이 상승하는 시기입니다. 특히 중순 이후 좋은 소식이 있을 것으로 보입니다.";
    case "daily":
      return "오늘은 전반적으로 안정적인 하루입니다. 애정운이 특히 좋으니 소중한 사람과 시간을 보내보세요. 행운의 숫자는 7입니다.";
    case "tarot":
      return "과거의 순수했던 마음(The Fool)이 현재 희망(The Star)으로 이어지며, 미래에는 큰 성공과 활력(The Sun)이 기다리고 있습니다.";
    case "face":
      return "이마가 넓어 초년운이 좋고, 눈매가 또렷해 대인관계가 원만합니다. 코가 오똑해 재물운이 안정적인 인상입니다.";
    case "palm":
      return "생명선이 길고 선명해 건강운이 좋습니다. 감정선이 부드럽게 이어져 애정운도 안정적인 편입니다.";
    default:
      return "";
  }
}

async function main() {
  const existing = await prisma.fortuneRequest.count();
  if (existing > 0) {
    console.log(`이미 fortune_requests ${existing}건이 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const users = await prisma.user.findMany({ where: { deletedAt: null }, select: { id: true }, take: 100 });
  if (users.length === 0) {
    console.log("시딩할 users가 없습니다. 먼저 회원 시딩을 실행하세요.");
    return;
  }

  const activeTemplates = await prisma.aiPromptTemplate.findMany({ where: { isActive: true } });
  const templateByDomain = new Map(activeTemplates.map((t) => [t.fortuneTypeOrDomain, t]));
  if (templateByDomain.size === 0) {
    console.log("ai_prompt_templates가 없습니다. 먼저 seed_ai_content.ts를 실행하세요.");
    return;
  }

  let requestCount = 0;
  let resultCount = 0;

  for (const user of users) {
    // 회원당 최근 14일 내 2~6건의 요청 생성
    const requestsForUser = Math.floor(randomBetween(2, 6));
    for (let i = 0; i < requestsForUser; i++) {
      const fortuneType = FORTUNE_TYPES[Math.floor(Math.random() * FORTUNE_TYPES.length)];
      const daysAgo = Math.floor(randomBetween(0, 14));
      const createdAt = new Date();
      createdAt.setDate(createdAt.getDate() - daysAgo);
      createdAt.setHours(Math.floor(randomBetween(0, 24)), Math.floor(randomBetween(0, 60)));

      // 최근 1일 이내 요청 중 8%는 의도적으로 pending 상태로 남김
      // (대시보드 🟢 "지금 운세 보는 사람 수" 위젯 시연용 — 실제 진행중 데이터)
      const isPending = daysAgo === 0 && Math.random() < 0.08;
      const isFailed = !isPending && Math.random() < 0.03;
      const status = isPending ? "pending" : isFailed ? "failed" : "success";

      const template = templateByDomain.get(fortuneType);
      if (!template) continue;

      const request = await prisma.fortuneRequest.create({
        data: {
          userId: user.id,
          fortuneType,
          inputPayload: JSON.stringify(samplePayload(fortuneType)),
          sourceType: "ai_generated",
          pointSpent: fortuneType === "daily" ? 30 : fortuneType === "tarot" ? 80 : fortuneType === "saju" ? 100 : 150,
          status,
          createdAt,
          updatedAt: createdAt,
          createdBy: `user:${user.id}`,
          updatedBy: `user:${user.id}`,
        },
      });
      requestCount++;

      if (status === "success") {
        await prisma.fortuneResult.create({
          data: {
            requestId: request.id,
            resultText: sampleResultText(fortuneType),
            resultMeta: JSON.stringify({ tokenUsage: Math.floor(randomBetween(300, 1500)) }),
            aiModel: AI_MODELS[Math.floor(Math.random() * AI_MODELS.length)],
            promptTemplateId: template.id,
            promptVersion: template.version,
            createdAt,
            updatedAt: createdAt,
            createdBy: "system",
            updatedBy: "system",
          },
        });
        resultCount++;
      }
    }
  }

  console.log(`fortune_requests ${requestCount}건, fortune_results ${resultCount}건 시딩 완료.`);
  console.log("(참고) 금일(daysAgo=0) 요청 중 일부는 의도적으로 status='pending'으로 남겨 라이브운영센터 위젯 시연에 사용됨.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
