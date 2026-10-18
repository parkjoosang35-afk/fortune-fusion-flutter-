// 복주머니 쿠폰 공유 링크 OG 이미지 — 구버전(리비전 세그먼트 없는) 링크
// 호환용. 이 라우트가 생기기 전에 이미 카카오톡 등으로 퍼진 `/coupon/{token}`
// 링크의 og:image URL이 이 경로를 참조하고 있을 가능성에 대비한다
// (귀인지도 `/api/public/og/guinji/[token]/route.ts`와 동일한 목적).
//
// [동적 vs 정적] 이 구버전 라우트는 revCode가 없어 "그 쿠폰이 발행된
// 시점의 리비전"을 알 수 없다 — 그래서 정적 폴백만 제공한다(귀인지도
// 구버전 라우트도 동일하게 항상 정적 이미지만 반환). 새로 발급되는 모든
// og:image URL은 `coupon/[token]/page.tsx`의 generateMetadata()가 항상
// `[token]/[revCode]/route.ts`(동적) 쪽을 가리키므로, 이 라우트는 과거
// 링크 호환 목적으로만 존재한다.
import { NextResponse } from "next/server";
import { OG_CORS_HEADERS, serveStaticBokjuCouponOgImage, ogCorsOptionsResponse } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    return await serveStaticBokjuCouponOgImage();
  } catch (e) {
    console.error("[og/bokju-coupon/[token]] 정적 이미지 서빙 실패:", e);
    return NextResponse.json(
      { success: false, error: "OG 이미지를 불러오지 못했습니다." },
      { status: 500, headers: OG_CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return ogCorsOptionsResponse();
}
