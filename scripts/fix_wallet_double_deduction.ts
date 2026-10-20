import { prisma } from "../src/lib/db";

// [버그 수정] test_coupon_redeem_limit.ts의 내장 정리 로직(91~102행)이
// wallet.updateMany(decrement)까지는 성공했으나 그 다음 pointHistory.deleteMany()가
// point_histories의 append-only DB 트리거에 막혀 예외가 발생, 스크립트가 "실패"로
// 종료되었다. 이를 "정리가 전혀 안 됐다"고 오판하여 별도의 cleanup_test_coupon_data.ts
// (구버전)에서 동일한 PointHistory(id 1282~1285)를 대상으로 wallet decrement를
// 한 번 더 실행 → 실제 운영 유저 1,2,3의 지갑 잔액이 적립액만큼 2중으로 차감됨.
//
// 증거:
//   - user1: 테스트 전 스냅샷 106387, 1차 차감 후(정상) 106387, 2차 차감(버그) 후 106367 (−20 추가 차감)
//   - user2: 테스트 전 스냅샷 651,   1차 차감 후(정상) 651,   2차 차감(버그) 후 641   (−10 추가 차감)
//   - user3: 테스트 전 스냅샷 240,   1차 차감 후(정상) 240,   2차 차감(버그) 후 230   (−10 추가 차감)
//
// PointHistory(1282~1285)는 append-only 트리거로 삭제 불가하므로 "실제 발생한 적립
// 기록"으로 영구 보존하고, Wallet.balance만 중복 차감분을 되돌려 테스트 전 스냅샷과
// 정확히 일치시킨다. (주의: 기존에 존재하던 drift(user1 -5, user2 +6)는 이번 버그와
// 무관하므로 건드리지 않고 그대로 둔다 - 작업 범위 외 임의 조정 금지 원칙)

const RESTORE = [
  { userId: 1, amount: 20 }, // 106367 -> 106387
  { userId: 2, amount: 10 }, // 641 -> 651
  { userId: 3, amount: 10 }, // 230 -> 240
];

async function main() {
  console.log("=== [복구 전] 현재 지갑 잔액 ===");
  const before = await prisma.wallet.findMany({
    where: { userId: { in: [1, 2, 3] }, currencyType: "POINT" },
  });
  console.log(before.map((w) => ({ userId: w.userId, balance: w.balance })));

  for (const r of RESTORE) {
    await prisma.wallet.updateMany({
      where: { userId: r.userId, currencyType: "POINT" },
      data: { balance: { increment: r.amount } },
    });
  }

  console.log("\n=== [복구 후] 지갑 잔액 (기대값: 1=106387, 2=651, 3=240) ===");
  const after = await prisma.wallet.findMany({
    where: { userId: { in: [1, 2, 3] }, currencyType: "POINT" },
  });
  console.log(after.map((w) => ({ userId: w.userId, balance: w.balance })));

  const expect: Record<number, number> = { 1: 106387, 2: 651, 3: 240 };
  for (const w of after) {
    if (w.balance !== expect[w.userId]) {
      throw new Error(`FAIL: user${w.userId} 복구 후 잔액(${w.balance})이 기대값(${expect[w.userId]})과 다름`);
    }
  }
  console.log("\n✅ 3명 모두 테스트 전 스냅샷과 정확히 일치 - 중복 차감 복구 완료");
}

main()
  .then(() => { console.log("복구 성공"); process.exit(0); })
  .catch((e) => { console.error("복구 실패:", e); process.exit(1); });
