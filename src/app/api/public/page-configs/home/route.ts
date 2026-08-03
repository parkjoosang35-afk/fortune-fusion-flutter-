// [메인화면 관리자 편집기] GET /api/public/page-configs/home
// Flutter 앱 런타임 조회 API (스펙 §15 "/app/page-configs/home"에 대응).
// 기존 프로젝트 공개 API 컨벤션(/api/public/fortune/... 등)과 동일하게
// /api/public/page-configs/home 경로로 통일해 Flutter의 adminApiBaseUrl 규칙을 그대로 따른다.
//
// [서버가 하는 일] 발행(published)된 버전의 섹션+첨부+노출조건 원본을 그대로 내려준다.
// hidden/archived 상태 섹션과 첨부/노출조건 evaluation은 서버가 하지 않고 그대로
// 원본 데이터를 전달한다(단, deletedAt만 제외) — 최종 가시성 판단은 Flutter의
// SectionVisibilityEvaluator가 사용자 상태(로그인/열림패스/행복머니 등)를 알고 있는
// 클라이언트에서 수행한다(§17 "앱 동작 원칙"). 서버는 스케줄 시각 판단에 필요한
// scheduleEnabled/startAt/endAt 원본 값만 그대로 넘긴다.
import { prisma } from "@/lib/db";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";
const PAGE_KEY = "home";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    const config = await prisma.pageConfig.findUnique({ where: { pageKey: PAGE_KEY } });
    if (!config?.currentPublishedVersionId) {
      // 발행된 버전이 없으면 success:false로 응답 -> Flutter가 fallback 기본 홈 config 사용.
      return NextResponse.json(
        { success: false, error: "발행된 홈 화면 구성이 없습니다.", data: null },
        { headers: CORS_HEADERS },
      );
    }

    const version = await prisma.pageVersion.findUnique({ where: { id: config.currentPublishedVersionId } });
    const sections = await prisma.pageSection.findMany({
      where: { pageVersionId: config.currentPublishedVersionId, deletedAt: null },
      include: { attachments: { orderBy: { displayOrder: "asc" } }, displayRules: { where: { isActive: true } } },
      orderBy: { sortOrder: "asc" },
    });

    const data = {
      pageKey: PAGE_KEY,
      versionId: version?.id ?? null,
      versionNumber: version?.versionNumber ?? null,
      publishedAt: version?.publishedAt?.toISOString() ?? null,
      sections: sections.map((s) => {
        let platformTargets: string[] | null = null;
        if (s.platformTargets) {
          try {
            platformTargets = JSON.parse(s.platformTargets);
          } catch {
            platformTargets = null;
          }
        }
        return {
          id: s.id,
          sectionKey: s.sectionKey,
          blockType: s.blockType,
          title: s.title,
          subtitle: s.subtitle,
          description: s.description,
          buttonText: s.buttonText,
          buttonLink: s.buttonLink,
          badgeText: s.badgeText,
          emptyStateText: s.emptyStateText,
          stylePreset: s.stylePreset,
          backgroundPreset: s.backgroundPreset,
          alignmentPreset: s.alignmentPreset,
          densityPreset: s.densityPreset,
          isVisible: s.isVisible,
          status: s.status,
          isPinned: s.isPinned,
          isRequired: s.isRequired,
          sortOrder: s.sortOrder,
          platformTargets,
          scheduleEnabled: s.scheduleEnabled,
          startAt: s.startAt ? s.startAt.toISOString() : null,
          endAt: s.endAt ? s.endAt.toISOString() : null,
          linkedAssetType: s.linkedAssetType,
          linkedFeatureScope: s.linkedFeatureScope,
          linkedCampaignId: s.linkedCampaignId,
          linkedProductId: s.linkedProductId,
          attachments: s.attachments.map((a) => ({
            attachmentUrl: a.attachmentUrl,
            usageType: a.usageType,
            isPrimary: a.isPrimary,
            displayOrder: a.displayOrder,
          })),
          displayRules: s.displayRules.map((r) => ({
            ruleType: r.ruleType,
            ruleOperator: r.ruleOperator,
            ruleValue: r.ruleValue,
          })),
        };
      }),
    };

    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/page-configs/home] 실패:", e);
    return NextResponse.json(
      { success: false, error: "홈 화면 구성 조회 중 오류가 발생했습니다.", data: null },
      { status: 500, headers: CORS_HEADERS },
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
