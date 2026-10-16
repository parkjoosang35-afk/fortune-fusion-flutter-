-- [복주머니 마케팅 쿠폰 시스템 — 기본 테이블 11종 신규 생성]
-- 배경: 598c1d1 커밋(최초 구현)이 `prisma db push`로만 로컬 dev.db에 반영되고
-- 정식 마이그레이션 파일을 생성하지 않은 채로 이후 작업(a1151aa, d2ded0d)이
-- `ALTER TABLE ... ADD COLUMN`(20261016050000) / 기존 테이블 존재 전제의
-- 테이블 재생성(20261017010000) 마이그레이션을 추가하는 바람에, 운영 서버처럼
-- 이 11개 테이블이 전혀 존재하지 않는 DB에 `prisma migrate deploy`를 실행하면
-- "no such table: bokju_coupon_campaigns" 에러로 실패한다. 이 마이그레이션은
-- 그 누락된 "0번째" 단계를 사후 보완하여, 이후 2개 마이그레이션이 전제하는
-- 컬럼 구성(design_template/custom_template_id 없음 — 각각 다음 두 마이그레이션이
-- 추가)으로 11개 테이블을 생성한다. 로컬 dev.db는 이미 db push로 동일 구조를
-- 갖고 있으므로 `prisma migrate resolve --applied`로 이력만 보정한다.

CREATE TABLE "bokju_partners" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "manager_name" TEXT,
    "manager_contact" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "bokju_partner_accounts" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "partner_id" INTEGER NOT NULL,
    "login_id" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'PARTNER_ADMIN',
    "invite_token" TEXT,
    "invite_expires_at" DATETIME,
    "last_login_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bokju_partner_accounts_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "bokju_partners" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "bokju_partner_accounts_login_id_key" ON "bokju_partner_accounts"("login_id");
CREATE INDEX "bokju_partner_accounts_partner_id_idx" ON "bokju_partner_accounts"("partner_id");

CREATE TABLE "bokju_coupon_campaigns" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "grant_amount" INTEGER NOT NULL,
    "issue_type" TEXT NOT NULL DEFAULT 'INDIVIDUAL',
    "target_audience" TEXT NOT NULL DEFAULT 'ALL',
    "use_limit_per_member" INTEGER NOT NULL DEFAULT 1,
    "shared_total_limit" INTEGER,
    "valid_from" DATETIME NOT NULL,
    "valid_to" DATETIME NOT NULL,
    "guide_text" TEXT,
    "distribution_method" TEXT NOT NULL DEFAULT 'PARTNER',
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "issued_count" INTEGER NOT NULL DEFAULT 0,
    "allocated_count" INTEGER NOT NULL DEFAULT 0,
    "redeemed_count" INTEGER NOT NULL DEFAULT 0,
    "used_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "created_by" TEXT
);

CREATE TABLE "bokju_coupons" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "campaign_id" INTEGER NOT NULL,
    "coupon_no" TEXT NOT NULL,
    "redeem_token" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'CREATED',
    "partner_id" INTEGER,
    "allocation_id" INTEGER,
    "assigned_user_id" INTEGER,
    "issued_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" DATETIME NOT NULL,
    "redeemed_at" DATETIME,
    "redeemed_by" INTEGER,
    "revoked_at" DATETIME,
    "revoked_reason" TEXT,
    "row_version" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "bokju_coupons_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "bokju_coupon_campaigns" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "bokju_coupons_coupon_no_key" ON "bokju_coupons"("coupon_no");
CREATE UNIQUE INDEX "bokju_coupons_redeem_token_key" ON "bokju_coupons"("redeem_token");
CREATE INDEX "bokju_coupons_campaign_id_status_idx" ON "bokju_coupons"("campaign_id", "status");
CREATE INDEX "bokju_coupons_partner_id_status_idx" ON "bokju_coupons"("partner_id", "status");
CREATE INDEX "bokju_coupons_allocation_id_idx" ON "bokju_coupons"("allocation_id");

CREATE TABLE "bokju_coupon_shared_usages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "campaign_id" INTEGER NOT NULL,
    "coupon_no" TEXT NOT NULL,
    "user_id" INTEGER NOT NULL,
    "used_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bokju_coupon_shared_usages_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "bokju_coupon_campaigns" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "bokju_coupon_shared_usages_campaign_id_user_id_key" ON "bokju_coupon_shared_usages"("campaign_id", "user_id");

CREATE TABLE "bokju_coupon_allocations" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "campaign_id" INTEGER NOT NULL,
    "partner_id" INTEGER NOT NULL,
    "allocated_qty" INTEGER NOT NULL,
    "delivered_at" DATETIME,
    "acknowledged_at" DATETIME,
    "distribute_deadline" DATETIME,
    "recalled_qty" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'ALLOCATED',
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bokju_coupon_allocations_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "bokju_coupon_campaigns" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "bokju_coupon_allocations_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "bokju_partners" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "bokju_coupon_allocations_partner_id_status_idx" ON "bokju_coupon_allocations"("partner_id", "status");
CREATE INDEX "bokju_coupon_allocations_campaign_id_idx" ON "bokju_coupon_allocations"("campaign_id");

CREATE TABLE "bokju_coupon_delivery_reports" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "allocation_id" INTEGER NOT NULL,
    "partner_id" INTEGER NOT NULL,
    "reported_qty" INTEGER NOT NULL,
    "reported_date" DATETIME NOT NULL,
    "method" TEXT NOT NULL,
    "note" TEXT,
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bokju_coupon_delivery_reports_allocation_id_fkey" FOREIGN KEY ("allocation_id") REFERENCES "bokju_coupon_allocations" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "bokju_coupon_delivery_reports_allocation_id_idx" ON "bokju_coupon_delivery_reports"("allocation_id");

CREATE TABLE "bokju_coupon_redemptions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "coupon_id" INTEGER,
    "campaign_id" INTEGER,
    "user_id" INTEGER,
    "result" TEXT NOT NULL,
    "fail_reason" TEXT,
    "request_id" TEXT NOT NULL,
    "granted_amount" INTEGER,
    "balance_after" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "bokju_coupon_redemptions_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "bokju_coupon_campaigns" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "bokju_coupon_redemptions_request_id_key" ON "bokju_coupon_redemptions"("request_id");
CREATE INDEX "bokju_coupon_redemptions_user_id_campaign_id_result_idx" ON "bokju_coupon_redemptions"("user_id", "campaign_id", "result");
CREATE INDEX "bokju_coupon_redemptions_campaign_id_result_idx" ON "bokju_coupon_redemptions"("campaign_id", "result");

CREATE TABLE "bokju_coupon_image_jobs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "campaign_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "total_count" INTEGER NOT NULL,
    "processed_count" INTEGER NOT NULL DEFAULT 0,
    "failed_count" INTEGER NOT NULL DEFAULT 0,
    "failed_coupon_ids" TEXT,
    "zip_path" TEXT,
    "excel_path" TEXT,
    "started_at" DATETIME,
    "completed_at" DATETIME,
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "bokju_coupon_image_jobs_campaign_id_idx" ON "bokju_coupon_image_jobs"("campaign_id");

CREATE TABLE "bokju_coupon_audit_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "actor_id" TEXT,
    "actor_type" TEXT NOT NULL DEFAULT 'ADMIN',
    "campaign_id" INTEGER,
    "target_type" TEXT NOT NULL,
    "target_id" INTEGER,
    "action_type" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "payload" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "bokju_coupon_audit_logs_campaign_id_created_at_idx" ON "bokju_coupon_audit_logs"("campaign_id", "created_at");
CREATE INDEX "bokju_coupon_audit_logs_target_type_target_id_idx" ON "bokju_coupon_audit_logs"("target_type", "target_id");

CREATE TABLE "bokju_coupon_push_jobs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "campaign_id" INTEGER NOT NULL,
    "send_mode" TEXT NOT NULL,
    "target_filter" TEXT NOT NULL DEFAULT 'ALL',
    "target_user_ids" TEXT,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "deep_link" TEXT,
    "scheduled_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "success_count" INTEGER NOT NULL DEFAULT 0,
    "fail_count" INTEGER NOT NULL DEFAULT 0,
    "is_test" BOOLEAN NOT NULL DEFAULT false,
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" DATETIME
);
CREATE INDEX "bokju_coupon_push_jobs_campaign_id_idx" ON "bokju_coupon_push_jobs"("campaign_id");
