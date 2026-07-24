// Phase18-Consultation-1: 04A 도메인 G-1/G-2 (consultation_sessions/consultation_messages) 시딩
// 05§3.0.1 💬"AI 상담 진행 건수" 라이브 위젯(ended_at IS NULL 카운트) 시연을 위해
// 회원별로 상담 세션을 생성하고, 그중 일부는 의도적으로 ended_at=NULL(진행중)로 남긴다.
// 세션마다 user/ai 교차 메시지 2~6개를 함께 생성한다(session_id FK 관계 검증용).
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

const CONSULTATION_TYPES = ["love", "career", "general"] as const;

function randomBetween(min: number, max: number) {
  return Math.random() * (max - min) + min;
}

function sampleUserMessage(type: string): string {
  switch (type) {
    case "love":
      return "요즘 만나는 사람과의 관계가 고민이에요. 앞으로 어떻게 될까요?";
    case "career":
      return "이직을 고민 중인데, 지금이 적절한 시기인지 궁금해요.";
    default:
      return "요즘 마음이 답답한데 어떻게 하면 좋을까요?";
  }
}

function sampleAiMessage(type: string): string {
  switch (type) {
    case "love":
      return "지금 관계에서 느끼시는 불안함은 소통 부족에서 오는 경우가 많아요. 솔직한 대화를 먼저 시도해보시는 건 어떨까요?";
    case "career":
      return "이직은 타이밍보다 준비 상태가 더 중요합니다. 지금 목표로 하는 분야에 필요한 역량을 먼저 점검해보시길 권해드려요.";
    default:
      return "지금 느끼시는 감정은 충분히 자연스러운 반응이에요. 잠시 스스로를 돌아볼 시간을 가져보시는 것도 좋겠습니다.";
  }
}

async function main() {
  const existing = await prisma.consultationSession.count();
  if (existing > 0) {
    console.log(`이미 consultation_sessions ${existing}건이 존재합니다. 시딩을 건너뜁니다.`);
    return;
  }

  const users = await prisma.user.findMany({ where: { deletedAt: null }, select: { id: true }, take: 100 });
  if (users.length === 0) {
    console.log("시딩할 users가 없습니다. 먼저 회원 시딩을 실행하세요.");
    return;
  }

  let sessionCount = 0;
  let messageCount = 0;

  for (const user of users) {
    // 회원당 최근 14일 내 0~2건의 상담 세션 생성(전체 회원이 상담을 이용하지는 않음)
    const sessionsForUser = Math.floor(randomBetween(0, 3));
    for (let i = 0; i < sessionsForUser; i++) {
      const type = CONSULTATION_TYPES[Math.floor(Math.random() * CONSULTATION_TYPES.length)];
      const daysAgo = Math.floor(randomBetween(0, 14));
      const startedAt = new Date();
      startedAt.setDate(startedAt.getDate() - daysAgo);
      startedAt.setHours(Math.floor(randomBetween(0, 24)), Math.floor(randomBetween(0, 60)));

      // 금일(daysAgo=0) 세션 중 12%는 의도적으로 진행중(ended_at=NULL)으로 남김
      // (대시보드 💬 "AI 상담 진행 건수" 위젯 시연용)
      const isOngoing = daysAgo === 0 && Math.random() < 0.12;
      let endedAt: Date | null = null;
      let satisfactionScore: number | null = null;
      if (!isOngoing) {
        endedAt = new Date(startedAt);
        endedAt.setMinutes(endedAt.getMinutes() + Math.floor(randomBetween(5, 30)));
        satisfactionScore = Math.floor(randomBetween(3, 6)); // 3~5
      }

      const session = await prisma.consultationSession.create({
        data: {
          userId: user.id,
          type,
          startedAt,
          endedAt,
          satisfactionScore,
          consentToStore: true,
          createdAt: startedAt,
          updatedAt: endedAt ?? startedAt,
          createdBy: `user:${user.id}`,
          updatedBy: `user:${user.id}`,
        },
      });
      sessionCount++;

      // 세션당 user/ai 교차 메시지 2~6개 생성
      const messagesForSession = Math.floor(randomBetween(2, 7));
      let msgTime = new Date(startedAt);
      for (let m = 0; m < messagesForSession; m++) {
        const sender = m % 2 === 0 ? "user" : "ai";
        const content = sender === "user" ? sampleUserMessage(type) : sampleAiMessage(type);
        msgTime = new Date(msgTime);
        msgTime.setMinutes(msgTime.getMinutes() + 1);

        await prisma.consultationMessage.create({
          data: {
            sessionId: session.id,
            sender,
            content,
            tokenCount: Math.floor(randomBetween(30, 200)),
            createdAt: msgTime,
            updatedAt: msgTime,
            createdBy: sender === "user" ? `user:${user.id}` : "system",
            updatedBy: sender === "user" ? `user:${user.id}` : "system",
          },
        });
        messageCount++;
      }
    }
  }

  console.log(`consultation_sessions ${sessionCount}건, consultation_messages ${messageCount}건 시딩 완료.`);
  console.log("(참고) 금일(daysAgo=0) 세션 중 일부는 의도적으로 ended_at=NULL(진행중)으로 남겨 라이브운영센터 위젯 시연에 사용됨.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
