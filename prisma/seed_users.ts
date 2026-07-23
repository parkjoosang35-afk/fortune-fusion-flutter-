// Phase18-1 회원 관리 목업 데이터 시딩
// 04A A-5 user_grades(4등급) + A-1/A-2 users/user_profiles 10건 + A-4 user_login_logs 일부
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import bcrypt from "bcryptjs";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const GRADES = [
  { code: "bronze", name: "브론즈", minActivityScore: 0, pointEarnMultiplier: 1.0, sortOrder: 1 },
  { code: "silver", name: "실버", minActivityScore: 100, pointEarnMultiplier: 1.1, sortOrder: 2 },
  { code: "gold", name: "골드", minActivityScore: 500, pointEarnMultiplier: 1.3, sortOrder: 3 },
  { code: "vip", name: "VIP", minActivityScore: 2000, pointEarnMultiplier: 1.5, sortOrder: 4 },
];

const USERS = [
  { nickname: "별빛나그네", email: "star_traveler@example.com", gender: "female", grade: "gold", status: "active", mbti: "INFP" },
  { nickname: "행운의사슴", email: "lucky_deer@example.com", gender: "male", grade: "silver", status: "active", mbti: "ESTJ" },
  { nickname: "달빛소녀", email: "moonlight_girl@example.com", gender: "female", grade: "bronze", status: "active", mbti: "INFJ" },
  { nickname: "타로마스터", email: "tarot_master@example.com", gender: "male", grade: "vip", status: "active", mbti: "ENTP" },
  { nickname: "사주연구소", email: "saju_lab@example.com", gender: "unspecified", grade: "gold", status: "active", mbti: "INTJ" },
  { nickname: "구름위산책", email: "cloud_walker@example.com", gender: "female", grade: "bronze", status: "suspended", mbti: "ISFP", withdrawalReason: null },
  { nickname: "행복한하루", email: "happy_day@example.com", gender: "male", grade: "silver", status: "active", mbti: "ESFJ" },
  { nickname: "관상천재", email: "physiognomy_pro@example.com", gender: "female", grade: "bronze", status: "active", mbti: "ISTP" },
  { nickname: "궁합박사", email: "compat_doc@example.com", gender: "male", grade: "gold", status: "active", mbti: "ENFJ" },
  { nickname: "탈퇴한유령", email: "ghost_left@example.com", gender: "unspecified", grade: "bronze", status: "withdrawn", mbti: null, withdrawalReason: "서비스 이용 빈도가 낮아 탈퇴" },
];

async function main() {
  console.log("[seed_users] 1) user_grades 시딩...");
  const gradeMap = new Map<string, number>();
  for (const g of GRADES) {
    const created = await prisma.userGrade.upsert({
      where: { code: g.code },
      update: {
        name: g.name,
        minActivityScore: g.minActivityScore,
        pointEarnMultiplier: g.pointEarnMultiplier,
        sortOrder: g.sortOrder,
      },
      create: { ...g, createdBy: "system" },
    });
    gradeMap.set(g.code, created.id);
  }
  console.log(`[seed_users]    -> ${GRADES.length}개 등급 완료`);

  console.log("[seed_users] 2) users + user_profiles 10건 시딩...");
  const passwordHash = await bcrypt.hash("password123!", 10);
  let count = 0;
  for (const u of USERS) {
    const existing = await prisma.user.findUnique({ where: { email: u.email } });
    if (existing) continue;

    const user = await prisma.user.create({
      data: {
        email: u.email,
        passwordHash,
        nickname: u.nickname,
        gender: u.gender,
        status: u.status,
        withdrawalReason: u.withdrawalReason ?? null,
        signupChannel: "app",
        marketingAgreed: Math.random() > 0.5,
        gradeId: gradeMap.get(u.grade),
        lastLoginAt: u.status === "withdrawn" ? null : new Date(),
        createdBy: "system",
        profile: {
          create: {
            mbti: u.mbti,
            isLunar: false,
            introText: `안녕하세요, ${u.nickname}입니다.`,
            createdBy: "system",
          },
        },
      },
    });

    // 로그인 이력 2~3건씩 생성
    for (let i = 0; i < 3; i++) {
      await prisma.userLoginLog.create({
        data: {
          userId: user.id,
          loginType: i % 2 === 0 ? "email" : "kakao",
          ipAddress: `192.168.1.${10 + i}`,
          successFlag: true,
          createdAt: new Date(Date.now() - i * 86400000),
        },
      });
    }

    // 탈퇴 회원은 탈퇴 이력도 생성
    if (u.status === "withdrawn") {
      await prisma.userWithdrawalLog.create({
        data: {
          userId: user.id,
          reason: u.withdrawalReason,
          dataPurgeScheduledAt: new Date(Date.now() + 30 * 86400000),
        },
      });
    }

    count++;
  }
  console.log(`[seed_users]    -> ${count}건 회원 신규 생성 완료`);
  console.log("[seed_users] 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
