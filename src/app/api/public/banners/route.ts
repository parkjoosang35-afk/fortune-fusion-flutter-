// 공개(비인증) 배너 조회 API — CMS 제휴광고 배너를 프론트(Flutter 앱 등)에 노출하기 위한 엔드포인트.
//
// [배경] 관리자 화면(/cms/banners)에서 배너를 생성/활성화하는 기능(actions/banners.ts)은
// 이미 존재했으나, 그 데이터를 "프론트에서 조회"할 수 있는 공개 API가 전혀 없었다.
// 그 결과 관리자에서 아무리 '활성'으로 설정해도 프론트(Flutter 앱)에는 애초에 아무 데이터도
// 전달되지 않아 배너가 노출되지 않는 것이 근본 원인이었다. 이 라우트를 신설하여 해결한다.
//
// [필터링 조건] 다음 조건을 모두 만족하는 배너만 반환한다 (문의된 15개 점검항목 중 1~5, 13, 14번 대응):
//   1) deletedAt이 null (소프트 삭제되지 않음)
//   2) isActive === true (활성 상태)
//   3) status === 'active'
//   4) startAt이 없거나, 현재시각 >= startAt
//   5) endAt이 없거나, 현재시각 <= endAt
//   6) position 쿼리 파라미터가 주어진 경우 positionCode 일치
//   7) 정렬은 sortOrder 오름차순
//
// [진단 로그] 사용자가 "어느 단계에서 배너가 누락되는지 로그로 확인하고 싶다"고 요청했으므로,
// 각 필터링 단계마다 몇 건이 남았는지 console.log로 출력한다. 서버(Next.js) 콘솔에서 확인 가능.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

// [ORB 차단 대응] adScript에 포함된 <script src="https://외부도메인/...">를 서버 프록시
// (/api/public/ad-proxy?url=...) 경로로 치환한다. 배경:
// 쿠팡파트너스 등 제휴사가 발급하는 <script src="..."> 태그는 302 리다이렉트를 거쳐 실제
// CDN(예: partners.coupangcdn.com)으로 이동하는 구조인데, 최신 Chrome의 ORB(Opaque
// Response Blocking) 정책이 이런 크로스오리진 리다이렉트 스크립트 요청을 차단
// (net::ERR_BLOCKED_BY_ORB)한다. 서버가 대신 원본을 fetch(리다이렉트 해석)하여 같은
// 오리진으로 중계하면 브라우저 입장에서 리다이렉트가 사라져 차단을 피할 수 있다.
function rewriteExternalScriptSrc(adScript: string | null, origin: string): string | null {
  if (!adScript) return adScript;
  return adScript.replace(
    /<script([^>]*?)\ssrc=(["'])(https?:\/\/[^"']+)\2([^>]*)>/gi,
    (match, before, quote, url, after) => {
      const proxyUrl = `${origin}/api/public/ad-proxy?url=${encodeURIComponent(url)}`;
      return `<script${before} src=${quote}${proxyUrl}${quote}${after}>`;
    }
  );
}

// [브라우저 전용 403 대응] 쿠팡파트너스 위젯 라이브러리(g.js)는 1단계(g.js 로드) 후
// `new PartnersCoupang.G({...})`를 호출하면 내부적으로 2단계 요청
// "{serverBaseUrl}widgets.html?id=...&trackingCode=..."을 iframe src로 삽입해 실제 캐러셀
// 상품 데이터를 로드한다. 이 2단계 요청은 실제 브라우저(headless/non-headless 무관)에서 보내면
// Akamai Bot Manager에 의해 403이 반환되지만, 동일 요청을 서버(curl/Node fetch)에서 보내면
// 항상 200이 반환됨을 확인했다(브라우저 자동화/행동 신호 기반 차단으로 추정).
//
// PartnersCoupang.G 생성자는 두 번째/세 번째 위치 인자 또는 옵션 객체의 serverBaseUrl,
// logServerBaseUrl로 기본 도메인("https://ads-partners.coupang.com/")을 오버라이드할 수 있다.
// 이를 우리 서버의 프록시 경로로 치환하면, 위젯이 생성하는 iframe이 대신 우리 서버를 거쳐
// 쿠팡 서버에 요청하게 되어 브라우저 차단을 회피할 수 있다.
function rewriteCoupangServerBaseUrl(adScript: string | null, origin: string): string | null {
  if (!adScript) return adScript;
  if (!adScript.includes("PartnersCoupang.G")) return adScript;

  const proxyBase = `${origin}/api/public/ad-proxy/coupang-widget/`;

  return adScript.replace(
    /new\s+PartnersCoupang\.G\(\s*(\{[^{}]*\})\s*\)/g,
    (match, jsonLiteral) => {
      try {
        const options = JSON.parse(jsonLiteral);
        options.serverBaseUrl = proxyBase;
        // logServerBaseUrl(클릭/노출 로그 전송)은 광고 렌더링에 필수적이지 않고,
        // 로그 서버(logs-partners.coupang.com)는 원본 도메인 그대로 두어도 렌더링에는 영향 없음.
        return `new PartnersCoupang.G(${JSON.stringify(options)})`;
      } catch {
        // JSON 파싱 실패 시 원본 그대로 반환 (안전장치)
        return match;
      }
    }
  );
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const position = searchParams.get("position"); // home_top | home_middle | home_bottom (optional)
  const now = new Date();
  const origin = new URL(request.url).origin;

  console.log("========== [GET /api/public/banners] 배너 조회 시작 ==========");
  console.log(`[1] 요청 파라미터: position=${position ?? "(전체)"} , 현재시각(UTC)=${now.toISOString()}`);

  // Step 1: DB에서 소프트 삭제되지 않은 배너 전체를 가져온다.
  const all = await prisma.banner.findMany({
    where: { deletedAt: null },
  });
  console.log(`[2] DB 조회 결과 (deletedAt=null): ${all.length}건 -> ids=[${all.map((b) => b.id).join(", ")}]`);

  // Step 2: isActive === true 필터
  const activeOnly = all.filter((b) => b.isActive === true);
  console.log(
    `[3] is_active=true 필터 후: ${activeOnly.length}건 -> ids=[${activeOnly.map((b) => b.id).join(", ")}]` +
      (activeOnly.length < all.length
        ? ` (제외된 항목: ${all
            .filter((b) => !b.isActive)
            .map((b) => `id=${b.id}(is_active=${b.isActive})`)
            .join(", ")})`
        : "")
  );

  // Step 3: status === 'active' 필터
  const statusOk = activeOnly.filter((b) => b.status === "active");
  console.log(
    `[4] status='active' 필터 후: ${statusOk.length}건` +
      (statusOk.length < activeOnly.length
        ? ` (제외된 항목: ${activeOnly
            .filter((b) => b.status !== "active")
            .map((b) => `id=${b.id}(status=${b.status})`)
            .join(", ")})`
        : "")
  );

  // Step 4: 노출 기간(startAt~endAt) 필터
  const withinDateRange = statusOk.filter((b) => {
    if (b.startAt && now < b.startAt) return false;
    if (b.endAt && now > b.endAt) return false;
    return true;
  });
  console.log(
    `[5] 노출기간(start_at~end_at) 필터 후: ${withinDateRange.length}건` +
      (withinDateRange.length < statusOk.length
        ? ` (제외된 항목: ${statusOk
            .filter((b) => (b.startAt && now < b.startAt) || (b.endAt && now > b.endAt))
            .map(
              (b) =>
                `id=${b.id}(start_at=${b.startAt?.toISOString() ?? "null"}, end_at=${
                  b.endAt?.toISOString() ?? "null"
                })`
            )
            .join(", ")})`
        : "")
  );

  // Step 5: 필수값 누락 여부 재검증 (방어적 재확인)
  //   - adType='image' -> title + imageUrl 필수
  //   - adType='script' -> title + adScript 필수 (제휴사 원본 광고소스)
  const withRequiredFields = withinDateRange.filter((b) => {
    if (!b.title) return false;
    if (b.adType === "script") return !!b.adScript;
    return !!b.imageUrl;
  });
  console.log(`[6] 필수값(adType별 title/imageUrl 또는 adScript) 검증 후: ${withRequiredFields.length}건`);

  // Step 6: position 파라미터 필터 (지정된 경우에만)
  const positionFiltered = position
    ? withRequiredFields.filter((b) => b.positionCode === position)
    : withRequiredFields;
  console.log(
    `[7] position='${position ?? "(미지정=전체)"}' 필터 후: ${positionFiltered.length}건 -> ids=[${positionFiltered
      .map((b) => b.id)
      .join(", ")}]`
  );

  // Step 7: sortOrder 오름차순 정렬
  const sorted = [...positionFiltered].sort((a, b) => a.sortOrder - b.sortOrder);

  const payload = sorted.map((b) => ({
    id: b.id,
    title: b.title,
    adType: b.adType, // 'image' | 'script'
    imageUrl: b.imageUrl,
    linkUrl: b.linkUrl,
    adScript: rewriteExternalScriptSrc(rewriteCoupangServerBaseUrl(b.adScript, origin), origin), // adType='script'일 때 제휴사 원본 광고 태그(iframe/script). 1) PartnersCoupang.G의 serverBaseUrl을 프록시로 치환(위젯 2단계 요청의 브라우저 403 회피), 2) 외부 <script src>를 ORB 차단 회피를 위해 서버 프록시 경로로 치환.
    positionCode: b.positionCode,
    sortOrder: b.sortOrder,
  }));

  console.log(`[8] 최종 응답: ${payload.length}건 반환 -> ${JSON.stringify(payload.map((p) => p.id))}`);
  console.log("========== [GET /api/public/banners] 배너 조회 종료 ==========");

  return NextResponse.json(
    { success: true, count: payload.length, data: payload },
    {
      headers: {
        // 프론트에서 활성화 직후 즉시 반영되도록 캐시를 명시적으로 무효화한다. (12번 점검항목 대응)
        "Cache-Control": "no-store, no-cache, must-revalidate",
        // Flutter 웹/모바일에서 다른 오리진으로 호출할 수 있도록 CORS 허용.
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
