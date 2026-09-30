import { prisma } from "../src/lib/db";
async function main() {
  const txId = process.argv[2];
  const txn = await prisma.resultAccessTransaction.findUnique({ where: { transactionId: txId } });
  console.log("=== ResultAccessTransaction (환불 확인) ===");
  console.log(JSON.stringify(txn, null, 2));
  const wallet = await prisma.wallet.findFirst({ where: { userId: 123, currencyType: "POINT" } });
  console.log("현재 복주머니 잔액:", wallet?.balance, "(예상: 310 - 환불되었어야 함, POUCH 100 begin 후 실패했으므로 환불되면 310으로 복원)");
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
