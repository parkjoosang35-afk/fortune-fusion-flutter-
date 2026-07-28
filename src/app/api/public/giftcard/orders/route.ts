// 공개(비인증) 상품권 교환(발급) API — GiftcardRepository.orderProduct() 대응.
//
// [설계결정 - 포인트 오케스트레이션 분리] giftcard_detail_screen.dart는 이미
// WalletProvider.spend() → orderProduct() → 실패시 WalletProvider.earn()(환불)으로
// 클라이언트 레벨 오케스트레이션을 완료했다. 따라서 이 API는 wallet 로직을 전혀
// 다루지 않고, 순수 재고 차감 + giftcard_issues 레코드 생성만 담당한다
// (02번§1.2 WalletService 단일 인터페이스 원칙 — wallet/spend, wallet/earn을 그대로
// 재사용, 중복 트랜잭션 로직 구현 방지).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

function parseProductId(idParam: string): number | null {
  const match = /^gc_(\d+)$/.exec(idParam);
  if (match) return Number(match[1]);
  const n = Number(idParam);
  return Number.isInteger(n) ? n : null;
}

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

function generateCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const parts: string[] = [];
  for (let g = 0; g < 3; g++) {
    let part = "";
    for (let i = 0; i < 4; i++) {
      part += chars[Math.floor(Math.random() * chars.length)];
    }
    parts.push(part);
  }
  return parts.join("-");
}

function toIssueDto(issue: {
  id: number;
  pointSpent: number;
  status: string;
  issuedCode: string | null;
  issuedAt: Date | null;
  expiresAt: Date | null;
  usage?: { usedAt: Date } | null;
  product: {
    id: number;
    name: string;
    brand: string;
    requiredPoint: number;
    stockCount: number;
    validDays: number;
  };
}) {
  return {
    id: `gci_${issue.id}`,
    product: {
      id: `gc_${issue.product.id}`,
      name: issue.product.name,
      brand: issue.product.brand,
      requiredPoint: issue.product.requiredPoint,
      stockCount: issue.product.stockCount,
      validDays: issue.product.validDays,
      imageEmoji: pickEmoji(issue.product.brand, issue.product.name),
    },
    pointSpent: issue.pointSpent,
    status: issue.status,
    issuedCode: issue.issuedCode,
    issuedAt: issue.issuedAt?.toISOString() ?? null,
    expiresAt: issue.expiresAt?.toISOString() ?? null,
    usedAt: issue.usage?.usedAt.toISOString() ?? null,
  };
}

export async function POST(request: NextRequest) {
  let body: { userId?: number; productId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const productId = body.productId ? parseProductId(body.productId) : null;
  if (productId === null) {
    return NextResponse.json(
      { success: false, error: "존재하지 않는 상품입니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const issue = await prisma.$transaction(async (tx) => {
      const product = await tx.giftcardProduct.findFirst({
        where: { id: productId, deletedAt: null, isActive: true, status: "active" },
      });
      if (!product) throw new Error("PRODUCT_NOT_FOUND");
      if (product.stockCount <= 0) throw new Error("OUT_OF_STOCK");

      await tx.giftcardProduct.update({
        where: { id: product.id },
        data: { stockCount: product.stockCount - 1 },
      });

      const now = new Date();
      const created = await tx.giftcardIssue.create({
        data: {
          userId,
          productId: product.id,
          pointSpent: product.requiredPoint,
          issuedCode: generateCode(),
          issuedAt: now,
          expiresAt: new Date(now.getTime() + product.validDays * 24 * 60 * 60 * 1000),
          status: "issued",
        },
        include: { product: true, usage: true },
      });
      return created;
    });

    return NextResponse.json({ success: true, data: toIssueDto(issue) }, { headers: CORS_HEADERS });
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "PRODUCT_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "존재하지 않는 상품입니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "OUT_OF_STOCK") {
      // 재고 소진 시 giftcard_issues에 실패 레코드를 남겨 Flutter의 failed 상태 처리 흐름과
      // 일치시킨다(giftcard_detail_screen.dart가 issue.status===failed를 감지해 환불 처리).
      try {
        const productForFail = await prisma.giftcardProduct.findUnique({ where: { id: productId! } });
        if (productForFail) {
          const failedIssue = await prisma.giftcardIssue.create({
            data: {
              userId,
              productId: productForFail.id,
              pointSpent: productForFail.requiredPoint,
              status: "failed",
            },
            include: { product: true, usage: true },
          });
          return NextResponse.json(
            { success: true, data: toIssueDto(failedIssue) },
            { headers: CORS_HEADERS }
          );
        }
      } catch (inner) {
        console.error("[POST /api/public/giftcard/orders] 실패 레코드 생성 중 오류:", inner);
      }
      return NextResponse.json(
        { success: false, error: "재고가 모두 소진되었습니다." },
        { status: 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/giftcard/orders] 실패:", e);
    return NextResponse.json(
      { success: false, error: "상품권 발급 중 오류가 발생했습니다." },
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
