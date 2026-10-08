import { prisma } from "../src/lib/db";

async function main() {
  const mapCount = await prisma.guinjiMap.count();
  const memberCount = await prisma.guinjiMapMember.count();
  const relCount = await prisma.guinjiRelationship.count();
  console.log("maps:", mapCount);
  console.log("members:", memberCount);
  console.log("relationships:", relCount);

  if (relCount > 0) {
    const sample = await prisma.guinjiRelationship.findMany({ take: 5 });
    console.log(JSON.stringify(sample, null, 2));
    const byType = await prisma.guinjiRelationship.groupBy({
      by: ["relationType"],
      _count: true,
    });
    console.log("by type:", JSON.stringify(byType, null, 2));
  }

  if (mapCount > 0) {
    const sampleMap = await prisma.guinjiMap.findFirst();
    console.log("sample map ownerSajuParsed:", sampleMap?.ownerSajuParsed?.slice(0, 300));
  }
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
