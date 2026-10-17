-- [3단계 — 02d_3단계-리비전고정.md] 쿠폰 디자인 스튜디오 — 발행 시점 디자인
-- 리비전 고정. 순수 추가(additive)만 수행한다 — 신규 테이블 1개 + 기존
-- 테이블 2곳에 nullable 컬럼 1개씩. 기존 데이터 변경 0건.
--
-- [금지 목록 준수]
--   · NOT NULL + DEFAULT 로 기존 테이블을 재작성하지 않는다(ALTER TABLE
--     ADD COLUMN 으로 nullable 컬럼만 추가 — SQLite 가 FK/제약 없는 컬럼
--     추가는 "12단계 테이블 변경" 없이 그대로 지원한다. 20261017010000
--     마이그레이션처럼 FK 가 필요한 경우와 달리, 이번 두 컬럼은 전부
--     @relation 없는 스칼라라 테이블 재생성이 필요 없다).
--   · 기존 bokju_coupons(212행), bokju_coupon_campaigns(3행) 백필 금지 —
--     두 컬럼 모두 기본값을 주지 않아 기존 행은 전부 NULL로 남는다(= 레거시
--     디자인 경로 유지).
--   · 신규 테이블에 campaign_id 에 대한 FOREIGN KEY 선언을 하지 않는다
--     (Prisma 스키마에 @relation 을 선언하지 않았으므로 여기서도 참조
--     무결성 제약을 걸지 않는다 — 조회는 애플리케이션 레벨 2차 쿼리로 한다).

-- ── 1) 신규 테이블: 디자인 리비전 스냅샷 (레이아웃 JSON 만 저장) ──
CREATE TABLE "bokju_coupon_design_revisions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "campaign_id" INTEGER NOT NULL,
    "rev_no" INTEGER NOT NULL,
    "layout" TEXT NOT NULL,
    "content_hash" TEXT NOT NULL,
    "note" TEXT,
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX "bokju_coupon_design_revisions_campaign_id_rev_no_key"
    ON "bokju_coupon_design_revisions"("campaign_id", "rev_no");

CREATE UNIQUE INDEX "bokju_coupon_design_revisions_campaign_id_content_hash_key"
    ON "bokju_coupon_design_revisions"("campaign_id", "content_hash");

-- ── 2) bokju_coupon_campaigns: "지금 발행에 쓸 리비전" 포인터 (nullable) ──
-- 기존 3행은 전부 NULL(레거시) 로 남는다.
ALTER TABLE "bokju_coupon_campaigns" ADD COLUMN "current_design_revision_id" INTEGER;

-- ── 3) bokju_coupons: "이 쿠폰이 발행된 시점"의 리비전 각인 (nullable) ──
-- 기존 212행은 전부 NULL(레거시 디자인으로 발행됨) 로 남는다 — 백필하지
-- 않는다(백필하면 기존 쿠폰이 신규 렌더러를 타게 되어 회귀가 깨진다).
ALTER TABLE "bokju_coupons" ADD COLUMN "design_revision_id" INTEGER;
