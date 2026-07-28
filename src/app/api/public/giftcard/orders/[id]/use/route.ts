// 공개(비인증) 상품권 사용처리 API — GiftcardRepository.useIssue() 대응.
// giftcard_usages(J-3) UQ(issue_id) 제약 반영: 이미 사용된 건은 재사용 불가.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function pickEmoji(brand: string, name: string): string {
  const text = `${brand} ${name}`;
  if (text.includes("스타벅스") || text.includes("커피") || text.includes("카페")) return "☕";
  if (text.includes("치킨") || text.includes("BBQ")) return "🍗";
  if (text.includes("배스킨") || text.includes("아이스크림")) return "🍨";
  if (text.includes("문화상품권") || text.includes("영화")) return "🎟️";
  if (text.includes("GS25") || text.includes("CU") || text.includes("편의점")) return "🏪";
  if (text.includes("피자")) return "🍕";
  if (text.includes("햄버거") || text.includes("버거")) return "🍔";
  return "🎁";
}

function parseIssueId(idParam: string): number | null {
  const match = /^gci_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const issueId = parseIssueId(id);
  if (issueId === null) {
    return NextResponse.json(
      { success: false, error: "상품권 내역을 찾을 수 없습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const issue = await tx.giftcardIssue.findUnique({
        where: { id: issueId },
        include: { product: true, usage: true },
      });
      if (!issue) throw new Error("NOT_FOUND");
      if (issue.status !== "issued") throw new Error("INVALID_STATUS");
      if (issue.usage) throw new Error("ALREADY_USED");
      if (issue.expiresAt && issue.expiresAt.getTime() < Date.now()) {
        throw new Error("EXPIRED");
      }

      await tx.giftcardUsage.create({ data: { issueId: issue.id } });
      const updated = await tx.giftcardIssue.findUnique({
        where: { id: issue.id },
        include: { product: true, usage: true },
      });
      return updated!;
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `gci_${result.id}`,
          product: {
            id: `gc_${result.product.id}`,
            name: result.product.name,
            brand: result.product.brand,
            requiredPoint: result.product.requiredPoint,
            stockCount: result.product.stockCount,
            validDays: result.product.validDays,
            imageEmoji: pickEmoji(result.product.brand, result.product.name),
          },
          pointSpent: result.pointSpent,
          status: result.status,
          issuedCode: result.issuedCode,
          issuedAt: result.issuedAt?.toISOString() ?? null,
          expiresAt: result.expiresAt?.toISOString() ?? null,
          usedAt: result.usage?.usedAt.toISOString() ?? null,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    const errorMap: Record<string, { status: number; error: string }> = {
      NOT_FOUND: { status: 404, error: "상품권 내역을 찾을 수 없습니다." },
      INVALID_STATUS: { status: 400, error: "사용할 수 없는 상태입니다." },
      ALREADY_USED: { status: 400, error: "이미 사용된 상품권입니다." },
      EXPIRED: { status: 400, error: "사용 기간이 만료되었습니다." },
    };
    const mapped = errorMap[message];
    if (mapped) {
      return NextResponse.json(
        { success: false, error: mapped.error },
        { status: mapped.status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/giftcard/orders/[id]/use] 실패:", e);
    return NextResponse.json(
      { success: false, error: "사용처리 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
