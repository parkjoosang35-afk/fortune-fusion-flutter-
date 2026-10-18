// 복주머니 쿠폰 공유 링크 OG(Open Graph) 이미지 서빙 API — 신규(리비전
// 캐시버스팅 경로 포함) 링크용.
//
// [설계 승인 — 02r→02s→02t] 귀인지도 `/api/public/og/guinji/[token]/[shareCode]`
// 패턴을 그대로 복제한다(02q §1-1 "renderOgImage() 재사용, 새로 만들지
// 마십시오"). shareCode 자리에 "그 쿠폰이 발행된 시점의 designRevisionId"
// (또는 레거시 쿠폰이면 'legacy')가 들어간다 — 02q §1-4 "캠페인 리비전
// 기반 쿼리로 캐시 키를 바꾼다" 요구를 경로 세그먼트로 구현한 것(카톡이
// 쿼리스트링을 무시하는 사례 대응은 귀인지도와 동일한 이유).
//
// [GET /api/public/og/bokju-coupon/{token}/{revCode}.(없음, 경로만)]
// `coupon/[token]/page.tsx`의 generateMetadata()가 그 쿠폰의
// coupon.designRevisionId(없으면 'legacy')를 revCode로 채워 이 URL을
// 만든다. 디자인이 바뀌어 새 리비전이 생기면 이후 발행되는 쿠폰은 새
// revCode를 받으므로 og:image URL 자체가 달라져 캐시가 자동 무효화된다.
//
// [02t §0-X-7] revCode는 "레이아웃(테마)"만 동결한다. campaign.title/
// guideText는 캠페인이 수정되면 즉시 반영된다(동결 대상이 아님) — 그래서
// 캐시 헤더를 길게 잡지 않는다(아래 max-age=0).
import { NextRequest, NextResponse } from "next/server";
import {
  OG_CORS_HEADERS,
  findBokjuCouponOgContext,
  resolveOgThemeByRevCode,
  buildBokjuCouponOgImage,
  serveStaticBokjuCouponOgImage,
  ogCorsOptionsResponse,
} from "../../_shared";

export const dynamic = "force-dynamic";

/** [귀인지도 선례와 동일] 빌더 timeout 2초 — 동적 생성 지연 시 카드 깨짐 방지. */
const BUILD_TIMEOUT_MS = 2000;

async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`buildBokjuCouponOgImage timeout after ${ms}ms`)), ms);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timer!);
  }
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string; revCode: string }> }
) {
  const { token, revCode } = await params;

  try {
    const ctx = await findBokjuCouponOgContext(token);
    // 쿠폰이 없거나 만료/삭제됐으면 즉시 정적 폴백 — 그릴 캠페인 정보가 없다.
    if (!ctx) {
      return await serveStaticBokjuCouponOgImage();
    }

    const theme = await resolveOgThemeByRevCode(revCode);
    const buffer = await withTimeout(
      buildBokjuCouponOgImage(ctx, theme),
      BUILD_TIMEOUT_MS
    );

    return new NextResponse(buffer as unknown as BodyInit, {
      status: 200,
      headers: {
        ...OG_CORS_HEADERS,
        // [02q §1-1 규칙 "image/jpeg 를 명시"] renderOgImage()는 sharp
        // .jpeg()로 인코딩한다(renderer.ts:320) — image/png로 표기하면 안 된다.
        "Content-Type": "image/jpeg",
        // [02t §0-X-7] 제목/안내문구는 동결 대상이 아니므로 캐시를 길게
        // 잡지 않는다. revCode 자체가 레이아웃 캐시버스팅을 담당한다.
        "Cache-Control": "public, max-age=0, must-revalidate",
      },
    });
  } catch (e) {
    console.error("[og/bokju-coupon/[token]/[revCode]] 동적 생성 실패, 정적 이미지로 폴백:", e);
    try {
      return await serveStaticBokjuCouponOgImage();
    } catch (fallbackError) {
      console.error("[og/bokju-coupon/[token]/[revCode]] 정적 폴백까지 실패:", fallbackError);
      return NextResponse.json(
        { success: false, error: "OG 이미지를 불러오지 못했습니다." },
        { status: 500, headers: OG_CORS_HEADERS }
      );
    }
  }
}

export async function OPTIONS() {
  return ogCorsOptionsResponse();
}
