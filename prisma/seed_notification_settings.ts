// 05_Admin_System_Design.md §3.9 "알림 관리" — 4차(마지막) 소단위: 발송 설정 현황
// 04A N-3 notification_preferences + N-4 push_tokens 시딩 데이터.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({ url: process.env.DATABASE_URL ?? "file:./prisma/dev.db" });
const prisma = new PrismaClient({ adapter });

// 04A N-3 명시 화이트리스트
const CATEGORIES = ["marketing", "fortune_update", "matching", "community"] as const;
// 04A N-4 명시 화이트리스트
const PLATFORMS = ["android", "ios", "web"] as const;

async function main() {
  const existingPrefs = await prisma.notificationPreference.count();
  const existingTokens = await prisma.pushToken.count();
  if (existingPrefs > 0 && existingTokens > 0) {
    console.log(
      `이미 알림 수신설정 ${existingPrefs}건 / 푸시토큰 ${existingTokens}건이 존재합니다. 시딩을 건너뜁니다.`
    );
    return;
  }

  const users = await prisma.user.findMany({ select: { id: true, status: true } });
  if (users.length === 0) {
    throw new Error("시딩할 User가 없습니다. users 테이블을 먼저 채워주세요.");
  }

  // ── notification_preferences: 회원별 카테고리 4종 전부 생성(UQ(user_id,category)) ──
  // 마케팅 카테고리는 회원마다 동의/비동의를 다르게 섞어 집계 화면에서
  // 카테고리별 비율 차이가 보이도록 구성한다.
  const prefData: { userId: number; category: string; isEnabled: boolean }[] = [];
  users.forEach((u, idx) => {
    CATEGORIES.forEach((category) => {
      let isEnabled = true;
      if (category === "marketing") {
        // 마케팅은 절반 정도만 동의(현실적인 수신동의 분포)
        isEnabled = idx % 2 === 0;
      } else if (category === "community" && idx % 3 === 0) {
        isEnabled = false;
      }
      prefData.push({ userId: u.id, category, isEnabled });
    });
  });
  await prisma.notificationPreference.createMany({ data: prefData });
  console.log(`알림 수신설정(notification_preferences) ${prefData.length}건 시딩 완료.`);

  // ── push_tokens: 회원별 1~2개 플랫폼 토큰(UQ(fcm_token)) ──
  const tokenData: { userId: number; fcmToken: string; platform: string }[] = [];
  users.forEach((u, idx) => {
    const platform = PLATFORMS[idx % PLATFORMS.length];
    tokenData.push({
      userId: u.id,
      fcmToken: `fcm_token_user${u.id}_${platform}_${idx}`,
      platform,
    });
    // 일부 회원은 모바일+웹 중복 로그인으로 토큰 2개(현실적인 멀티 디바이스 시나리오)
    if (idx % 3 === 0) {
      const secondPlatform = PLATFORMS[(idx + 1) % PLATFORMS.length];
      tokenData.push({
        userId: u.id,
        fcmToken: `fcm_token_user${u.id}_${secondPlatform}_${idx}_2`,
        platform: secondPlatform,
      });
    }
  });
  await prisma.pushToken.createMany({ data: tokenData });
  console.log(`푸시 토큰(push_tokens) ${tokenData.length}건 시딩 완료.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
