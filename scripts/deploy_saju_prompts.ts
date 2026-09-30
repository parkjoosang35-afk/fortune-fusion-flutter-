// [정통사주 AI 프롬프트 개선 — saju-output-spec.pdf §11 적용순서체크리스트 4번]
// "프롬프트 교체 — admin_web ai_prompt_templates의 정통사주 템플릿을 §7장 본문으로
// 교체. temperature 0.7."
//
// ai_prompt_templates는 "버전 증가, 덮어쓰기 금지"가 원칙(saveNewPromptVersion과
// 동일 패턴 — 09_AI_System_Design.md §4)이므로, 이 스크립트도 각 도메인의 최신
// version+1로 새 row를 만들고, 기존 활성 버전을 비활성화한 뒤 신규 버전을 활성화한다
// (deployPromptVersion과 동일한 트랜잭션 패턴).
//
// 실행: cd admin_web && npx tsx scripts/deploy_saju_prompts.ts
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import { buildSajuSystemPrompt, type SajuPromptDomain } from "../src/lib/saju-prompt-builder";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const DOMAINS: SajuPromptDomain[] = [
  "saju",
  "saju_wealth",
  "saju_career",
  "saju_love",
  "saju_health",
  "saju_monthly",
];

async function main() {
  for (const domain of DOMAINS) {
    const templateBody = buildSajuSystemPrompt(domain);

    const latest = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: domain },
      orderBy: { version: "desc" },
    });
    const newVersion = (latest?.version ?? 0) + 1;

    const created = await prisma.aiPromptTemplate.create({
      data: {
        fortuneTypeOrDomain: domain,
        version: newVersion,
        templateBody,
        isActive: false,
        createdBy: "saju_qa_migration_script",
        updatedBy: "saju_qa_migration_script",
      },
    });

    await prisma.$transaction([
      prisma.aiPromptTemplate.updateMany({
        where: { fortuneTypeOrDomain: domain, isActive: true },
        data: { isActive: false, updatedBy: "saju_qa_migration_script" },
      }),
      prisma.aiPromptTemplate.update({
        where: { id: created.id },
        data: { isActive: true, updatedBy: "saju_qa_migration_script" },
      }),
    ]);

    await prisma.operationLog.create({
      data: {
        actorType: "system",
        actorId: null,
        action: "deploy",
        targetType: "ai_prompt_template",
        targetId: created.id,
        before: JSON.stringify({ activeVersion: latest?.version ?? null }),
        after: JSON.stringify({
          activeVersion: newVersion,
          note: "saju-output-spec.pdf §7 시스템 프롬프트 적용",
        }),
      },
    });

    console.log(`[${domain}] v${newVersion} 배포 완료 (id=${created.id}, ${templateBody.length}자)`);
  }
  console.log("완료: 6개 도메인 모두 신규 버전 배포됨.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
