// 공개(비인증) "운세 전체보기" 데이터 API — Flutter FortuneCategoryRepository 대응.
//
// [운세 카테고리 확장] 전체보기 화면(all_categories_screen.dart / fortune_hub_screen.dart)이
// 하드코딩 나열 대신 관리자 기준(FortuneCategory/FortuneCategoryGroup)으로 렌더링할 수
// 있도록 그룹별로 정렬된 카테고리 목록을 반환한다. currentLiveVersion은
// AiPromptTemplate(도메인=categoryKey, isActive=true)에서 실시간으로 조회해
// "버전 관리 화면에서 배포 전환한 결과"가 전체보기에도 즉시 반영되게 한다.
//
// [주의] 이 API는 신규 부가 데이터일 뿐, 기존 saju/tarot/daily/face/palm/
// compatibility/consultation 개별 요청 API(각 카테고리 결과 생성)는 전혀
// 건드리지 않는다.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    const groups = await prisma.fortuneCategoryGroup.findMany({
      where: { isVisible: true, deletedAt: null },
      orderBy: { displayOrder: "asc" },
      include: {
        categories: {
          where: { isActive: true, isVisible: true, deletedAt: null },
          orderBy: { displayOrder: "asc" },
        },
      },
    });

    // 카테고리키(=fortuneTypeOrDomain) 목록으로 현재 배포중 버전을 한 번에 조회
    const allKeys = groups.flatMap((g) => g.categories.map((c) => c.categoryKey));
    const activeTemplates = allKeys.length
      ? await prisma.aiPromptTemplate.findMany({
          where: { fortuneTypeOrDomain: { in: allKeys }, isActive: true },
          select: { fortuneTypeOrDomain: true, version: true },
        })
      : [];
    const liveVersionMap = new Map(
      activeTemplates.map((t) => [t.fortuneTypeOrDomain, t.version])
    );

    const data = groups
      .filter((g) => g.categories.length > 0)
      .map((g) => ({
        code: g.code,
        label: g.label,
        description: g.description,
        displayOrder: g.displayOrder,
        categories: g.categories.map((c) => ({
          categoryKey: c.categoryKey,
          slug: c.slug,
          title: c.title,
          shortDescription: c.shortDescription,
          icon: c.icon,
          heroImageUrl: c.heroImageUrl,
          isFeatured: c.isFeatured,
          badgeLabel: c.badgeLabel,
          requiresPass: c.requiresPass,
          route: c.route,
          resultLengthHint: c.resultLengthHint,
          currentLiveVersion: liveVersionMap.get(c.categoryKey) ?? null,
          relatedCategoryKeys: c.relatedCategoryKeys
            ? (JSON.parse(c.relatedCategoryKeys) as string[])
            : [],
        })),
      }));

    return NextResponse.json({ success: true, data: { groups: data } }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/fortune/categories] 실패:", e);
    return NextResponse.json(
      { success: false, error: "카테고리 목록을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
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
