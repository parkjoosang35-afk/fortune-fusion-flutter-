// [Phase2 검증 스크립트, 1회성] ResultAccessService의 핵심 시나리오를 실제 DB에
// 대해 실행해 확인한다. 테스트 후 생성한 데이터는 스크립트 끝에서 정리(삭제)한다.
import { prisma } from "../src/lib/db";
import {
  beginResultAccess,
  completeResultAccess,
  failAndRefundResultAccess,
  getResultAccessQuote,
  ResultAccessError,
} from "../src/lib/result-access-service";
import { grantOpenPass } from "../src/lib/open-pass-service";
import { earnLuckPouch } from "../src/lib/luck-pouch-engine";
import { randomUUID } from "crypto";

async function main() {
  console.log("=== ResultAccessService 검증 시작 ===");

  // 1) 테스트용 임시 유저 생성(nickname/email 모두 매 실행마다 고유값 — 재실행 시 충돌 방지)
  const suffix = randomUUID().slice(0, 8);
  const testUser = await prisma.user.create({
    data: {
      email: `ras_test_${suffix}@example.com`,
      passwordHash: "test",
      nickname: `ras_test_${suffix}`,
      status: "active",
    },
  });
  const userId = testUser.id;
  console.log("테스트 유저 생성:", userId);

  try {
    // 2) 신규 횟수제 프리패스 정책 확보(쿠팡 정책 id=11 재사용 또는 임시 정책 생성)
    let policy = await prisma.passPolicy.findFirst({ where: { grantCount: { not: null } } });
    if (!policy) throw new Error("횟수제 정책이 없습니다(백필 확인 필요)");
    console.log("사용할 정책:", policy.id, policy.name, "grantCount=", policy.grantCount);

    // 3) 프리패스 2회 지급 (grantOpenPass는 durationMin 기반 expiresAt만 다루므로
    //    신규 횟수제 필드는 여기서 직접 채워서 테스트한다 — Phase3에서 전용 지급
    //    함수로 대체될 예정)
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const userPass = await prisma.userPass.create({
      data: {
        userId,
        policyId: policy.id,
        activatedAt: now,
        expiresAt,
        sourceType: "test_mode",
        status: "active",
        grantedCount: 2,
        remainingCount: 2,
        grantSource: "COUPANG_DAILY",
      },
    });
    console.log("UserPass 생성(횟수제 2회):", userPass.id);

    // 4) 복주머니 100개 이상 적립
    await prisma.$transaction(async (tx) => {
      await earnLuckPouch(tx, { userId, amount: 300, sourceType: "manual", memo: "테스트용 적립" });
    });

    // 5) getResultAccessQuote 확인
    const quote1 = await getResultAccessQuote(userId, "saju", "saju");
    console.log("Quote(초기):", quote1);
    if (quote1.freePassRemaining !== 2) throw new Error("FAIL: freePassRemaining != 2");
    if (quote1.pouchBalance !== 300) throw new Error("FAIL: pouchBalance != 300");

    // 6) FREEPASS로 결과보기 1회 -> remainingCount 2->1
    const tx1 = `test_tx_${randomUUID()}`;
    const begin1 = await beginResultAccess({
      userId,
      transactionId: tx1,
      contentType: "saju",
      categoryKey: "saju",
      paymentMethod: "FREEPASS",
    });
    console.log("beginResultAccess(FREEPASS) 1회차:", begin1);
    if (begin1.freePassRemaining !== 1) throw new Error("FAIL: 1회 소비 후 remaining != 1");

    // 7) 동일 transactionId로 재호출 -> 멱등성 확인(중복 차감 없이 동일 결과)
    const begin1Again = await beginResultAccess({
      userId,
      transactionId: tx1,
      contentType: "saju",
      categoryKey: "saju",
      paymentMethod: "FREEPASS",
    });
    console.log("멱등 재호출:", begin1Again);
    if (!begin1Again.idempotent) throw new Error("FAIL: 멱등 재호출인데 idempotent=false");

    const passAfterIdempotent = await prisma.userPass.findUnique({ where: { id: userPass.id } });
    if (passAfterIdempotent?.remainingCount !== 1) {
      throw new Error(`FAIL: 멱등 재호출로 중복 차감됨 remainingCount=${passAfterIdempotent?.remainingCount}`);
    }
    console.log("OK: 멱등 재호출로 중복 차감 없음 확인");

    // 8) FREEPASS로 결과보기 2회차 -> remainingCount 1->0, 이걸 완료 처리
    const tx2 = `test_tx_${randomUUID()}`;
    const begin2 = await beginResultAccess({
      userId,
      transactionId: tx2,
      contentType: "tarot",
      categoryKey: "tarot",
      paymentMethod: "FREEPASS",
    });
    console.log("beginResultAccess(FREEPASS) 2회차:", begin2);
    if (begin2.freePassRemaining !== 0) throw new Error("FAIL: 2회 소비 후 remaining != 0");
    // completeResultAccess는 fortuneRequestId에 FK 제약이 있으므로 실제 존재하는
    // FortuneRequest 행을 만들어 연결한다(§8.5 실제 흐름과 동일하게 AI 생성 성공 후
    // 생성된 요청 id를 넘긴다는 것을 검증).
    const dummyRequest = await prisma.fortuneRequest.create({
      data: { userId, fortuneType: "tarot", inputPayload: "{}", sourceType: "ai_generated", status: "success" },
    });
    await completeResultAccess(tx2, dummyRequest.id);
    const txn2AfterComplete = await prisma.resultAccessTransaction.findUnique({ where: { transactionId: tx2 } });
    if (txn2AfterComplete?.status !== "success") throw new Error("FAIL: completeResultAccess 후 status != success");
    console.log("OK: completeResultAccess로 거래 success 확정 확인");

    // 9) 이제 0회 -> FREEPASS 재시도 시 NO_FREEPASS_BALANCE 에러 확인
    const tx3 = `test_tx_${randomUUID()}`;
    let gotExpectedError = false;
    try {
      await beginResultAccess({
        userId,
        transactionId: tx3,
        contentType: "saju",
        categoryKey: "saju",
        paymentMethod: "FREEPASS",
      });
    } catch (e) {
      if (e instanceof ResultAccessError && e.code === "NO_FREEPASS_BALANCE") {
        gotExpectedError = true;
      } else {
        throw e;
      }
    }
    if (!gotExpectedError) throw new Error("FAIL: 0회 상태에서 FREEPASS 승인이 되어버림");
    console.log("OK: 프리패스 0회 상태에서 정상적으로 차단됨");

    // 10) POUCH로 결과보기 -> 300 - 100 = 200
    const tx4 = `test_tx_${randomUUID()}`;
    const begin4 = await beginResultAccess({
      userId,
      transactionId: tx4,
      contentType: "daily",
      categoryKey: "daily",
      paymentMethod: "POUCH",
    });
    console.log("beginResultAccess(POUCH):", begin4);
    if (begin4.pouchBalance !== 200) throw new Error(`FAIL: POUCH 차감 후 잔액 != 200 (실제 ${begin4.pouchBalance})`);

    // 11) POUCH 차감 후 "AI 생성 실패" 시나리오 -> failAndRefundResultAccess로 환불
    await failAndRefundResultAccess(tx4);
    const walletAfterRefund = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } });
    console.log("환불 후 지갑 잔액:", walletAfterRefund?.balance);
    if (walletAfterRefund?.balance !== 300) throw new Error(`FAIL: 환불 후 잔액 != 300 (실제 ${walletAfterRefund?.balance})`);

    const txnAfterRefund = await prisma.resultAccessTransaction.findUnique({ where: { transactionId: tx4 } });
    if (txnAfterRefund?.status !== "refunded") throw new Error("FAIL: 거래 상태가 refunded로 바뀌지 않음");
    console.log("OK: POUCH 차감 실패 -> 환불 정상 동작 확인");

    // 12) 동일 거래에 대해 환불을 다시 호출해도 중복 환불되지 않아야 함
    await failAndRefundResultAccess(tx4);
    const walletAfterDoubleRefund = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } });
    if (walletAfterDoubleRefund?.balance !== 300) {
      throw new Error(`FAIL: 중복 환불 발생! 잔액=${walletAfterDoubleRefund?.balance}`);
    }
    console.log("OK: 중복 환불 방지 확인 (transaction_id 기준)");

    // 13) AD 결제수단 -> 차감 없이 pending 트랜잭션만 생성
    // [Phase4 §8.3 갱신] AD는 이제 completed 상태의 ResultAccessAdSession이
    // 반드시 필요하다(test_result_access_ad_session.ts가 그 자체 검증을
    // 전담하므로, 여기서는 "정상 completed 세션이면 여전히 통과한다"는
    // 통합 동작만 재확인한다).
    const adSession = await prisma.resultAccessAdSession.create({
      data: {
        userId,
        sessionId: `test_sess_${randomUUID()}`,
        status: "completed",
        completedAt: new Date(),
      },
    });
    const tx5 = `test_tx_${randomUUID()}`;
    const begin5 = await beginResultAccess({
      userId,
      transactionId: tx5,
      contentType: "saju",
      categoryKey: "saju",
      paymentMethod: "AD",
      adSessionId: adSession.sessionId,
    });
    console.log("beginResultAccess(AD):", begin5);
    if (begin5.amount !== 0) throw new Error("FAIL: AD인데 amount != 0");
    const walletAfterAd = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } });
    if (walletAfterAd?.balance !== 300) throw new Error("FAIL: AD인데 복주머니가 차감됨");
    console.log("OK: AD 결제수단은 프리패스/복주머니 차감 없음 확인");

    // 14) 동시성(잔여 0) - Promise.all로 동시에 여러 FREEPASS 소비 시도(전부 실패해야 함)
    const concurrentResults = await Promise.allSettled(
      Array.from({ length: 5 }).map(() =>
        beginResultAccess({
          userId,
          transactionId: `test_tx_concurrent_${randomUUID()}`,
          contentType: "saju",
          categoryKey: "saju",
          paymentMethod: "FREEPASS",
        })
      )
    );
    const concurrentSuccess = concurrentResults.filter((r) => r.status === "fulfilled").length;
    console.log("동시성 테스트(잔여 0에서 5회 동시 시도) 성공 건수:", concurrentSuccess);
    if (concurrentSuccess !== 0) throw new Error("FAIL: 잔여 0인데 동시요청 중 일부가 성공함");
    console.log("OK: 잔여 0 상태에서 동시요청 전부 정상 차단");

    // 15) [§14.7 핵심 동시성 시나리오] 잔여 "1"회 상태에서 5개 요청이 동시에 경쟁 →
    //     정확히 1건만 성공하고 나머지 4건은 실패해야 한다(초과 차감 절대 금지).
    await prisma.userPass.update({ where: { id: userPass.id }, data: { remainingCount: 1 } });
    const raceResults = await Promise.allSettled(
      Array.from({ length: 5 }).map(() =>
        beginResultAccess({
          userId,
          transactionId: `test_tx_race_${randomUUID()}`,
          contentType: "saju",
          categoryKey: "saju",
          paymentMethod: "FREEPASS",
        })
      )
    );
    const raceSuccess = raceResults.filter((r) => r.status === "fulfilled").length;
    console.log("동시성 테스트(잔여 1에서 5회 동시 경쟁) 성공 건수:", raceSuccess);
    if (raceSuccess !== 1) throw new Error(`FAIL: 잔여 1인데 성공 건수가 1이 아님(실제 ${raceSuccess})`);
    const passAfterRace = await prisma.userPass.findUnique({ where: { id: userPass.id } });
    if (passAfterRace?.remainingCount !== 0) {
      throw new Error(`FAIL: 경쟁 후 remainingCount != 0 (실제 ${passAfterRace?.remainingCount})`);
    }
    console.log("OK: 잔여 1 상태에서 동시 경쟁 → 정확히 1건만 성공, 초과 차감 없음 확인(§14.7)");

    console.log("\n=== 전체 시나리오 통과 ===");
  } finally {
    // 정리: point_histories는 운영 DB에 append-only 트리거(DELETE/UPDATE 금지)가
    // 걸려 있어(재화 무결성 설계) 삭제할 수 없다 — 그 결과 point_histories가
    // 참조하는 wallet/user도 FK로 삭제할 수 없다. 삭제 가능한 것(트랜잭션 원장/
    // 프리패스)만 정리하고, 테스트 유저/지갑/포인트이력은 감사 로그처럼 남겨둔다
    // ("적립/차감 이력은 절대 지우지 않는다" 운영 원칙을 테스트에서도 동일하게 따른다).
    await prisma.resultAccessTransaction.deleteMany({ where: { userId } });
    await prisma.resultAccessAdSession.deleteMany({ where: { userId } });
    await prisma.userPass.deleteMany({ where: { userId } });
    await prisma.fortuneRequest.deleteMany({ where: { userId } });
    console.log("테스트 데이터 정리 완료 (거래/프리패스/사주요청 삭제, 유저", userId, "는 포인트 이력 보존을 위해 유지)");
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("TEST FAILED:", e);
    process.exit(1);
  });
