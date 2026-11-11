import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";

// [관리자 2.0 전면 재설계 - Task 9d] 1:1 고객문의 목록.
//
// [RBAC] rbac.ts 주석 결정에 따라 "users" 코드 재사용(cs 역할 RW 요건과 일치).
// [설계] Report(폴리모픽) 목록과 달리 Inquiry는 항상 User 1명이 주체이므로
// targetType별 분기 조회가 필요 없다 — user 관계를 include해서 바로 닉네임/
// 이메일을 가져온다. status/category 필터는 쿼리스트링 기반 단순 필터링
// (?status=open 등)으로 구현하고, Firestore/Prisma 복합 인덱스 이슈를 피하기
// 위해 where에는 단일 필드만 쓰고 정렬은 스키마에 이미 선언된
// @@index([status, created_at])를 그대로 활용한다(단일 where + orderBy 조합은
// 별도 composite index 걱정 없이 SQLite에서도 안전).
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

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function InquiriesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "users")) {
    redirect("/dashboard");
  }

  const { status } = await searchParams;
  const validStatus = status && ["open", "in_progress", "closed"].includes(status) ? status : undefined;

  const inquiries = await prisma.inquiry.findMany({
    where: validStatus ? { status: validStatus } : undefined,
    orderBy: { createdAt: "desc" },
    take: 50,
    include: {
      user: { select: { nickname: true, email: true } },
      assignedAdmin: { select: { name: true } },
      _count: { select: { messages: true } },
    },
  });

  const counts = await Promise.all([
    prisma.inquiry.count({ where: { status: "open" } }),
    prisma.inquiry.count({ where: { status: "in_progress" } }),
    prisma.inquiry.count({ where: { status: "closed" } }),
  ]);
  const [openCount, inProgressCount, closedCount] = counts;

  const tabs: { value: string | undefined; label: string; count: number }[] = [
    { value: undefined, label: "전체", count: openCount + inProgressCount + closedCount },
    { value: "open", label: "접수", count: openCount },
    { value: "in_progress", label: "답변중", count: inProgressCount },
    { value: "closed", label: "종료", count: closedCount },
  ];

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">1:1 고객문의</h1>
        <p className="mt-1 text-sm text-slate-500">
          회원이 작성한 문의를 비동기 스레드(회원 질문 ↔ 운영자 답변) 형태로 처리합니다.
          실시간 채팅이 아닌 1차 범위(접수→답변중→종료) 기준입니다.
        </p>
      </div>

      <div className="mb-4 flex gap-2">
        {tabs.map((t) => (
          <Link
            key={t.label}
            href={t.value ? `/member-ops/inquiries?status=${t.value}` : "/member-ops/inquiries"}
            className={`rounded-full border px-3 py-1.5 text-xs font-medium ${
              validStatus === t.value
                ? "border-indigo-400 bg-indigo-100 text-indigo-700"
                : "border-slate-200 bg-white text-slate-600 hover:bg-slate-100"
            }`}
          >
            {t.label} ({t.count})
          </Link>
        ))}
      </div>

      <section>
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-3">제목</th>
                <th className="px-4 py-3">분류</th>
                <th className="px-4 py-3">작성자</th>
                <th className="px-4 py-3">담당자</th>
                <th className="px-4 py-3">대화</th>
                <th className="px-4 py-3">상태</th>
                <th className="px-4 py-3">접수일</th>
              </tr>
            </thead>
            <tbody>
              {inquiries.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center text-slate-500">
                    접수된 문의가 없습니다.
                  </td>
                </tr>
              )}
              {inquiries.map((inq) => {
                const st = STATUS_LABEL[inq.status] ?? { label: inq.status, cls: "bg-white text-slate-500" };
                return (
                  <tr
                    key={inq.id}
                    className="border-b border-slate-200/60 hover:bg-slate-100/40"
                  >
                    <td className="px-4 py-3 text-slate-800">
                      <Link href={`/member-ops/inquiries/${inq.id}`} className="font-medium hover:underline">
                        {inq.title}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-slate-500">
                      {CATEGORY_LABEL[inq.category] ?? inq.category}
                    </td>
                    <td className="px-4 py-3 text-slate-500">
                      {inq.user.nickname}
                      <div className="text-[10px] text-slate-400">{inq.user.email ?? "-"}</div>
                    </td>
                    <td className="px-4 py-3 text-slate-500">
                      {inq.assignedAdmin?.name ?? <span className="text-slate-600">미배정</span>}
                    </td>
                    <td className="px-4 py-3 text-slate-500">{inq._count.messages}건</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2 py-0.5 text-xs ${st.cls}`}>{st.label}</span>
                    </td>
                    <td className="px-4 py-3 text-slate-500">{fmtDate(inq.createdAt)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
