import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { redirect, notFound } from "next/navigation";
import InquiryThread from "@/components/InquiryThread";

// [관리자 2.0 전면 재설계 - Task 9d] 1:1 고객문의 상세 — 회원↔운영자 스레드 조회
// + 답변 작성/종료/재오픈(InquiryThread 클라이언트 컴포넌트에 위임).
export const dynamic = "force-dynamic";

const STATUS_LABEL: Record<string, { label: string; cls: string }> = {
  open: { label: "접수", cls: "bg-white text-slate-600" },
  in_progress: { label: "답변중", cls: "bg-amber-100 text-amber-700" },
  closed: { label: "종료", cls: "bg-emerald-100 text-emerald-700" },
};

const CATEGORY_LABEL: Record<string, string> = {
  payment: "결제/복주머니",
  account: "계정",
  content: "콘텐츠 이용",
  bug: "오류 신고",
  etc: "기타",
};

export default async function InquiryDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "users")) {
    redirect("/dashboard");
  }
  const canWrite = canWriteMenu(session.roleCode, "users");

  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isInteger(id) || id <= 0) {
    notFound();
  }

  const inquiry = await prisma.inquiry.findUnique({
    where: { id },
    include: {
      user: { select: { nickname: true, email: true, phone: true } },
      assignedAdmin: { select: { name: true } },
      messages: {
        orderBy: { createdAt: "asc" },
        include: { senderAdmin: { select: { name: true } } },
      },
    },
  });

  if (!inquiry) {
    notFound();
  }

  const st = STATUS_LABEL[inquiry.status] ?? { label: inquiry.status, cls: "bg-white text-slate-500" };

  return (
    <div>
      <div className="mb-4">
        <Link href="/member-ops/inquiries" className="text-xs text-slate-500 hover:underline">
          ← 목록으로
        </Link>
      </div>

      <div className="mb-6 rounded-xl border border-slate-200 bg-white p-4">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-bold text-slate-900">{inquiry.title}</h1>
            <p className="mt-1 text-sm text-slate-500">
              {inquiry.user.nickname} ({inquiry.user.email ?? inquiry.user.phone ?? "-"})
            </p>
          </div>
          <span className={`rounded-full px-2.5 py-1 text-xs ${st.cls}`}>{st.label}</span>
        </div>
        <div className="mt-3 flex gap-4 text-xs text-slate-500">
          <span>분류: {CATEGORY_LABEL[inquiry.category] ?? inquiry.category}</span>
          <span>담당자: {inquiry.assignedAdmin?.name ?? "미배정"}</span>
          <span>접수일: {inquiry.createdAt.toISOString().slice(0, 19).replace("T", " ")}</span>
        </div>
      </div>

      <InquiryThread
        inquiry={{ id: inquiry.id, status: inquiry.status }}
        messages={inquiry.messages.map((m) => ({
          id: m.id,
          senderType: m.senderType,
          senderAdminName: m.senderAdmin?.name ?? null,
          body: m.body,
          createdAt: m.createdAt,
        }))}
        canWrite={canWrite}
      />
    </div>
  );
}
