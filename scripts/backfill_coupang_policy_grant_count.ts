import { prisma } from "@/lib/db";

async function main() {
  // §3.1/§3.3: 쿠팡파트너스 프리패스 정책(id=11)을 횟수제로 백필한다.
  //   grantCount=2      : 지급 1회당 결과보기 2건 제공
  //   dailyClaimLimit=1 : 하루 1회만 "획득" 가능(어뷰징 방지)
  //   validityDays=null : 유효기간 없음(기존 durationMin=60은 레거시 시간제 호환용으로 그대로 보존)
  const before = await prisma.passPolicy.findUnique({ where: { id: 11 } });
  if (!before) {
    console.error("Policy id=11 not found. Aborting.");
    process.exit(1);
  }
  console.log("BEFORE:", JSON.stringify({
    id: before.id,
    name: before.name,
    passType: before.passType,
    grantCount: before.grantCount,
    dailyClaimLimit: before.dailyClaimLimit,
    validityDays: before.validityDays,
  }));

  const updated = await prisma.passPolicy.update({
    where: { id: 11 },
    data: {
      grantCount: 2,
      dailyClaimLimit: 1,
      // validityDays는 null 유지(무제한) - 지시서 §3.5 관리자 UI에서 추후 조정 가능
    },
  });

  console.log("AFTER:", JSON.stringify({
    id: updated.id,
    name: updated.name,
    passType: updated.passType,
    grantCount: updated.grantCount,
    dailyClaimLimit: updated.dailyClaimLimit,
    validityDays: updated.validityDays,
  }));
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
