import { prisma } from "../src/lib/db";

async function main() {
  const members = await prisma.guinjiMapMember.findMany({
    where: { status: "active" },
    include: { relationship: true },
  });
  for (const m of members) {
    console.log(m.id, m.mapId, m.name, m.birthTimeMissing, "hasRel:", !!m.relationship);
    console.log("  sajuParsed:", m.sajuParsed.slice(0, 200));
  }
}
main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
