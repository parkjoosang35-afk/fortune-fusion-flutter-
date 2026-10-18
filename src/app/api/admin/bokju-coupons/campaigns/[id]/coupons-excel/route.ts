// [복주머니 마케팅 쿠폰 — 턴B(02w §0-AA-2)] GET /api/admin/bokju-coupons/campaigns/:id/coupons-excel
// 쿠폰번호/등록링크 엑셀을 파일로 저장하지 않고 요청 시점에 그 자리에서
// 응답 스트림으로 직접 흘려보낸다(참고구현 writeNumbersXlsx(res, rows, meta)
// 와 동일한 패턴 — WorkbookWriter({ stream: res })). 기존에는
// runImageJob() 완료 시점에 미리 파일로 만들어 excelPath를 DB에 저장해
// 두었으나, 그 경로가 public/ 밖(storage/)인데 응답에는 public 경로 문자열을
// 돌려주는 "깨진 링크" 상태가 발생했다(02t/02u 보안 수정) — 스트리밍으로
// 바꾸면 "저장된 경로 문자열" 자체가 존재하지 않으므로 그 불일치가 원천
// 차단된다.
import { PassThrough, Readable } from "stream";
import { prisma } from "@/lib/db";
import { jsonError, requireAdminOrResponse, isAdminActor, resolvePublicOrigin } from "@/lib/page-config-helpers";
import { streamCouponExcel } from "@/lib/bokju-coupon-image-service";

export const dynamic = "force-dynamic";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const actor = await requireAdminOrResponse();
  if (!isAdminActor(actor)) return actor;

  const { id } = await params;
  const campaignId = Number(id);
  if (!Number.isInteger(campaignId)) return jsonError("campaignId가 올바르지 않습니다.");

  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
  if (!campaign) return jsonError("캠페인을 찾을 수 없습니다.", 404);

  const coupons = await prisma.bokjuCoupon.findMany({
    where: { campaignId },
    select: { id: true, couponNo: true, redeemToken: true, status: true, expiresAt: true },
    orderBy: { id: "asc" },
  });
  if (coupons.length === 0) {
    return jsonError("발행된 쿠폰이 없습니다.", 404);
  }

  const registerBaseUrl = resolvePublicOrigin(request);

  // Node Writable(PassThrough) <-> Web ReadableStream 변환: ExcelJS
  // WorkbookWriter는 Node stream API(.write/.end)만 받으므로 PassThrough를
  // 만들어 스트림의 목적지로 넘기고, 그 Readable 쪽을 Web ReadableStream으로
  // 변환해 Next.js Response body로 전달한다(둘 다 같은 버퍼를 공유한다).
  const passthrough = new PassThrough();

  // await하지 않는다 — streamCouponExcel이 write()를 호출하는 동안 동시에
  // Response가 그 바이트를 읽어 응답으로 흘려보내야 하므로, 여기서 기다리면
  // 교착(deadlock)된다. 에러는 passthrough.destroy(err)로 전달해 응답 스트림이
  // 비정상 종료되게 한다(반쪽 xlsx가 정상처럼 내려가지 않도록 함).
  streamCouponExcel(passthrough, campaignId, coupons, registerBaseUrl).catch((e) => {
    console.error(`[GET /api/admin/bokju-coupons/campaigns/:id/coupons-excel] 스트리밍 실패:`, e);
    passthrough.destroy(e instanceof Error ? e : new Error(String(e)));
  });

  const webStream = Readable.toWeb(passthrough) as unknown as ReadableStream;
  const encodedTitle = encodeURIComponent(`${campaign.title}_쿠폰번호.xlsx`);

  return new Response(webStream, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="coupons.xlsx"; filename*=UTF-8''${encodedTitle}`,
    },
  });
}
