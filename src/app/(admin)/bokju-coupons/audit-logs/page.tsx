import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import BokjuCouponSubNav from "@/components/BokjuCouponSubNav";

export const dynamic = "force-dynamic";

const ACTION_LABEL: Record<string, string> = {
  ISSUE: "쿠폰 발행",
  STATUS_CHANGE: "상태 변경",
  ALLOCATE: "업체 배정",
  DELIVER: "발송 완료",
  RECALL: "미등록 회수",
  REVOKE: "쿠폰 중지",
  IMAGE_GENERATE_START: "이미지 생성 시작",
  DELETE: "삭제",
  BULK_DELETE: "일괄 삭제",
};

export default async function BokjuAuditLogsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "bokju_coupon")) {
    redirect("/dashboard");
  }

  const logs = await prisma.bokjuCouponAuditLog.findMany({
    orderBy: { createdAt: "desc" },
    take: 200,
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">마케팅 쿠폰 — 감사 로그</h1>
        <p className="mt-1 text-sm text-slate-500">
          쿠폰 발행/상태변경/배정/발송/회수/중지 등 주요 관리 행위를 기록합니다(최근 200건).
        </p>
      </div>

      <BokjuCouponSubNav />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">일시</th>
              <th className="px-4 py-3">행위</th>
              <th className="px-4 py-3">대상</th>
              <th className="px-4 py-3">내용</th>
              <th className="px-4 py-3">실행자</th>
            </tr>
          </thead>
          <tbody>
            {logs.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-slate-500">
                  기록된 감사 로그가 없습니다.
                </td>
              </tr>
            )}
            {logs.map((l) => (
              <tr key={l.id} className="border-b border-slate-100">
                <td className="px-4 py-3 text-xs text-slate-500">{l.createdAt.toLocaleString("ko-KR")}</td>
                <td className="px-4 py-3">
                  <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-700">
                    {ACTION_LABEL[l.actionType] ?? l.actionType}
                  </span>
                </td>
                <td className="px-4 py-3 text-xs text-slate-500">
                  {l.targetType}
                  {l.targetId ? ` #${l.targetId}` : ""}
                </td>
                <td className="px-4 py-3">{l.summary}</td>
                <td className="px-4 py-3 text-xs text-slate-500">{l.actorId ?? "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
