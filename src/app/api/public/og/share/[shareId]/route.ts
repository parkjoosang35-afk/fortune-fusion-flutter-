// 결과 공유 카톡 OG(Open Graph) 이미지 서빙 API.
// `GET /api/public/og/share/{shareId}.png`.
//
// [동적 카드] shareId로 SharedResult(title/resultType)를 조회해
// [buildShareOgPng]로 카드를 그린다. 실패(레코드 없음/폰트 로드 실패/렌더
// 에러 등) 시 **반드시** 정적 PNG로 폴백한다(guinji D2 조건 3과 동일한
// 원칙 — 카톡에 빈 카드가 노출되는 것을 절대 허용하지 않는다).
//
// [캐시] shareId 자체가 매번 새 값(공유마다 새 레코드)이므로 짧게 캐시해도
// 무방하나, 조회수 반영 등 최신성을 위해 guinji [shareCode] 라우트와
// 동일하게 max-age=0으로 낮춘다.
import { NextRequest, NextResponse } from "next/server";
import { readFile } from "fs/promises";
import path from "path";
import { prisma } from "@/lib/db";
import { buildShareOgPng } from "../buildShareOgPng";
import { isValidShareContentType, type ShareContentType } from "@/lib/share-og-config";

export const dynamic = "force-dynamic";

const OG_IMAGE_PATH = path.join(process.cwd(), "public", "guinji", "og-guinji-1200x630.png");
const OG_CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** [함정표] 빌더 timeout 2초 — guinji shareCode 라우트와 동일 원칙. */
const BUILD_TIMEOUT_MS = 2000;

async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`buildShareOgPng timeout after ${ms}ms`)), ms);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timer!);
  }
}

async function serveStaticFallback(): Promise<NextResponse> {
  const imageBuffer = await readFile(OG_IMAGE_PATH);
  return new NextResponse(imageBuffer as unknown as BodyInit, {
    status: 200,
    headers: {
      ...OG_CORS_HEADERS,
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=3600, immutable",
    },
  });
}

// [2027-02 6개 카테고리 통일] 하드코딩 배열 대신 중앙 설정
// (`@/lib/share-og-config`)의 화이트리스트 검증 함수를 그대로 사용한다.
function isKnownResultType(v: string): v is ShareContentType {
  return isValidShareContentType(v);
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ shareId: string }> }
) {
  const { shareId: shareIdParam } = await params;
  const shareId = shareIdParam.endsWith(".png") ? shareIdParam.slice(0, -4) : shareIdParam;

  try {
    const shared = await prisma.sharedResult.findUnique({
      where: { shareId },
      select: { title: true, description: true, resultType: true, deletedAt: true, status: true },
    });

    if (!shared || shared.deletedAt != null || shared.status !== "active" || !isKnownResultType(shared.resultType)) {
      return await serveStaticFallback();
    }

    const imageResponse = await withTimeout(
      buildShareOgPng({
        resultType: shared.resultType,
        title: shared.title,
        tagline: shared.description || undefined,
      }),
      BUILD_TIMEOUT_MS
    );
    const dynamicBuffer = Buffer.from(await imageResponse.arrayBuffer());
    return new NextResponse(dynamicBuffer as unknown as BodyInit, {
      status: 200,
      headers: {
        ...OG_CORS_HEADERS,
        "Content-Type": "image/png",
        "Cache-Control": "public, max-age=0, must-revalidate",
      },
    });
  } catch (e) {
    console.error("[og/share/[shareId]] buildShareOgPng 실패, 정적 이미지로 폴백:", e);
    try {
      return await serveStaticFallback();
    } catch (fallbackError) {
      console.error("[og/share/[shareId]] 정적 폴백까지 실패:", fallbackError);
      return NextResponse.json(
        { success: false, error: "OG 이미지를 불러오지 못했습니다." },
        { status: 500, headers: OG_CORS_HEADERS }
      );
    }
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
