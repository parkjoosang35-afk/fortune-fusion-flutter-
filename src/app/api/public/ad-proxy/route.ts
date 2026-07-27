// 제휴사 광고 스크립트 프록시 API — CMS "광고소스형" 배너에 삽입된 원본 <script src="...">
// URL(예: 쿠팡파트너스 https://ads-partners.coupang.com/g.js)을 브라우저가 직접 요청하면,
// 최신 Chrome의 ORB(Opaque Response Blocking) 정책에 의해 크로스오리진 302 리다이렉트를
// 거치는 스크립트 요청이 차단되는 문제(net::ERR_BLOCKED_BY_ORB)가 발생한다.
//
// 이 라우트는 서버가 대신 원본 URL을 fetch(자동 리다이렉트 해석 포함)하여 최종 스크립트
// 본문을 그대로 텍스트로 응답한다. 클라이언트(Flutter Web의 iframe)는 이 프록시 URL을
// 같은 오리진(admin_web 서버) 경로로 요청하게 되므로 리다이렉트가 응답에 노출되지 않고,
// ORB 차단을 피할 수 있다.
//
// 허용 대상: query param `url`에 http(s) 스킴의 URL만 허용. SSRF 방지를 위해 사설 IP/로컬
// 주소는 차단한다.
import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

function isBlockedHost(hostname: string): boolean {
  const lower = hostname.toLowerCase();
  if (
    lower === "localhost" ||
    lower === "127.0.0.1" ||
    lower === "0.0.0.0" ||
    lower === "::1"
  ) {
    return true;
  }
  // 사설 IP 대역(10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) 차단
  const privateIpPattern =
    /^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)/;
  if (privateIpPattern.test(lower)) return true;
  return false;
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const targetUrl = searchParams.get("url");

  if (!targetUrl) {
    return NextResponse.json(
      { success: false, error: "url 파라미터가 필요합니다." },
      { status: 400 }
    );
  }

  let parsed: URL;
  try {
    parsed = new URL(targetUrl);
  } catch {
    return NextResponse.json(
      { success: false, error: "유효하지 않은 URL입니다." },
      { status: 400 }
    );
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return NextResponse.json(
      { success: false, error: "http/https URL만 허용됩니다." },
      { status: 400 }
    );
  }

  if (isBlockedHost(parsed.hostname)) {
    return NextResponse.json(
      { success: false, error: "허용되지 않은 호스트입니다." },
      { status: 400 }
    );
  }

  try {
    console.log(`[ad-proxy] 프록시 요청 시작 -> ${targetUrl}`);
    const upstream = await fetch(parsed.toString(), {
      method: "GET",
      redirect: "follow", // 302 등 리다이렉트를 서버 측에서 모두 해석
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      },
      cache: "no-store",
    });

    console.log(
      `[ad-proxy] 응답 수신 -> status=${upstream.status}, finalUrl=${upstream.url}`
    );

    if (!upstream.ok) {
      return NextResponse.json(
        {
          success: false,
          error: `업스트림 응답 오류: ${upstream.status}`,
        },
        { status: 502 }
      );
    }

    const body = await upstream.text();
    const contentType =
      upstream.headers.get("content-type") || "application/javascript";

    console.log(
      `[ad-proxy] 프록시 완료 -> bodyLength=${body.length}, contentType=${contentType}`
    );

    return new NextResponse(body, {
      status: 200,
      headers: {
        "Content-Type": contentType,
        "Cache-Control": "public, max-age=300", // 5분 캐시 (광고 스크립트는 자주 안 변함)
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    console.error("[ad-proxy] 프록시 요청 실패:", error);
    return NextResponse.json(
      { success: false, error: "프록시 요청에 실패했습니다." },
      { status: 502 }
    );
  }
}
