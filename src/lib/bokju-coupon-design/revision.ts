// src/lib/bokju-coupon-design/revision.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 3단계: 디자인 리비전 고정
//
// [목표 — 02d_3단계-리비전고정.md §2] 발행 시점의 디자인을 리비전으로
// 박아 둔다. 디자인을 몇 번을 고쳐도 이미 발행된 쿠폰은 그때 모습 그대로다.
//
// [설계 — 참고 구현의 campaign_design_rev 를 SQLite/Prisma 로] 참고 구현
// (sintong-coupon/src/coupon/issue.service.ts publishDesign/resolveLayoutForCoupon)
// 의 구조를 가져오되, 이 프로젝트(Next.js+Prisma+SQLite) 관행에 맞춘다:
//   · contentHash 유니크 제약으로 "같은 디자인 재발행 시 새 리비전 생성 안 함"
//     을 DB 레벨에서 보장한다(참고 구현에는 없던 안전장치 — 리비전 무한
//     증식 방지, 02d §3-1).
//   · @relation 을 선언하지 않는다(금지 목록 #3) — 조회는 전부 2차 쿼리.
//
// [절대 불가침 — 02d_3단계-리비전고정.md §7 금지 목록]
//   1. 기존 bokju_coupons 212행 / bokju_coupon_campaigns 3행 백필 금지.
//   2. 리비전 행 UPDATE·DELETE 금지 — 이 파일에 그런 함수를 만들지 않는다
//      (freezeRevision() 만 있고 고치는 길이 없다).
//   3. BokjuCouponDesignRevision 에 @relation 선언 금지(스키마 쪽에서 이미
//      스칼라로만 선언함 — 이 파일은 그 스칼라 컬럼으로만 조회한다).
//   4. designRevisionId 를 렌더 시점에 조회하지 않는다 — 발행(쿠폰 행 생성)
//      시점에 이미 각인되어 있어야 하며, 이 파일의 resolveLayoutForCoupon()
//      은 "이미 각인된 값을 읽어 레이아웃을 찾는" 역할만 한다(각인 자체는
//      호출부인 bokju-coupon-service.ts issueCoupons() 가 한다).
//   5. bokju-coupon-image-service.ts / bokju-coupon-visibility.ts 는
//      이 파일에서 import 하지 않는다(완전히 독립된 신규 경로).
//   9. 리비전 테이블에 이미지 경로·바이트를 저장하지 않는다 — layout(JSON)
//      만 저장한다(freezeRevision 의 data.layout 참고).
// ─────────────────────────────────────────────────────────────────────
import { createHash } from 'node:crypto';
import { prisma } from '@/lib/db';
import type { DesignLayout } from './layout';
import { designLayoutSchema } from './layout';

export interface FreezeRevisionResult {
  id: number;
  revNo: number;
  reused: boolean;
}

/**
 * 키 정렬한 JSON → sha256. 같은 디자인이면 객체 키 순서가 달라도 항상
 * 같은 해시가 나온다(JSON.stringify 는 키 순서를 보존하므로, 재귀적으로
 * 키를 정렬한 뒤 직렬화해야 한다).
 */
export function canonicalHash(layout: DesignLayout): string {
  const canonical = sortKeysDeep(layout);
  return createHash('sha256').update(JSON.stringify(canonical)).digest('hex');
}

function sortKeysDeep(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeysDeep);
  if (value !== null && typeof value === 'object') {
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      sorted[key] = sortKeysDeep((value as Record<string, unknown>)[key]);
    }
    return sorted;
  }
  return value;
}

/**
 * 레이아웃 스냅샷을 저장한다. 같은 캠페인에 같은 contentHash 가 이미 있으면
 * 새 행을 만들지 않고 그 리비전을 재사용한다(reused=true) — 리비전 무한
 * 증식 방지(02d §4-1).
 *
 * [동시성] campaignId+contentHash 유니크 제약이 있으므로, 동시에 같은
 * 디자인을 두 번 동결해도 한쪽만 insert 되고 다른 쪽은 P2002 를 잡아
 * 기존 행을 재조회한다(경쟁 조건 안전).
 */
export async function freezeRevision(
  campaignId: number,
  layout: DesignLayout,
  opts: { note?: string; createdBy?: string } = {},
): Promise<FreezeRevisionResult> {
  const parsed = designLayoutSchema.parse(layout); // 저장 전 스키마 검증(유효하지 않은 레이아웃을 리비전으로 박지 않는다)
  const contentHash = canonicalHash(parsed);

  const existing = await prisma.bokjuCouponDesignRevision.findUnique({
    where: { campaignId_contentHash: { campaignId, contentHash } },
  });
  if (existing) {
    return { id: existing.id, revNo: existing.revNo, reused: true };
  }

  try {
    const agg = await prisma.bokjuCouponDesignRevision.aggregate({
      where: { campaignId },
      _max: { revNo: true },
    });
    const revNo = (agg._max.revNo ?? 0) + 1;

    const created = await prisma.bokjuCouponDesignRevision.create({
      data: {
        campaignId,
        revNo,
        layout: JSON.stringify(parsed),
        contentHash,
        note: opts.note,
        createdBy: opts.createdBy,
      },
    });
    return { id: created.id, revNo: created.revNo, reused: false };
  } catch (e) {
    // P2002 = campaignId+contentHash 유니크 제약 충돌(동시 동결 경쟁) →
    // 이미 다른 요청이 만든 행을 재조회해 reused 로 반환한다.
    if ((e as { code?: string }).code === 'P2002') {
      const raced = await prisma.bokjuCouponDesignRevision.findUnique({
        where: { campaignId_contentHash: { campaignId, contentHash } },
      });
      if (raced) return { id: raced.id, revNo: raced.revNo, reused: true };
    }
    throw e;
  }
}

/**
 * 캠페인의 "지금 발행에 쓸 리비전" 포인터를 교체한다. 되돌리기도 이 함수
 * 하나로 가능하다(이전 리비전 id 를 다시 지정하면 된다) — 리비전 행
 * 자체는 절대 수정하지 않고, 캠페인이 "어느 리비전을 가리키는지"만 바꾼다.
 */
export async function setCurrentRevision(campaignId: number, revisionId: number | null): Promise<void> {
  if (revisionId !== null) {
    const rev = await prisma.bokjuCouponDesignRevision.findUnique({ where: { id: revisionId } });
    if (!rev || rev.campaignId !== campaignId) {
      throw new Error(`리비전 ${revisionId} 을(를) 캠페인 ${campaignId} 에서 찾을 수 없습니다.`);
    }
  }
  await prisma.bokjuCouponCampaign.update({
    where: { id: campaignId },
    data: { currentDesignRevisionId: revisionId },
  });
}

/**
 * 쿠폰의 리비전 레이아웃을 반환한다. [금지 목록 #4] 이 함수는 "발행
 * 시점에 이미 각인된 coupon.designRevisionId" 를 읽을 뿐이다 — 렌더
 * 시점에 campaign.currentDesignRevisionId 를 대신 조회하지 않는다
 * (발행과 렌더 사이에 디자인이 바뀌면, 그 조회는 이미 발행된 쿠폰에
 * 새 디자인을 그려버리기 때문 — 02d §3-3 "가장 중요한 한 줄").
 *
 * 리비전이 없으면(레거시 쿠폰, designRevisionId=null) null 을 반환한다 —
 * 호출부가 기존 경로(bokju-coupon-image-service.ts)로 분기해야 한다.
 */
export async function resolveLayoutForCoupon(couponId: number): Promise<DesignLayout | null> {
  const coupon = await prisma.bokjuCoupon.findUnique({
    where: { id: couponId },
    select: { designRevisionId: true },
  });
  if (!coupon || coupon.designRevisionId == null) return null;

  const rev = await prisma.bokjuCouponDesignRevision.findUnique({
    where: { id: coupon.designRevisionId },
  });
  if (!rev) return null; // 데이터 정합성 방어(이론상 FK 없으므로 수동 삭제 시에만 발생) — 레거시 분기로 폴백

  return designLayoutSchema.parse(JSON.parse(rev.layout));
}

/** 언제 무엇이 바뀌었는지 — 캠페인의 전체 리비전 이력(최신순). */
export async function listRevisions(campaignId: number) {
  return prisma.bokjuCouponDesignRevision.findMany({
    where: { campaignId },
    orderBy: { revNo: 'desc' },
    select: { id: true, revNo: true, note: true, createdBy: true, createdAt: true, contentHash: true },
  });
}

// [불변성 — 금지 목록 #2] 이 파일에는 리비전 행을 수정·삭제하는 함수를
// 의도적으로 만들지 않는다. freezeRevision() 만 있고 고치는 길이 없다.
