// 결과 공유 생성 API — Flutter ShareApiService.createShareLink() 대응.
// [sintong-share-proposal.pdf §5] `POST /api/share`.
//
// [요청] { resultType, title, description, payload, imageUrl?, sourceRefId? }
// - resultType: fortune/tarot/face/palm/wish 중 하나(화이트리스트).
// - title/description: OG 태그 및 공유 문구에 그대로 노출된다. 서버는
//   내용을 검열하지 않지만 길이 상한만 강제한다(과도한 payload 방지).
// - payload: 결과 화면이 표시에 필요로 하는 값만 담은 JSON 문자열(또는
//   객체 — 서버가 JSON.stringify 처리). **원본 민감정보(생년월일 원본,
//   실명, 손금/관상 원본 사진, 전화번호, 이메일, 소원 원문)를 절대 담지
//   않을 것**(제안서 (h)절 보안 원칙 — 이 API는 이를 강제 검증하지
//   않으므로 호출부인 Flutter ShareService가 화이트리스트 원칙을 반드시
//   지켜야 한다).
//
// [응답] { success, data: { shareId, shareUrl } }
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  CORS_HEADERS,
  CORS_HEADERS_WITH_AUTH,
  SHARE_DESCRIPTION_MAX_LENGTH,
  SHARE_PAYLOAD_MAX_LENGTH,
  SHARE_TITLE_MAX_LENGTH,
  generateShareId,
  isValidResultType,
  requireUser,
  unauthorizedResponse,
} from "./_shared";

export const dynamic = "force-dynamic";

type CreateShareBody = {
  resultType?: unknown;
  title?: unknown;
  description?: unknown;
  payload?: unknown;
  imageUrl?: unknown;
  sourceRefId?: unknown;
};

export async function POST(request: NextRequest) {
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();

  let body: CreateShareBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  if (!isValidResultType(body.resultType)) {
    return NextResponse.json(
      { success: false, error: "resultType이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (typeof body.title !== "string" || body.title.trim().length === 0) {
    return NextResponse.json(
      { success: false, error: "title이 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (typeof body.description !== "string") {
    return NextResponse.json(
      { success: false, error: "description이 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (body.payload == null) {
    return NextResponse.json(
      { success: false, error: "payload가 필요합니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const title = body.title.trim().slice(0, SHARE_TITLE_MAX_LENGTH);
  const description = body.description.trim().slice(0, SHARE_DESCRIPTION_MAX_LENGTH);
  const payloadStr =
    typeof body.payload === "string" ? body.payload : JSON.stringify(body.payload);
  if (payloadStr.length > SHARE_PAYLOAD_MAX_LENGTH) {
    return NextResponse.json(
      { success: false, error: "payload가 너무 큽니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  const imageUrl = typeof body.imageUrl === "string" ? body.imageUrl : null;
  const sourceRefId = typeof body.sourceRefId === "string" ? body.sourceRefId : null;

  try {
    // shareId 충돌은 사실상 발생하지 않지만(62^10 공간), unique 제약이
    // 있으므로 방어적으로 재시도한다(guinji generateGuinjiToken()과 동일 패턴).
    let created: { shareId: string } | null = null;
    for (let attempt = 0; attempt < 3 && !created; attempt++) {
      const shareId = generateShareId();
      try {
        created = await prisma.sharedResult.create({
          data: {
            shareId,
            userId: auth.userId,
            resultType: body.resultType as string,
            sourceRefId,
            title,
            description,
            payload: payloadStr,
            imageUrl,
          },
          select: { shareId: true },
        });
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code !== "P2002") throw e;
        // shareId 충돌 — 루프 재시도.
      }
    }
    if (!created) {
      throw new Error("SHARE_ID_GENERATION_FAILED");
    }

    const baseUrl = process.env.PUBLIC_BASE_URL ?? "http://localhost:3000";
    const shareUrl = `${baseUrl}/r/${created.shareId}`;

    return NextResponse.json(
      { success: true, data: { shareId: created.shareId, shareUrl } },
      { status: 201, headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/share] 실패:", e);
    return NextResponse.json(
      { success: false, error: "공유 링크 생성 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS_WITH_AUTH });
}
