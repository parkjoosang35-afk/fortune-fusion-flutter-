// 초기 시딩 스크립트
// - 04A B-2 admin_roles: 4개 역할 마스터 데이터
// - 04A B-3 admin_permissions: 05_Admin_System_Design.md §5.2 매트릭스를 DB에 적재
// - 04A B-1 admin_users: sksks77777 계정을 super_admin으로 시딩 (사용자 승인됨)
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";
import bcrypt from "bcryptjs";
import { ADMIN_MENU_GROUPS, RBAC_MATRIX, type AdminRoleCode } from "../src/lib/rbac";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const ROLES: { code: AdminRoleCode; name: string }[] = [
  { code: "super_admin", name: "최고 관리자" },
  { code: "operator", name: "운영자" },
  { code: "cs", name: "고객지원" },
  { code: "content_manager", name: "콘텐츠 관리자" },
];

async function main() {
  console.log("[seed] 1) admin_roles 시딩...");
  const roleMap = new Map<AdminRoleCode, number>();
  for (const role of ROLES) {
    const created = await prisma.adminRole.upsert({
      where: { code: role.code },
      update: { name: role.name },
      create: { code: role.code, name: role.name, createdBy: "system" },
    });
    roleMap.set(role.code, created.id);
  }
  console.log(`[seed]    -> ${ROLES.length}개 역할 완료`);

  console.log("[seed] 2) admin_permissions 시딩 (05단계 §5.2 매트릭스 반영)...");
  let permCount = 0;
  for (const menu of ADMIN_MENU_GROUPS) {
    const roleMatrix = RBAC_MATRIX[menu.code];
    if (!roleMatrix) continue;
    for (const roleCode of Object.keys(roleMatrix) as AdminRoleCode[]) {
      const perm = roleMatrix[roleCode];
      const roleId = roleMap.get(roleCode)!;
      await prisma.adminPermission.upsert({
        where: { roleId_menuCode: { roleId, menuCode: menu.code } },
        update: {
          canRead: perm.read,
          canWrite: perm.write,
          canDelete: perm.delete,
        },
        create: {
          roleId,
          menuCode: menu.code,
          canRead: perm.read,
          canWrite: perm.write,
          canDelete: perm.delete,
          createdBy: "system",
        },
      });
      permCount++;
    }
  }
  console.log(`[seed]    -> ${permCount}건 권한 레코드 완료`);

  console.log("[seed] 3) sksks77777 관리자 계정 시딩 (super_admin)...");
  const superAdminRoleId = roleMap.get("super_admin")!;
  // 초기 임시 비밀번호 — 최초 로그인 후 반드시 변경 필요(운영 전환 시 필수 조치)
  const passwordHash = await bcrypt.hash("ChangeMe!2024", 10);
  await prisma.adminUser.upsert({
    where: { email: "sksks77777" },
    update: {},
    create: {
      email: "sksks77777",
      passwordHash,
      name: "sksks77777",
      roleId: superAdminRoleId,
      is2faEnabled: false,
      createdBy: "system",
    },
  });
  console.log("[seed]    -> sksks77777 계정 생성 완료 (초기 비밀번호: ChangeMe!2024)");

  console.log("[seed] 완료.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
