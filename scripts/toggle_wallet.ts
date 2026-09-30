import { prisma } from "../src/lib/db";
async function main() {
  const userId = Number(process.argv[2]);
  const action = process.argv[3]; // "delete" or "restore"
  const wallet = await prisma.wallet.findFirst({ where: { userId, currencyType: "POINT" } });
  if (!wallet) { console.log("wallet not found"); return; }
  if (action === "delete") {
    await prisma.wallet.update({ where: { id: wallet.id }, data: { deletedAt: new Date() } });
    console.log("wallet soft-deleted:", wallet.id);
  } else {
    await prisma.wallet.update({ where: { id: wallet.id }, data: { deletedAt: null } });
    console.log("wallet restored:", wallet.id);
  }
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
