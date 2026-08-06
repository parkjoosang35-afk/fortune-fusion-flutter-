import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";
import { redirect } from "next/navigation";
import RewardSubNav from "@/components/RewardSubNav";
import OpenPassAttachmentCreateForm from "@/components/OpenPassAttachmentCreateForm";
import OpenPassAttachmentRow from "@/components/OpenPassAttachmentRow";

// [사용자 요청: 열림패스 관리자 첨부파일 관리] §6-2
// happy-money-products/page.tsx와 동일한 Server Component 템플릿을 따른다.
export const dynamic = "force-dynamic";

export default async function OpenPassAttachmentsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "reward")) {
    redirect("/dashboard");
  }

  const roleMatrix = RBAC_MATRIX.reward[session.roleCode as keyof typeof RBAC_MATRIX.reward];
  const canWrite = !!roleMatrix?.write;
  const canDelete = !!roleMatrix?.delete;

  const attachments = await prisma.openPassAttachment.findMany({
    where: { deletedAt: null },
    orderBy: [{ purpose: "asc" }, { displayOrder: "asc" }, { id: "asc" }],
  });

  // 첨부파일별 활성 상품 연결 수 (N:M 바인딩 테이블 기준). §6-2 표시 컬럼 "연결된 열림패스 상품".
  const bindingCounts = await prisma.openPassProductAttachment.groupBy({
    by: ["attachmentId"],
    where: { isActive: true },
    _count: { _all: true },
  });
  const countMap = new Map(bindingCounts.map((b) => [b.attachmentId, b._count._all]));

  const activeCount = attachments.filter((a) => a.isActive).length;
  const typeCount = new Set(attachments.map((a) => a.fileType)).size;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">리워드 관리 — 열림패스 첨부파일</h1>
        <p className="mt-1 text-sm text-slate-500">
          열림패스 상품의 배너/영상/문서/링크 등 운영 소재를 업로드하고 용도(purpose)별로 관리합니다.
          여기서 등록한 첨부파일은 &quot;상품연결&quot; 화면에서 특정 열림패스 상품에 바인딩해야 앱에 노출됩니다.
        </p>
      </div>

      <RewardSubNav />

      <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">전체 첨부파일 수</p>
          <p className="mt-1 text-2xl font-bold text-slate-900">{attachments.length}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">활성 첨부파일 수</p>
          <p className="mt-1 text-2xl font-bold text-emerald-700">{activeCount}</p>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <p className="text-sm text-slate-500">사용 중인 파일 유형 수</p>
          <p className="mt-1 text-2xl font-bold text-amber-700">{typeCount}</p>
        </div>
      </div>

      <OpenPassAttachmentCreateForm canWrite={canWrite} />

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 bg-white text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">파일명</th>
              <th className="px-4 py-3">타입</th>
              <th className="px-4 py-3">용도</th>
              <th className="px-4 py-3">미리보기</th>
              <th className="px-4 py-3">크기</th>
              <th className="px-4 py-3">업로드 일시</th>
              <th className="px-4 py-3">활성 상태</th>
              <th className="px-4 py-3">연결된 상품</th>
              <th className="px-4 py-3">관리</th>
            </tr>
          </thead>
          <tbody>
            {attachments.length === 0 && (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-slate-500">
                  등록된 첨부파일이 없습니다.
                </td>
              </tr>
            )}
            {attachments.map((attachment) => (
              <OpenPassAttachmentRow
                key={attachment.id}
                attachment={attachment}
                linkedProductCount={countMap.get(attachment.id) ?? 0}
                canWrite={canWrite}
                canDelete={canDelete}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
