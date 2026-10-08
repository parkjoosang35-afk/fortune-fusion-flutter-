// 귀인지도 V2 — 기존 DB에 남아있는 구형 12종 GuinjiRelationship 레코드를
// V2 6종으로 재계산해 백필한다.
//
// [배경] ③단계 조사 결과(scripts/check-guinji-data.ts) 기존 dev DB에는
// relationship이 4건뿐이고 전부 구형 12종(JORYEOK×3, JAGEUKJE×1)이다 —
// 실사용 데이터가 아니라 테스트성 데이터로 판단, 범위가 작아 안전하게
// 재계산 가능.
//
// [절대 준수] Prisma 스키마는 변경하지 않는다(③단계 확정) — 기존
// `relation_type`/`chemistry_score`/`ohaeng_evidence` 컬럼에 V2 6종 값을
// 그대로 UPDATE만 한다.
//
// [입력 데이터] GuinjiMap.ownerSajuParsed(소유자, 한자 GuinjiSajuInput
// JSON) + GuinjiMapMember.sajuParsed(상대, 동일 포맷) + member.name을
// 사용해 기존 라우트와 동일한 judgeGuinjiRelationV2()를 호출한다.
//
// [실행] npx tsx scripts/backfill-guinji-v2.ts [--dry-run]
import { prisma } from "../src/lib/db";
import type { GuinjiSajuInput } from "../src/lib/guinji-relation-judger";
import { judgeGuinjiRelationV2 } from "../src/lib/guinji-v2/judge";

const DRY_RUN = process.argv.includes("--dry-run");

async function main() {
  const relationships = await prisma.guinjiRelationship.findMany({
    include: { map: true, member: true },
  });

  console.log(`대상 relationship 총 ${relationships.length}건 (dry-run=${DRY_RUN})`);

  let ok = 0;
  let skipped = 0;
  let failed = 0;

  for (const rel of relationships) {
    const label = `relationship#${rel.id} (map#${rel.mapId}, member#${rel.memberId}, 기존=${rel.relationType})`;

    if (!rel.map.ownerSajuParsed) {
      console.warn(`  ⚠️  SKIP ${label}: map.ownerSajuParsed 없음`);
      skipped++;
      continue;
    }
    if (!rel.member.sajuParsed) {
      console.warn(`  ⚠️  SKIP ${label}: member.sajuParsed 없음`);
      skipped++;
      continue;
    }

    try {
      const ownerSaju = JSON.parse(rel.map.ownerSajuParsed) as GuinjiSajuInput;
      const memberSaju = JSON.parse(rel.member.sajuParsed) as GuinjiSajuInput;

      const judged = await judgeGuinjiRelationV2(ownerSaju, memberSaju, {
        other: rel.member.name,
      });

      console.log(
        `  ${label} -> V2=${judged.relationType} score=${judged.chemistryScore} ` +
          `reason="${judged.ohaengEvidence.reason.slice(0, 60)}..."`,
      );

      if (!DRY_RUN) {
        await prisma.guinjiRelationship.update({
          where: { id: rel.id },
          data: {
            relationType: judged.relationType,
            chemistryScore: judged.chemistryScore,
            ohaengEvidence: JSON.stringify(judged.ohaengEvidence),
            calculatedAt: new Date(),
          },
        });
      }
      ok++;
    } catch (e) {
      console.error(`  ❌ FAIL ${label}:`, e instanceof Error ? e.message : e);
      failed++;
    }
  }

  console.log(`\n완료: OK=${ok} SKIPPED=${skipped} FAILED=${failed}` + (DRY_RUN ? " (dry-run, 실제 DB 미반영)" : ""));
  if (failed > 0) process.exit(1);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
