import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import OpenPassBindingsPanel from "@/components/OpenPassBindingsPanel";

// [사용자 요청: 열림패스 상품-첨부파일/광고소스 바인딩] §5/§6-4
export const dynamic = "force-dynamic";

export default async function OpenPassBindingsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const [policies, attachments, adSources] = await Promise.all([
    prisma.passPolicy.findMany({
      where: { deletedAt: null },
      orderBy: [{ id: "asc" }],
      select: {
        id: true,
        name: true,
        isActive: true,
        happyMoneyPrice: true,
        heroAttachmentId: true,
        promoAttachmentId: true,
        fallbackAttachmentId: true,
      },
    }),
    prisma.openPassAttachment.findMany({
      where: { deletedAt: null, isActive: true },
      orderBy: { id: "asc" },
      select: { id: true, fileName: true, fileType: true, purpose: true },
    }),
    prisma.openPassAdSource.findMany({
      where: { deletedAt: null },
      orderBy: { priority: "asc" },
      select: { id: true, sourceName: true, sourceType: true, isActive: true },
    }),
  ]);

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">리워드 관리 — 프리패스 상품연결</h1>
        <p className="mt-1 text-sm text-slate-400">
          프리패스 상품 하나에 여러 첨부파일과 여러 광고소스를 N:M으로 연결합니다.
          앱은 usageType/platform별 &quot;대표(isPrimary) 1개&quot;를 우선 사용하며, 이 화면에서 지정한 값이
          그대로 Flutter 앱 노출/광고 요청/보상 흐름에 반영됩니다.
        </p>
      </div>

      <RewardSubNav />

      <OpenPassBindingsPanel policies={policies} attachments={attachments} adSources={adSources} />
    </div>
  );
}
