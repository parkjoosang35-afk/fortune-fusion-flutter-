-- [AI 쿠폰 디자인 표시·숨김 기능] 관리자가 AI에게 배경을 요청하고(BokjuCouponDesignAsset),
-- 배경 + 11개 정보 항목 표시/숨김 설정을 템플릿으로 저장(BokjuCouponDesignTemplate)해
-- 재사용할 수 있게 한다. 캠페인은 customTemplateId로 특정 템플릿을 선택하거나(설정 시
-- 우선 적용), null이면 기존 4종 내장 디자인(design_template 컬럼)을 그대로 쓴다 —
-- 완전한 하위 호환(기존 캠페인/쿠폰은 전혀 영향받지 않음).

CREATE TABLE "bokju_coupon_design_assets" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "prompt" TEXT NOT NULL,
    "image_path" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'READY',
    "fail_reason" TEXT,
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "bokju_coupon_design_templates" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "design_asset_id" INTEGER,
    "visibility" TEXT NOT NULL,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "is_archived" BOOLEAN NOT NULL DEFAULT false,
    "created_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "bokju_coupon_design_templates_design_asset_id_fkey" FOREIGN KEY ("design_asset_id") REFERENCES "bokju_coupon_design_assets" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "bokju_coupon_design_templates_design_asset_id_idx" ON "bokju_coupon_design_templates"("design_asset_id");

-- ── bokju_coupon_campaigns에 custom_template_id(FK, SET NULL) 추가 ──
-- SQLite는 ALTER TABLE ADD COLUMN으로 FK 제약을 추가할 수 없으므로(기존 테이블의
-- redeemed_count/design_template처럼 제약 없는 컬럼 추가와 달리, 이번엔 진짜
-- ON DELETE SET NULL 참조 무결성이 필요 — bokju_coupon_redemptions.campaign_id와
-- 동일한 패턴 유지), SQLite 공식 "12단계 테이블 변경" 절차로 테이블을 재생성한다.
PRAGMA foreign_keys=OFF;

CREATE TABLE "new_bokju_coupon_campaigns" (
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
    "created_by" TEXT,
    "design_template" TEXT NOT NULL DEFAULT 'CLASSIC',
    "custom_template_id" INTEGER,
    CONSTRAINT "bokju_coupon_campaigns_custom_template_id_fkey" FOREIGN KEY ("custom_template_id") REFERENCES "bokju_coupon_design_templates" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

INSERT INTO "new_bokju_coupon_campaigns" (
    "id","title","grant_amount","issue_type","target_audience","use_limit_per_member",
    "shared_total_limit","valid_from","valid_to","guide_text","distribution_method",
    "status","issued_count","allocated_count","redeemed_count","used_count",
    "created_at","updated_at","created_by","design_template"
)
SELECT
    "id","title","grant_amount","issue_type","target_audience","use_limit_per_member",
    "shared_total_limit","valid_from","valid_to","guide_text","distribution_method",
    "status","issued_count","allocated_count","redeemed_count","used_count",
    "created_at","updated_at","created_by","design_template"
FROM "bokju_coupon_campaigns";

DROP TABLE "bokju_coupon_campaigns";
ALTER TABLE "new_bokju_coupon_campaigns" RENAME TO "bokju_coupon_campaigns";

CREATE INDEX "bokju_coupon_campaigns_custom_template_id_idx" ON "bokju_coupon_campaigns"("custom_template_id");

PRAGMA foreign_key_check;
PRAGMA foreign_keys=ON;
