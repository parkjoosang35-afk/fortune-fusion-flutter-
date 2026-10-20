// ══════════════════════════════════════════════════════════════════
// BokjuCouponService — 복주머니 마케팅 쿠폰(제휴업체 QR → 회원 등록 → 복주머니
// 적립) 공용 로직의 단일 소스.
//
// [출처] 외부에서 전달받은 Express+PostgreSQL 독립 서버 패키지
// (sintong-coupon-kit)의 핵심 도메인 로직(상태 전이표, 중복 등록 차단,
// 멱등성 처리, 업체 배정/회수)을 이 프로젝트의 실제 운영 스택
// (Next.js App Router + Prisma + SQLite)에 맞게 새로 이식한 것이다.
// 원본은 독립 Express 서버 + PostgreSQL 전제라 "app.ts 2줄 추가"로 끝나지
// 않았고(이 프로젝트엔 Express 서버 자체가 없음), 지갑 적립도 원본이
// 가정한 wallet_ledger 테이블이 아니라 기존 Wallet/PointHistory 원장을
// 그대로 써야 해서 전면 재작성했다.
//
// [지갑 연동 원칙 — 반드시 지킬 것]
//   복주머니 적립은 항상 luck-pouch-engine.ts의 earnLuckPouch()를 통해서만
//   한다. 이중 적립 차단은 PointHistory(sourceType="bokju_coupon",
//   sourceId=coupon.id)의 "존재 여부 선확인 + requestId 유니크 제약"
//   조합으로 보장한다(SQLite는 부분 유니크 인덱스를 지원하지 않으므로,
//   원본의 WHERE절 유니크 인덱스 대신 애플리케이션 레벨 체크를 쓴다).
//
// [상태 전이 — 20장 전이표 대응]
//   CREATED → ISSUED → ALLOCATED → DELIVERED → REDEEMED
//                 └──────────────→ ASSIGNED ──┘
//   REDEEMED/EXPIRED/REVOKED는 종료 상태(전이 불가).
//   ★ ISSUED 상태도 등록(redeem) 가능해야 한다 — 업체를 거치지 않는
//     직접배포(DIRECT) 쿠폰이 여기 빠지면 영원히 등록할 수 없다
//     (원본 패키지가 실행 검증 중 발견했다고 밝힌 치명적 버그 #1).
// ══════════════════════════════════════════════════════════════════
import { randomBytes, createHash, randomUUID } from "node:crypto";
import { prisma } from "@/lib/db";
import type { Prisma } from "@/generated/prisma/client";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { createNotification } from "@/lib/notification-engine";
import { initializeNewCampaignDesign } from "@/lib/bokju-coupon-design/studio-api";

type Tx = Prisma.TransactionClient;

export class BokjuCouponError extends Error {
  code: string;
  details?: unknown;
  constructor(code: string, message: string, details?: unknown) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 혼동 문자(I,O,0,1) 제외
const COUPON_PREFIX = process.env.BOKJU_COUPON_PREFIX ?? "ST";

/** 등록(redeem) 가능 상태 — ISSUED가 빠지면 직접배포 쿠폰이 영원히 등록 불가(버그 #1 재발 방지). */
const REDEEMABLE_FROM = new Set(["ISSUED", "ALLOCATED", "DELIVERED", "ASSIGNED"]);

const SOURCE_TYPE = "bokju_coupon";

// ────────────────────────────────────────────────────────── 발급
/** [카카오톡 스타일 쿠폰 디자인 템플릿 4종] bokju-coupon-image-service.ts의
 * renderCouponImage()가 지원하는 디자인 식별자와 동일한 값 집합을 쓴다. */
export type BokjuCouponDesignTemplate = "CLASSIC" | "PREMIUM" | "KAKAO" | "MINIMAL";
export const BOKJU_COUPON_DESIGN_TEMPLATES: BokjuCouponDesignTemplate[] = [
  "CLASSIC",
  "PREMIUM",
  "KAKAO",
  "MINIMAL",
];

export interface CreateCampaignInput {
  title: string;
  grantAmount: number;
  issueType?: "INDIVIDUAL" | "SHARED";
  targetAudience?: "ALL" | "NEW" | "EXISTING";
  useLimitPerMember?: number;
  sharedTotalLimit?: number;
  /** [마케팅 쿠폰 발행 관리 개선 §3-1] 총 발행 수량 상한. null/undefined = 무제한.
   * 양의 정수를 주면 issueCoupons()가 issuedCount 누적치와 원자적으로 비교해
   * 이 값을 넘는 발행을 막는다. API 레이어(POST campaigns route)에서 "기본값은
   * 무제한이 아닌 한정 수량"을 강제하므로, 여기서는 null도 허용해 하위호환을
   * 깨지 않는다(기존 테스트/스크립트가 이 필드 없이 호출해도 그대로 동작). */
  totalIssueLimit?: number | null;
  validFrom: Date;
  validTo: Date;
  guideText?: string;
  distributionMethod?: "DIRECT" | "PARTNER" | "GIFT";
  designTemplate?: BokjuCouponDesignTemplate;
  /** [AI 쿠폰 디자인 표시·숨김 기능] 저장된 커스텀 템플릿(BokjuCouponDesignTemplate) id.
   * 지정하면 designTemplate(4종 내장) 대신 이 템플릿의 배경+표시설정으로 렌더링한다.
   * null/undefined면 기존 4종 내장 템플릿 그대로 사용(하위 호환). */
  customTemplateId?: number | null;
}

export async function createCampaign(input: CreateCampaignInput, actorId: string) {
  if (input.validTo <= input.validFrom) {
    throw new BokjuCouponError("INVALID_PERIOD", "사용 만료일은 시작일보다 뒤여야 합니다.");
  }
  if (input.issueType === "SHARED" && !input.sharedTotalLimit) {
    throw new BokjuCouponError("SHARED_LIMIT_REQUIRED", "공용번호 쿠폰은 총 사용 한도가 필요합니다.");
  }
  if (input.totalIssueLimit != null && (!Number.isInteger(input.totalIssueLimit) || input.totalIssueLimit < 1)) {
    throw new BokjuCouponError("INVALID_TOTAL_ISSUE_LIMIT", "총 발행 수량은 1 이상의 정수이거나 무제한(비워둠)이어야 합니다.");
  }
  // [AI 쿠폰 디자인 표시·숨김 기능 §9] 보관(archive)된 템플릿을 새 캠페인에 연결하는
  // 것을 막는다 — 보관 템플릿은 "더 이상 신규 발급에 쓰지 않음"이 목적이므로, 여기서
  // 막지 않으면 보관 의미가 무력화된다. 존재하지 않는 id도 동일하게 차단한다.
  if (input.customTemplateId != null) {
    const tpl = await prisma.bokjuCouponDesignTemplate.findUnique({
      where: { id: input.customTemplateId },
      select: { id: true, isArchived: true },
    });
    if (!tpl) {
      throw new BokjuCouponError("TEMPLATE_NOT_FOUND", "선택한 디자인 템플릿을 찾을 수 없습니다.");
    }
    if (tpl.isArchived) {
      throw new BokjuCouponError("TEMPLATE_ARCHIVED", "보관 처리된 템플릿은 새 캠페인에 사용할 수 없습니다.");
    }
  }
  const campaign = await prisma.bokjuCouponCampaign.create({
    data: {
      title: input.title,
      grantAmount: input.grantAmount,
      issueType: input.issueType ?? "INDIVIDUAL",
      targetAudience: input.targetAudience ?? "ALL",
      useLimitPerMember: input.useLimitPerMember ?? 1,
      sharedTotalLimit: input.issueType === "SHARED" ? input.sharedTotalLimit : null,
      totalIssueLimit: input.totalIssueLimit ?? null,
      validFrom: input.validFrom,
      validTo: input.validTo,
      guideText: input.guideText,
      distributionMethod: input.distributionMethod ?? "PARTNER",
      designTemplate: input.designTemplate ?? "CLASSIC",
      customTemplateId: input.customTemplateId ?? null,
      status: "DRAFT",
      createdBy: actorId,
    },
  });

  // [작업순서6 — 02l §0-Q-2 결정 (a)] 신규 캠페인의 초기 리비전을
  // buildTemplate('classic', …) 기본값으로 즉시 동결해 currentDesignRevisionId
  // 를 채운다. 캠페인 생성 자체는 이미 커밋되었으므로, 리비전 생성이
  // 실패하더라도(이론상 불가능 — initializeNewCampaignDesign 내부에서
  // null 반환으로 방어됨) 캠페인 생성 자체를 되돌리지 않는다. 기존
  // 캠페인(1/23/24)은 이 함수가 새로 만든 campaign.id 만 인자로 받으므로
  // 전혀 접촉하지 않는다(조건② — 자동 전환 금지 유지).
  await initializeNewCampaignDesign(campaign.id, { createdBy: actorId });

  return { campaignId: campaign.id };
}

/**
 * [쿠폰번호 간소화 — 2026-12] 기존 "난수 12자 + 체크섬 2자"(예:
 * `ST-6K2CFNHFVP57-C8`, 총 17자)는 QR을 못 찍어 손으로 입력해야 하는
 * 고객 입장에서 너무 길다는 지적(사용자 리포트: "번호가 너무 길어서
 * 치다가 틀려요")에 따라 "난수 8자(4+4 그룹) + 체크섬 1자"로 줄인다
 * (예: `ST-6K2C-FNHF-P`, 총 13자 — 4자 끊어 읽기 쉽고 입력 실수도
 * 줄어든다). 32개 기호 알파벳(혼동 문자 제외) 기준 32^8 ≈ 1.1조
 * 조합으로, 등록 시도 횟수 제한([redeemCoupon]의 분당 10회 제한)과
 * 결합하면 추측 공격은 여전히 비현실적이다(§13 "쿠폰번호는 추측하기
 * 어렵게 생성" 요건 유지). 체크섬은 보안이 아니라 오타 자체 검출용
 * (예: "입력하신 번호에 오타가 있는 것 같아요" 같은 안내에 추후 활용
 * 가능 — 현재는 아직 별도 검증 로직을 추가하지 않음, 서버가 DB
 * 조회 실패로 자연히 "존재하지 않는 쿠폰"을 반환).
 *
 * [하위 호환] 기존에 이미 발급되어 인쇄/공유된 쿠폰(12자 바디 형식)은
 * 전혀 건드리지 않는다 — DB에 저장된 그대로 유효하며, 조회는 항상
 * 문자열 완전일치이므로 길이가 섞여 있어도 문제없다. 이 함수는
 * 새로 발급하는 쿠폰에만 적용된다.
 */
function generateCouponNo(): string {
  const raw = Array.from(randomBytes(8)).map((b) => ALPHABET[b % ALPHABET.length]).join("");
  const body = `${raw.slice(0, 4)}-${raw.slice(4, 8)}`;
  const checksum = createHash("sha1").update(raw).digest("hex").slice(0, 1).toUpperCase();
  return `${COUPON_PREFIX}-${body}-${checksum}`;
}

/**
 * [쿠폰번호 간소화 — 구조적 버그 수정, 2026-12] 지금까지 고객용 조회
 * (resolve/redeem) API는 오직 `redeemToken`(QR에만 인코딩되는 32자 hex)
 * 으로만 쿠폰을 찾았고, 쿠폰 이미지에 큼직하게 인쇄되는 `couponNo`는
 * 발급/표시(엑셀·이미지)에만 쓰일 뿐 조회에는 전혀 연결되어 있지
 * 않았다 — 즉 [BokjuCouponEntryScreen](Flutter "코드 직접 입력" 화면)에
 * 인쇄된 쿠폰번호를 그대로 입력하면 QR 형식(URL/hex)이 아니므로
 * "존재하지 않는 쿠폰"으로 100% 실패하는 치명적 버그였다(§5 "QR코드
 * 쿠폰번호 자동 입력 **또는 직접 입력**" 요건 미충족). 이 헬퍼를
 * resolve/redeem 양쪽에서 공용으로 써서, 사용자가 QR 토큰이든 인쇄된
 * couponNo든 어느 쪽을 입력해도 동일하게 조회되도록 한다.
 *
 * [정규화] couponNo는 항상 대문자로 저장되므로 비교 전 대문자 변환한다
 * (고객이 소문자로 치거나 대소문자가 섞여도 허용). redeemToken은
 * randomBytes().toString('hex')로 항상 소문자이므로 그대로 비교한다
 * (대문자 변환하면 오히려 QR 스캔 결과와 불일치할 수 있어 하지 않음).
 */
export async function findCouponByIdentifier(tx: Tx | typeof prisma, identifier: string) {
  const raw = identifier.trim();
  if (!raw) return null;
  return tx.bokjuCoupon.findFirst({
    where: { OR: [{ redeemToken: raw }, { couponNo: raw.toUpperCase() }] },
    include: { campaign: true },
  });
}

/** [등록 시도 제한 — §13 "등록 시도 횟수를 제한"] 최근 60초 이내 같은 회원의
 * 등록 시도(성공/실패 불문) 건수를 [BokjuCouponRedemption] 로그에서 센다.
 * 별도 카운터 테이블 없이 기존에 모든 시도마다 이미 남기고 있던
 * [logAttempt]/[logFailureOutsideTx] 기록을 그대로 재사용한다(소원방
 * [enforceRateLimitAndLog]와 동일한 설계 — wishroom-engine.ts
 * `checkRateLimit` 참고, 분당 10회 상한도 동일하게 맞춤). 쿠폰번호
 * 추측(무작위 대입) 공격 시 분당 10회로 제한되어, 32^8 조합 공간을
 * 현실적인 시간 내에 전수조사하는 것이 불가능해진다.
 */
async function enforceRedeemRateLimit(userId: number): Promise<void> {
  const since = new Date(Date.now() - 60_000);
  const recent = await prisma.bokjuCouponRedemption.count({ where: { userId, createdAt: { gte: since } } });
  if (recent >= 10) {
    throw new BokjuCouponError("RATE_LIMITED", "등록 시도가 너무 잦습니다. 잠시 후 다시 시도해 주세요.");
  }
}

/**
 * 쿠폰 대량 발행. SQLite는 PostgreSQL의 `ON CONFLICT DO NOTHING`처럼 다중
 * 유니크 제약을 한 INSERT 문으로 동시에 흡수하는 깔끔한 수단이 없으므로,
 * 건별로 create()하고 유니크 제약 충돌(P2002)만 재시도로 흡수한다
 * (원본 버그 #2 — "INSERT 하나에 ON CONFLICT 두 번 불가"와 동일한 문제의식을
 * SQLite 방식으로 재구현한 것).
 */
export async function issueCoupons(campaignId: number, count: number, actorId: string) {
  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
  if (!campaign) throw new BokjuCouponError("CAMPAIGN_NOT_FOUND", "캠페인을 찾을 수 없습니다.");
  if (campaign.status !== "ACTIVE") {
    throw new BokjuCouponError("CAMPAIGN_NOT_ACTIVE", "ACTIVE 상태의 캠페인만 발행할 수 있습니다.");
  }
  if (count < 1 || count > 1_000_000) {
    throw new BokjuCouponError("INVALID_COUNT", "발행 수량은 1 ~ 1,000,000 사이여야 합니다.");
  }

  // [마케팅 쿠폰 발행 관리 개선 §5-1,2] 총 발행 수량 선점 — 실제 쿠폰 행을
  // 만들기 전에 issuedCount를 "조건부로" 먼저 증가시킨다. 하나의 raw UPDATE
  // 문이라 SQLite에서 통째로 원자적으로 실행되므로, 여러 관리자가 동시에
  // 발행 버튼을 눌러도(동시성 제어) WHERE 조건(issued_count + count <=
  // total_issue_limit)을 만족하는 요청만 통과한다 — redeemCoupon()의 조건부
  // UPDATE 패턴(§3-3 "가장 중요한 한 줄")과 동일한 설계를 발행 측에도
  // 적용한 것이다. totalIssueLimit이 NULL이면 무제한이므로 조건 없이 통과.
  const reserved = await prisma.$executeRaw`
    UPDATE bokju_coupon_campaigns
    SET issued_count = issued_count + ${count}
    WHERE id = ${campaignId}
      AND status = 'ACTIVE'
      AND (total_issue_limit IS NULL OR issued_count + ${count} <= total_issue_limit)
  `;
  if (reserved === 0) {
    // 한도초과인지, 그 사이 상태가 바뀐 것인지 재조회해 정확한 사유를 안내한다.
    const fresh = await prisma.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    if (!fresh) throw new BokjuCouponError("CAMPAIGN_NOT_FOUND", "캠페인을 찾을 수 없습니다.");
    if (fresh.status !== "ACTIVE") {
      throw new BokjuCouponError("CAMPAIGN_NOT_ACTIVE", "ACTIVE 상태의 캠페인만 발행할 수 있습니다.");
    }
    const remaining = Math.max(0, (fresh.totalIssueLimit ?? 0) - fresh.issuedCount);
    throw new BokjuCouponError(
      "ISSUE_LIMIT_EXCEEDED",
      `총 발행 한도(${fresh.totalIssueLimit}장)를 초과합니다. 현재 발행 ${fresh.issuedCount}장, 추가 발행 가능 ${remaining}장.`
    );
  }

  let created = 0;
  let attempt = 0;
  while (created < count && attempt < count * 3 + 10) {
    attempt += 1;
    try {
      await prisma.bokjuCoupon.create({
        data: {
          campaignId,
          couponNo: generateCouponNo(),
          redeemToken: randomBytes(16).toString("hex"),
          status: "ISSUED",
          expiresAt: campaign.validTo,
          // [3단계 — 02d_3단계-리비전고정.md §3-3 "가장 중요한 한 줄"]
          // 쿠폰 행 생성 시점에 각인한다(렌더 시점에 조회하지 않는다).
          // campaign.currentDesignRevisionId 가 null 이면(레거시 캠페인,
          // 현재 3개 캠페인 전부 이 상태) 쿠폰도 null로 남아 기존
          // bokju-coupon-image-service.ts 경로를 그대로 탄다 — 하위 호환.
          designRevisionId: campaign.currentDesignRevisionId,
        },
      });
      created += 1;
    } catch (e) {
      // P2002 = 유니크 제약 충돌(coupon_no/redeem_token 우연히 중복) → 새 번호로 재시도
      if ((e as { code?: string }).code !== "P2002") throw e;
    }
  }
  if (created < count) {
    // [마케팅 쿠폰 발행 관리 개선 §5-5] 실제로 만들지 못한 수량만큼 위에서
    // 선점했던 issuedCount를 되돌려 집계가 실제 쿠폰 수와 어긋나지 않게 한다.
    const shortfall = count - created;
    await prisma.bokjuCouponCampaign.update({
      where: { id: campaignId },
      data: { issuedCount: { decrement: shortfall } },
    });
    throw new BokjuCouponError("ISSUE_INCOMPLETE", `요청 ${count}건 중 ${created}건만 생성되었습니다.`);
  }

  // issuedCount는 위 선점 단계에서 이미 전량 증가되었으므로 여기서 다시 증가시키지 않는다.
  return { issued: created };
}

export async function revokeCoupon(couponId: number, reason: string) {
  return prisma.$transaction(async (tx) => {
    const coupon = await tx.bokjuCoupon.findUnique({ where: { id: couponId } });
    if (!coupon) throw new BokjuCouponError("COUPON_NOT_FOUND", "쿠폰을 찾을 수 없습니다.");
    if (coupon.status === "REDEEMED") {
      throw new BokjuCouponError(
        "ALREADY_REDEEMED",
        "이미 적립된 쿠폰은 사용 중지할 수 없습니다. 적립 정정은 지갑 도메인 절차로 처리하세요."
      );
    }
    await tx.bokjuCoupon.update({
      where: { id: couponId },
      data: { status: "REVOKED", revokedAt: new Date(), revokedReason: reason, rowVersion: { increment: 1 } },
    });
    return { couponId, status: "REVOKED" };
  });
}

// ────────────────────────────────────────────────────────── 쿠폰/캠페인 삭제
// [복주머니 마케팅 쿠폰 — 쿠폰 삭제 기능]
// revokeCoupon()은 "사용 중지"(상태만 REVOKED로 바꾸는 soft 처리)이고, 아래
// 함수들은 실제로 DB row 자체를 지우는 hard delete다. 두 기능은 용도가 다르므로
// 공존시킨다(이미 운영 중인 revoke 플로우를 건드리지 않음).
//
// [핵심 안전장치 — 반드시 지킬 것] 이미 적립(REDEEMED)된 쿠폰은 그 자체로
// PointHistory(실제 지갑 적립 원장)와 연결된 금전적 사실 기록이다. 이걸 삭제하면
// "회원은 복주머니를 받았는데 관리자 화면에서는 쿠폰이 아예 없었던 것처럼
// 보이는" 회계 불일치가 발생한다. 따라서 REDEEMED 쿠폰은 단건이든 벌크든
// 캠페인 전체든 어떤 경로로도 삭제를 허용하지 않는다(강제 삭제 옵션 없음 —
// revoke조차 거부하는 것과 동일한 원칙을 더 엄격하게 적용).
const UNDELETABLE_COUPON_STATUSES = new Set(["REDEEMED"]);

/** 단건 쿠폰 삭제. REDEEMED는 거부. 캠페인 issuedCount(및 배정 상태였다면
 * allocatedCount)를 함께 보정해 집계 숫자가 삭제 후에도 실제 쿠폰 수와 어긋나지
 * 않도록 한다. */
export async function deleteCoupon(couponId: number) {
  return prisma.$transaction(async (tx) => {
    const coupon = await tx.bokjuCoupon.findUnique({ where: { id: couponId } });
    if (!coupon) throw new BokjuCouponError("COUPON_NOT_FOUND", "쿠폰을 찾을 수 없습니다.");
    if (UNDELETABLE_COUPON_STATUSES.has(coupon.status)) {
      throw new BokjuCouponError(
        "COUPON_ALREADY_USED",
        "이미 적립(등록 완료)된 쿠폰은 삭제할 수 없습니다. 적립 기록 보존을 위한 보호 조치입니다."
      );
    }

    await tx.bokjuCoupon.delete({ where: { id: couponId } });

    // 집계 보정: issuedCount는 항상 1 감소, allocatedCount는 배정된 적이 있었던
    // 경우(ALLOCATED/DELIVERED/ASSIGNED/RECALLED)에만 1 감소시킨다(미배정
    // ISSUED 상태였다면 allocatedCount에 애초에 포함되지 않았으므로 건드리지 않음).
    const wasAllocated = ["ALLOCATED", "DELIVERED", "ASSIGNED", "RECALLED"].includes(coupon.status);
    await tx.bokjuCouponCampaign.update({
      where: { id: coupon.campaignId },
      data: {
        issuedCount: { decrement: 1 },
        ...(wasAllocated ? { allocatedCount: { decrement: 1 } } : {}),
      },
    });

    return { couponId, campaignId: coupon.campaignId, couponNo: coupon.couponNo };
  });
}

/**
 * 벌크 쿠폰 삭제. 부분 실패를 허용한다 — 선택한 쿠폰 중 일부가 REDEEMED라고
 * 해서 전체 요청을 통째로 거부하면("하나라도 걸리면 전부 실패") 관리자가
 * 매번 하나씩 재시도해야 하는 번거로움이 생기므로, 삭제 가능한 건은 삭제하고
 * 불가능한 건은 사유와 함께 skipped 목록으로 반환한다(allocateToPartner() 등
 * 기존 "부분 처리를 조용히 넘기지 않는다" 원칙과 동일하게, 결과를 명시적으로
 * 알려준다 — 다만 여기서는 "조용히 넘기지 않되 막지도 않는다"는 차이가 있다).
 */
export async function bulkDeleteCoupons(couponIds: number[]) {
  if (couponIds.length === 0) {
    throw new BokjuCouponError("INVALID_INPUT", "삭제할 쿠폰을 선택해 주세요.");
  }
  if (couponIds.length > 5000) {
    throw new BokjuCouponError("TOO_MANY", "한 번에 최대 5,000건까지 삭제할 수 있습니다.");
  }

  return prisma.$transaction(async (tx) => {
    const coupons = await tx.bokjuCoupon.findMany({ where: { id: { in: couponIds } } });
    const foundIds = new Set(coupons.map((c) => c.id));

    const deletable = coupons.filter((c) => !UNDELETABLE_COUPON_STATUSES.has(c.status));
    const skipped: { couponId: number; couponNo: string; reason: string }[] = [];

    for (const id of couponIds) {
      if (!foundIds.has(id)) {
        skipped.push({ couponId: id, couponNo: "", reason: "NOT_FOUND" });
      }
    }
    for (const c of coupons) {
      if (UNDELETABLE_COUPON_STATUSES.has(c.status)) {
        skipped.push({ couponId: c.id, couponNo: c.couponNo, reason: "ALREADY_USED" });
      }
    }

    if (deletable.length === 0) {
      return { deletedCount: 0, skipped };
    }

    // 캠페인별로 묶어 issuedCount/allocatedCount 보정 폭을 미리 계산한다.
    const byCampaign = new Map<number, { issued: number; allocated: number }>();
    for (const c of deletable) {
      const entry = byCampaign.get(c.campaignId) ?? { issued: 0, allocated: 0 };
      entry.issued += 1;
      if (["ALLOCATED", "DELIVERED", "ASSIGNED", "RECALLED"].includes(c.status)) entry.allocated += 1;
      byCampaign.set(c.campaignId, entry);
    }

    await tx.bokjuCoupon.deleteMany({ where: { id: { in: deletable.map((c) => c.id) } } });

    for (const [campaignId, delta] of byCampaign) {
      await tx.bokjuCouponCampaign.update({
        where: { id: campaignId },
        data: {
          issuedCount: { decrement: delta.issued },
          ...(delta.allocated > 0 ? { allocatedCount: { decrement: delta.allocated } } : {}),
        },
      });
    }

    return { deletedCount: deletable.length, skipped };
  });
}

/**
 * 캠페인 전체 삭제. 하위에 REDEEMED 쿠폰이 단 한 장이라도 있으면 전체를
 * 거부한다(부분 삭제 불가 원칙 — "회원이 실제로 받은 복주머니 기록이 있는
 * 캠페인"은 통째로 보존해야 감사·정산 추적이 가능하다). 통과하면 연관된
 * 모든 하위 레코드를 트랜잭션으로 함께 정리한다:
 *   - BokjuCouponDeliveryReport(배정 보고서) → 배정 FK가 RESTRICT라 먼저 삭제
 *   - BokjuCouponAllocation(배정) → 쿠폰 FK가 RESTRICT라 먼저 삭제
 *   - BokjuCouponSharedUsage(공용번호 사용 이력)
 *   - BokjuCoupon(쿠폰 본체)
 *   - BokjuCouponImageJob / BokjuCouponPushJob(백그라운드 작업 — FK 제약 없지만
 *     고아 레코드 방지를 위해 함께 정리)
 *   - BokjuCouponRedemption(등록 시도 로그)는 FK가 SET NULL이라 자동으로
 *     campaignId만 NULL 처리되어 로그 자체는 보존된다(실패 이력까지 지우면
 *     "왜 그 캠페인이 삭제됐는지" 감사 추적이 끊기므로 의도적으로 보존).
 *   - BokjuCouponAuditLog도 동일하게 campaignId FK가 없어 로그가 그대로
 *     남는다(삭제 행위 자체도 감사 로그에 남겨야 하므로 당연히 보존).
 */
export async function deleteCampaign(campaignId: number) {
  return prisma.$transaction(async (tx) => {
    const campaign = await tx.bokjuCouponCampaign.findUnique({ where: { id: campaignId } });
    if (!campaign) throw new BokjuCouponError("CAMPAIGN_NOT_FOUND", "캠페인을 찾을 수 없습니다.");

    const redeemedCount = await tx.bokjuCoupon.count({ where: { campaignId, status: "REDEEMED" } });
    if (redeemedCount > 0) {
      throw new BokjuCouponError(
        "CAMPAIGN_HAS_REDEEMED_COUPONS",
        `이미 적립 완료된 쿠폰이 ${redeemedCount}장 있어 캠페인을 삭제할 수 없습니다. ` +
          `개별적으로 삭제 가능한 쿠폰만 정리하거나, 캠페인 상태를 CLOSED로 변경해 주세요.`
      );
    }

    const couponCount = await tx.bokjuCoupon.count({ where: { campaignId } });

    const allocations = await tx.bokjuCouponAllocation.findMany({ where: { campaignId }, select: { id: true } });
    const allocationIds = allocations.map((a) => a.id);
    if (allocationIds.length > 0) {
      await tx.bokjuCouponDeliveryReport.deleteMany({ where: { allocationId: { in: allocationIds } } });
    }
    await tx.bokjuCouponAllocation.deleteMany({ where: { campaignId } });
    await tx.bokjuCouponSharedUsage.deleteMany({ where: { campaignId } });
    await tx.bokjuCoupon.deleteMany({ where: { campaignId } });
    await tx.bokjuCouponImageJob.deleteMany({ where: { campaignId } });
    await tx.bokjuCouponPushJob.deleteMany({ where: { campaignId } });
    // BokjuCouponRedemption/BokjuCouponAuditLog는 의도적으로 보존(위 주석 참고).

    await tx.bokjuCouponCampaign.delete({ where: { id: campaignId } });

    return { campaignId, deletedCoupons: couponCount, title: campaign.title };
  });
}

// ────────────────────────────────────────────────────────── 회원 푸시 발송
// [최종본 §10 "기존 회원 푸시 알림" + §22.5 "배정 우선, 발송 실패는 배정을 취소하지 않음"]
// 이 프로젝트에는 FCM 발송 서비스 계정이 없으므로(별도 FCM 전용 서버를 새로
// 만들지 않는다는 notification-engine.ts의 기존 원칙과 동일하게), "실제 푸시
// 디바이스 발송" 대신 이미 존재하는 알림센터(Notification 테이블)에 실제로
// 쌓이는 것으로 구현한다. sendMode="BROADCAST"는 대상 조건(전체/신규/기존/지정)에
// 맞는 회원들에게 "이벤트 안내" 알림만 보낸다(개인별 쿠폰 사전 배정 없음 —
// 회원은 알림을 보고 평소처럼 QR/링크로 등록한다). sendMode="INDIVIDUAL"(개별
// 선물)은 원본 pseudocode(22.5 send_gift_push)와 동일하게 ① 쿠폰을 회원에게
// 먼저 배정하고 커밋한 뒤 ② 그 쿠폰의 등록 링크를 담아 알림을 보낸다 — 알림
// 발송(2단계)이 실패해도 ①의 배정은 되돌리지 않는다(쿠폰이 사라지면 안 됨).
const NEW_MEMBER_WINDOW_DAYS = 7; // resolve/redeem route와 동일 기준(신규회원 판정)

/** 알림 탭 시 이동할 딥링크 포맷 — wishDeepLink(notification-engine.ts)와 동일한 "type:id" 관례. */
function couponRedeemDeepLink(redeemToken: string): string {
  return `bokju_coupon:${redeemToken}`;
}
function couponCampaignDeepLink(campaignId: number): string {
  return `bokju_coupon_campaign:${campaignId}`;
}

export interface CreatePushJobInput {
  campaignId: number;
  sendMode: "BROADCAST" | "INDIVIDUAL";
  targetFilter?: "ALL" | "NEW" | "EXISTING" | "SPECIFIC";
  targetUserIds?: number[];
  title: string;
  body: string;
  scheduledAt?: Date;
  isTest?: boolean;
}

/** BROADCAST 대상 회원 ID 목록 조회(삭제/비활성 제외). SPECIFIC은 targetUserIds를 그대로 검증만 한다. */
async function resolveBroadcastAudience(
  filter: "ALL" | "NEW" | "EXISTING" | "SPECIFIC",
  targetUserIds: number[] | undefined
): Promise<number[]> {
  if (filter === "SPECIFIC") {
    if (!targetUserIds || targetUserIds.length === 0) {
      throw new BokjuCouponError("TARGET_REQUIRED", "지정 회원 발송은 회원 ID 목록이 필요합니다.");
    }
    const found = await prisma.user.findMany({
      where: { id: { in: targetUserIds }, deletedAt: null },
      select: { id: true },
    });
    return found.map((u) => u.id);
  }
  const where: Prisma.UserWhereInput = { deletedAt: null, status: "active" };
  if (filter === "NEW" || filter === "EXISTING") {
    const cutoff = new Date(Date.now() - NEW_MEMBER_WINDOW_DAYS * 24 * 60 * 60 * 1000);
    where.createdAt = filter === "NEW" ? { gte: cutoff } : { lt: cutoff };
  }
  const users = await prisma.user.findMany({ where, select: { id: true } });
  return users.map((u) => u.id);
}

/**
 * 푸시(알림) 작업 생성. 즉시 테스트 발송(isTest)이 아니면 작업 레코드를 만들고
 * 실제 발송은 백그라운드(runPushJob)로 넘긴 뒤 jobId를 즉시 반환한다
 * (이미지 생성 작업과 동일한 "202 + polling" 패턴 — bokju-coupon-image-service.ts 참고).
 */
export async function createPushJob(input: CreatePushJobInput, actorId: string) {
  const campaign = await prisma.bokjuCouponCampaign.findUnique({ where: { id: input.campaignId } });
  if (!campaign) throw new BokjuCouponError("CAMPAIGN_NOT_FOUND", "캠페인을 찾을 수 없습니다.");
  if (!input.title.trim()) throw new BokjuCouponError("TITLE_REQUIRED", "푸시 제목은 필수입니다.");
  if (!input.body.trim()) throw new BokjuCouponError("BODY_REQUIRED", "푸시 내용은 필수입니다.");

  if (input.sendMode === "INDIVIDUAL" && (!input.targetUserIds || input.targetUserIds.length === 0)) {
    throw new BokjuCouponError("TARGET_REQUIRED", "개별 선물 발송은 대상 회원을 선택해야 합니다.");
  }

  // ── 테스트 발송: 집계에 남기지 않고 지정한 1명에게만 즉시 보낸다(관리자 기기 확인 목적).
  if (input.isTest) {
    const testUserId = input.targetUserIds?.[0];
    if (!testUserId) {
      throw new BokjuCouponError("TEST_TARGET_REQUIRED", "테스트 발송은 확인할 회원 1명을 지정해야 합니다.");
    }
    const user = await prisma.user.findUnique({ where: { id: testUserId }, select: { id: true, deletedAt: true } });
    if (!user || user.deletedAt) throw new BokjuCouponError("USER_NOT_FOUND", "테스트 대상 회원을 찾을 수 없습니다.");

    const result = await prisma.$transaction((tx) =>
      createNotification(tx, {
        userId: testUserId,
        category: "marketing",
        title: `[테스트] ${input.title}`,
        body: input.body,
        deepLink: couponCampaignDeepLink(input.campaignId),
      })
    );
    return { test: true, targetCount: 1, created: result.created };
  }

  const job = await prisma.bokjuCouponPushJob.create({
    data: {
      campaignId: input.campaignId,
      sendMode: input.sendMode,
      targetFilter: input.sendMode === "INDIVIDUAL" ? "SPECIFIC" : input.targetFilter ?? "ALL",
      targetUserIds:
        input.sendMode === "INDIVIDUAL" || input.targetFilter === "SPECIFIC"
          ? JSON.stringify(input.targetUserIds ?? [])
          : null,
      title: input.title,
      body: input.body,
      deepLink: input.sendMode === "BROADCAST" ? couponCampaignDeepLink(input.campaignId) : null,
      scheduledAt: input.scheduledAt ?? null,
      status: "PENDING",
      createdBy: actorId,
    },
  });

  // 백그라운드 실행(await하지 않음) — generate-images와 동일한 비동기 작업 패턴.
  // 발송 시점="예약"(scheduledAt이 미래)인 경우, 원본 pseudocode의 워커 루프
  // (WHERE scheduled_at IS NULL OR scheduled_at <= now())를 별도 큐/크론 없이도
  // 만족시키기 위해 setTimeout으로 실제 실행을 그 시각까지 지연시킨다. 즉시 발송
  // ("즉시" 또는 scheduledAt 미지정/과거)은 지금까지와 동일하게 바로 실행한다.
  const delayMs = job.scheduledAt ? job.scheduledAt.getTime() - Date.now() : 0;
  if (delayMs > 0) {
    setTimeout(() => {
      void runPushJob(job.id).catch((e) => {
        console.error(`[BokjuCouponPushJob ${job.id}] 예약 실행 중 예외:`, e);
      });
    }, delayMs);
  } else {
    void runPushJob(job.id).catch((e) => {
      console.error(`[BokjuCouponPushJob ${job.id}] 실행 중 예외:`, e);
    });
  }

  return { pushJobId: job.id };
}

/**
 * INDIVIDUAL(선물) 1명분 — 쿠폰을 먼저 배정하고 "반드시 커밋"한다.
 * 조건부 UPDATE(상태=ISSUED인 것 중 1건)로 동시 발송 작업끼리 같은 쿠폰을
 * 집어가는 경합을 방지한다(allocateToPartner와 동일한 원리, 단 배정 단위는
 * 1건·대상은 회원이라는 점만 다르다).
 */
async function assignOneCouponToMember(campaignId: number, userId: number): Promise<{ redeemToken: string } | null> {
  return prisma.$transaction(async (tx) => {
    const candidate = await tx.bokjuCoupon.findFirst({
      where: { campaignId, status: "ISSUED" },
      orderBy: { id: "asc" },
      select: { id: true, rowVersion: true, redeemToken: true },
    });
    if (!candidate) return null;
    const claimed = await tx.bokjuCoupon.updateMany({
      where: { id: candidate.id, status: "ISSUED", rowVersion: candidate.rowVersion },
      data: { status: "ASSIGNED", assignedUserId: userId, rowVersion: { increment: 1 } },
    });
    if (claimed.count === 0) return null; // 다른 트랜잭션이 먼저 가져감 — 이번 대상은 실패 처리(호출부에서 재시도)
    return { redeemToken: candidate.redeemToken };
  });
}

/** 백그라운드 발송 루프. 대상별 성공/실패만 집계하고(원본 push_target 상세 테이블은 범위 밖), 실패해도 이미 배정된 쿠폰은 그대로 둔다. */
async function runPushJob(jobId: number): Promise<void> {
  const job = await prisma.bokjuCouponPushJob.findUnique({ where: { id: jobId } });
  if (!job) return;

  await prisma.bokjuCouponPushJob.update({ where: { id: jobId }, data: { status: "SENDING" } });

  let targetIds: number[];
  if (job.sendMode === "INDIVIDUAL" || job.targetFilter === "SPECIFIC") {
    targetIds = job.targetUserIds ? (JSON.parse(job.targetUserIds) as number[]) : [];
  } else {
    targetIds = await resolveBroadcastAudience(
      job.targetFilter as "ALL" | "NEW" | "EXISTING",
      undefined
    );
  }

  let success = 0;
  let fail = 0;

  for (const userId of targetIds) {
    try {
      let deepLink = job.deepLink ?? couponCampaignDeepLink(job.campaignId);

      if (job.sendMode === "INDIVIDUAL") {
        // ① 쿠폰 배정 — 커밋 완료(이 시점부터 쿠폰은 회원 소유, 아래 알림이 실패해도 유지).
        const assigned = await assignOneCouponToMember(job.campaignId, userId);
        if (!assigned) {
          fail += 1; // 배정할 ISSUED 쿠폰이 소진됨 — 알림도 보내지 않는다(22.5 발송 순서 원칙).
          continue;
        }
        deepLink = couponRedeemDeepLink(assigned.redeemToken);
      }

      // ② 알림 발송(실패해도 위 배정은 되돌리지 않음 — 별도 트랜잭션).
      await prisma.$transaction((tx) =>
        createNotification(tx, {
          userId,
          category: "marketing",
          title: job.title,
          body: job.body,
          deepLink,
        })
      );
      success += 1;
    } catch (e) {
      console.error(`[BokjuCouponPushJob ${jobId}] 대상 회원 ${userId} 처리 실패:`, e);
      fail += 1;
    }
  }

  await prisma.bokjuCouponPushJob.update({
    where: { id: jobId },
    data: {
      status: fail > 0 ? (success > 0 ? "PARTIAL" : "FAILED") : "COMPLETED",
      successCount: success,
      failCount: fail,
      completedAt: new Date(),
    },
  });
}

export async function getPushJob(jobId: number) {
  return prisma.bokjuCouponPushJob.findUnique({ where: { id: jobId } });
}

export async function listPushJobsForCampaign(campaignId: number) {
  return prisma.bokjuCouponPushJob.findMany({
    where: { campaignId },
    orderBy: { createdAt: "desc" },
  });
}

// ────────────────────────────────────────────────────────── 업체 배정
export async function registerPartner(input: { name: string; managerName?: string; managerContact?: string }) {
  const partner = await prisma.bokjuPartner.create({ data: input });
  return { partnerId: partner.id };
}

export interface PartnerScope {
  partnerId: number;
  accountId: number;
  role: "PARTNER_ADMIN" | "PARTNER_STAFF";
}

export async function allocateToPartner(
  input: { campaignId: number; partnerId: number; qty: number; distributeDeadline?: Date },
  actorId: string
) {
  return prisma.$transaction(async (tx) => {
    const campaign = await tx.bokjuCouponCampaign.findUnique({ where: { id: input.campaignId } });
    if (!campaign) throw new BokjuCouponError("CAMPAIGN_NOT_FOUND", "캠페인을 찾을 수 없습니다.");

    const availableCoupons = await tx.bokjuCoupon.findMany({
      where: { campaignId: input.campaignId, status: "ISSUED" },
      take: input.qty,
      orderBy: { id: "asc" },
    });
    if (availableCoupons.length < input.qty) {
      throw new BokjuCouponError(
        "ALLOCATION_EXCEEDED",
        `미배정 수량이 부족합니다. 가용 ${availableCoupons.length}장 / 요청 ${input.qty}장`
      );
    }

    const allocation = await tx.bokjuCouponAllocation.create({
      data: {
        campaignId: input.campaignId,
        partnerId: input.partnerId,
        allocatedQty: input.qty,
        distributeDeadline: input.distributeDeadline,
        createdBy: actorId,
      },
    });

    // ★ 부분 배정을 조용히 넘기지 않는다 — 건별 UPDATE가 모두 적용됐는지 결과로 확인.
    const result = await tx.bokjuCoupon.updateMany({
      where: { id: { in: availableCoupons.map((c) => c.id) }, status: "ISSUED" },
      data: { status: "ALLOCATED", partnerId: input.partnerId, allocationId: allocation.id },
    });
    if (result.count !== input.qty) {
      throw new BokjuCouponError(
        "ALLOCATION_EXCEEDED",
        `배정 가능한 쿠폰이 부족합니다. 요청 ${input.qty}장 / 실제 ${result.count}장`
      );
    }

    await tx.bokjuCouponCampaign.update({
      where: { id: input.campaignId },
      data: { allocatedCount: { increment: input.qty } },
    });

    return { allocationId: allocation.id };
  });
}

export async function markDelivered(allocationId: number) {
  return prisma.$transaction(async (tx) => {
    const result = await tx.bokjuCouponAllocation.updateMany({
      where: { id: allocationId, status: "ALLOCATED" },
      data: { deliveredAt: new Date(), status: "DELIVERED" },
    });
    if (result.count === 0) throw new BokjuCouponError("INVALID_ALLOCATION_STATE", "배정 상태가 아닙니다.");
    await tx.bokjuCoupon.updateMany({
      where: { allocationId, status: "ALLOCATED" },
      data: { status: "DELIVERED" },
    });
    return { allocationId, status: "DELIVERED" };
  });
}

export async function listMyAllocations(scope: PartnerScope) {
  const allocations = await prisma.bokjuCouponAllocation.findMany({
    where: { partnerId: scope.partnerId },
    include: { campaign: true, reports: true },
    orderBy: { createdAt: "desc" },
  });
  return Promise.all(
    allocations.map(async (a) => {
      const redeemedQty = await prisma.bokjuCoupon.count({
        where: { allocationId: a.id, status: "REDEEMED" },
      });
      const reportedQty = a.reports.reduce((sum, r) => sum + r.reportedQty, 0);
      return {
        allocationId: a.id,
        campaignId: a.campaignId,
        title: a.campaign.title,
        allocatedQty: a.allocatedQty,
        deliveredAt: a.deliveredAt,
        acknowledgedAt: a.acknowledgedAt,
        distributeDeadline: a.distributeDeadline,
        status: a.status,
        redeemedQty,
        reportedQty,
      };
    })
  );
}

export async function acknowledgeAllocation(scope: PartnerScope, allocationId: number) {
  const result = await prisma.bokjuCouponAllocation.updateMany({
    where: { id: allocationId, partnerId: scope.partnerId },
    data: { acknowledgedAt: new Date() },
  });
  if (result.count === 0) throw new BokjuCouponError("PARTNER_FORBIDDEN", "본인 업체의 배정이 아닙니다.");
  return { allocationId, acknowledged: true };
}

export async function reportDistribution(
  scope: PartnerScope,
  allocationId: number,
  input: { qty: number; date: Date; method: string; note?: string }
) {
  return prisma.$transaction(async (tx) => {
    const allocation = await tx.bokjuCouponAllocation.findUnique({ where: { id: allocationId } });
    if (!allocation || allocation.partnerId !== scope.partnerId) {
      throw new BokjuCouponError("PARTNER_FORBIDDEN", "본인 업체의 배정이 아닙니다.");
    }
    const existing = await tx.bokjuCouponDeliveryReport.aggregate({
      where: { allocationId },
      _sum: { reportedQty: true },
    });
    const prevTotal = existing._sum.reportedQty ?? 0;
    const nextTotal = prevTotal + input.qty;
    if (nextTotal > allocation.allocatedQty) {
      throw new BokjuCouponError(
        "REPORT_EXCEEDED",
        `보고 합계가 배정 수량을 초과합니다. 배정 ${allocation.allocatedQty}장 / 누적 보고 ${prevTotal}장 / 잔여 ${allocation.allocatedQty - prevTotal}장`
      );
    }
    const report = await tx.bokjuCouponDeliveryReport.create({
      data: {
        allocationId,
        partnerId: scope.partnerId,
        reportedQty: input.qty,
        reportedDate: input.date,
        method: input.method,
        note: input.note,
        createdBy: String(scope.accountId),
      },
    });
    await tx.bokjuCouponAllocation.update({ where: { id: allocationId }, data: { status: "REPORTED" } });
    return { reportId: report.id, cumulative: nextTotal };
  });
}

/** 업체 보고 수치(reportedQty)와 시스템이 실제 확인한 등록 수치(redeemedQty)는 항상 분리해서 반환한다 — 절대 합치지 않는다. */
export async function myStats(scope: PartnerScope, allocationId: number) {
  const allocation = await prisma.bokjuCouponAllocation.findUnique({ where: { id: allocationId } });
  if (!allocation || allocation.partnerId !== scope.partnerId) {
    throw new BokjuCouponError("PARTNER_FORBIDDEN", "본인 업체의 배정이 아닙니다.");
  }
  const [reportAgg, redeemedQty, remainingQty] = await Promise.all([
    prisma.bokjuCouponDeliveryReport.aggregate({ where: { allocationId }, _sum: { reportedQty: true } }),
    prisma.bokjuCoupon.count({ where: { allocationId, status: "REDEEMED" } }),
    prisma.bokjuCoupon.count({ where: { allocationId, status: { in: ["ALLOCATED", "DELIVERED"] } } }),
  ]);
  const allocatedQty = allocation.allocatedQty;
  return {
    allocatedQty,
    reportedQty: reportAgg._sum.reportedQty ?? 0, // ★ 업체가 제출한 수치
    redeemedQty, // ★ 시스템이 확인한 실제 등록 — reportedQty와 혼동 금지
    remainingQty,
    redemptionRate: allocatedQty ? +((redeemedQty / allocatedQty) * 100).toFixed(1) : 0,
    measuredAt: new Date().toISOString(), // ★ 집계 시점을 항상 함께 표시
  };
}

// ────────────────────────────────────────────────────────── 회수/재배정
export async function recallUnregistered(allocationId: number, confirm = false) {
  return prisma.$transaction(async (tx) => {
    const allocation = await tx.bokjuCouponAllocation.findUnique({ where: { id: allocationId } });
    if (!allocation) throw new BokjuCouponError("ALLOCATION_NOT_FOUND", "배정을 찾을 수 없습니다.");

    const targets = await tx.bokjuCoupon.findMany({
      where: {
        allocationId,
        status: { in: ["ALLOCATED", "DELIVERED"] },
        redeemedAt: null,
        assignedUserId: null,
      },
    });

    const reportAgg = await tx.bokjuCouponDeliveryReport.aggregate({
      where: { allocationId },
      _sum: { reportedQty: true },
    });
    const reportedTotal = reportAgg._sum.reportedQty ?? 0;

    if (!confirm && reportedTotal > targets.length) {
      throw new BokjuCouponError(
        "RECALL_CONFIRM_REQUIRED",
        `업체 보고 ${reportedTotal}장 중 미등록은 ${targets.length}장입니다. ` +
          `고객이 받았지만 아직 등록하지 않았을 수 있으니 확인 후 진행하세요.`,
        { reportedQty: reportedTotal, unregistered: targets.length }
      );
    }

    if (targets.length === 0) return { recalledQty: 0, couponIds: [] as number[] };

    const ids = targets.map((t) => t.id);
    await tx.bokjuCoupon.updateMany({
      where: { id: { in: ids } },
      data: { status: "RECALLED", rowVersion: { increment: 1 } },
    });
    await tx.bokjuCouponAllocation.update({
      where: { id: allocationId },
      data: { recalledQty: { increment: ids.length }, status: "RECALLED" },
    });
    return { recalledQty: ids.length, couponIds: ids };
  });
}

/**
 * [스펙 §9/§22.6 재배정] 회수(RECALLED)된 쿠폰을 다른(또는 동일) 업체에 재배정한다.
 * 재배정 조건(§9 "재배정 조건"): "아직 사용되지 않았고(redeemedAt null) 다른 회원에게
 * 유효하게 배정되지 않은(assignedUserId null) 쿠폰만" 허용 — 고객에게 이미 전달된
 * 쿠폰이 갑자기 무효가 되는 일을 막기 위함이다.
 *
 * allocateToPartner()와 동일하게 "부분 재배정을 조용히 넘기지 않는다" 원칙을 따르며,
 * 새 BokjuCouponAllocation 레코드를 생성해 기존(RECALLED) allocation과 실적 집계가
 * 섞이지 않도록 한다. campaign.allocatedCount는 최초 배정 시 이미 1회 증가했으므로
 * 재배정 시에는 다시 증가시키지 않는다(동일 쿠폰이 업체만 바뀌어 순환할 뿐 신규 발행이
 * 아니기 때문 — 중복 카운트 방지).
 */
export async function reassignRecalledCoupons(
  input: { campaignId: number; newPartnerId: number; qty: number; distributeDeadline?: Date },
  actorId: string
) {
  return prisma.$transaction(async (tx) => {
    const campaign = await tx.bokjuCouponCampaign.findUnique({ where: { id: input.campaignId } });
    if (!campaign) throw new BokjuCouponError("CAMPAIGN_NOT_FOUND", "캠페인을 찾을 수 없습니다.");

    const partner = await tx.bokjuPartner.findUnique({ where: { id: input.newPartnerId } });
    if (!partner) throw new BokjuCouponError("PARTNER_NOT_FOUND", "재배정 대상 업체를 찾을 수 없습니다.");

    const candidates = await tx.bokjuCoupon.findMany({
      where: {
        campaignId: input.campaignId,
        status: "RECALLED",
        redeemedAt: null,
        assignedUserId: null,
      },
      take: input.qty,
      orderBy: { id: "asc" },
    });
    if (candidates.length < input.qty) {
      throw new BokjuCouponError(
        "REASSIGN_EXCEEDED",
        `재배정 가능한 회수 쿠폰이 부족합니다. 가용 ${candidates.length}장 / 요청 ${input.qty}장`
      );
    }

    const allocation = await tx.bokjuCouponAllocation.create({
      data: {
        campaignId: input.campaignId,
        partnerId: input.newPartnerId,
        allocatedQty: input.qty,
        distributeDeadline: input.distributeDeadline,
        createdBy: actorId,
      },
    });

    // ★ 부분 재배정을 조용히 넘기지 않는다 — 건별 UPDATE가 모두 적용됐는지 결과로 확인.
    const result = await tx.bokjuCoupon.updateMany({
      where: { id: { in: candidates.map((c) => c.id) }, status: "RECALLED" },
      data: {
        status: "ALLOCATED",
        partnerId: input.newPartnerId,
        allocationId: allocation.id,
        rowVersion: { increment: 1 },
      },
    });
    if (result.count !== input.qty) {
      throw new BokjuCouponError(
        "REASSIGN_EXCEEDED",
        `재배정 가능한 쿠폰이 부족합니다. 요청 ${input.qty}장 / 실제 ${result.count}장`
      );
    }

    return { allocationId: allocation.id, reassignedQty: result.count };
  });
}

// ────────────────────────────────────────────────────────── 등록(redeem) — 심장부
export interface RedeemInput {
  userId: number;
  token: string;
  idempotencyKey: string;
  isNewMember?: boolean;
}

export type RedeemResult =
  | {
      ok: true;
      code: "SUCCESS";
      grantedAmount: number;
      balanceAfter: number;
      couponNoMasked: string;
      redeemedAt: string;
      replayed: boolean;
    }
  | { ok: false; code: string; message: string };

function maskCouponNo(couponNo: string): string {
  const parts = couponNo.split("-");
  if (parts.length < 3) return couponNo.slice(0, 2) + "****";
  return `${parts[0]}-****-${parts[parts.length - 1].slice(-4)}`;
}

function failure(code: string, message: string): RedeemResult {
  return { ok: false, code, message };
}

/**
 * 쿠폰 등록 — 복주머니 적립까지 한 트랜잭션으로 처리한다.
 *
 * 동시성/중복 방지 설계(SQLite 전용, 원본의 PostgreSQL 부분 유니크 인덱스를
 * 대체):
 *   1) 먼저 idempotencyKey(=requestId)로 재전송 여부를 확인 → 재전송이면
 *      최초 결과를 그대로 반환(재지급 없음).
 *   2) 트랜잭션 내부에서 coupon.status가 REDEEMABLE_FROM에 속하는지 재확인한
 *      뒤, BokjuCouponRedemption(requestId UNIQUE)을 먼저 insert해 멱등성을
 *      확보하고, 이어서 coupon.status를 REDEEMED로 조건부 UPDATE
 *      (WHERE status IN REDEEMABLE_FROM AND rowVersion=기존값)한다. 이
 *      UPDATE가 0행이면 동시에 다른 요청이 먼저 성공한 것이므로 전체
 *      롤백하고 ALREADY_USED로 처리한다 — Prisma($transaction, SQLite는
 *      기본적으로 트랜잭션을 직렬화하므로 "먼저 커밋한 쪽이 이긴다"가
 *      그대로 성립한다.
 *   3) 복주머니 적립은 반드시 earnLuckPouch()를 통하고, sourceId=coupon.id로
 *      귀속시켜 나중에 PointHistory만 보고도 어느 쿠폰 적립인지 추적 가능.
 */
export async function redeemCoupon(input: RedeemInput): Promise<RedeemResult> {
  const { userId, token, idempotencyKey } = input;

  // ── 0) 멱등키 재전송이면 최초 결과를 그대로 반환 (재전송은 추측 공격이
  //      아니라 네트워크 재시도 등 정상 흐름이므로 분당 제한 카운트 전에 처리)
  const replay = await prisma.bokjuCouponRedemption.findUnique({ where: { requestId: idempotencyKey } });
  if (replay) {
    if (replay.result !== "SUCCESS") return failure("ALREADY_USED", "이미 처리된 요청입니다.");
    const coupon = replay.couponId ? await prisma.bokjuCoupon.findUnique({ where: { id: replay.couponId } }) : null;
    return {
      ok: true,
      code: "SUCCESS",
      grantedAmount: replay.grantedAmount ?? 0,
      balanceAfter: replay.balanceAfter ?? 0,
      couponNoMasked: coupon ? maskCouponNo(coupon.couponNo) : "",
      redeemedAt: replay.createdAt.toISOString(),
      replayed: true,
    };
  }

  // ── 0.5) 등록 시도 횟수 제한(§13) — 실제 신규 시도에 대해서만 적용,
  //        트랜잭션 진입 전에 걸러내어 불필요한 DB 쓰기를 막는다.
  try {
    await enforceRedeemRateLimit(userId);
  } catch (err) {
    if (err instanceof BokjuCouponError) {
      return failure(err.code, err.message);
    }
    throw err;
  }

  try {
    return await prisma.$transaction(async (tx) => {
      const now = new Date();
      const coupon = await findCouponByIdentifier(tx, token);

      if (!coupon) {
        await logAttempt(tx, null, null, userId, "INVALID", "COUPON_NOT_FOUND", idempotencyKey);
        return failure("INVALID", "존재하지 않거나 사용할 수 없는 쿠폰입니다.");
      }

      if (coupon.campaign.status === "PAUSED" || coupon.campaign.status === "CLOSED") {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "REVOKED", "CAMPAIGN_PAUSED", idempotencyKey);
        return failure("REVOKED", "중지된 이벤트의 쿠폰입니다.");
      }
      if (coupon.status === "REDEEMED") {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "DUPLICATE", "ALREADY_REDEEMED", idempotencyKey);
        return failure("ALREADY_USED", "이미 등록된 쿠폰입니다.");
      }
      if (coupon.status === "REVOKED" || coupon.status === "RECALLED") {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "REVOKED", coupon.status, idempotencyKey);
        return failure("REVOKED", "사용이 중지되었거나 회수된 쿠폰입니다.");
      }
      if (coupon.status === "EXPIRED" || coupon.expiresAt <= now) {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "EXPIRED", "EXPIRED", idempotencyKey);
        return failure("EXPIRED", "사용 기간이 만료된 쿠폰입니다.");
      }
      if (!REDEEMABLE_FROM.has(coupon.status)) {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "INVALID", `STATUS_${coupon.status}`, idempotencyKey);
        return failure("INVALID", "아직 등록할 수 없는 쿠폰입니다.");
      }
      if (coupon.assignedUserId && coupon.assignedUserId !== userId) {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "NOT_TARGET", "NOT_ASSIGNED", idempotencyKey);
        return failure("NOT_TARGET", "본인에게 배정된 쿠폰이 아닙니다.");
      }
      if (!isEligible(coupon.campaign.targetAudience, input.isNewMember, coupon.assignedUserId, userId)) {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "NOT_TARGET", "AUDIENCE_MISMATCH", idempotencyKey);
        return failure("NOT_TARGET", "이 쿠폰의 사용 대상이 아닙니다.");
      }

      // 회원당 사용 제한
      const usedCount = await tx.bokjuCouponRedemption.count({
        where: { userId, campaignId: coupon.campaignId, result: "SUCCESS" },
      });
      if (usedCount >= coupon.campaign.useLimitPerMember) {
        await logAttempt(tx, coupon.id, coupon.campaignId, userId, "NOT_TARGET", "LIMIT_EXCEEDED", idempotencyKey);
        return failure("LIMIT_EXCEEDED", `이 쿠폰은 회원당 ${coupon.campaign.useLimitPerMember}회까지 사용할 수 있습니다.`);
      }

      // ── 유형별 사용권 확보
      if (coupon.campaign.issueType === "SHARED") {
        try {
          await tx.bokjuCouponSharedUsage.create({
            data: { campaignId: coupon.campaignId, couponNo: coupon.couponNo, userId },
          });
        } catch (e) {
          if ((e as { code?: string }).code === "P2002") {
            await logAttempt(tx, coupon.id, coupon.campaignId, userId, "DUPLICATE", "ALREADY_REDEEMED", idempotencyKey);
            return failure("ALREADY_USED", "이미 등록된 쿠폰입니다.");
          }
          throw e;
        }
        const limit = coupon.campaign.sharedTotalLimit ?? 0;
        const updated = await tx.bokjuCouponCampaign.updateMany({
          where: { id: coupon.campaignId, usedCount: { lt: limit } },
          data: { usedCount: { increment: 1 } },
        });
        if (updated.count === 0) {
          throw new BokjuCouponError("SHARED_LIMIT_EXCEEDED", "이벤트 참여 한도가 모두 소진되었습니다.");
        }
        await tx.bokjuCouponRedemption.create({
          data: { couponId: null, campaignId: coupon.campaignId, userId, result: "SUCCESS", requestId: idempotencyKey },
        });
      } else {
        // 개별번호/지정 쿠폰: coupon.status 조건부 UPDATE가 동시 요청을 차단하는 핵심 방어선
        const claimed = await tx.bokjuCoupon.updateMany({
          where: { id: coupon.id, status: coupon.status, rowVersion: coupon.rowVersion },
          data: { status: "REDEEMED", redeemedAt: now, redeemedBy: userId, rowVersion: { increment: 1 } },
        });
        if (claimed.count === 0) {
          // 다른 트랜잭션이 먼저 성공 — 전체 롤백 후 바깥에서 ALREADY_USED로 기록
          throw new DuplicateClaimError();
        }
        await tx.bokjuCouponRedemption.create({
          data: { couponId: coupon.id, campaignId: coupon.campaignId, userId, result: "SUCCESS", requestId: idempotencyKey },
        });
      }

      // ── 복주머니 적립 — 반드시 기존 지갑 엔진을 통해서만
      const earnOutcome = await earnLuckPouch(tx, {
        userId,
        amount: coupon.campaign.grantAmount,
        sourceType: SOURCE_TYPE,
        sourceId: coupon.id,
        memo: `쿠폰 등록 ${maskCouponNo(coupon.couponNo)}`,
      });
      if (earnOutcome.grantedAmount <= 0) {
        // 일일 상한 등으로 실제 지급액이 0이면 쿠폰을 소모 처리하지 않고 롤백한다
        // (쿠폰만 태우고 복주머니를 못 받는 상황 방지).
        throw new BokjuCouponError("WALLET_DAILY_CAP_REACHED", "오늘 복주머니 적립 한도에 도달해 등록할 수 없습니다. 내일 다시 시도해 주세요.");
      }

      const balanceAfter = earnOutcome.balanceAfter ?? 0;
      await tx.bokjuCouponRedemption.update({
        where: { requestId: idempotencyKey },
        data: { grantedAmount: earnOutcome.grantedAmount, balanceAfter },
      });
      if (coupon.campaign.issueType !== "SHARED") {
        await tx.bokjuCouponCampaign.update({
          where: { id: coupon.campaignId },
          data: { redeemedCount: { increment: 1 } },
        });
      }

      return {
        ok: true,
        code: "SUCCESS",
        grantedAmount: earnOutcome.grantedAmount,
        balanceAfter,
        couponNoMasked: maskCouponNo(coupon.couponNo),
        redeemedAt: now.toISOString(),
        replayed: false,
      };
    });
  } catch (err) {
    if (err instanceof DuplicateClaimError) {
      await logFailureOutsideTx(userId, null, null, "DUPLICATE", "ALREADY_REDEEMED", idempotencyKey);
      return failure("ALREADY_USED", "이미 등록된 쿠폰입니다.");
    }
    if (err instanceof BokjuCouponError) throw err;
    throw err;
  }
}

class DuplicateClaimError extends Error {}

function isEligible(
  audience: string,
  isNewMember: boolean | undefined,
  assignedUserId: number | null,
  userId: number
): boolean {
  switch (audience) {
    case "ALL":
      return true;
    case "NEW":
      return isNewMember === true;
    case "EXISTING":
      return isNewMember === false;
    case "SPECIFIC":
      return !!assignedUserId && assignedUserId === userId;
    default:
      return false;
  }
}

async function logAttempt(
  tx: Tx,
  couponId: number | null,
  campaignId: number | null,
  userId: number | null,
  result: string,
  reason: string,
  requestId: string
): Promise<void> {
  try {
    await tx.bokjuCouponRedemption.create({
      data: { couponId, campaignId, userId, result, failReason: reason, requestId },
    });
  } catch (e) {
    if ((e as { code?: string }).code !== "P2002") throw e; // requestId 중복이면 이미 기록된 것이므로 무시
  }
}

async function logFailureOutsideTx(
  userId: number | null,
  couponId: number | null,
  campaignId: number | null,
  result: string,
  reason: string,
  requestId: string
): Promise<void> {
  try {
    await prisma.bokjuCouponRedemption.create({
      data: { couponId, campaignId, userId, result, failReason: reason, requestId },
    });
  } catch {
    /* 로그 실패가 본 흐름을 막지 않도록 무시 */
  }
}

export { randomUUID };
