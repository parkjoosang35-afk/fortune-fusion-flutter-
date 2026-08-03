import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import TestLabPanel from "@/components/TestLabPanel";

// [열림패스/행복머니/복주머니 통합정책] §6 운영 테스트랩 / §7-3 화면 구성.
// 이 페이지는 Server Component로서 활성 상태의 열림패스 정책 / 행복머니 상품 /
// 복주머니 규칙 목록만 조회해 TestLabPanel(client)에 props로 전달한다.
// 실제 지급/차감/구매/시뮬레이션 로직은 전부 admin-simulation.ts의 Server Action이 담당하며,
// TestLabPanel은 그 함수들을 useTransition으로 직접 호출한다(FormData 불필요).
export const dynamic = "force-dynamic";

export default async function TestLabPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const [policies, products, rules, adSources] = await Promise.all([
    prisma.passPolicy.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ id: "asc" }],
      select: { id: true, name: true, durationMin: true, happyMoneyPrice: true },
    }),
    prisma.happyMoneyProduct.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ displayPriority: "asc" }, { id: "asc" }],
      select: { id: true, name: true, cashPrice: true, happyMoneyAmount: true, bonusAmount: true },
    }),
    prisma.luckPouchRule.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: [{ displayPriority: "asc" }, { id: "asc" }],
      select: { id: true, name: true, ruleType: true, actionType: true, amount: true, cashPrice: true },
    }),
    prisma.openPassAdSource.findMany({
      where: { deletedAt: null },
      orderBy: [{ priority: "asc" }],
      select: { id: true, sourceName: true, sourceType: true, isActive: true },
    }),
  ]);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">운영 테스트랩</h1>
        <p className="mt-1 text-sm text-slate-400">
          실결제·실광고 없이 특정 유저 기준으로 열림패스 / 행복머니 / 복주머니의 지급·차감·구매·사용·만료를
          직접 실행하고 결과를 즉시 확인할 수 있는 시뮬레이션 센터입니다.
        </p>
      </div>

      <RewardSubNav />

      <TestLabPanel policies={policies} products={products} rules={rules} adSources={adSources} />
    </div>
  );
}
