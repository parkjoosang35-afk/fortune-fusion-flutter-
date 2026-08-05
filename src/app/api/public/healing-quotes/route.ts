// 공개(비인증) "힐링 문구" 콘텐츠 목록 조회 API — Flutter 앱 홈 화면에서
// 1분마다 로컬 순환 노출하기 위한 엔드포인트.
//
// [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고 그 자리에 좋은 글귀/힐링 문구/긍정 명언/
// 응원의 한마디 기능을 db에서 불러와 1분마다 자동 변경. 이 API는 lucky-number API와 달리
// "활성 문구 전체 목록"을 배열로 반환한다(단일 슬롯이 아님) — 앱이 받은 리스트를 로컬에서
// 순환시키기 때문.
//
// [필터링 조건]
//   1) deletedAt이 null
//   2) isActive === true
//   3) status === 'active'
//   4) startAt이 없거나, 현재시각 >= startAt
//   5) endAt이 없거나, 현재시각 <= endAt
//   6) content가 비어있지 않음
//   7) 정렬은 sortOrder 오름차순, 목록 전체 반환
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(_request: NextRequest) {
  const now = new Date();

  const all = await prisma.healingQuote.findMany({
    where: { deletedAt: null },
  });

  const activeOnly = all.filter((q) => q.isActive === true && q.status === "active");

  const withinDateRange = activeOnly.filter((q) => {
    if (q.startAt && now < q.startAt) return false;
    if (q.endAt && now > q.endAt) return false;
    return true;
  });

  const withRequiredFields = withinDateRange.filter((q) => !!q.content && q.content.trim().length > 0);

  const sorted = [...withRequiredFields].sort((a, b) => a.sortOrder - b.sortOrder);

  const payload = sorted.map((q) => ({
    id: q.id,
    content: q.content,
    author: q.author,
    category: q.category,
  }));

  return NextResponse.json(
    { success: true, data: payload },
    {
      headers: {
        "Cache-Control": "no-store, no-cache, must-revalidate",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
