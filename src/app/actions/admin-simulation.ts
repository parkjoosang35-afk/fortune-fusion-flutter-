"use server";

// ══════════════════════════════════════════════════════════════════
// AdminSimulationService — 열림패스/행복머니/복주머니 통합정책 §6 "운영 테스트랩"
//
// 이 파일은 (prevState, formData) 형태의 폼 액션이 아니라, 클라이언트 컴포넌트에서
// useTransition + 직접 호출(startTransition(() => fn(args)))로 사용하는 "일반 Server
// Action 함수" 묶음이다. 테스트랩 UI는 유저 선택 + 파라미터 입력이 버튼마다 달라
// FormData 기반보다 타입 있는 함수 시그니처가 더 적합하기 때문(문서 §10 권장 함수
// 목록의 서버 대응 버전).
//
// 모든 잔액 변경은 point-adjust.ts와 동일한 "ledger 트랜잭션" 패턴을 따른다:
// 잔액 테이블 update + 원장(history) insert를 하나의 $transaction으로 묶어 원자성 보장.
// 모든 CUD는 예외 없이 operation_logs(AdminAuditLog 대응)에 기록한다(§15 금지 원칙 반영).
// ══════════════════════════════════════════════════════════════════
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canWriteMenu } from "@/lib/rbac";
import {
  grantOpenPass,
  OpenPassServiceError,
  checkAdRewardEligibility,
  resolveFallbackAttachment,
  recordAdRewardLog,
} from "@/lib/open-pass-service";
import { earnLuckPouch, spendLuckPouch } from "@/lib/luck-pouch-engine";

// [재화 구조 정리 - 재연결, 2026-08] 이 파일은 원래 "행복머니(Wallet/POINT)"와
// "복주머니(LuckPouchWallet, 별도 테이블)"를 서로 다른 두 자산으로 나눠 시뮬레이션하도록
// 작성되었으나(§3 "행복머니 테스트" vs §4 "복주머니 테스트"), 이후 재화 구조가
// "Wallet(POINT) 하나만 복주머니로 취급"하는 단일 자산 구조로 정리되면서
// LuckPouchWallet/LuckPouchHistory는 실제 앱의 어떤 화면도 읽지 않는 죽은 테이블이 되었다.
// 그 결과 §4 "복주머니 테스트" 버튼들은 실제 사용자가 보는 잔액과 무관한 유령 잔액을
// 조작하고 있었다(관리자가 테스트랩에서 지급/차감해도 실제 앱에는 반영되지 않는 버그).
// 아래 §4 함수들은 함수 시그니처(TestLabPanel.tsx 호출부)를 그대로 유지한 채, 내부
// 구현만 실제 원장(Wallet/POINT)과 공용 엔진(earnLuckPouch/spendLuckPouch)을 사용하도록
// 재연결했다 — 이제 테스트랩에서의 지급/차감/사용 시뮬레이션이 실제 앱과 동일한 코드
// 경로를 거쳐 동일한 잔액에 반영된다.
//
// [라벨 정리, 2026-08 후속] §3 함수명(adminManualGrantHappyMoney 등)과 내부 주석,
// operationLog의 action 코드(happy_money_grant 등)는 하위 호환·이력 일관성을 위해
// 그대로 두었으나, 관리자 화면에 노출되는 한글 문구(버튼 결과 메시지, 섹션 제목,
// TestLabPanel.tsx의 라벨)는 "복주머니"로 통일했다 — "라벨 혼용 금지" 원칙은
// 사용자 앱뿐 아니라 최종 5대 메뉴에 포함된 관리자 테스트랩에도 동일하게 적용되어야
// 하기 때문이다. 함수/필드 이름까지 바꾸지 않은 이유는 순수 리네이밍이 이번
// "구조 재연결" 작업의 핵심이 아니고, 자칫 다른 곳의 참조를 놓쳐 새로운 버그를
// 만들 위험이 이름 정리로 얻는 이득보다 크기 때문이다(라벨=UI 문구만 교체, 코드
// 식별자는 유지 — 리스크 최소화 원칙).
//
// [추가 정리] §3 adminManualGrantHappyMoney/adminManualDeductHappyMoney는 원래
// tx.wallet 조작 코드를 직접 손으로 다시 구현하고 있었다 — §4와 완전히 동일한
// 자산(Wallet/POINT, admin_adjust 소스타입은 일일 상한 제외 대상)을 다루면서도
// 별도 구현이었던 것으로, 이 역시 "동일 로직 여러 곳 중복 구현"에 해당해 향후
// 두 구현이 다르게 진화하면 또 다른 이원화 버그의 씨앗이 될 수 있었다. 이번
// 재연결 작업에서 §4와 동일하게 공용 earnLuckPouch/spendLuckPouch 호출로 통일했다
// (내부 구현만 교체, 외부 함수 시그니처는 유지). 반면 "purchase" 소스타입 함수
// (adminSimulatePurchaseHappyMoneyProduct, spendHappyMoneyInternal 기반 함수들)는
// §4의 purchase 분기와 동일하게 tx.wallet 직접 조작을 그대로 유지했다(구매는
// 일일 적립 상한 산정에서 애초에 제외 대상이라 공용 엔진을 거칠 실익이 없고,
// HappyMoneyProduct 카탈로그 자체는 RewardSubNav.tsx에 이미 [금지]로 문서화된
// 레거시 진입점이라 스키마 차원 정리는 더 큰 범위의 별도 작업으로 남겨둔다).

export interface SimResult {
  success: boolean;
  message: string;
  data?: Record<string, unknown>;
}

async function requireWriteAccess(): Promise<
  { ok: true; session: Awaited<ReturnType<typeof verifyAdminSession>> } | { ok: false; result: SimResult }
> {
  const session = await verifyAdminSession();
  if (!canWriteMenu(session.roleCode, "reward")) {
    return { ok: false, result: { success: false, message: "이 작업을 수행할 권한이 없습니다." } };
  }
  return { ok: true, session };
}

async function logAdminAction(params: {
  adminId: number;
  action: string;
  targetType: string;
  targetId?: number | null;
  before?: unknown;
  after?: unknown;
}) {
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: params.adminId,
      action: params.action,
      targetType: params.targetType,
      targetId: params.targetId ?? null,
      before: params.before != null ? JSON.stringify(params.before) : null,
      after: params.after != null ? JSON.stringify(params.after) : null,
    },
  });
}

// [리팩터링] 복주머니/행복머니 지갑 find-or-create, 열림패스 지급 로직은
// src/lib/open-pass-service.ts로 이동해 관리자 테스트랩과 실제 광고보상 콜백
// (/api/public/open-pass/reward-complete)이 완전히 동일한 함수를 공유하도록 통일했다
// (§15 금지 원칙: 관리자/앱 정책 불일치 금지).

function revalidateTestLab() {
  revalidatePath("/reward/test-lab");
  revalidatePath("/reward/happy-money-products");
  revalidatePath("/reward/luck-pouch-rules");
}

// ════════════════════════════════════════════════════════════════
// 1) 유저 자산 스냅샷 조회
// ════════════════════════════════════════════════════════════════
export async function adminGetUserAssetSnapshot(userId: number): Promise<SimResult> {
  await verifyAdminSession();
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return { success: false, message: "존재하지 않는 유저입니다." };

  // [재화 구조 정리 - 재연결] happyWallet/luckWallet은 과거에는 서로 다른 테이블
  // (Wallet/POINT vs LuckPouchWallet)이었으나, 현재는 Wallet(POINT) 하나가 곧
  // "복주머니"다. 두 값이 항상 동일하게 나오는 것은 버그가 아니라 단일 원장으로
  // 정리된 결과이며, happyMoneyBalance 필드는 TestLabPanel.tsx 호환을 위해
  // 당분간 유지한다(실제 의미는 복주머니 잔액과 동일).
  const [happyWallet, openPasses, recentPointHistory] = await Promise.all([
    prisma.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } }),
    prisma.userPass.findMany({
      where: { userId },
      orderBy: { id: "desc" },
      take: 10,
      include: { policy: { select: { name: true, passType: true, scope: true } } },
    }),
    prisma.pointHistory.findMany({ where: { userId }, orderBy: { createdAt: "desc" }, take: 10 }),
  ]);
  const luckWallet = happyWallet;
  const recentLuckHistory = recentPointHistory;

  const now = new Date();
  const activeOpenPass = openPasses.find((p) => p.status === "active" && p.expiresAt > now);

  return {
    success: true,
    message: "조회 완료",
    data: {
      user: { id: user.id, nickname: user.nickname, status: user.status },
      happyMoneyBalance: happyWallet?.balance ?? 0,
      luckPouchBalance: luckWallet?.balance ?? 0,
      isOpenPassActive: !!activeOpenPass,
      activeOpenPass: activeOpenPass
        ? {
            id: activeOpenPass.id,
            policyName: activeOpenPass.policy.name,
            expiresAt: activeOpenPass.expiresAt.toISOString(),
            scope: activeOpenPass.scope ?? activeOpenPass.policy.scope,
          }
        : null,
      openPasses: openPasses.map((p) => ({
        id: p.id,
        policyName: p.policy.name,
        status: p.status,
        sourceType: p.sourceType,
        activatedAt: p.activatedAt.toISOString(),
        expiresAt: p.expiresAt.toISOString(),
      })),
      recentPointHistory: recentPointHistory.map((h) => ({
        id: h.id,
        amount: h.amount,
        type: h.type,
        sourceType: h.sourceType,
        memo: h.memo,
        createdAt: h.createdAt.toISOString(),
      })),
      recentLuckHistory: recentLuckHistory.map((h) => ({
        id: h.id,
        amount: h.amount,
        type: h.type,
        sourceType: h.sourceType,
        memo: h.memo,
        createdAt: h.createdAt.toISOString(),
      })),
    },
  };
}

// ════════════════════════════════════════════════════════════════
// 2) 열림패스 테스트 (§6-2)
// ════════════════════════════════════════════════════════════════

export async function adminGrantOpenPass(input: {
  userId: number;
  policyId: number;
  durationOverrideMin?: number;
  scopeOverride?: string;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  try {
    const { userPass, policy } = await grantOpenPass({
      userId: input.userId,
      policyId: input.policyId,
      sourceType: "manual",
      durationOverrideMin: input.durationOverrideMin,
      scopeOverride: input.scopeOverride,
      grantedByAdminId: auth.session.adminUserId,
    });
    await logAdminAction({
      adminId: auth.session.adminUserId,
      action: "open_pass_grant",
      targetType: "user_pass",
      targetId: userPass.id,
      after: { userId: input.userId, policyId: input.policyId, expiresAt: userPass.expiresAt },
    });
    revalidateTestLab();
    return {
      success: true,
      message: `${policy.name} 지급 완료 (만료: ${userPass.expiresAt.toLocaleString("ko-KR")})`,
      data: { userPassId: userPass.id, expiresAt: userPass.expiresAt.toISOString() },
    };
  } catch (e) {
    if (e instanceof OpenPassServiceError && e.code === "POLICY_NOT_FOUND") {
      return { success: false, message: e.message };
    }
    console.error("[adminGrantOpenPass] 실패:", e);
    return { success: false, message: "열림패스 지급 중 오류가 발생했습니다." };
  }
}

export async function adminForceExpireOpenPass(userPassId: number): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const before = await prisma.userPass.findUnique({ where: { id: userPassId } });
  if (!before) return { success: false, message: "존재하지 않는 열림패스 인스턴스입니다." };

  const after = await prisma.userPass.update({
    where: { id: userPassId },
    data: { expiresAt: new Date(), status: "expired" },
  });

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_force_expire",
    targetType: "user_pass",
    targetId: userPassId,
    before: { status: before.status, expiresAt: before.expiresAt },
    after: { status: after.status, expiresAt: after.expiresAt },
  });
  revalidateTestLab();
  return { success: true, message: "열림패스를 강제 만료 처리했습니다." };
}

export async function adminRevokeOpenPass(userPassId: number): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const before = await prisma.userPass.findUnique({ where: { id: userPassId } });
  if (!before) return { success: false, message: "존재하지 않는 열림패스 인스턴스입니다." };

  const after = await prisma.userPass.update({
    where: { id: userPassId },
    data: { expiresAt: new Date(), status: "revoked", revokedAt: new Date() },
  });

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_revoke",
    targetType: "user_pass",
    targetId: userPassId,
    before: { status: before.status },
    after: { status: after.status },
  });
  revalidateTestLab();
  return { success: true, message: "열림패스를 회수(revoke) 처리했습니다." };
}

export async function adminSimulateOpenPassSource(input: {
  userId: number;
  policyId: number;
  source: "ad_reward" | "purchase" | "event" | "test_mode";
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  try {
    const { userPass, policy } = await grantOpenPass({
      userId: input.userId,
      policyId: input.policyId,
      sourceType: input.source === "purchase" ? "subscription" : input.source === "ad_reward" ? "ad" : input.source === "event" ? "event" : "test_mode",
      grantedByAdminId: auth.session.adminUserId,
    });
    const sourceLabel = {
      ad_reward: "광고보상 지급",
      purchase: "구매 지급",
      event: "이벤트 지급",
      test_mode: "테스트 지급",
    }[input.source];
    await logAdminAction({
      adminId: auth.session.adminUserId,
      action: `open_pass_simulate_${input.source}`,
      targetType: "user_pass",
      targetId: userPass.id,
      after: { userId: input.userId, policyId: input.policyId },
    });
    revalidateTestLab();
    return { success: true, message: `[시뮬레이션] ${sourceLabel} — ${policy.name} 지급 완료`, data: { userPassId: userPass.id } };
  } catch (e) {
    if (e instanceof OpenPassServiceError && e.code === "POLICY_NOT_FOUND") {
      return { success: false, message: e.message };
    }
    console.error("[adminSimulateOpenPassSource] 실패:", e);
    return { success: false, message: "시뮬레이션 처리 중 오류가 발생했습니다." };
  }
}

// ════════════════════════════════════════════════════════════════
// 3) 복주머니 테스트 - 수동조정 · 레거시 구매 카탈로그 경로 (§6-3, 구 "행복머니 테스트")
// ════════════════════════════════════════════════════════════════

export async function adminManualGrantHappyMoney(input: {
  userId: number;
  amount: number;
  memo: string;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;
  if (input.amount <= 0) return { success: false, message: "지급 금액은 1 이상이어야 합니다." };

  // [재화 구조 정리 - 재연결] §4 adminManualGrantLuckPouch와 완전히 동일한 자산
  // (Wallet/POINT)을 다루므로, 손으로 짠 중복 로직 대신 공용 엔진을 그대로 재사용한다
  // (중복 구현이 서로 다르게 진화해 또 다른 이원화 버그가 생기는 것을 방지).
  const earnResult = await prisma.$transaction((tx) =>
    earnLuckPouch(tx, {
      userId: input.userId,
      amount: input.amount,
      sourceType: "admin_adjust",
      memo: input.memo || "관리자 수동 지급",
    })
  );
  const result = earnResult.balanceAfter ?? 0;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "happy_money_grant",
    targetType: "user_happy_money",
    targetId: input.userId,
    after: { amount: input.amount, newBalance: result, memo: input.memo },
  });
  revalidateTestLab();
  return { success: true, message: `복주머니 ${input.amount.toLocaleString()} 지급 완료 (잔액 ${result.toLocaleString()})`, data: { balance: result } };
}

export async function adminManualDeductHappyMoney(input: {
  userId: number;
  amount: number;
  memo: string;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;
  if (input.amount <= 0) return { success: false, message: "차감 금액은 1 이상이어야 합니다." };

  // [재화 구조 정리 - 재연결] §4 adminManualDeductLuckPouch와 동일한 원장을 다루므로
  // 공용 spendLuckPouch()로 통일한다(중복 로직 이원화 방지).
  const spendResult = await prisma.$transaction((tx) =>
    spendLuckPouch(tx, {
      userId: input.userId,
      amount: input.amount,
      sourceType: "admin_adjust",
      memo: input.memo || "관리자 수동 차감",
    })
  );
  if (!spendResult.ok) {
    return { success: false, message: "잔액 부족: 복주머니가 부족합니다." };
  }
  const result = spendResult.balanceAfter ?? 0;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "happy_money_deduct",
    targetType: "user_happy_money",
    targetId: input.userId,
    after: { amount: input.amount, newBalance: result, memo: input.memo },
  });
  revalidateTestLab();
  return { success: true, message: `복주머니 ${input.amount.toLocaleString()} 차감 완료 (잔액 ${result.toLocaleString()})`, data: { balance: result } };
}

export async function adminSimulatePurchaseHappyMoneyProduct(input: {
  userId: number;
  productId: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const product = await prisma.happyMoneyProduct.findUnique({ where: { id: input.productId } });
  if (!product || product.deletedAt) return { success: false, message: "존재하지 않는 충전 상품입니다." };

  const totalAmount = product.happyMoneyAmount + product.bonusAmount;
  const result = await prisma.$transaction(async (tx) => {
    let wallet = await tx.wallet.findFirst({ where: { userId: input.userId, currencyType: "POINT", deletedAt: null } });
    if (!wallet) wallet = await tx.wallet.create({ data: { userId: input.userId, currencyType: "POINT", balance: 0 } });
    const newBalance = wallet.balance + totalAmount;
    await tx.wallet.update({ where: { id: wallet.id }, data: { balance: newBalance, balanceSyncedAt: new Date() } });
    await tx.pointHistory.create({
      data: {
        walletId: wallet.id,
        userId: input.userId,
        amount: totalAmount,
        type: "earn",
        sourceType: "purchase",
        sourceId: product.id,
        balanceAfter: newBalance,
        memo: `[시뮬레이션 구매] ${product.name} (${product.cashPrice.toLocaleString()}원)`,
      },
    });
    return newBalance;
  });

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "happy_money_simulate_purchase",
    targetType: "user_happy_money",
    targetId: input.userId,
    after: { productId: product.id, totalAmount, newBalance: result },
  });
  revalidateTestLab();
  return {
    success: true,
    message: `[시뮬레이션] ${product.name} 구매 → 복주머니 ${totalAmount.toLocaleString()} 지급 (잔액 ${result.toLocaleString()})`,
    data: { balance: result },
  };
}

async function spendHappyMoneyInternal(tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0], userId: number, amount: number, sourceType: string, memo: string, sourceId?: number) {
  const wallet = await tx.wallet.findFirst({ where: { userId, currencyType: "POINT", deletedAt: null } });
  if (!wallet) throw new Error("WALLET_NOT_FOUND");
  if (wallet.balance < amount) throw new Error("INSUFFICIENT_BALANCE");
  const newBalance = wallet.balance - amount;
  await tx.wallet.update({ where: { id: wallet.id }, data: { balance: newBalance, balanceSyncedAt: new Date() } });
  await tx.pointHistory.create({
    data: { walletId: wallet.id, userId, amount: -amount, type: "spend", sourceType, sourceId, balanceAfter: newBalance, memo },
  });
  return newBalance;
}

export async function adminSimulatePurchaseOpenPassViaHappyMoney(input: {
  userId: number;
  policyId: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const policy = await prisma.passPolicy.findUnique({ where: { id: input.policyId } });
  if (!policy || policy.deletedAt) return { success: false, message: "존재하지 않는 열림패스 정책입니다." };
  if (policy.happyMoneyPrice == null) return { success: false, message: "이 정책은 복주머니 구매가 불가능합니다(happyMoneyPrice 미설정)." };

  try {
    const newBalance = await prisma.$transaction(async (tx) => {
      const balance = await spendHappyMoneyInternal(tx, input.userId, policy.happyMoneyPrice!, "purchase", `열림패스 구매: ${policy.name}`);
      const now = new Date();
      const expiresAt = new Date(now.getTime() + policy.durationMin * 60_000);
      await tx.userPass.create({
        data: {
          userId: input.userId,
          policyId: policy.id,
          activatedAt: now,
          expiresAt,
          sourceType: "subscription",
          status: "active",
        },
      });
      return balance;
    });

    await logAdminAction({
      adminId: auth.session.adminUserId,
      action: "happy_money_simulate_purchase_open_pass",
      targetType: "user_pass",
      targetId: input.userId,
      after: { policyId: policy.id, price: policy.happyMoneyPrice, newHappyMoneyBalance: newBalance },
    });
    revalidateTestLab();
    return {
      success: true,
      message: `[시뮬레이션] 복주머니 ${policy.happyMoneyPrice.toLocaleString()} 차감 → ${policy.name} 구매 완료 (잔액 ${newBalance.toLocaleString()})`,
      data: { balance: newBalance },
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : "UNKNOWN";
    if (msg === "INSUFFICIENT_BALANCE") return { success: false, message: "잔액 부족: 복주머니가 부족하여 구매할 수 없습니다." };
    console.error("[adminSimulatePurchaseOpenPassViaHappyMoney] 실패:", e);
    return { success: false, message: "구매 시뮬레이션 중 오류가 발생했습니다." };
  }
}

export async function adminSimulatePurchaseSubscriptionOrGift(input: {
  userId: number;
  kind: "subscription" | "gift";
  amount: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  try {
    const newBalance = await prisma.$transaction((tx) =>
      spendHappyMoneyInternal(
        tx,
        input.userId,
        input.amount,
        "purchase",
        input.kind === "subscription" ? "[시뮬레이션] 구독 상품 구매" : "[시뮬레이션] 상품권 구매"
      )
    );
    await logAdminAction({
      adminId: auth.session.adminUserId,
      action: `happy_money_simulate_purchase_${input.kind}`,
      targetType: "user_happy_money",
      targetId: input.userId,
      after: { amount: input.amount, newBalance },
    });
    revalidateTestLab();
    return {
      success: true,
      message: `[시뮬레이션] 복주머니 ${input.amount.toLocaleString()} 차감 → ${
        input.kind === "subscription" ? "구독 상품" : "상품권"
      } 구매 완료 (잔액 ${newBalance.toLocaleString()})`,
      data: { balance: newBalance },
    };
  } catch (e) {
    const msg = e instanceof Error ? e.message : "UNKNOWN";
    if (msg === "INSUFFICIENT_BALANCE") return { success: false, message: "잔액 부족: 복주머니가 부족하여 구매할 수 없습니다." };
    console.error("[adminSimulatePurchaseSubscriptionOrGift] 실패:", e);
    return { success: false, message: "구매 시뮬레이션 중 오류가 발생했습니다." };
  }
}

export async function adminSimulateInsufficientBalance(input: { userId: number; amount: number }): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  try {
    await prisma.$transaction((tx) => spendHappyMoneyInternal(tx, input.userId, input.amount, "purchase", "[시뮬레이션] 잔액부족 실패 케이스"));
    return { success: false, message: "예상과 달리 차감에 성공했습니다(잔액이 충분했음). 실패 케이스를 재현하려면 더 큰 금액을 입력하세요." };
  } catch (e) {
    const msg = e instanceof Error ? e.message : "UNKNOWN";
    if (msg === "INSUFFICIENT_BALANCE") {
      return { success: true, message: "[시뮬레이션] 예상대로 잔액 부족으로 실패 처리되었습니다. (실제 잔액 변경 없음)" };
    }
    return { success: false, message: "예상치 못한 오류가 발생했습니다." };
  }
}

// ════════════════════════════════════════════════════════════════
// 4) 복주머니 테스트 (§6-4)
// ════════════════════════════════════════════════════════════════

export async function adminManualGrantLuckPouch(input: { userId: number; amount: number; memo: string }): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;
  if (input.amount <= 0) return { success: false, message: "지급 수량은 1 이상이어야 합니다." };

  // [재화 구조 정리 - 재연결] 죽은 LuckPouchWallet 대신 실제 원장(Wallet/POINT)에
  // 실제 앱과 동일한 earnLuckPouch()로 지급한다 — 이제 이 버튼이 실제 사용자
  // 잔액을 바꾼다(과거에는 아무도 읽지 않는 유령 잔액만 바뀌었음).
  const earnResult = await prisma.$transaction((tx) =>
    earnLuckPouch(tx, {
      userId: input.userId,
      amount: input.amount,
      sourceType: "admin_adjust",
      memo: input.memo || "관리자 수동 지급",
    })
  );
  const newBalance = earnResult.balanceAfter ?? 0;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "luck_pouch_grant",
    targetType: "user_luck_pouch",
    targetId: input.userId,
    after: { amount: input.amount, newBalance, memo: input.memo },
  });
  revalidateTestLab();
  return { success: true, message: `복주머니 ${input.amount.toLocaleString()} 지급 완료 (잔액 ${newBalance.toLocaleString()})`, data: { balance: newBalance } };
}

export async function adminManualDeductLuckPouch(input: { userId: number; amount: number; memo: string }): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;
  if (input.amount <= 0) return { success: false, message: "차감 수량은 1 이상이어야 합니다." };

  // [재화 구조 정리 - 재연결] 실제 원장(Wallet/POINT)에 spendLuckPouch()로 차감한다.
  const spendResult = await prisma.$transaction((tx) =>
    spendLuckPouch(tx, {
      userId: input.userId,
      amount: input.amount,
      sourceType: "admin_adjust",
      memo: input.memo || "관리자 수동 차감",
    })
  );

  if (!spendResult.ok) {
    return { success: false, message: "잔액 부족: 복주머니가 부족합니다." };
  }
  const newBalance = spendResult.balanceAfter ?? 0;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "luck_pouch_deduct",
    targetType: "user_luck_pouch",
    targetId: input.userId,
    after: { amount: input.amount, newBalance, memo: input.memo },
  });
  revalidateTestLab();
  return { success: true, message: `복주머니 ${input.amount.toLocaleString()} 차감 완료 (잔액 ${newBalance.toLocaleString()})`, data: { balance: newBalance } };
}

export async function adminSimulateLuckPouchRule(input: { userId: number; ruleId: number }): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const rule = await prisma.luckPouchRule.findUnique({ where: { id: input.ruleId } });
  if (!rule || rule.deletedAt) return { success: false, message: "존재하지 않는 복주머니 규칙입니다." };

  // [재화 구조 정리 - 재연결] 세 분기 모두 죽은 LuckPouchWallet 대신 실제
  // 원장(Wallet/POINT)을 사용한다. earn은 실제 적립 진입점과 동일하게
  // earnLuckPouch(일일 상한 클리핑 적용)를 쓰지만, purchase는 실결제로 얻는
  // 수량이라 일일 적립 상한 대상이 아니므로(다른 구매 시뮬레이션 함수들과 동일한
  // 원칙) 직접 지급한다. spend는 실제 소비 진입점과 동일하게 spendLuckPouch를 쓴다.
  try {
    if (rule.ruleType === "earn") {
      const earnResult = await prisma.$transaction((tx) =>
        earnLuckPouch(tx, {
          userId: input.userId,
          amount: rule.amount,
          sourceType: rule.actionType,
          sourceId: rule.id,
          memo: `[시뮬레이션] ${rule.name}`,
        })
      );
      const newBalance = earnResult.balanceAfter ?? 0;
      await logAdminAction({ adminId: auth.session.adminUserId, action: "luck_pouch_simulate_earn", targetType: "user_luck_pouch", targetId: input.userId, after: { ruleId: rule.id, newBalance } });
      revalidateTestLab();
      return { success: true, message: `[시뮬레이션] ${rule.name} → +${rule.amount} (잔액 ${newBalance.toLocaleString()})`, data: { balance: newBalance } };
    }

    if (rule.ruleType === "purchase") {
      const newBalance = await prisma.$transaction(async (tx) => {
        let wallet = await tx.wallet.findFirst({ where: { userId: input.userId, currencyType: "POINT", deletedAt: null } });
        if (!wallet) wallet = await tx.wallet.create({ data: { userId: input.userId, currencyType: "POINT", balance: 0 } });
        const balance = wallet.balance + rule.amount;
        await tx.wallet.update({ where: { id: wallet.id }, data: { balance, balanceSyncedAt: new Date() } });
        await tx.pointHistory.create({
          data: {
            walletId: wallet.id,
            userId: input.userId,
            amount: rule.amount,
            type: "earn",
            sourceType: "purchase",
            sourceId: rule.id,
            balanceAfter: balance,
            memo: `[시뮬레이션 구매] ${rule.name} (${(rule.cashPrice ?? 0).toLocaleString()}원)`,
          },
        });
        return balance;
      });
      await logAdminAction({ adminId: auth.session.adminUserId, action: "luck_pouch_simulate_purchase", targetType: "user_luck_pouch", targetId: input.userId, after: { ruleId: rule.id, newBalance } });
      revalidateTestLab();
      return { success: true, message: `[시뮬레이션] ${rule.name} 구매 → +${rule.amount} (잔액 ${newBalance.toLocaleString()})`, data: { balance: newBalance } };
    }

    // spend
    const spendResult = await prisma.$transaction((tx) =>
      spendLuckPouch(tx, {
        userId: input.userId,
        amount: rule.amount,
        sourceType: rule.actionType,
        sourceId: rule.id,
        memo: `[시뮬레이션] ${rule.name}`,
      })
    );
    if (!spendResult.ok) {
      return { success: false, message: "잔액 부족: 복주머니가 부족하여 사용할 수 없습니다." };
    }
    const newBalance = spendResult.balanceAfter ?? 0;
    await logAdminAction({ adminId: auth.session.adminUserId, action: "luck_pouch_simulate_spend", targetType: "user_luck_pouch", targetId: input.userId, after: { ruleId: rule.id, newBalance } });
    revalidateTestLab();
    return { success: true, message: `[시뮬레이션] ${rule.name} → -${rule.amount} (잔액 ${newBalance.toLocaleString()})`, data: { balance: newBalance } };
  } catch (e) {
    console.error("[adminSimulateLuckPouchRule] 실패:", e);
    return { success: false, message: "시뮬레이션 처리 중 오류가 발생했습니다." };
  }
}

// ════════════════════════════════════════════════════════════════
// 5) 통합 시뮬레이션 (§6-5 / §12 시나리오 1~8)
// ════════════════════════════════════════════════════════════════

export async function adminRunIntegratedScenario(input: {
  scenarioKey:
    | "purchase_happy_money_then_open_pass"
    | "earn_luck_pouch_then_spend"
    | "luck_pouch_highlight"
    | "expire_open_pass_then_relock"
    | "policy_reload_check";
  userId: number;
  productId?: number;
  policyId?: number;
  earnRuleId?: number;
  spendRuleId?: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const steps: string[] = [];

  switch (input.scenarioKey) {
    case "purchase_happy_money_then_open_pass": {
      if (!input.productId || !input.policyId) return { success: false, message: "productId, policyId가 필요합니다." };
      const r1 = await adminSimulatePurchaseHappyMoneyProduct({ userId: input.userId, productId: input.productId });
      steps.push(`1) 복주머니 충전: ${r1.message}`);
      if (!r1.success) return { success: false, message: steps.join("\n") };
      const r2 = await adminSimulatePurchaseOpenPassViaHappyMoney({ userId: input.userId, policyId: input.policyId });
      steps.push(`2) 열림패스 구매: ${r2.message}`);
      const snap = await adminGetUserAssetSnapshot(input.userId);
      steps.push(`3) 접근 상태 확인: isOpenPassActive=${snap.data?.isOpenPassActive}`);
      return { success: r2.success, message: steps.join("\n"), data: snap.data };
    }
    case "earn_luck_pouch_then_spend": {
      if (!input.earnRuleId || !input.spendRuleId) return { success: false, message: "earnRuleId, spendRuleId가 필요합니다." };
      const r1 = await adminSimulateLuckPouchRule({ userId: input.userId, ruleId: input.earnRuleId });
      steps.push(`1) 복주머니 적립: ${r1.message}`);
      const r2 = await adminSimulateLuckPouchRule({ userId: input.userId, ruleId: input.spendRuleId });
      steps.push(`2) 복주머니 사용(응원 등): ${r2.message}`);
      const snap = await adminGetUserAssetSnapshot(input.userId);
      steps.push(`3) 잔액 확인: ${snap.data?.luckPouchBalance}`);
      return { success: r2.success, message: steps.join("\n"), data: snap.data };
    }
    case "luck_pouch_highlight": {
      if (!input.spendRuleId) return { success: false, message: "spendRuleId(강조 규칙)가 필요합니다." };
      const r1 = await adminSimulateLuckPouchRule({ userId: input.userId, ruleId: input.spendRuleId });
      steps.push(`1) 글 강조 사용: ${r1.message}`);
      return { success: r1.success, message: steps.join("\n") };
    }
    case "expire_open_pass_then_relock": {
      const snapBefore = await adminGetUserAssetSnapshot(input.userId);
      const activePass = snapBefore.data?.activeOpenPass as { id: number } | null | undefined;
      if (!activePass) return { success: false, message: "활성 열림패스가 없어 만료 시나리오를 실행할 수 없습니다. 먼저 지급하세요." };
      const r1 = await adminForceExpireOpenPass(activePass.id);
      steps.push(`1) 열림패스 강제 만료: ${r1.message}`);
      const snapAfter = await adminGetUserAssetSnapshot(input.userId);
      steps.push(`2) 재잠금 확인: isOpenPassActive=${snapAfter.data?.isOpenPassActive}`);
      return { success: true, message: steps.join("\n"), data: snapAfter.data };
    }
    case "policy_reload_check": {
      steps.push("1) 정책값은 관리자 화면에서 변경 즉시 DB에 반영됩니다.");
      steps.push("2) Flutter 앱은 PolicySyncService.refreshAdminPolicies() 호출 시 최신 정책을 재조회합니다.");
      steps.push("3) 앱에서 '새로고침'을 눌러 변경된 정책(예: 정책 비활성화, 가격 변경)이 반영되는지 확인하세요.");
      return { success: true, message: steps.join("\n") };
    }
    default:
      return { success: false, message: "알 수 없는 시나리오입니다." };
  }
}

// ════════════════════════════════════════════════════════════════
// 8) 열림패스 광고 시뮬레이션 (§6-5/§11 관리자 테스트 요구사항)
//    checkAdRewardEligibility/grantOpenPass/resolveFallbackAttachment/recordAdRewardLog는
//    모두 open-pass-service.ts에 구현되어 있으며, 실제 앱의 /api/public/open-pass/
//    reward-complete·reward-failed 라우트와 완전히 동일한 함수를 호출한다
//    (§15 금지 원칙: 관리자 테스트와 실제 앱 동작이 다르면 안 됨).
// ════════════════════════════════════════════════════════════════

export async function adminSimulateAdRewardSuccess(input: {
  userId: number;
  policyId: number;
  adSourceId: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const eligibility = await checkAdRewardEligibility(input.userId, input.adSourceId);
  if (!eligibility.eligible) {
    const reasonLabel: Record<string, string> = {
      AD_SOURCE_NOT_FOUND: "존재하지 않는 광고소스입니다.",
      AD_SOURCE_INACTIVE: "이 광고소스는 현재 비활성 상태입니다.",
      AD_SOURCE_NOT_STARTED: "이 광고소스는 아직 노출 시작 전입니다.",
      AD_SOURCE_ENDED: "이 광고소스는 노출 기간이 종료되었습니다.",
      COOLDOWN: `쿨다운 중입니다. ${("cooldownRemainingSec" in eligibility && eligibility.cooldownRemainingSec) || 0}초 후 다시 시도하세요.`,
      DAILY_LIMIT_REACHED: "오늘의 일일 시청 제한에 도달했습니다.",
    };
    return { success: false, message: `[광고 성공 시뮬레이션 실패] ${reasonLabel[eligibility.reason] ?? eligibility.reason}` };
  }

  try {
    const { userPass, policy } = await grantOpenPass({
      userId: input.userId,
      policyId: input.policyId,
      sourceType: "ad",
    });
    await recordAdRewardLog({
      userId: input.userId,
      adSourceId: input.adSourceId,
      passPolicyId: input.policyId,
      result: "success",
      rewardGranted: true,
      userPassId: userPass.id,
    });
    await logAdminAction({
      adminId: auth.session.adminUserId,
      action: "open_pass_ad_reward_success_sim",
      targetType: "user_pass",
      targetId: userPass.id,
      after: { userId: input.userId, adSourceId: input.adSourceId, policyId: input.policyId },
    });
    revalidateTestLab();
    return {
      success: true,
      message: `[광고 성공 시뮬레이션] 광고 시청 완료 → ${policy.name} 지급 (만료: ${userPass.expiresAt.toLocaleString("ko-KR")})`,
      data: { userPassId: userPass.id, expiresAt: userPass.expiresAt.toISOString() },
    };
  } catch (e) {
    if (e instanceof OpenPassServiceError) return { success: false, message: e.message };
    console.error("[adminSimulateAdRewardSuccess] 실패:", e);
    return { success: false, message: "보상 지급 시뮬레이션 중 오류가 발생했습니다." };
  }
}

export async function adminSimulateAdRewardFail(input: {
  userId: number;
  adSourceId: number;
  policyId?: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  await recordAdRewardLog({
    userId: input.userId,
    adSourceId: input.adSourceId,
    passPolicyId: input.policyId ?? null,
    result: "fail",
    rewardGranted: false,
  });
  const fallback = await resolveFallbackAttachment(input.adSourceId, input.policyId ?? null);
  const policy = input.policyId ? await prisma.passPolicy.findUnique({ where: { id: input.policyId } }) : null;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_ad_reward_fail_sim",
    targetType: "open_pass_ad_source",
    targetId: input.adSourceId,
    after: { userId: input.userId, policyId: input.policyId },
  });
  revalidateTestLab();

  return {
    success: true,
    message: fallback
      ? `[광고 실패 시뮬레이션] 광고 시청 실패 → fallback 소재 "${fallback.fileName}"(${fallback.fileType}) 노출${
          policy?.happyMoneyPrice != null ? ` + "복주머니로 구매" 대체 CTA 노출(₩${policy.happyMoneyPrice})` : ""
        }`
      : `[광고 실패 시뮬레이션] 광고 시청 실패 → fallback 소재가 설정되지 않아 기본 안내 문구("잠시 후 다시 시도해주세요")를 노출합니다.`,
    data: {
      fallbackAttachment: fallback,
      alternateCtaHappyMoneyPurchase: policy?.happyMoneyPrice != null,
    },
  };
}

export async function adminSimulateAdRewardNoFill(input: {
  userId: number;
  adSourceId: number;
  policyId?: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  await recordAdRewardLog({
    userId: input.userId,
    adSourceId: input.adSourceId,
    passPolicyId: input.policyId ?? null,
    result: "no_fill",
    rewardGranted: false,
  });
  const fallback = await resolveFallbackAttachment(input.adSourceId, input.policyId ?? null);
  const policy = input.policyId ? await prisma.passPolicy.findUnique({ where: { id: input.policyId } }) : null;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_ad_reward_no_fill_sim",
    targetType: "open_pass_ad_source",
    targetId: input.adSourceId,
    after: { userId: input.userId, policyId: input.policyId },
  });
  revalidateTestLab();

  return {
    success: true,
    message: fallback
      ? `[광고 no-fill 시뮬레이션] 채워질 광고가 없음(no-fill) → fallback 소재 "${fallback.fileName}"(${fallback.fileType}) 노출${
          policy?.happyMoneyPrice != null ? ` + "복주머니로 구매" 대체 CTA 노출(₩${policy.happyMoneyPrice})` : ""
        }`
      : `[광고 no-fill 시뮬레이션] 채워질 광고가 없음(no-fill) → fallback 소재가 설정되지 않아 기본 안내 문구를 노출합니다.`,
    data: { fallbackAttachment: fallback, alternateCtaHappyMoneyPurchase: policy?.happyMoneyPrice != null },
  };
}

// [프리패스 테스트 인프라 §4/§8-B] 광고 "중도 취소"/"타임아웃" 시뮬레이션.
// fail/no_fill과 동일한 구조(fallback 안내 + 로그 기록)이나 result 값을 구분해서 기록한다.
// (§9 로그: fail/no_fill/cancel/timeout을 각각 다른 사유로 리포팅할 수 있어야 함)
export async function adminSimulateAdRewardCancel(input: {
  userId: number;
  adSourceId: number;
  policyId?: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  await recordAdRewardLog({
    userId: input.userId,
    adSourceId: input.adSourceId,
    passPolicyId: input.policyId ?? null,
    result: "cancel",
    rewardGranted: false,
  });
  const fallback = await resolveFallbackAttachment(input.adSourceId, input.policyId ?? null);
  const policy = input.policyId ? await prisma.passPolicy.findUnique({ where: { id: input.policyId } }) : null;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_ad_reward_cancel_sim",
    targetType: "open_pass_ad_source",
    targetId: input.adSourceId,
    after: { userId: input.userId, policyId: input.policyId },
  });
  revalidateTestLab();

  return {
    success: true,
    message: fallback
      ? `[광고 중도취소 시뮬레이션] 유저가 광고 시청을 중간에 닫음(cancel) → fallback 소재 "${fallback.fileName}"(${fallback.fileType}) 노출${
          policy?.happyMoneyPrice != null ? ` + "복주머니로 구매" 대체 CTA 노출(₩${policy.happyMoneyPrice})` : ""
        }`
      : `[광고 중도취소 시뮬레이션] 유저가 광고 시청을 중간에 닫음(cancel) → fallback 소재가 설정되지 않아 기본 안내 문구를 노출합니다.`,
    data: { fallbackAttachment: fallback, alternateCtaHappyMoneyPurchase: policy?.happyMoneyPrice != null },
  };
}

export async function adminSimulateAdRewardTimeout(input: {
  userId: number;
  adSourceId: number;
  policyId?: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  await recordAdRewardLog({
    userId: input.userId,
    adSourceId: input.adSourceId,
    passPolicyId: input.policyId ?? null,
    result: "timeout",
    rewardGranted: false,
  });
  const fallback = await resolveFallbackAttachment(input.adSourceId, input.policyId ?? null);
  const policy = input.policyId ? await prisma.passPolicy.findUnique({ where: { id: input.policyId } }) : null;

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_ad_reward_timeout_sim",
    targetType: "open_pass_ad_source",
    targetId: input.adSourceId,
    after: { userId: input.userId, policyId: input.policyId },
  });
  revalidateTestLab();

  return {
    success: true,
    message: fallback
      ? `[광고 타임아웃 시뮬레이션] 광고 로드/시청이 제한시간을 초과함(timeout) → fallback 소재 "${fallback.fileName}"(${fallback.fileType}) 노출${
          policy?.happyMoneyPrice != null ? ` + "복주머니로 구매" 대체 CTA 노출(₩${policy.happyMoneyPrice})` : ""
        }`
      : `[광고 타임아웃 시뮬레이션] 광고 로드/시청이 제한시간을 초과함(timeout) → fallback 소재가 설정되지 않아 기본 안내 문구를 노출합니다.`,
    data: { fallbackAttachment: fallback, alternateCtaHappyMoneyPurchase: policy?.happyMoneyPrice != null },
  };
}

// [프리패스 테스트 인프라 §8-A] "5분 남음 만들기" 빠른 테스트 버튼용.
// 유저의 현재 활성 패스(있으면) 만료시각을 "지금부터 N분 후"로 강제 조정한다.
// 없으면 새로 발급한다(둘 다 §13 "임박 만료 문구/재잠금" 테스트 시나리오를 즉시 재현하기 위함).
export async function adminSetOpenPassRemainingMinutes(input: {
  userId: number;
  policyId: number;
  remainingMinutes: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const now = new Date();
  const targetExpiresAt = new Date(now.getTime() + input.remainingMinutes * 60_000);

  const activePass = await prisma.userPass.findFirst({
    where: { userId: input.userId, status: "active", expiresAt: { gt: now } },
    orderBy: { expiresAt: "desc" },
  });

  let userPassId: number;
  if (activePass) {
    const updated = await prisma.userPass.update({
      where: { id: activePass.id },
      data: { expiresAt: targetExpiresAt },
    });
    userPassId = updated.id;
  } else {
    const policy = await prisma.passPolicy.findUnique({ where: { id: input.policyId } });
    if (!policy || policy.deletedAt) return { success: false, message: "존재하지 않는 프리패스 정책입니다." };
    const created = await prisma.userPass.create({
      data: {
        userId: input.userId,
        policyId: input.policyId,
        activatedAt: now,
        expiresAt: targetExpiresAt,
        sourceType: "test_mode",
        status: "active",
        grantedByAdminId: auth.session.adminUserId,
      },
    });
    userPassId = created.id;
  }

  await logAdminAction({
    adminId: auth.session.adminUserId,
    action: "open_pass_set_remaining_minutes",
    targetType: "user_pass",
    targetId: userPassId,
    after: { userId: input.userId, remainingMinutes: input.remainingMinutes, expiresAt: targetExpiresAt },
  });
  revalidateTestLab();

  return {
    success: true,
    message: `[남은시간 강제조정] 유저 #${input.userId}의 프리패스 남은시간을 ${input.remainingMinutes}분으로 설정했습니다(만료: ${targetExpiresAt.toLocaleString("ko-KR")}). 앱에서 "임박 만료" 문구/카운트다운을 확인하세요.`,
    data: { userPassId, expiresAt: targetExpiresAt.toISOString() },
  };
}

// [프리패스 테스트 인프라 §7/§8-A] "활성 중 추가지급(누적 확인)" 버튼용.
// grantOpenPass()를 그대로 호출해 실제 앱/광고보상 경로와 동일한 누적 로직을 태운다.
// 지급 전/후 만료시각을 함께 반환해 "정말 합산되었는지"를 관리자가 눈으로 확인할 수 있게 한다.
export async function adminGrantOpenPassAccumulationTest(input: {
  userId: number;
  policyId: number;
  durationOverrideMin: number;
}): Promise<SimResult> {
  const auth = await requireWriteAccess();
  if (!auth.ok) return auth.result;

  const now = new Date();
  const before = await prisma.userPass.findFirst({
    where: { userId: input.userId, status: "active", expiresAt: { gt: now } },
    orderBy: { expiresAt: "desc" },
  });
  const beforeExpiresAt = before?.expiresAt ?? null;

  try {
    const { userPass, policy } = await grantOpenPass({
      userId: input.userId,
      policyId: input.policyId,
      sourceType: "test_mode",
      durationOverrideMin: input.durationOverrideMin,
      grantedByAdminId: auth.session.adminUserId,
    });
    await logAdminAction({
      adminId: auth.session.adminUserId,
      action: "open_pass_accumulation_test",
      targetType: "user_pass",
      targetId: userPass.id,
      before: { expiresAt: beforeExpiresAt },
      after: { expiresAt: userPass.expiresAt },
    });
    revalidateTestLab();

    const beforeLabel = beforeExpiresAt
      ? `기존 만료 ${beforeExpiresAt.toLocaleString("ko-KR")}`
      : "기존 활성 패스 없음(신규 발급)";
    return {
      success: true,
      message: `[누적지급 테스트] ${beforeLabel} → ${policy.name} ${input.durationOverrideMin}분 추가 지급 → 새 만료 ${userPass.expiresAt.toLocaleString(
        "ko-KR"
      )}. 남은시간이 단순 교체가 아니라 합산되었는지 확인하세요.`,
      data: { beforeExpiresAt: beforeExpiresAt?.toISOString() ?? null, afterExpiresAt: userPass.expiresAt.toISOString() },
    };
  } catch (e) {
    if (e instanceof OpenPassServiceError) return { success: false, message: e.message };
    console.error("[adminGrantOpenPassAccumulationTest] 실패:", e);
    return { success: false, message: "누적지급 테스트 중 오류가 발생했습니다." };
  }
}

// [§11 "특정 광고소스 비활성 후 fallback 동작 확인" / "adUnitId 변경 후 앱 반영 확인"]
// 상품에 연결된 광고소스 중 앱이 실제로 어떤 것을 우선 사용할지 미리보기.
export async function adminPreviewProductAdConfig(input: { policyId: number; platform?: string }): Promise<SimResult> {
  await verifyAdminSession();
  const platform = input.platform ?? "all";
  const bindings = await prisma.openPassProductAdSource.findMany({
    where: {
      passPolicyId: input.policyId,
      isActive: true,
      OR: [{ platform }, { platform: "all" }],
    },
    include: { adSource: true },
    orderBy: { priority: "asc" },
  });
  const eligibleAdSources = bindings
    .filter((b) => b.adSource.isActive && !b.adSource.deletedAt)
    .map((b) => ({
      bindingId: b.id,
      adSourceId: b.adSourceId,
      sourceName: b.adSource.sourceName,
      sourceType: b.adSource.sourceType,
      adUnitId: b.adSource.adUnitId,
      priority: b.priority,
      isPrimary: b.isPrimary,
      testModeEnabled: b.adSource.testModeEnabled,
    }));
  return {
    success: true,
    message: eligibleAdSources.length > 0 ? `앱이 우선 사용할 광고소스: ${eligibleAdSources[0].sourceName}` : "연결된 활성 광고소스가 없습니다.",
    data: { eligibleAdSources },
  };
}

// ── 유저 검색(테스트랩 유저 선택 영역용) ──
export async function adminSearchUsers(query: string): Promise<SimResult> {
  await verifyAdminSession();
  const users = await prisma.user.findMany({
    where: query
      ? { OR: [{ nickname: { contains: query } }, { email: { contains: query } }] }
      : {},
    orderBy: { id: "asc" },
    take: 20,
    select: { id: true, nickname: true, email: true, status: true },
  });
  return { success: true, message: "조회 완료", data: { users } };
}
