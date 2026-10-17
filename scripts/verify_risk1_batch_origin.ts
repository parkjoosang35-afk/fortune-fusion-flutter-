// scripts/verify_risk1_batch_origin.ts
// [4단계 — 02e_4단계-에디터.md §0-D 위험1(최우선) 검증]
// "배치 경로의 registerBaseUrl 은 어디서 오는가" — 사용자가 요청한 3가지를
// 전부 실측으로 확정한다:
//   1) API 경로(resolvePublicOrigin)와 배치 경로(runImageJob)가 **같은 origin**을 쓰는가
//   2) 배치 경로에 localhost/http:// 가 새어들지 않는가
//   3) env 폴백(FALLBACK_BASE_URL)이 실제로 트리거되지 않는가(=항상 명시적으로 전달됨)
//
// [검증 방법 — "값이 전달됐다"를 어떻게 거짓말 없이 증명하는가]
// registerBaseUrl 을 함수 인자로 받는지 "타입"만 보는 것은 증거가 아니다
// (타입은 맞는데 실제로는 다른 값이 쓰일 수 있다 — 이것이 위험1의 핵심
// 우려다). 그래서 이 스크립트는 "관찰 가능한 최종 산출물"을 본다:
//   실제 PNG 쿠폰 이미지의 QR 코드를 jsQR 로 디코딩해, 그 안에 인코딩된
//   URL 의 origin 이 resolvePublicOrigin() 이 계산한 값과 바이트 단위로
//   일치하는지 확인한다. QR 은 "어느 코드가 실행됐는지"를 속일 수 없는
//   증거다(테스트13/14 가 이미지 "치수"로 증명한 것과 같은 패턴 — 이번엔
//   이미지 "내용"으로 증명한다).
//
// [시나리오 구성 — "API 경로"를 실제로 재현]
// generate-images/route.ts 를 Next.js 서버를 띄워 HTTP 로 호출하는 것은
// 이 스크립트의 범위를 벗어난다(그러면 admin 세션 쿠키 발급까지 필요).
// 대신 resolvePublicOrigin() 자체를 "API 경로가 실제로 호출하는 것과
// 동일한 함수"로 직접 import 해, 그 함수가 흉내 낸 Request 객체(실제
// 프로덕션에서 리버스프록시가 넘기는 x-forwarded-host/proto 헤더가 달린
// Request)로 계산한 값을 그대로 startImageGenerationJob() 에 넘긴다.
// 이것이 "API 경로와 배치 경로가 같은 함수의 같은 반환값을 쓴다"는 것을
// 코드 레벨로 증명한다(함수가 같으므로 호출 결과도 같다 — route.ts
// 28번 줄과 retry/route.ts 19번 줄이 호출하는 것과 100% 동일한 라인).
import { prisma } from "../src/lib/db";
import { defaultLayout } from "../src/lib/bokju-coupon-design/layout";
import { freezeRevision, setCurrentRevision } from "../src/lib/bokju-coupon-design/revision";
import { startImageGenerationJob, getImageJob, readCouponImage } from "../src/lib/bokju-coupon-image-service";
import { createHash } from "node:crypto";
import { readFile, rm } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import jsQR from "jsqr";

// [주의 — 왜 page-config-helpers.ts 에서 직접 import 하지 않는가]
// page-config-helpers.ts 는 dal.ts 를 통해 'server-only' 패키지를 로드한다
// (Next.js RSC 경계 강제용). tsx 로 이 파일을 "일반 Node 스크립트"로 실행하면
// 'server-only' 가 즉시 throw 한다(React Server Component 바깥에서 import
// 됐다고 판단) — Next.js 서버 프로세스 밖에서는 import 자체가 불가능하다.
// 그래서 resolvePublicOrigin() 의 로직을 **원본 그대로** 아래에 복사해
// 쓰되, 실제 소스 파일과 바이트 단위로 동일한지 아래 [부가 확인] 블록에서
// 별도로 검증한다 — "복사했는데 몰래 다르게 바꿔서 테스트를 통과시켰다"는
// 반론을 차단하기 위함이다.
function resolvePublicOriginForTest(request: Request): string {
  if (process.env.NEXT_PUBLIC_APP_BASE_URL) return process.env.NEXT_PUBLIC_APP_BASE_URL;

  const headers = request.headers;
  const forwardedHost = headers.get("x-forwarded-host");
  const forwardedProto = headers.get("x-forwarded-proto");
  if (forwardedHost) {
    const proto = forwardedProto?.split(",")[0]?.trim() || "https";
    return `${proto}://${forwardedHost.split(",")[0]?.trim()}`;
  }
  return new URL(request.url).origin;
}

async function waitForJob(jobId: number, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  let job = await getImageJob(jobId);
  while (job && job.status !== "COMPLETED" && job.status !== "FAILED" && Date.now() < deadline) {
    await new Promise((r) => setTimeout(r, 200));
    job = await getImageJob(jobId);
  }
  return job;
}

/** PNG 버퍼에서 QR 을 디코딩해 안에 인코딩된 URL 문자열을 반환한다. */
async function decodeQrFromPng(buf: Buffer): Promise<string | null> {
  const { data, info } = await sharp(buf).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const result = jsQR(new Uint8ClampedArray(data), info.width, info.height);
  return result ? result.data : null;
}

let failed = false;
function check(label: string, ok: boolean, detail: string) {
  console.log(`  ${ok ? "✅" : "❌"} ${label} — ${detail}`);
  if (!ok) failed = true;
}

async function main() {
  console.log("── [위험1 검증] 배치 경로의 registerBaseUrl 출처 확정 ──\n");

  // ── 사전 조건: env 폴백에 "트랩" 값을 심는다 ──────────────────────────
  // FALLBACK_BASE_URL(renderer.ts 103번 줄)이 실제로 쓰인다면, 이
  // 트랩 값이 QR 에 그대로 찍혀 나와야 한다. 명시적으로 전달되는 정상
  // 경로라면 이 트랩 값은 QR 어디에도 나타나지 않아야 한다.
  const TRAP_ENV_VALUE = "http://localhost:ENV-FALLBACK-TRAP-9999";
  process.env.COUPON_BASE_URL = TRAP_ENV_VALUE;
  console.log(`[0] env 트랩 설정: COUPON_BASE_URL=${TRAP_ENV_VALUE}`);
  console.log("    (이 값이 QR 에 나타나면 env 폴백이 실제로 쓰인 것 — 버그)\n");

  // ── 1) "API 경로"를 흉내 낸 실제 Request 객체로 origin 계산 ───────────
  // generate-images/route.ts 28번 줄, retry/route.ts 19번 줄과 100% 동일한
  // 호출: resolvePublicOrigin(request). 리버스프록시 뒤 운영 배포를
  // 재현하기 위해 x-forwarded-host/proto 헤더를 단 Request 를 만든다.
  const fakeProdRequest = new Request("http://127.0.0.1:4300/api/admin/bokju-coupons/campaigns/1/generate-images", {
    method: "POST",
    headers: {
      "x-forwarded-host": "coupon-studio-staging.sintong-internal.example",
      "x-forwarded-proto": "https",
    },
  });
  const apiComputedOrigin = resolvePublicOriginForTest(fakeProdRequest);
  console.log(`[1] API 경로 계산값(resolvePublicOrigin) = ${apiComputedOrigin}`);
  check(
    "계산값이 트랩(env)과 다르고 x-forwarded-* 헤더를 반영함",
    apiComputedOrigin === "https://coupon-studio-staging.sintong-internal.example",
    `실제값=${apiComputedOrigin}`
  );

  // ── 2) 캠페인/리비전/쿠폰 준비 ─────────────────────────────────────────
  const campaign = await prisma.bokjuCouponCampaign.create({
    data: {
      title: "[검증] 위험1 - registerBaseUrl 출처 캠페인",
      grantAmount: 777,
      validFrom: new Date("2026-01-01T00:00:00Z"),
      validTo: new Date("2026-12-31T23:59:59Z"),
      guideText: "QR코드를 찍고 복주머니를 받으세요",
    },
  });
  console.log(`\n[2] 캠페인 생성 campaignId=${campaign.id}`);

  const layout = defaultLayout({ width: 1080, height: 1080 });
  const rev = await freezeRevision(campaign.id, layout, { note: "[검증] 위험1 전용 리비전", createdBy: "verify-risk1" });
  await setCurrentRevision(campaign.id, rev.id);
  console.log(`[3] 리비전 동결 revId=${rev.id}`);

  const coupon = await prisma.bokjuCoupon.create({
    data: {
      campaignId: campaign.id,
      couponNo: "VERIFY-RISK1-" + Date.now(),
      redeemToken: createHash("sha256").update("verify-risk1-" + Date.now()).digest("hex").slice(0, 32),
      expiresAt: campaign.validTo,
      designRevisionId: rev.id,
    },
  });
  console.log(`[4] 쿠폰 발행(각인) couponId=${coupon.id} designRevisionId=${coupon.designRevisionId}`);

  // ── 3) "배치 경로" 실행 — API 경로가 계산한 값을 그대로 넘긴다 ─────────
  // 이것이 route.ts 28번 줄이 하는 것과 정확히 동일한 호출이다:
  //   const registerBaseUrl = resolvePublicOrigin(request);
  //   startImageGenerationJob(campaignId, actor.adminId, { registerBaseUrl });
  const job = await startImageGenerationJob(campaign.id, "verify-risk1", {
    registerBaseUrl: apiComputedOrigin,
  });
  console.log(`\n[5] 배치 발행 시작 jobId=${job.jobId} (registerBaseUrl=${apiComputedOrigin} 를 그대로 전달)`);

  const jobStatus = await waitForJob(job.jobId);
  if (jobStatus?.status !== "COMPLETED") {
    throw new Error(`배치 발행 실패: status=${jobStatus?.status}`);
  }
  console.log(`[6] 배치 발행 완료 status=${jobStatus.status}`);

  // ── 4) 최종 산출물(PNG)의 QR 을 디코딩해 실제 origin 확인 ──────────────
  const buf = await readCouponImage(campaign.id, coupon.id);
  if (!buf) throw new Error("쿠폰 이미지가 생성되지 않았습니다.");
  const decoded = await decodeQrFromPng(buf);
  console.log(`\n[7] QR 디코딩 결과(실물 쿠폰에 인쇄되는 값) = ${decoded}`);

  if (!decoded) {
    throw new Error("QR 디코딩 실패 — jsQR 이 코드를 읽지 못했습니다.");
  }

  const decodedOrigin = new URL(decoded).origin;

  console.log("\n── 판정 ──");

  // 요청 1: API 경로와 배치 경로가 같은 origin 을 쓰는가
  check(
    "[요청1] API 경로 origin === 배치 경로 QR 에 찍힌 origin",
    decodedOrigin === apiComputedOrigin,
    `API=${apiComputedOrigin} / QR=${decodedOrigin}`
  );

  // 요청2: localhost/http:// 가 새어들지 않는가
  const leaksLocalhost = decoded.includes("localhost") || decoded.startsWith("http://");
  check(
    "[요청2] QR 에 localhost/http:// 가 섞여있지 않다",
    !leaksLocalhost,
    `QR 전체값=${decoded}`
  );

  // 요청3: env 폴백(트랩 값)이 실제로 쓰이지 않았는가
  const trapLeaked = decoded.includes("ENV-FALLBACK-TRAP");
  check(
    "[요청3] env 폴백(COUPON_BASE_URL 트랩값)이 QR 에 나타나지 않는다 — 명시적 전달만 쓰였다",
    !trapLeaked,
    trapLeaked ? "🔴 트랩 값이 QR 에 그대로 찍혔다 — env 폴백이 실제로 쓰였다(버그)" : "트랩 값 없음 — 정상"
  );

  // ── 5) API 경로와 배치 경로가 "같은 함수"를 쓰는지 소스 레벨로도 재확인 ──
  console.log("\n[부가 확인] 소스 코드상 호출부 동일성:");
  const routeSrc = await readFile(
    path.join(process.cwd(), "src/app/api/admin/bokju-coupons/campaigns/[id]/generate-images/route.ts"),
    "utf-8"
  );
  const retrySrc = await readFile(
    path.join(process.cwd(), "src/app/api/admin/bokju-coupons/image-jobs/[id]/retry/route.ts"),
    "utf-8"
  );
  const routeUsesResolve = routeSrc.includes("resolvePublicOrigin(request)");
  const retryUsesResolve = retrySrc.includes("resolvePublicOrigin(request)");
  check(
    "generate-images/route.ts 가 resolvePublicOrigin(request) 를 호출한다",
    routeUsesResolve,
    routeUsesResolve ? "확인됨" : "불일치 — 소스 변경됨"
  );
  check(
    "image-jobs/:id/retry/route.ts 가 resolvePublicOrigin(request) 를 호출한다",
    retryUsesResolve,
    retryUsesResolve ? "확인됨" : "불일치 — 소스 변경됨"
  );

  // 두 라우트가 같은 import 출처(page-config-helpers.ts)에서 가져오는지 확인
  // — "이름만 같은 다른 함수"를 쓰는 것이 아님을 보장한다.
  const bothImportFromSameModule =
    routeSrc.includes('resolvePublicOrigin } from "@/lib/page-config-helpers"') &&
    retrySrc.includes('resolvePublicOrigin } from "@/lib/page-config-helpers"');
  check(
    "두 라우트가 동일 모듈(@/lib/page-config-helpers)에서 resolvePublicOrigin 을 import 한다",
    bothImportFromSameModule,
    bothImportFromSameModule ? "확인됨 — 같은 함수, 다른 계산식 아님" : "불일치"
  );

  // 위에서 복사해 쓴 resolvePublicOriginForTest() 가 실제 원본 소스와
  // 로직상 바이트 단위로 동일한지 확인한다(복사 후 몰래 바꿔치기 방지).
  const helperSrc = await readFile(path.join(process.cwd(), "src/lib/page-config-helpers.ts"), "utf-8");
  const fnMatch = helperSrc.match(
    /export function resolvePublicOrigin\(request: Request\): string \{[\s\S]*?\n\}/
  );
  const originalFnBody = fnMatch ? fnMatch[0] : null;
  const expectedFnBody = `export function resolvePublicOrigin(request: Request): string {
  if (process.env.NEXT_PUBLIC_APP_BASE_URL) return process.env.NEXT_PUBLIC_APP_BASE_URL;

  const headers = request.headers;
  const forwardedHost = headers.get("x-forwarded-host");
  const forwardedProto = headers.get("x-forwarded-proto");
  if (forwardedHost) {
    const proto = forwardedProto?.split(",")[0]?.trim() || "https";
    return \`\${proto}://\${forwardedHost.split(",")[0]?.trim()}\`;
  }
  return new URL(request.url).origin;
}`;
  check(
    "이 스크립트가 복사해 쓴 resolvePublicOriginForTest() 가 원본 page-config-helpers.ts 의 resolvePublicOrigin() 과 바이트 단위로 동일하다",
    originalFnBody === expectedFnBody,
    originalFnBody === expectedFnBody ? "확인됨 — 복사본이 원본과 완전 일치" : "🔴 불일치 — 원본이 바뀌었거나 복사본이 낡음, 이 스크립트를 갱신해야 함"
  );

  // ── 정리 ───────────────────────────────────────────────────────────
  delete process.env.COUPON_BASE_URL;
  await prisma.bokjuCoupon.deleteMany({ where: { campaignId: campaign.id } });
  await prisma.bokjuCouponImageJob.deleteMany({ where: { campaignId: campaign.id } });
  await prisma.bokjuCouponDesignRevision.deleteMany({ where: { campaignId: campaign.id } });
  await prisma.bokjuCouponCampaign.delete({ where: { id: campaign.id } });
  const dir = path.join(process.cwd(), "public", "uploads", "bokju-coupons", `campaign_${campaign.id}`);
  await rm(dir, { recursive: true, force: true }).catch(() => {});
  console.log("\n[정리 완료] 이 스크립트가 만든 캠페인/쿠폰/리비전/이미지 전부 삭제됨. env 트랩 해제됨.");

  if (failed) {
    console.error("\n❌ 위험1 검증 실패 — 위 판정 중 하나 이상이 ❌ 입니다.");
    process.exitCode = 1;
  } else {
    console.log("\n✅ 위험1 검증 통과 — API 경로와 배치 경로가 동일한 origin을 쓰고,");
    console.log("   localhost/http:// 유입이 없으며, env 폴백이 실제로 트리거되지 않습니다.");
  }
}

main()
  .catch((e) => {
    console.error("검증 스크립트 실행 중 오류:", e);
    delete process.env.COUPON_BASE_URL;
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
