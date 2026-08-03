-- ═══════════════════════════════════════════════════════════════
-- [재화 구조 정리 - 마이그레이션 drift 캐치업, 2026-08]
-- 이 마이그레이션은 새로운 스키마 변경이 아니라, 과거 개발 과정에서
-- `prisma db push`로 dev.db에 직접 반영되고 마이그레이션 파일 생성이
-- 누락되었던 24개 테이블 + banners/wishes 일부 컬럼을 마이그레이션
-- 이력에 사후 기록하는 것이다. schema.prisma는 이미 이 상태와 100%
-- 일치하며(코드 검증 완료), 라이브 dev.db에도 이미 모두 존재하는
-- 내용이므로 이 파일은 `prisma migrate resolve --applied`로만
-- 적용 기록되고, 실제 SQL은 라이브 DB에 대해 실행되지 않는다
-- (신규 빈 DB로부터 재현할 때만 이 SQL이 실제로 실행됨).
-- ═══════════════════════════════════════════════════════════════

-- ── lucky_number_contents ──
CREATE TABLE IF NOT EXISTS "lucky_number_contents" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "content_type" TEXT NOT NULL DEFAULT 'image',
    "image_url" TEXT,
    "video_url" TEXT,
    "script" TEXT,
    "caption" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE INDEX "lucky_number_contents_is_active_idx" ON "lucky_number_contents"("is_active");

-- ── wish_bokju ──
CREATE TABLE IF NOT EXISTS "wish_bokju" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "wish_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'manual',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_bokju_wish_id_fkey" FOREIGN KEY ("wish_id") REFERENCES "wishes" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_bokju_wish_id_idx" ON "wish_bokju"("wish_id");

-- ── wish_config ──
CREATE TABLE IF NOT EXISTS "wish_config" (
    "key" TEXT NOT NULL PRIMARY KEY,
    "value" TEXT NOT NULL,
    "description" TEXT,
    "updated_at" DATETIME NOT NULL,
    "updated_by" TEXT
);

-- ── wish_reviews ──
CREATE TABLE IF NOT EXISTS "wish_reviews" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "wish_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'visible',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "wish_reviews_wish_id_fkey" FOREIGN KEY ("wish_id") REFERENCES "wishes" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "wish_reviews_wish_id_idx" ON "wish_reviews"("wish_id");

-- ── happy_money_products ──
CREATE TABLE IF NOT EXISTS "happy_money_products" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "cash_price" INTEGER NOT NULL,
    "happy_money_amount" INTEGER NOT NULL,
    "bonus_amount" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "display_priority" INTEGER NOT NULL DEFAULT 0,
    "allowed_usage_scopes" TEXT NOT NULL DEFAULT 'pass,subscription,gift',
    "is_event_grantable" BOOLEAN NOT NULL DEFAULT true,
    "is_manual_grantable" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- ── luck_pouch_rules ──
CREATE TABLE IF NOT EXISTS "luck_pouch_rules" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "rule_type" TEXT NOT NULL,
    "action_type" TEXT NOT NULL,
    "target_scope" TEXT,
    "amount" INTEGER NOT NULL,
    "cash_price" INTEGER,
    "daily_limit" INTEGER,
    "is_purchasable" BOOLEAN NOT NULL DEFAULT false,
    "is_manual_grantable" BOOLEAN NOT NULL DEFAULT true,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "display_priority" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

-- ── luck_pouch_wallets ──
CREATE TABLE IF NOT EXISTS "luck_pouch_wallets" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "balance" INTEGER NOT NULL DEFAULT 0,
    "balance_synced_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "luck_pouch_wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "luck_pouch_wallets_user_id_key" ON "luck_pouch_wallets"("user_id");

-- ── luck_pouch_histories ──
CREATE TABLE IF NOT EXISTS "luck_pouch_histories" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "wallet_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "source_type" TEXT NOT NULL,
    "source_id" INTEGER,
    "balance_after" INTEGER NOT NULL,
    "memo" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "luck_pouch_histories_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "luck_pouch_wallets" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "luck_pouch_histories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "luck_pouch_histories_user_id_created_at_idx" ON "luck_pouch_histories"("user_id", "created_at");
CREATE INDEX "luck_pouch_histories_source_type_source_id_idx" ON "luck_pouch_histories"("source_type", "source_id");

-- ── feature_asset_bindings ──
CREATE TABLE IF NOT EXISTS "feature_asset_bindings" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "scope" TEXT NOT NULL,
    "feature_group" TEXT NOT NULL,
    "primary_asset" TEXT NOT NULL,
    "secondary_assets" TEXT,
    "access_type" TEXT NOT NULL,
    "editable_by_admin" BOOLEAN NOT NULL DEFAULT true,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "updated_by" TEXT
);
CREATE UNIQUE INDEX "feature_asset_bindings_scope_key" ON "feature_asset_bindings"("scope");

-- ── pass_policies ──
CREATE TABLE IF NOT EXISTS "pass_policies" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "pass_type" TEXT NOT NULL,
    "duration_min" INTEGER NOT NULL,
    "daily_limit" INTEGER,
    "cta_text" TEXT,
    "banner_image_url" TEXT,
    "link_url" TEXT,
    "bonus_point" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    "description" TEXT,
    "scope" TEXT NOT NULL DEFAULT 'fortune_today,fortune_tarot,fortune_saju,fortune_compatibility,fortune_face_palm,fortune_theme',
    "happy_money_price" INTEGER,
    "ad_reward_enabled" BOOLEAN NOT NULL DEFAULT true,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "display_priority" INTEGER NOT NULL DEFAULT 0,
    "ui_copy" TEXT
, "fallback_attachment_id" INTEGER, "hero_attachment_id" INTEGER, "promo_attachment_id" INTEGER);

-- ── user_passes ──
CREATE TABLE IF NOT EXISTS "user_passes" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "policy_id" INTEGER NOT NULL,
    "activated_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" DATETIME NOT NULL,
    "source_type" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "revoked_at" DATETIME,
    "scope" TEXT,
    "granted_by_admin_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "user_passes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "user_passes_policy_id_fkey" FOREIGN KEY ("policy_id") REFERENCES "pass_policies" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "user_passes_user_id_expires_at_idx" ON "user_passes"("user_id", "expires_at");

-- ── open_pass_ad_sources ──
CREATE TABLE IF NOT EXISTS "open_pass_ad_sources" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "source_name" TEXT NOT NULL,
    "source_type" TEXT NOT NULL,
    "network_name" TEXT,
    "ad_unit_id" TEXT,
    "placement_id" TEXT,
    "reward_type" TEXT,
    "reward_value" INTEGER,
    "cooldown_seconds" INTEGER NOT NULL DEFAULT 0,
    "daily_limit" INTEGER,
    "failover_enabled" BOOLEAN NOT NULL DEFAULT true,
    "fallback_attachment_id" INTEGER,
    "test_mode_enabled" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE INDEX "open_pass_ad_sources_source_type_is_active_idx" ON "open_pass_ad_sources"("source_type", "is_active");

-- ── open_pass_product_attachments ──
CREATE TABLE IF NOT EXISTS "open_pass_product_attachments" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "pass_policy_id" INTEGER NOT NULL,
    "attachment_id" INTEGER NOT NULL,
    "usage_type" TEXT NOT NULL,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "open_pass_product_attachments_pass_policy_id_fkey" FOREIGN KEY ("pass_policy_id") REFERENCES "pass_policies" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "open_pass_product_attachments_attachment_id_fkey" FOREIGN KEY ("attachment_id") REFERENCES "open_pass_attachments" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "open_pass_product_attachments_pass_policy_id_usage_type_idx" ON "open_pass_product_attachments"("pass_policy_id", "usage_type");
CREATE UNIQUE INDEX "open_pass_product_attachments_pass_policy_id_attachment_id_usage_type_key" ON "open_pass_product_attachments"("pass_policy_id", "attachment_id", "usage_type");

-- ── open_pass_product_ad_sources ──
CREATE TABLE IF NOT EXISTS "open_pass_product_ad_sources" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "pass_policy_id" INTEGER NOT NULL,
    "ad_source_id" INTEGER NOT NULL,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "platform" TEXT NOT NULL DEFAULT 'all',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "open_pass_product_ad_sources_pass_policy_id_fkey" FOREIGN KEY ("pass_policy_id") REFERENCES "pass_policies" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "open_pass_product_ad_sources_ad_source_id_fkey" FOREIGN KEY ("ad_source_id") REFERENCES "open_pass_ad_sources" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "open_pass_product_ad_sources_pass_policy_id_platform_priority_idx" ON "open_pass_product_ad_sources"("pass_policy_id", "platform", "priority");
CREATE UNIQUE INDEX "open_pass_product_ad_sources_pass_policy_id_ad_source_id_platform_key" ON "open_pass_product_ad_sources"("pass_policy_id", "ad_source_id", "platform");

-- ── open_pass_ad_reward_logs ──
CREATE TABLE IF NOT EXISTS "open_pass_ad_reward_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "ad_source_id" INTEGER NOT NULL,
    "pass_policy_id" INTEGER,
    "result" TEXT NOT NULL,
    "reward_granted" BOOLEAN NOT NULL DEFAULT false,
    "user_pass_id" INTEGER,
    "idempotency_key" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "open_pass_ad_reward_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "open_pass_ad_reward_logs_ad_source_id_fkey" FOREIGN KEY ("ad_source_id") REFERENCES "open_pass_ad_sources" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "open_pass_ad_reward_logs_idempotency_key_key" ON "open_pass_ad_reward_logs"("idempotency_key");
CREATE INDEX "open_pass_ad_reward_logs_user_id_ad_source_id_created_at_idx" ON "open_pass_ad_reward_logs"("user_id", "ad_source_id", "created_at");

-- ── open_pass_attachments ──
CREATE TABLE IF NOT EXISTS "open_pass_attachments" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "file_name" TEXT NOT NULL,
    "file_type" TEXT NOT NULL,
    "mime_type" TEXT,
    "file_url" TEXT,
    "thumbnail_url" TEXT,
    "purpose" TEXT NOT NULL,
    "file_size" INTEGER,
    "html_content" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "metadata_json" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE INDEX "open_pass_attachments_purpose_is_active_idx" ON "open_pass_attachments"("purpose", "is_active");

-- ── fortune_category_groups ──
CREATE TABLE IF NOT EXISTS "fortune_category_groups" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "code" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "description" TEXT,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "is_visible" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE UNIQUE INDEX "fortune_category_groups_code_key" ON "fortune_category_groups"("code");

-- ── fortune_categories ──
CREATE TABLE IF NOT EXISTS "fortune_categories" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "category_key" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "short_description" TEXT,
    "group_id" INTEGER,
    "icon" TEXT,
    "hero_image_url" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "is_visible" BOOLEAN NOT NULL DEFAULT true,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "is_featured" BOOLEAN NOT NULL DEFAULT false,
    "badge_label" TEXT,
    "requires_pass" BOOLEAN NOT NULL DEFAULT true,
    "route" TEXT,
    "result_length_hint" TEXT,
    "input_template_id" TEXT,
    "loading_template_id" TEXT,
    "result_template_id" TEXT,
    "paywall_template_id" TEXT,
    "related_category_keys" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "fortune_categories_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "fortune_category_groups" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "fortune_categories_category_key_key" ON "fortune_categories"("category_key");
CREATE UNIQUE INDEX "fortune_categories_slug_key" ON "fortune_categories"("slug");
CREATE INDEX "fortune_categories_group_id_display_order_idx" ON "fortune_categories"("group_id", "display_order");
CREATE INDEX "fortune_categories_is_active_is_visible_idx" ON "fortune_categories"("is_active", "is_visible");

-- ── page_configs ──
CREATE TABLE IF NOT EXISTS "page_configs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "page_key" TEXT NOT NULL,
    "current_published_version_id" INTEGER,
    "current_draft_version_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "page_configs_current_published_version_id_fkey" FOREIGN KEY ("current_published_version_id") REFERENCES "page_versions" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "page_configs_current_draft_version_id_fkey" FOREIGN KEY ("current_draft_version_id") REFERENCES "page_versions" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "page_configs_page_key_key" ON "page_configs"("page_key");

-- ── page_versions ──
CREATE TABLE IF NOT EXISTS "page_versions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "page_key" TEXT NOT NULL,
    "version_number" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'draft',
    "created_by" TEXT,
    "published_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "published_at" DATETIME
);
CREATE INDEX "page_versions_page_key_status_idx" ON "page_versions"("page_key", "status");
CREATE UNIQUE INDEX "page_versions_page_key_version_number_key" ON "page_versions"("page_key", "version_number");

-- ── page_sections ──
CREATE TABLE IF NOT EXISTS "page_sections" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "page_version_id" INTEGER NOT NULL,
    "section_key" TEXT NOT NULL,
    "block_type" TEXT NOT NULL,
    "title" TEXT,
    "subtitle" TEXT,
    "description" TEXT,
    "button_text" TEXT,
    "button_link" TEXT,
    "badge_text" TEXT,
    "empty_state_text" TEXT,
    "style_preset" TEXT NOT NULL DEFAULT 'default',
    "background_preset" TEXT NOT NULL DEFAULT 'white',
    "alignment_preset" TEXT NOT NULL DEFAULT 'left',
    "density_preset" TEXT NOT NULL DEFAULT 'normal',
    "is_visible" BOOLEAN NOT NULL DEFAULT true,
    "status" TEXT NOT NULL DEFAULT 'visible',
    "is_pinned" BOOLEAN NOT NULL DEFAULT false,
    "is_required" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "platform_targets" TEXT,
    "schedule_enabled" BOOLEAN NOT NULL DEFAULT false,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "linked_asset_type" TEXT,
    "linked_feature_scope" TEXT,
    "linked_campaign_id" TEXT,
    "linked_product_id" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "page_sections_page_version_id_fkey" FOREIGN KEY ("page_version_id") REFERENCES "page_versions" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "page_sections_page_version_id_sort_order_idx" ON "page_sections"("page_version_id", "sort_order");
CREATE INDEX "page_sections_page_version_id_section_key_idx" ON "page_sections"("page_version_id", "section_key");

-- ── section_attachment_bindings ──
CREATE TABLE IF NOT EXISTS "section_attachment_bindings" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "section_id" INTEGER NOT NULL,
    "attachment_url" TEXT NOT NULL,
    "usage_type" TEXT NOT NULL,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "section_attachment_bindings_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "page_sections" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "section_attachment_bindings_section_id_usage_type_idx" ON "section_attachment_bindings"("section_id", "usage_type");

-- ── section_display_rules ──
CREATE TABLE IF NOT EXISTS "section_display_rules" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "section_id" INTEGER NOT NULL,
    "rule_type" TEXT NOT NULL,
    "rule_operator" TEXT NOT NULL,
    "rule_value" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "section_display_rules_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "page_sections" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "section_display_rules_section_id_idx" ON "section_display_rules"("section_id");

-- ── page_audit_logs ──
CREATE TABLE IF NOT EXISTS "page_audit_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "admin_id" TEXT,
    "page_key" TEXT NOT NULL,
    "section_id" INTEGER,
    "action_type" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "payload" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "page_audit_logs_page_key_created_at_idx" ON "page_audit_logs"("page_key", "created_at");

-- ── banners: image_url NOT NULL → nullable, ad_type/ad_script 컬럼 추가 ──
-- (SQLite는 ALTER TABLE로 컬럼 제약을 직접 못 바꾸므로 표준 12단계
--  테이블 재작성 패턴을 사용한다: PRAGMA off -> new table -> copy -> drop -> rename -> index -> pragma on)
PRAGMA foreign_keys=OFF;

CREATE TABLE "new_banners" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "image_url" TEXT,
    "link_url" TEXT,
    "ad_type" TEXT NOT NULL DEFAULT 'image',
    "ad_script" TEXT,
    "position_code" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);

INSERT INTO "new_banners" ("id","title","image_url","link_url","position_code","sort_order","is_active","start_at","end_at","status","created_at","updated_at","deleted_at","created_by","updated_by")
SELECT "id","title","image_url","link_url","position_code","sort_order","is_active","start_at","end_at","status","created_at","updated_at","deleted_at","created_by","updated_by" FROM "banners";

DROP TABLE "banners";
ALTER TABLE "new_banners" RENAME TO "banners";
CREATE INDEX "banners_position_code_is_active_idx" ON "banners"("position_code", "is_active");

PRAGMA foreign_keys=ON;

-- ── wishes: 소원성(Wish Castle) 확장 필드 추가 (goal_tag/candle_level/bokju_count/is_milestone_shown/achieved_at) ──
ALTER TABLE "wishes" ADD COLUMN "goal_tag" TEXT;
ALTER TABLE "wishes" ADD COLUMN "candle_level" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "wishes" ADD COLUMN "bokju_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "wishes" ADD COLUMN "is_milestone_shown" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "wishes" ADD COLUMN "achieved_at" DATETIME;
