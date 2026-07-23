// Phase18-3-2 리워드 관리(출석/미션/업적/랭킹) 목업 데이터 시딩
// 04A D-1~D-8: attendances / attendance_reward_rules / missions / user_missions /
//              achievements / user_achievements / ranking_snapshots / ranking_rewards
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

function randomInt(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// ── 1) attendance_reward_rules: 1일차~30일차 연속출석 보너스 규칙(7일 단위로 보너스 증가) ──
async function seedAttendanceRewardRules() {
  console.log("[seed_domain_d] 1) attendance_reward_rules 시딩...");
  const existing = await prisma.attendanceRewardRule.count();
  if (existing > 0) {
    console.log(`[seed_domain_d]    -> 이미 ${existing}건 존재, skip`);
    return;
  }
  const rules = [
    { streakDay: 1, rewardPoint: 10 },
    { streakDay: 3, rewardPoint: 20 },
    { streakDay: 7, rewardPoint: 50 },
    { streakDay: 14, rewardPoint: 100 },
    { streakDay: 21, rewardPoint: 150 },
    { streakDay: 30, rewardPoint: 300 },
  ];
  for (const r of rules) {
    await prisma.attendanceRewardRule.create({
      data: { ...r, createdBy: "system_seed", updatedBy: "system_seed" },
    });
  }
  console.log(`[seed_domain_d]    -> ${rules.length}건 생성`);
}

// ── 2) attendances: 각 유저별 최근 30일 중 랜덤 출석(70% 확률), streak_count 연쇄 계산 ──
async function seedAttendances() {
  console.log("[seed_domain_d] 2) attendances 시딩(최근 30일)...");
  const existing = await prisma.attendance.count();
  if (existing > 0) {
    console.log(`[seed_domain_d]    -> 이미 ${existing}건 존재, skip`);
    return;
  }
  const rules = await prisma.attendanceRewardRule.findMany({ orderBy: { streakDay: "asc" } });
  const users = await prisma.user.findMany({ select: { id: true } });
  const now = new Date();
  let count = 0;

  for (const u of users) {
    let streak = 0;
    for (let daysAgo = 29; daysAgo >= 0; daysAgo--) {
      const attended = Math.random() < 0.7;
      if (!attended) {
        streak = 0;
        continue;
      }
      streak += 1;
      const attendDate = new Date(now);
      attendDate.setDate(attendDate.getDate() - daysAgo);
      attendDate.setHours(0, 0, 0, 0);

      // 해당 streak 이하의 가장 큰 streakDay 규칙 적용
      const applicable = rules.filter((r) => r.streakDay <= streak).sort((a, b) => b.streakDay - a.streakDay)[0];
      const rewardPoint = applicable?.rewardPoint ?? 10;

      await prisma.attendance.create({
        data: {
          userId: u.id,
          attendDate,
          streakCount: streak,
          rewardPoint,
        },
      });
      count++;
    }
  }
  console.log(`[seed_domain_d]    -> ${count}건 생성`);
}

// ── 3) missions: daily 3개 + weekly 2개 + achievement(1회성) 2개 ──
const MISSIONS = [
  { title: "오늘의 운세 확인하기", actionType: "view_daily_fortune", targetCount: 1, rewardPoint: 10, periodType: "daily" },
  { title: "타로 리딩 1회 이용", actionType: "tarot_reading", targetCount: 1, rewardPoint: 20, periodType: "daily" },
  { title: "커뮤니티 글 작성", actionType: "community_post", targetCount: 1, rewardPoint: 15, periodType: "daily" },
  { title: "주간 사주풀이 3회 이용", actionType: "saju_reading", targetCount: 3, rewardPoint: 100, periodType: "weekly" },
  { title: "친구 5명 초대", actionType: "invite_friend", targetCount: 5, rewardPoint: 200, periodType: "weekly" },
  { title: "첫 프로필 설정 완료", actionType: "complete_profile", targetCount: 1, rewardPoint: 50, periodType: "achievement" },
  { title: "AI 상담 첫 이용", actionType: "consultation_first_use", targetCount: 1, rewardPoint: 30, periodType: "achievement" },
];

async function seedMissions() {
  console.log("[seed_domain_d] 3) missions 시딩...");
  let count = 0;
  for (const m of MISSIONS) {
    const existing = await prisma.mission.findFirst({ where: { title: m.title } });
    if (existing) continue;
    await prisma.mission.create({
      data: { ...m, isActive: true, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    count++;
  }
  console.log(`[seed_domain_d]    -> ${count}건 생성 (기존 ${MISSIONS.length - count}건 skip)`);
}

// ── 4) user_missions: 각 유저별로 활성 미션 중 랜덤하게 진행현황 생성 ──
async function seedUserMissions() {
  console.log("[seed_domain_d] 4) user_missions 시딩...");
  const existing = await prisma.userMission.count();
  if (existing > 0) {
    console.log(`[seed_domain_d]    -> 이미 ${existing}건 존재, skip`);
    return;
  }
  const users = await prisma.user.findMany({ select: { id: true } });
  const missions = await prisma.mission.findMany({ where: { isActive: true } });
  let count = 0;

  for (const u of users) {
    for (const m of missions) {
      if (Math.random() < 0.3) continue; // 일부 미션은 아직 시작 안 함(레코드 없음)
      const progress = randomInt(0, m.targetCount);
      const status = progress >= m.targetCount ? (Math.random() < 0.6 ? "claimed" : "completed") : "in_progress";
      await prisma.userMission.create({
        data: {
          userId: u.id,
          missionId: m.id,
          progressCount: progress,
          status,
          claimedAt: status === "claimed" ? new Date() : null,
        },
      });
      count++;
    }
  }
  console.log(`[seed_domain_d]    -> ${count}건 생성`);
}

// ── 5) achievements: 마스터 데이터 6개 ──
const ACHIEVEMENTS = [
  { code: "first_login", title: "첫 발걸음", conditionType: "login_count", conditionValue: '{"count":1}', rewardPoint: 20 },
  { code: "attendance_7", title: "일주일 개근", conditionType: "streak_count", conditionValue: '{"streak":7}', rewardPoint: 50 },
  { code: "attendance_30", title: "한달 개근왕", conditionType: "streak_count", conditionValue: '{"streak":30}', rewardPoint: 300 },
  { code: "saju_master", title: "사주 마스터", conditionType: "feature_use_count", conditionValue: '{"feature":"saju","count":10}', rewardPoint: 100 },
  { code: "tarot_lover", title: "타로 애호가", conditionType: "feature_use_count", conditionValue: '{"feature":"tarot","count":10}', rewardPoint: 100 },
  { code: "community_star", title: "커뮤니티 스타", conditionType: "post_like_total", conditionValue: '{"likes":100}', rewardPoint: 150 },
];

async function seedAchievements() {
  console.log("[seed_domain_d] 5) achievements 시딩...");
  let count = 0;
  for (const a of ACHIEVEMENTS) {
    const existing = await prisma.achievement.findUnique({ where: { code: a.code } });
    if (existing) continue;
    await prisma.achievement.create({
      data: { ...a, createdBy: "system_seed", updatedBy: "system_seed" },
    });
    count++;
  }
  console.log(`[seed_domain_d]    -> ${count}건 생성 (기존 ${ACHIEVEMENTS.length - count}건 skip)`);
}

// ── 6) user_achievements: 각 유저별 랜덤하게 일부 업적 달성 ──
async function seedUserAchievements() {
  console.log("[seed_domain_d] 6) user_achievements 시딩...");
  const existing = await prisma.userAchievement.count();
  if (existing > 0) {
    console.log(`[seed_domain_d]    -> 이미 ${existing}건 존재, skip`);
    return;
  }
  const users = await prisma.user.findMany({ select: { id: true } });
  const achievements = await prisma.achievement.findMany();
  let count = 0;

  for (const u of users) {
    for (const a of achievements) {
      if (Math.random() < 0.55) continue; // 절반 이상은 미달성
      const achievedAt = new Date();
      achievedAt.setDate(achievedAt.getDate() - randomInt(0, 60));
      await prisma.userAchievement.create({
        data: { userId: u.id, achievementId: a.id, achievedAt },
      });
      count++;
    }
  }
  console.log(`[seed_domain_d]    -> ${count}건 생성`);
}

// ── 7) ranking_snapshots: 최근 2개 주간시즌(point 랭킹) 스냅샷 ──
async function seedRankingSnapshots() {
  console.log("[seed_domain_d] 7) ranking_snapshots 시딩...");
  const existing = await prisma.rankingSnapshot.count();
  if (existing > 0) {
    console.log(`[seed_domain_d]    -> 이미 ${existing}건 존재, skip`);
    return;
  }
  const users = await prisma.user.findMany({ select: { id: true } });

  function isoWeek(date: Date): string {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    const weekNo = Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
    return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
  }

  const now = new Date();
  const thisWeekAgo = new Date(now);
  thisWeekAgo.setDate(thisWeekAgo.getDate() - 7);
  const periods = [isoWeek(thisWeekAgo), isoWeek(now)];

  let count = 0;
  for (const period of periods) {
    // 랜덤 점수 부여 후 랭킹 산출
    const scored = users.map((u) => ({ userId: u.id, score: randomInt(50, 3000) }));
    scored.sort((a, b) => b.score - a.score);
    for (let i = 0; i < scored.length; i++) {
      await prisma.rankingSnapshot.create({
        data: {
          rankingType: "point",
          period,
          userId: scored[i].userId,
          rank: i + 1,
          score: scored[i].score,
        },
      });
      count++;
    }
  }
  console.log(`[seed_domain_d]    -> ${count}건 생성 (기간: ${periods.join(", ")})`);
}

// ── 8) ranking_rewards: point 랭킹 구간별 보상 ──
async function seedRankingRewards() {
  console.log("[seed_domain_d] 8) ranking_rewards 시딩...");
  const existing = await prisma.rankingReward.count();
  if (existing > 0) {
    console.log(`[seed_domain_d]    -> 이미 ${existing}건 존재, skip`);
    return;
  }
  const rewards = [
    { rankingType: "point", rankRangeMin: 1, rankRangeMax: 1, rewardPoint: 5000 },
    { rankingType: "point", rankRangeMin: 2, rankRangeMax: 3, rewardPoint: 3000 },
    { rankingType: "point", rankRangeMin: 4, rankRangeMax: 10, rewardPoint: 1000 },
    { rankingType: "point", rankRangeMin: 11, rankRangeMax: 50, rewardPoint: 300 },
  ];
  for (const r of rewards) {
    await prisma.rankingReward.create({
      data: { ...r, createdBy: "system_seed", updatedBy: "system_seed" },
    });
  }
  console.log(`[seed_domain_d]    -> ${rewards.length}건 생성`);
}

async function main() {
  console.log("=== Phase18-3-2 리워드(출석/미션/업적/랭킹) 목업 데이터 시딩 시작 ===");
  await seedAttendanceRewardRules();
  await seedAttendances();
  await seedMissions();
  await seedUserMissions();
  await seedAchievements();
  await seedUserAchievements();
  await seedRankingSnapshots();
  await seedRankingRewards();
  console.log("=== 시딩 완료 ===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
