// [Phase3 검증 스크립트, 1회성] claimCoupangDailyPass()의 §3.2~§3.7 핵심 시나리오를
// 실제 DB에 대해 실행해 확인한다. 테스트 후 생성한 데이터는 스크립트 끝에서 정리(삭제)한다.
import { prisma } from "../src/lib/db";
import { claimCoupangDailyPass, OpenPassServiceError } from "../src/lib/open-pass-service";
import { randomUUID } from "crypto";

const COUPANG_POLICY_ID = 11;

async function main() {
  console.log("=== 쿠팡 프리패스 하루 1회 원자적 지급 검증 시작 ===");

  const suffix = randomUUID().slice(0, 8);
  const testUser = await prisma.user.create({
    data: {
      email: `coupang_test_${suffix}@example.com`,
      passwordHash: "test",
      nickname: `coupang_test_${suffix}`,
      status: "active",
    },
  });
  const userId = testUser.id;
  console.log("테스트 유저 생성:", userId);

  try {
    const policy = await prisma.passPolicy.findUnique({ where: { id: COUPANG_POLICY_ID } });
    if (!policy || policy.grantCount == null) {
      throw new Error("정책 id=11이 횟수제로 백필되어 있지 않습니다(사전조건 실패)");
    }
    console.log("사용할 정책:", policy.id, policy.name, "grantCount=", policy.grantCount);

    // ── 1) 최초 1회 획득 → +grantCount(2) 지급 ──
    const first = await claimCoupangDailyPass({ userId, policyId: COUPANG_POLICY_ID });
    console.log("1차 지급 결과:", { claimed: first.claimed, remainingCount: first.userPass?.remainingCount });
    if (!first.claimed) throw new Error("FAIL: 최초 획득인데 claimed=false");
    if (first.userPass?.remainingCount !== policy.grantCount) {
      throw new Error(`FAIL: 최초 지급 후 remainingCount != ${policy.grantCount} (실제 ${first.userPass?.remainingCount})`);
    }
    if (first.userPass?.grantSource !== "COUPANG_DAILY") {
      throw new Error(`FAIL: grantSource != COUPANG_DAILY (실제 ${first.userPass?.grantSource})`);
    }
    console.log("OK: 최초 획득 시 정확히 grantCount만큼 지급, grantSource=COUPANG_DAILY 확인");

    // ── 2) 같은 날 재시도 → 지급 없이 claimed=false (§3.3 하루 1회 제한) ──
    const second = await claimCoupangDailyPass({ userId, policyId: COUPANG_POLICY_ID });
    console.log("2차(같은 날 재시도) 결과:", second);
    if (second.claimed) throw new Error("FAIL: 같은 날 재획득이 허용됨(어뷰징 방지 실패)");
    if (second.alreadyClaimedDateKey == null) throw new Error("FAIL: alreadyClaimedDateKey가 비어있음");
    console.log("OK: 같은 날 재시도는 지급 없이 차단됨(§3.3)");

    // ── 3) 잔액 총합 확인: 여전히 grantCount만큼만 있어야 함(중복 누적 없음) ──
    const passesAfterSecond = await prisma.userPass.findMany({ where: { userId } });
    const totalRemaining = passesAfterSecond.reduce((sum, p) => sum + (p.remainingCount ?? 0), 0);
    if (totalRemaining !== policy.grantCount) {
      throw new Error(`FAIL: 2차 시도 후 총 잔여가 중복 누적됨(실제 ${totalRemaining})`);
    }
    console.log("OK: 2차 시도가 잔액에 전혀 영향 주지 않음 확인");

    // ── 4) [§3.4 핵심 동시성 시나리오] 같은 유저가 동시에 5개 요청 → 정확히 1건만
    //     claimed=true, 나머지 4건은 claimed=false여야 한다(하루 총 지급량은 항상
    //     정확히 grantCount(2)회). 새로운 유저로 다시 시작해 "0회 상태에서 동시 경쟁"을
    //     검증한다.
    const raceSuffix = randomUUID().slice(0, 8);
    const raceUser = await prisma.user.create({
      data: {
        email: `coupang_race_${raceSuffix}@example.com`,
        passwordHash: "test",
        nickname: `coupang_race_${raceSuffix}`,
        status: "active",
      },
    });
    try {
      const raceResults = await Promise.allSettled(
        Array.from({ length: 5 }).map(() =>
          claimCoupangDailyPass({ userId: raceUser.id, policyId: COUPANG_POLICY_ID })
        )
      );
      const claimedCount = raceResults.filter(
        (r) => r.status === "fulfilled" && r.value.claimed
      ).length;
      const rejectedCount = raceResults.filter((r) => r.status === "rejected").length;
      console.log("동시 경쟁(5회) 결과: claimed=", claimedCount, "rejected(예외)=", rejectedCount);
      if (claimedCount !== 1) {
        throw new Error(`FAIL: 동시 경쟁 중 claimed=true 건수가 1이 아님(실제 ${claimedCount})`);
      }
      const racePasses = await prisma.userPass.findMany({ where: { userId: raceUser.id } });
      const raceTotalGranted = racePasses.reduce((sum, p) => sum + (p.grantedCount ?? 0), 0);
      if (raceTotalGranted !== policy.grantCount) {
        throw new Error(`FAIL: 동시 경쟁 후 총 지급량 != ${policy.grantCount} (실제 ${raceTotalGranted})`);
      }
      const raceClaimLogs = await prisma.coupangPassClaimLog.count({ where: { userId: raceUser.id } });
      if (raceClaimLogs !== 1) {
        throw new Error(`FAIL: 동시 경쟁 후 CoupangPassClaimLog 행이 1개가 아님(실제 ${raceClaimLogs})`);
      }
      console.log("OK: 동시 5요청 경쟁 → 정확히 1건만 지급, 총 지급량 정확히 grantCount(§3.4)");
    } finally {
      await prisma.userPass.deleteMany({ where: { userId: raceUser.id } });
      await prisma.coupangPassClaimLog.deleteMany({ where: { userId: raceUser.id } });
      await prisma.operationLog.deleteMany({ where: { actorId: raceUser.id, actorType: "user" } });
    }

    // ── 5) [§3.7 핵심 분리 원칙] 관리자 지급(ADMIN_GRANT)이 "오늘 쿠팡 이미 획득함"
    //     기록에 영향을 주지 않아야 한다. 예시: 쿠팡+2 → 정통사주-1(잔여1, 이미 위에서
    //     반영됨) → 관리자+5(총잔여? ) 이후에도 "오늘 쿠팡 이미 받음" 판정은 유지되어야
    //     하고, 관리자 지급 자체도 CoupangPassClaimLog를 건드리지 않아야 한다.
    const beforeAdminGrant = await prisma.coupangPassClaimLog.findMany({ where: { userId } });
    if (beforeAdminGrant.length !== 1) {
      throw new Error(`FAIL: 관리자 지급 전 CoupangPassClaimLog 행 개수 != 1 (실제 ${beforeAdminGrant.length})`);
    }
    // 관리자 수동 지급을 흉내낸다(§3.5 grantSource=ADMIN_GRANT) — Phase5에서
    // 실제 관리자 UI/액션이 만들어지면 그 함수를 그대로 재사용해 이 부분을 대체할
    // 것이나, 현재는 UserPass.create 직접 호출로 "관리자 지급" 형태를 시뮬레이션한다.
    const adminGrant = await prisma.userPass.create({
      data: {
        userId,
        policyId: COUPANG_POLICY_ID,
        activatedAt: new Date(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        sourceType: "manual",
        status: "active",
        grantedCount: 5,
        remainingCount: 5,
        grantSource: "ADMIN_GRANT",
        grantReason: "이벤트",
      },
    });
    console.log("관리자 지급(+5) 시뮬레이션 완료:", adminGrant.id);

    const afterAdminGrant = await prisma.coupangPassClaimLog.findMany({ where: { userId } });
    if (afterAdminGrant.length !== 1) {
      throw new Error(
        `FAIL: 관리자 지급이 CoupangPassClaimLog에 영향을 줌(개수 ${afterAdminGrant.length})`
      );
    }
    console.log("OK: 관리자 지급이 CoupangPassClaimLog(쿠팡 일일 획득 기록)에 영향 없음 확인");

    // 관리자 지급 이후에도 "오늘 쿠팡 프리패스 재획득 시도"는 여전히 차단되어야 한다
    // (총 잔여가 늘었다고 해서 오늘 쿠팡 획득 제한이 초기화되면 안 됨, §3.7 핵심 예시).
    const thirdAttempt = await claimCoupangDailyPass({ userId, policyId: COUPANG_POLICY_ID });
    if (thirdAttempt.claimed) {
      throw new Error("FAIL: 관리자 지급 이후에도 쿠팡 재획득이 다시 허용되어버림(§3.7 위반)");
    }
    console.log("OK: 관리자 지급(+5) 이후에도 '오늘 쿠팡 이미 받음' 판정 그대로 유지됨(§3.7)");

    const totalAfterAdmin = (await prisma.userPass.findMany({ where: { userId } })).reduce(
      (sum, p) => sum + (p.remainingCount ?? 0),
      0
    );
    if (totalAfterAdmin !== policy.grantCount + 5) {
      throw new Error(`FAIL: 관리자 지급 후 총 잔여 != ${policy.grantCount + 5} (실제 ${totalAfterAdmin})`);
    }
    console.log(`OK: 총 잔여 = 쿠팡(${policy.grantCount}) + 관리자(5) = ${totalAfterAdmin} 정확히 합산됨`);

    // ── 6) 레거시 시간제 ad 정책(grantCount=null)에 이 함수를 잘못 호출하면
    //     명확한 에러여야 한다. 기존 레거시 ad 정책(id=1)은 이미 소프트삭제되어
    //     있어(사전조건과 무관한 이력) 이 검증만을 위한 임시 정책을 만들어 확인한다.
    const legacyPolicy = await prisma.passPolicy.create({
      data: {
        name: "[테스트 임시] 레거시 시간제 ad 정책",
        passType: "ad",
        durationMin: 60,
        isActive: true,
        grantCount: null,
      },
    });
    let legacyRejected = false;
    try {
      await claimCoupangDailyPass({ userId, policyId: legacyPolicy.id });
    } catch (e) {
      if (e instanceof OpenPassServiceError && e.code === "NOT_COUNT_BASED_POLICY") {
        legacyRejected = true;
      } else {
        throw e;
      }
    } finally {
      await prisma.passPolicy.delete({ where: { id: legacyPolicy.id } });
    }
    if (!legacyRejected) throw new Error("FAIL: 레거시 시간제 정책에 호출해도 에러가 나지 않음");
    console.log("OK: 레거시 시간제 정책(grantCount=null)에는 NOT_COUNT_BASED_POLICY로 명확히 차단됨");

    console.log("\n=== 전체 시나리오 통과 ===");
  } finally {
    await prisma.coupangPassClaimLog.deleteMany({ where: { userId } });
    await prisma.userPass.deleteMany({ where: { userId } });
    await prisma.operationLog.deleteMany({ where: { actorId: userId, actorType: "user" } });
    console.log("테스트 데이터 정리 완료 (프리패스/쿠팡획득기록/운영로그 삭제, 유저", userId, "유지)");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("TEST FAILED:", e);
    process.exit(1);
  });
