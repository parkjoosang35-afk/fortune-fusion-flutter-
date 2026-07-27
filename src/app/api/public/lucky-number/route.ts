// 공개(비인증) "오늘의 행운숫자" 콘텐츠 조회 API — Flutter 앱 홈 화면에 노출하기 위한 엔드포인트.
//
// [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — 이 API는 banners와
// 완전히 분리된 lucky_number_contents 테이블만 조회하며, 응답에도 광고 관련 필드(linkUrl 등)
// 나 "AD" 표기용 데이터를 포함하지 않는다.
//
// [필터링 조건] GET /api/public/banners와 동일한 패턴(참고 템플릿)을 따르되 position 파라미터는
// 없다(단일 슬롯 전용 콘텐츠이므로):
//   1) deletedAt이 null
//   2) isActive === true
//   3) status === 'active'
//   4) startAt이 없거나, 현재시각 >= startAt
//   5) endAt이 없거나, 현재시각 <= endAt
//   6) 정렬은 sortOrder 오름차순, 첫 번째 항목만 반환(단일 카드 슬롯)
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(_request: NextRequest) {
  const now = new Date();

  const all = await prisma.luckyNumberContent.findMany({
    where: { deletedAt: null },
  });

  const activeOnly = all.filter((c) => c.isActive === true && c.status === "active");

  const withinDateRange = activeOnly.filter((c) => {
    if (c.startAt && now < c.startAt) return false;
    if (c.endAt && now > c.endAt) return false;
    return true;
  });

  const withRequiredFields = withinDateRange.filter((c) => {
    if (!c.title) return false;
    if (c.contentType === "video") return !!c.videoUrl;
    if (c.contentType === "script") return !!c.script;
    return !!c.imageUrl;
  });

  const sorted = [...withRequiredFields].sort((a, b) => a.sortOrder - b.sortOrder);
  const top = sorted[0] ?? null;

  const payload = top
    ? {
        id: top.id,
        title: top.title,
        contentType: top.contentType, // 'image' | 'video' | 'script'
        imageUrl: top.imageUrl,
        videoUrl: top.videoUrl,
        script: top.script,
        caption: top.caption,
      }
    : null;

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
