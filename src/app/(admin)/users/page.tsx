import Link from "next/link";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import type { Prisma } from "@/generated/prisma/client";

// 05_Admin_System_Design.md §3.1 "회원 목록"
// 검색(닉네임/이메일/전화), 필터(상태/가입경로/가입일), 페이징
export const dynamic = "force-dynamic";

const STATUS_LABEL: Record<string, string> = {
  active: "정상",
  suspended: "정지",
  withdrawn: "탈퇴",
};

const STATUS_BADGE_CLASS: Record<string, string> = {
  active: "bg-emerald-950/60 text-emerald-400",
  suspended: "bg-amber-950/60 text-amber-400",
  withdrawn: "bg-slate-800 text-slate-400",
};

const PAGE_SIZE = 10;

interface UsersPageProps {
  searchParams: Promise<{
    q?: string;
    status?: string;
    channel?: string;
    from?: string;
    to?: string;
    page?: string;
  }>;
}

export default async function UsersPage({ searchParams }: UsersPageProps) {
  await verifyAdminSession();
  const params = await searchParams;

  const q = params.q?.trim() ?? "";
  const status = params.status ?? "";
  const channel = params.channel ?? "";
  const from = params.from ?? "";
  const to = params.to ?? "";
  const page = Math.max(1, Number(params.page ?? "1") || 1);

  const where: Prisma.UserWhereInput = {
    deletedAt: null,
    ...(q
      ? {
          OR: [
            { nickname: { contains: q } },
            { email: { contains: q } },
            { phone: { contains: q } },
          ],
        }
      : {}),
    ...(status ? { status } : {}),
    ...(channel ? { signupChannel: channel } : {}),
    ...(from || to
      ? {
          createdAt: {
            ...(from ? { gte: new Date(`${from}T00:00:00.000Z`) } : {}),
            ...(to ? { lte: new Date(`${to}T23:59:59.999Z`) } : {}),
          },
        }
      : {}),
  };

  const [total, users] = await Promise.all([
    prisma.user.count({ where }),
    prisma.user.findMany({
      where,
      include: { grade: true },
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PAGE_SIZE,
      take: PAGE_SIZE,
    }),
  ]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const buildQuery = (overrides: Record<string, string | number>) => {
    const sp = new URLSearchParams();
    if (q) sp.set("q", q);
    if (status) sp.set("status", status);
    if (channel) sp.set("channel", channel);
    if (from) sp.set("from", from);
    if (to) sp.set("to", to);
    sp.set("page", String(page));
    for (const [k, v] of Object.entries(overrides)) {
      sp.set(k, String(v));
    }
    return `/users?${sp.toString()}`;
  };

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">회원 관리</h1>
          <p className="mt-1 text-sm text-slate-400">
            총 {total.toLocaleString()}명의 회원이 조회되었습니다.
          </p>
        </div>
      </div>

      {/* 검색/필터 폼 — 05§3.1: 검색(닉네임/이메일/전화), 필터(상태/가입경로/가입일) */}
      <form
        method="GET"
        className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-6"
      >
        <input
          type="text"
          name="q"
          defaultValue={q}
          placeholder="닉네임 / 이메일 / 전화번호 검색"
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
        />
        <select
          name="status"
          defaultValue={status}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          <option value="">전체 상태</option>
          <option value="active">정상</option>
          <option value="suspended">정지</option>
          <option value="withdrawn">탈퇴</option>
        </select>
        <select
          name="channel"
          defaultValue={channel}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          <option value="">전체 가입경로</option>
          <option value="app">앱</option>
          <option value="kakao">카카오</option>
          <option value="google">구글</option>
          <option value="apple">애플</option>
        </select>
        <input
          type="date"
          name="from"
          defaultValue={from}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
        <input
          type="date"
          name="to"
          defaultValue={to}
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
        <div className="flex gap-2 md:col-span-6">
          <button
            type="submit"
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500"
          >
            검색
          </button>
          <Link
            href="/users"
            className="rounded-lg border border-slate-700 px-4 py-2 text-sm text-slate-300 transition hover:bg-slate-800"
          >
            초기화
          </Link>
        </div>
      </form>

      {/* 회원 목록 테이블 */}
      <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-900">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-3">ID</th>
              <th className="px-4 py-3">닉네임</th>
              <th className="px-4 py-3">이메일 / 전화</th>
              <th className="px-4 py-3">등급</th>
              <th className="px-4 py-3">가입경로</th>
              <th className="px-4 py-3">상태</th>
              <th className="px-4 py-3">가입일</th>
              <th className="px-4 py-3">최근 로그인</th>
            </tr>
          </thead>
          <tbody>
            {users.length === 0 && (
              <tr>
                <td colSpan={8} className="px-4 py-10 text-center text-slate-500">
                  조건에 맞는 회원이 없습니다.
                </td>
              </tr>
            )}
            {users.map((u) => (
              <tr
                key={u.id}
                className="border-b border-slate-800/60 hover:bg-slate-800/40"
              >
                <td className="px-4 py-3 text-slate-400">{u.id}</td>
                <td className="px-4 py-3">
                  <Link
                    href={`/users/${u.id}`}
                    className="font-medium text-white hover:text-indigo-400"
                  >
                    {u.nickname}
                  </Link>
                </td>
                <td className="px-4 py-3 text-slate-400">
                  {u.email ?? "-"}
                  {u.phone ? ` / ${u.phone}` : ""}
                </td>
                <td className="px-4 py-3 text-slate-300">
                  {u.grade?.name ?? "-"}
                </td>
                <td className="px-4 py-3 text-slate-300">{u.signupChannel}</td>
                <td className="px-4 py-3">
                  <span
                    className={`rounded-full px-2 py-1 text-xs font-medium ${STATUS_BADGE_CLASS[u.status] ?? "bg-slate-800 text-slate-400"}`}
                  >
                    {STATUS_LABEL[u.status] ?? u.status}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-400">
                  {u.createdAt.toISOString().slice(0, 10)}
                </td>
                <td className="px-4 py-3 text-slate-400">
                  {u.lastLoginAt
                    ? u.lastLoginAt.toISOString().slice(0, 10)
                    : "-"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* 페이징 */}
      <div className="mt-4 flex items-center justify-center gap-1">
        {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
          <Link
            key={p}
            href={buildQuery({ page: p })}
            className={`rounded-lg px-3 py-1.5 text-sm ${
              p === page
                ? "bg-indigo-600 text-white"
                : "text-slate-400 hover:bg-slate-800"
            }`}
          >
            {p}
          </Link>
        ))}
      </div>
    </div>
  );
}
