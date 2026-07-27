// 쿠팡파트너스 위젯 2단계 요청(widgets.html) 전용 프록시.
//
// PartnersCoupang.G({...}) 위젯 라이브러리는 내부적으로
// "{serverBaseUrl}widgets.html?id=...&trackingCode=..." 형태의 URL을 iframe src로 삽입해
// 실제 캐러셀 상품 데이터를 로드한다.
//
// 문제: 이 widgets.html 요청은 브라우저(Chrome, headless 여부 무관)에서 보낼 경우
// Akamai Bot Manager에 의해 403이 반환된다. 동일한 요청을 서버(curl, Node fetch 등)에서
// 보내면 항상 200이 정상 반환됨을 확인했다 — 즉 브라우저의 자동화/행동 신호 기반 차단으로 추정.
//
// 해결: admin_web의 banners API가 adScript에 삽입된 `new PartnersCoupang.G({...})` 호출의
// serverBaseUrl을 이 프록시 경로로 치환한다({origin}/api/public/ad-proxy/coupang-widget/).
// 그러면 라이브러리가 생성하는 iframe src가
// "http://localhost:3000/api/public/ad-proxy/coupang-widget/widgets.html?id=...&trackingCode=..."
// 형태가 되고, 이 라우트가 서버 사이드에서 실제 쿠팡 서버에 요청 후 결과를 그대로 중계한다.
import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

const UPSTREAM_ORIGIN = "https://ads-partners.coupang.com";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params;
  const { search } = new URL(request.url);

  // path는 고정된 UPSTREAM_ORIGIN(쿠팡 파트너스 도메인)에만 합쳐지므로 SSRF 위험 없음.
  const upstreamPath = path.map((seg) => encodeURIComponent(seg)).join("/");
  const targetUrl = `${UPSTREAM_ORIGIN}/${upstreamPath}${search}`;

  try {
    console.log(`[ad-proxy/coupang-widget] 프록시 요청 시작 -> ${targetUrl}`);
    const upstream = await fetch(targetUrl, {
      method: "GET",
      redirect: "follow",
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
      cache: "no-store",
    });

    console.log(
      `[ad-proxy/coupang-widget] 응답 수신 -> status=${upstream.status}, finalUrl=${upstream.url}`
    );

    if (!upstream.ok) {
      return NextResponse.json(
        { success: false, error: `업스트림 응답 오류: ${upstream.status}` },
        { status: 502 }
      );
    }

    const body = await upstream.text();
    const contentType = upstream.headers.get("content-type") || "text/html";

    console.log(
      `[ad-proxy/coupang-widget] 프록시 완료 -> bodyLength=${body.length}, contentType=${contentType}`
    );

    return new NextResponse(body, {
      status: 200,
      headers: {
        "Content-Type": contentType,
        "Cache-Control": "no-store",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    console.error("[ad-proxy/coupang-widget] 프록시 요청 실패:", error);
    return NextResponse.json(
      { success: false, error: "프록시 요청에 실패했습니다." },
      { status: 502 }
    );
  }
}
