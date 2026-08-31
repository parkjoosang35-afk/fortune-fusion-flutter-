// 귀인지도 공유 링크 OG(Open Graph) 이미지 서빙 API — 신규(캐시버스팅 경로
// 포함) 링크용. 2단계부터 동적 카드(`buildOgPng`)를 실제로 렌더링한다.
//
// [결정 매모 D1/D2/D6 — 2026-08-31] `GET /api/public/og/guinji/{token}/{shareCode}.png`.
//
// [2단 캐시버스팅] 카톡 등 SNS 크롤러는 "같은 URL"이면 이전에 가져온 OG
// 이미지를 계속 재사용하는 경우가 있고, 쿼리스트링(`?v=`)만 바꿔도 캐시가
// 갱신되지 않는 사례가 보고되어 있다. 이 라우트는 그 대응책의 "경로" 축을
// 담당한다 — `{shareCode}`가 매 공유 액션마다 달라지므로(Flutter
// `buildGuinjiInviteLink()` 참고) 이미지 URL 경로 자체가 항상 새 값이 되어,
// 카톡이 쿼리스트링을 무시하더라도 결국 새로 크롤링하게 된다.
//
// [동적 카드 — D2 조건] 닉네임을 조회해 [buildOgPng]로 카드를 그린다.
// 실패(닉네임 없음/폰트 로드 실패/렌더 에러 등) 시 **반드시** 정적 PNG로
// 폴백한다 — 카톡에 빈 카드가 노출되는 것을 절대 허용하지 않는다(D2 조건 3,
// 함정표 "동적 PNG 생성 실패 시 카드 깨짐" 대응).
//
// [캐시 헤더 — 결정 매모 2-2] 동적 생성이 실제로 들어갔으므로
// `public, max-age=0, must-revalidate`로 낮춘다 — 매 요청마다 최신 닉네임을
// 반영해야 하고(닉네임 변경 가능성), shareCode 자체가 이미 캐시버스팅
// 역할을 하므로 브라우저/CDN 단에서 길게 캐시할 이유가 없다.
import { NextRequest, NextResponse } from "next/server";
import { readFile } from "fs/promises";
import { findGuinjiMapOwnerNickname, OG_IMAGE_PATH, OG_CORS_HEADERS, ogCorsOptionsResponse } from "../../_shared";
import { buildOgPng } from "../../buildOgPng";

export const dynamic = "force-dynamic";

/** [D2 조건 3] 빌더 timeout 2초 — 함정표 "동적 PNG 생성 실패 시 카드 깨짐" 대응. */
const BUILD_TIMEOUT_MS = 2000;

async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`buildOgPng timeout after ${ms}ms`)), ms);
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

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string; shareCode: string }> }
) {
  const { token } = await params;

  try {
    const ownerNickname = await findGuinjiMapOwnerNickname(token);
    // 지도가 없거나 만료됐으면(닉네임 조회 실패) 즉시 정적 폴백 — 굳이
    // buildOgPng를 시도할 이유가 없다(어차피 그릴 닉네임이 없음).
    if (!ownerNickname) {
      return await serveStaticFallback();
    }

    const imageResponse = await withTimeout(
      buildOgPng({ ownerNickname }),
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
    // [D2 조건 3 / 함정표] 동적 생성 실패 시 절대 빈 카드를 내보내지 않고
    // 정적 PNG로 즉시 폴백한다. 에러는 로깅만 하고 사용자(크롤러)에게는
    // 항상 200 + 유효한 이미지를 보장한다.
    console.error("[og/guinji/[token]/[shareCode]] buildOgPng 실패, 정적 이미지로 폴백:", e);
    try {
      return await serveStaticFallback();
    } catch (fallbackError) {
      console.error("[og/guinji/[token]/[shareCode]] 정적 폴백까지 실패:", fallbackError);
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
