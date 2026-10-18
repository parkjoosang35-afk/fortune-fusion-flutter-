// 복주머니 마케팅 쿠폰 OG(Open Graph) 이미지 — 공용 서빙 헬퍼.
//
// [선례 — 귀인지도 패턴 그대로 복제] 02r→02s 에서 승인된 설계:
// `src/app/api/public/og/guinji/_shared.ts` + `[token]/[shareCode]/route.ts`
// 패턴을 쿠폰에 그대로 적용한다(02q §1-3 "참고 구현 renderOgImage() 재사용,
// 새로 만들지 마십시오" + 02s/02t §0-W-2 함정 가·나·다·라 반영).
//
// [02t §0-X-6 "라" 반영] `public/share-og/*.png` 정적 폴백은 파일별로
// 실제 포맷이 섞여 있다(bokju-coupon.png=JPEG, brand.png/tarot.png=진짜PNG).
// "하드코딩 대신 파일별 판별"을 요구받았으므로, 이미 studio-api.ts 에
// 존재하는 sniffImageMimeType()(매직바이트 검사)을 재사용해 Content-Type을
// 결정한다 — 새 판별 로직을 만들지 않는다(기존 자산 재사용 원칙).
//
// [02s §0-W-2-가] renderOgImage()에 테마를 반드시 전달한다 — 생략하면
// resolveTheme(undefined)가 bok-red 고정 팔레트로 폴백한다(night 팔레트
// 캠페인도 빨간 카드로 렌더되는 버그).
// [02s §0-W-2-나] renderOgImage()는 Buffer만 반환하고 Content-Type 설정
// 책임이 없다 — 라우트가 명시적으로 image/jpeg를 지정해야 한다.
// [02s §0-W-2-다] revCode는 레이아웃만 동결한다(제목/안내문구는 캠페인이
// 바뀌면 함께 바뀐다) — 캐시 TTL을 길게 잡으면 안 된다.
import { NextResponse } from "next/server";
import { readFile } from "fs/promises";
import path from "path";
import { prisma } from "@/lib/db";
import { renderOgImage, type RenderContext } from "@/lib/bokju-coupon-design/renderer";
import { resolveLayoutForCoupon } from "@/lib/bokju-coupon-design/revision";
import { sniffImageMimeType } from "@/lib/bokju-coupon-design/studio-api";

export const OG_CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** [02q §1-5 / 금지④] 정적 폴백 — 파일 자체는 수정하지 않는다(읽기 전용). */
const STATIC_OG_FALLBACK_PATH = path.join(
  process.cwd(),
  "public",
  "share-og",
  "bokju-coupon.png"
);

/**
 * [02t §0-X-6 "라"] 확장자(.png)만 보고 Content-Type을 하드코딩하지
 * 않는다 — 매직바이트로 실제 포맷을 판별한다(sniffImageMimeType 재사용).
 * 판별 실패 시에만 image/jpeg로 폴백(이 파일이 실제로 JPEG임을 이미
 * 확인했으므로 — 02s §0-W-2-라 매직바이트 확인 결과).
 */
export async function serveStaticBokjuCouponOgImage(): Promise<NextResponse> {
  const buf = await readFile(STATIC_OG_FALLBACK_PATH);
  const detected = sniffImageMimeType(new Uint8Array(buf));
  const contentType = detected ?? "image/jpeg";
  return new NextResponse(buf as unknown as BodyInit, {
    status: 200,
    headers: {
      ...OG_CORS_HEADERS,
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=3600, immutable",
    },
  });
}

export interface BokjuCouponOgContext {
  campaignTitle: string;
  grantAmount: number;
  guideText: string | null;
  validFrom: Date;
  validTo: Date;
  /** [02q §1-2] 쿠폰번호·QR·redeemToken은 절대 포함하지 않는다(화이트리스트). */
}

/**
 * [화이트리스트 원칙 — 귀인지도 findGuinjiMapOwnerNickname과 동일한 설계]
 * token으로 조회하는 값은 "OG 카드에 표시할 캠페인 단위 정보"뿐이다.
 * couponNo·redeemToken·QR 관련 값은 이 함수가 절대 반환하지 않는다
 * (02q §1-2 "OG 이미지는 인증 없는 크롤러가 가져간다" 요구 — 쿠폰 단위
 * 자산을 OG 경로로 흘려보내지 않기 위한 원천 차단).
 */
export async function findBokjuCouponOgContext(
  token: string
): Promise<BokjuCouponOgContext | null> {
  try {
    const coupon = await prisma.bokjuCoupon.findUnique({
      where: { redeemToken: token },
      select: {
        campaign: {
          select: {
            title: true,
            grantAmount: true,
            guideText: true,
            validFrom: true,
            validTo: true,
          },
        },
      },
    });
    if (!coupon) return null;
    return {
      campaignTitle: coupon.campaign.title,
      grantAmount: coupon.campaign.grantAmount,
      guideText: coupon.campaign.guideText,
      validFrom: coupon.campaign.validFrom,
      validTo: coupon.campaign.validTo,
    };
  } catch (e) {
    console.error("[og/bokju-coupon] 컨텍스트 조회 실패:", e);
    return null;
  }
}

/**
 * [02s §0-W-2-가] revCode로 지정된 리비전의 theme을 조회한다.
 * - revCode가 'legacy' 또는 숫자로 파싱 불가 → undefined(테마 미지정,
 *   resolveTheme()이 기본 팔레트로 폴백 — 레거시 디자인엔 theme 개념이
 *   없으므로 의도된 동작).
 * - revCode가 유효한 리비전 id → 그 리비전의 layout.theme을 꺼내 반환.
 *   [02d §3-2/§3-3 원칙과 동일] 렌더 시점에 캠페인의 현재 리비전을 보지
 *   않는다 — revCode로 명시된 "그 쿠폰이 발행된 시점" 리비전만 본다.
 */
export async function resolveOgThemeByRevCode(
  revCode: string
): Promise<unknown | undefined> {
  const revId = Number(revCode);
  if (!Number.isInteger(revId)) return undefined; // 'legacy' 등 비-숫자
  try {
    const rev = await prisma.bokjuCouponDesignRevision.findUnique({
      where: { id: revId },
      select: { layout: true },
    });
    if (!rev) return undefined;
    const parsed = JSON.parse(rev.layout) as { theme?: unknown };
    return parsed.theme;
  } catch (e) {
    console.error("[og/bokju-coupon] 리비전 테마 조회 실패:", e);
    return undefined;
  }
}

/**
 * [02q §1-1] renderOgImage()를 재사용해 동적 OG JPEG를 생성한다.
 * [02s §0-W-2-가] theme을 반드시 전달한다.
 */
export async function buildBokjuCouponOgImage(
  ctx: BokjuCouponOgContext,
  theme: unknown
): Promise<Buffer> {
  const renderCtx: RenderContext = {
    campaign: {
      title: ctx.campaignTitle,
      grantAmount: ctx.grantAmount,
      guideText: ctx.guideText,
      validFrom: ctx.validFrom,
      validTo: ctx.validTo,
    },
    // [02q §1-2] coupon 필드는 RenderContext 인터페이스상 필수이지만,
    // renderOgImage()는 ctx.coupon을 전혀 참조하지 않는다(couponNo·
    // redeemToken 미사용 — renderer.ts:281-322 확인됨). 빈 값으로 채워
    // 타입만 만족시키고 OG 이미지에는 노출되지 않는다.
    coupon: { couponNo: "", redeemToken: "" },
  };
  return renderOgImage(renderCtx, { theme });
}

/** revCode로부터 쿠폰 발행 시점 레이아웃의 theme을 가져오는 보조 재-export. */
export { resolveLayoutForCoupon };

export function ogCorsOptionsResponse(): NextResponse {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
