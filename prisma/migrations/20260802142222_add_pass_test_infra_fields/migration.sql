-- AlterTable
ALTER TABLE "open_pass_ad_sources" ADD COLUMN "fail_mode" TEXT;
ALTER TABLE "open_pass_ad_sources" ADD COLUMN "simulated_duration_seconds" INTEGER;

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_pass_policies" (
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
    "hero_attachment_id" INTEGER,
    "promo_attachment_id" INTEGER,
    "fallback_attachment_id" INTEGER,
    "display_priority" INTEGER NOT NULL DEFAULT 0,
    "ui_copy" TEXT,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "test_mode_allowed" BOOLEAN NOT NULL DEFAULT true
);
INSERT INTO "new_pass_policies" ("ad_reward_enabled", "banner_image_url", "bonus_point", "created_at", "created_by", "cta_text", "daily_limit", "deleted_at", "description", "display_priority", "duration_min", "fallback_attachment_id", "happy_money_price", "hero_attachment_id", "id", "is_active", "is_featured", "link_url", "name", "pass_type", "promo_attachment_id", "scope", "status", "ui_copy", "updated_at", "updated_by") SELECT "ad_reward_enabled", "banner_image_url", "bonus_point", "created_at", "created_by", "cta_text", "daily_limit", "deleted_at", "description", "display_priority", "duration_min", "fallback_attachment_id", "happy_money_price", "hero_attachment_id", "id", "is_active", "is_featured", "link_url", "name", "pass_type", "promo_attachment_id", "scope", "status", "ui_copy", "updated_at", "updated_by" FROM "pass_policies";
DROP TABLE "pass_policies";
ALTER TABLE "new_pass_policies" RENAME TO "pass_policies";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
