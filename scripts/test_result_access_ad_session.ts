// [Phase4 검증 스크립트, 1회성] §8.3 광고 결제수단의 서버 재검증(ResultAccessAdSession)을
// 실제 DB에 대해 실행해 확인한다. 테스트 후 생성한 데이터는 스크립트 끝에서 정리한다.
import { prisma } from "../src/lib/db";
import { beginResultAccess, ResultAccessError } from "../src/lib/result-access-service";
import { randomUUID } from "crypto";

async function main() {
  console.log("=== ResultAccessAdSession(§8.3 광고 서버 재검증) 검증 시작 ===");

  const suffix = randomUUID().slice(0, 8);
  const testUser = await prisma.user.create({
    data: {
      email: `ras_ad_test_${suffix}@example.com`,
      passwordHash: "test",
      nickname: `ras_ad_test_${suffix}`,
      status: "active",
    },
  });
  const userId = testUser.id;
  console.log("테스트 유저 생성:", userId);

  try {
    // ── 시나리오 1: adSessionId 없이 AD 결제 시도 → AD_SESSION_REQUIRED ──
    try {
      await beginResultAccess({
        userId,
        transactionId: `tx_${randomUUID()}`,
        contentType: "saju",
        paymentMethod: "AD",
      });
      throw new Error("실패해야 하는데 성공함(시나리오1)");
    } catch (e) {
      if (!(e instanceof ResultAccessError) || e.code !== "AD_SESSION_REQUIRED") throw e;
      console.log("OK: adSessionId 없으면 AD_SESSION_REQUIRED로 거부됨");
    }

    // ── 시나리오 2: 존재하지 않는 세션 → AD_SESSION_NOT_FOUND ──
    try {
      await beginResultAccess({
        userId,
        transactionId: `tx_${randomUUID()}`,
        contentType: "saju",
        paymentMethod: "AD",
        adSessionId: "nonexistent-session-id",
      });
      throw new Error("실패해야 하는데 성공함(시나리오2)");
    } catch (e) {
      if (!(e instanceof ResultAccessError) || e.code !== "AD_SESSION_NOT_FOUND") throw e;
      console.log("OK: 존재하지 않는 세션은 AD_SESSION_NOT_FOUND로 거부됨");
    }

    // ── 시나리오 3: pending(미완료) 세션으로 시도 → AD_SESSION_NOT_COMPLETED ──
    const pendingSession = await prisma.resultAccessAdSession.create({
      data: { userId, sessionId: `sess_${randomUUID()}`, status: "pending" },
    });
    try {
      await beginResultAccess({
        userId,
        transactionId: `tx_${randomUUID()}`,
        contentType: "saju",
        paymentMethod: "AD",
        adSessionId: pendingSession.sessionId,
      });
      throw new Error("실패해야 하는데 성공함(시나리오3)");
    } catch (e) {
      if (!(e instanceof ResultAccessError) || e.code !== "AD_SESSION_NOT_COMPLETED") throw e;
      console.log("OK: 완료되지 않은(pending) 세션은 AD_SESSION_NOT_COMPLETED로 거부됨 — 클라이언트 선언만으로 통과 불가 확인");
    }

    // ── 시나리오 4: completed 세션 → 정상 승인 + 세션이 consumed로 전환 ──
    const completedSession = await prisma.resultAccessAdSession.create({
      data: {
        userId,
        sessionId: `sess_${randomUUID()}`,
        status: "completed",
        completedAt: new Date(),
      },
    });
    const txId4 = `tx_${randomUUID()}`;
    const result4 = await beginResultAccess({
      userId,
      transactionId: txId4,
      contentType: "saju",
      paymentMethod: "AD",
      adSessionId: completedSession.sessionId,
    });
    if (result4.status !== "pending" || result4.paymentMethod !== "AD") {
      throw new Error("시나리오4 결과가 예상과 다름: " + JSON.stringify(result4));
    }
    const consumedCheck = await prisma.resultAccessAdSession.findUnique({
      where: { id: completedSession.id },
    });
    if (consumedCheck?.status !== "consumed") {
      throw new Error("완료된 세션이 consumed로 전환되지 않음");
    }
    console.log("OK: completed 세션으로는 정상 승인되고, 세션이 consumed로 전환됨(재사용 방지)");

    // ── 시나리오 5: 방금 소비(consumed)한 세션을 다른 트랜잭션에서 재사용 시도 → AD_SESSION_NOT_COMPLETED ──
    try {
      await beginResultAccess({
        userId,
        transactionId: `tx_${randomUUID()}`,
        contentType: "tarot",
        paymentMethod: "AD",
        adSessionId: completedSession.sessionId,
      });
      throw new Error("실패해야 하는데 성공함(시나리오5)");
    } catch (e) {
      if (!(e instanceof ResultAccessError) || e.code !== "AD_SESSION_NOT_COMPLETED") throw e;
      console.log("OK: 이미 소비된(consumed) 세션은 재사용 시도 시 거부됨(중복 결과보기 방지)");
    }

    // ── 시나리오 6: 다른 유저의 세션 사용 시도 → AD_SESSION_NOT_FOUND ──
    const otherUser = await prisma.user.create({
      data: {
        email: `ras_ad_other_${suffix}@example.com`,
        passwordHash: "test",
        nickname: `ras_ad_other_${suffix}`,
        status: "active",
      },
    });
    const otherSession = await prisma.resultAccessAdSession.create({
      data: {
        userId: otherUser.id,
        sessionId: `sess_${randomUUID()}`,
        status: "completed",
        completedAt: new Date(),
      },
    });
    try {
      await beginResultAccess({
        userId, // 세션 소유자가 아닌 userId로 시도
        transactionId: `tx_${randomUUID()}`,
        contentType: "saju",
        paymentMethod: "AD",
        adSessionId: otherSession.sessionId,
      });
      throw new Error("실패해야 하는데 성공함(시나리오6)");
    } catch (e) {
      if (!(e instanceof ResultAccessError) || e.code !== "AD_SESSION_NOT_FOUND") throw e;
      console.log("OK: 다른 유저 소유 세션은 AD_SESSION_NOT_FOUND로 거부됨(세션 탈취 방지)");
    }

    // 정리
    await prisma.resultAccessTransaction.deleteMany({ where: { userId: { in: [userId, otherUser.id] } } });
    await prisma.resultAccessAdSession.deleteMany({ where: { userId: { in: [userId, otherUser.id] } } });
    await prisma.user.delete({ where: { id: otherUser.id } });

    console.log("=== 전체 시나리오 통과 ===");
  } finally {
    await prisma.resultAccessTransaction.deleteMany({ where: { userId } });
    await prisma.resultAccessAdSession.deleteMany({ where: { userId } });
    await prisma.user.delete({ where: { id: userId } });
    console.log("테스트 데이터 정리 완료");
  }
}

main()
  .catch((e) => {
    console.error("테스트 실패:", e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
