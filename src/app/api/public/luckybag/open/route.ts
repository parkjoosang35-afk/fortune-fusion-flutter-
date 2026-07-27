// 공개(비인증) 복주머니 개봉(구매+추첨) API — Flutter LuckyBagRepository.open() 대응.
//
// [핵심 원칙] 확률 추첨과 포인트 차감/지급은 반드시 서버(이 API)에서 단일 트랜잭션으로
// 처리한다(클라이언트는 결과를 받아 애니메이션만 재생). 02_Feature_Specification.md §24-⑦
// "서버 측에서 확률 계산 및 결과 확정" 요건 대응.
//
// [처리 순서 - 하나의 $transaction 안에서]
//   1) 상품(luckybag_products) 조회 — 존재/활성 확인
//   2) 지갑(wallets) 조회 — 잔액 >= 가격 확인, 부족하면 즉시 실패
//   3) 가격만큼 차감 + point_histories(spend) 기록
//   4) 해당 상품의 활성 확률표(luckybag_reward_pools) 로드 → 가중 랜덤 추첨
//   5) 당첨 결과가 point 타입이면 즉시 적립 + point_histories(earn) 기록
//   6) 당첨 결과가 amulet 타입이면 user_amulets 레코드 생성(rewardRefId 없으면 랜덤 부적 1개 선택)
//   7) luckybag_open_logs 기록(reward_result JSON 스냅샷)
//   8) 최종 잔액과 당첨 결과를 응답으로 반환
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST(request: NextRequest) {
  let body: { userId?: number; productId?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const productId = Number(body.productId);

  if (!Number.isInteger(productId) || productId <= 0) {
    return NextResponse.json(
      { success: false, error: "productId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      // 1) 상품 확인
      const product = await tx.luckybagProduct.findFirst({
        where: { id: productId, deletedAt: null, isActive: true, status: "active" },
      });
      if (!product) throw new Error("PRODUCT_NOT_FOUND");

      // 2) 지갑 확인
      const wallet = await tx.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");
      if (wallet.balance < product.pricePoint) throw new Error("INSUFFICIENT_BALANCE");

      // 3) 가격 차감
      let balance = wallet.balance - product.pricePoint;
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance, balanceSyncedAt: new Date() },
      });
      await tx.pointHistory.create({
        data: {
          walletId: wallet.id,
          userId,
          amount: -product.pricePoint,
          type: "spend",
          sourceType: "luckybag",
          sourceId: product.id,
          balanceAfter: balance,
          memo: `${product.name} 열기`,
        },
      });

      // 4) 확률표 로드 + 가중 랜덤 추첨
      const pools = await tx.luckybagRewardPool.findMany({
        where: { luckybagProductId: productId, deletedAt: null, status: "active" },
        include: { grade: true },
      });
      if (pools.length === 0) throw new Error("NO_REWARD_POOL");

      const totalProbability = pools.reduce((sum, p) => sum + p.probability, 0);
      const roll = Math.random() * totalProbability;
      let acc = 0;
      let picked = pools[pools.length - 1];
      for (const pool of pools) {
        acc += pool.probability;
        if (roll <= acc) {
          picked = pool;
          break;
        }
      }

      // 5)/6) 당첨 결과에 따른 지급 처리
      let rewardLabel = "다음 기회에";
      let rewardAmount: number | null = null;
      let awardedAmuletName: string | null = null;

      if (picked.rewardType === "point") {
        rewardAmount = picked.rewardAmount ?? 0;
        balance += rewardAmount;
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance, balanceSyncedAt: new Date() },
        });
        await tx.pointHistory.create({
          data: {
            walletId: wallet.id,
            userId,
            amount: rewardAmount,
            type: "earn",
            sourceType: "luckybag",
            sourceId: product.id,
            balanceAfter: balance,
            memo: `${product.name} 개봉 보상`,
          },
        });
        rewardLabel = `${rewardAmount.toLocaleString()}P`;
      } else if (picked.rewardType === "amulet") {
        let amuletItem = picked.rewardRefId
          ? await tx.amuletItem.findUnique({ where: { id: picked.rewardRefId } })
          : null;
        if (!amuletItem) {
          // rewardRefId 미지정(랜덤 부적) — 활성 부적 중 하나를 무작위 선택
          const candidates = await tx.amuletItem.findMany({
            where: { deletedAt: null, status: "active" },
          });
          if (candidates.length > 0) {
            amuletItem = candidates[Math.floor(Math.random() * candidates.length)];
          }
        }
        if (amuletItem) {
          await tx.userAmulet.create({
            data: {
              userId,
              amuletItemId: amuletItem.id,
              sourceType: "luckybag",
              status: "held",
            },
          });
          awardedAmuletName = amuletItem.name;
          rewardLabel = amuletItem.name;
        } else {
          rewardLabel = "부적(재고 없음)";
        }
      } else if (picked.rewardType === "giftcard_fragment") {
        rewardLabel = "상품권 조각";
      } else {
        rewardLabel = "다음 기회에";
      }

      // 7) 개봉 로그 기록
      const openLog = await tx.luckybagOpenLog.create({
        data: {
          userId,
          luckybagProductId: product.id,
          rewardPoolId: picked.id,
          rewardResult: JSON.stringify({
            gradeCode: picked.grade.code,
            gradeName: picked.grade.name,
            rewardType: picked.rewardType,
            rewardLabel,
            rewardAmount,
            amuletName: awardedAmuletName,
          }),
          status: "completed",
        },
      });

      return {
        openLogId: openLog.id,
        gradeCode: picked.grade.code,
        gradeName: picked.grade.name,
        rewardType: picked.rewardType,
        rewardLabel,
        rewardAmount,
        remainingBalance: balance,
      };
    });

    return NextResponse.json({ success: true, data: outcome }, { headers: CORS_HEADERS });
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    const errorMap: Record<string, { status: number; error: string }> = {
      PRODUCT_NOT_FOUND: { status: 404, error: "존재하지 않는 상품입니다." },
      WALLET_NOT_FOUND: { status: 404, error: "지갑을 찾을 수 없습니다." },
      INSUFFICIENT_BALANCE: { status: 400, error: "포인트가 부족합니다." },
      NO_REWARD_POOL: { status: 500, error: "보상 확률표가 설정되지 않았습니다." },
    };
    const mapped = errorMap[message];
    if (mapped) {
      return NextResponse.json(
        { success: false, error: mapped.error },
        { status: mapped.status, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/luckybag/open] 실패:", e);
    return NextResponse.json(
      { success: false, error: "개봉 처리 중 오류가 발생했습니다." },
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
