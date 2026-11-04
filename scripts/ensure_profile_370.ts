import { prisma } from "../src/lib/db";
async function main() {
  const existing = await prisma.userProfile.findFirst({ where: { userId: 370 } });
  if (existing) {
    console.log("profile exists:", JSON.stringify(existing));
  } else {
    const p = await prisma.userProfile.create({
      data: {
        userId: 370,
        birthDate: "1995-05-15",
        birthTime: "10:30",
        isLunar: false,
        birthTimeUnknown: false,
      },
    });
    console.log("profile created:", JSON.stringify(p));
  }
}
main().finally(() => prisma.$disconnect());
