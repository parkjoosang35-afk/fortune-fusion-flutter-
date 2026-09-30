import { prisma } from "../src/lib/db";

async function main() {
  const txId = process.argv[2];
  const txn = await prisma.resultAccessTransaction.findUnique({ where: { transactionId: txId } });
  console.log("=== ResultAccessTransaction ===");
  console.log(JSON.stringify(txn, null, 2));

  if (txn?.userPassId) {
    const pass = await prisma.userPass.findUnique({ where: { id: txn.userPassId } });
    console.log("=== UserPass ===");
    console.log("remainingCount:", pass?.remainingCount, "grantedCount:", pass?.grantedCount);
  }
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
