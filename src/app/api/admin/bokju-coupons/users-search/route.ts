// [복주머니 마케팅 쿠폰] GET /api/admin/bokju-coupons/users-search?q=닉네임또는이메일
// 개별 회원 선물(INDIVIDUAL) 발송 대상을 고를 때 쓰는 가벼운 회원 검색.
// 최대 20건만 반환(목록 UI가 아니라 "대상 추가" 자동완성용).
import { jsonError, jsonOk, requireAdminOrResponse, isAdminActor } from "@/lib/page-config-helpers";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { searchParams } = new URL(request.url);
  const q = (searchParams.get("q") ?? "").trim();
  if (q.length < 1) return jsonOk({ users: [] });

  const users = await prisma.user.findMany({
    where: {
      deletedAt: null,
      OR: [{ nickname: { contains: q } }, { email: { contains: q } }],
    },
    select: { id: true, nickname: true, email: true },
    take: 20,
    orderBy: { id: "asc" },
  });

  return jsonOk({ users });
}
