-- AlterTable
ALTER TABLE "gunghap_invite" ADD COLUMN "expires_at" DATETIME;
ALTER TABLE "gunghap_invite" ADD COLUMN "major_id" TEXT;
ALTER TABLE "gunghap_invite" ADD COLUMN "sub_name" TEXT;

-- AlterTable
ALTER TABLE "gunghap_pair_result" ADD COLUMN "llm_detail_json" TEXT;
ALTER TABLE "gunghap_pair_result" ADD COLUMN "llm_generated_at" DATETIME;
ALTER TABLE "gunghap_pair_result" ADD COLUMN "llm_model" TEXT;
ALTER TABLE "gunghap_pair_result" ADD COLUMN "llm_source" TEXT;
ALTER TABLE "gunghap_pair_result" ADD COLUMN "major_id" TEXT;
ALTER TABLE "gunghap_pair_result" ADD COLUMN "sub_name" TEXT;

-- CreateTable
CREATE TABLE "fortune_period_results" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "kind" TEXT NOT NULL,
    "period_key" TEXT NOT NULL,
    "saju_rev" INTEGER NOT NULL DEFAULT 1,
    "engine_ver" TEXT NOT NULL DEFAULT 'v3.3',
    "payload" TEXT NOT NULL,
    "invalidated" BOOLEAN NOT NULL DEFAULT false,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "fortune_period_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_guinji_map" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "owner_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "invite_status" TEXT NOT NULL DEFAULT 'active',
    "token_issued_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revoked_at" DATETIME,
    "owner_saju_parsed" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "guinji_map_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_guinji_map" ("created_at", "deleted_at", "id", "invite_status", "name", "owner_id", "owner_saju_parsed", "revoked_at", "status", "token", "token_issued_at", "updated_at") SELECT "created_at", "deleted_at", "id", "invite_status", "name", "owner_id", "owner_saju_parsed", "revoked_at", "status", "token", coalesce("token_issued_at", CURRENT_TIMESTAMP) AS "token_issued_at", "updated_at" FROM "guinji_map";
DROP TABLE "guinji_map";
ALTER TABLE "new_guinji_map" RENAME TO "guinji_map";
CREATE UNIQUE INDEX "guinji_map_token_key" ON "guinji_map"("token");
CREATE UNIQUE INDEX "guinji_map_owner_id_key" ON "guinji_map"("owner_id");
CREATE TABLE "new_result_access_transactions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "transaction_id" TEXT NOT NULL,
    "content_type" TEXT NOT NULL,
    "content_id" TEXT,
    "category_key" TEXT,
    "payment_method" TEXT NOT NULL,
    "amount" INTEGER NOT NULL DEFAULT 0,
    "user_pass_id" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "refunded_at" DATETIME,
    "fortune_request_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "result_access_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "result_access_transactions_user_pass_id_fkey" FOREIGN KEY ("user_pass_id") REFERENCES "user_passes" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "result_access_transactions_fortune_request_id_fkey" FOREIGN KEY ("fortune_request_id") REFERENCES "fortune_requests" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_result_access_transactions" ("amount", "category_key", "content_id", "content_type", "created_at", "fortune_request_id", "id", "payment_method", "refunded_at", "status", "transaction_id", "updated_at", "user_id", "user_pass_id") SELECT "amount", "category_key", "content_id", "content_type", "created_at", "fortune_request_id", "id", "payment_method", "refunded_at", "status", "transaction_id", "updated_at", "user_id", "user_pass_id" FROM "result_access_transactions";
DROP TABLE "result_access_transactions";
ALTER TABLE "new_result_access_transactions" RENAME TO "result_access_transactions";
CREATE UNIQUE INDEX "result_access_transactions_transaction_id_key" ON "result_access_transactions"("transaction_id");
CREATE UNIQUE INDEX "result_access_transactions_fortune_request_id_key" ON "result_access_transactions"("fortune_request_id");
CREATE INDEX "result_access_transactions_user_id_created_at_idx" ON "result_access_transactions"("user_id", "created_at");
CREATE INDEX "result_access_transactions_status_idx" ON "result_access_transactions"("status");
CREATE TABLE "new_user_profiles" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "real_name" TEXT,
    "birth_date" TEXT,
    "birth_time" TEXT,
    "is_lunar" BOOLEAN NOT NULL DEFAULT false,
    "is_leap_month" BOOLEAN NOT NULL DEFAULT false,
    "birth_time_unknown" BOOLEAN NOT NULL DEFAULT false,
    "birth_place" TEXT,
    "saju_rev" INTEGER NOT NULL DEFAULT 1,
    "mbti" TEXT,
    "intro_text" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "user_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_user_profiles" ("birth_date", "birth_place", "birth_time", "birth_time_unknown", "created_at", "created_by", "deleted_at", "id", "intro_text", "is_leap_month", "is_lunar", "mbti", "real_name", "status", "updated_at", "updated_by", "user_id") SELECT "birth_date", "birth_place", "birth_time", "birth_time_unknown", "created_at", "created_by", "deleted_at", "id", "intro_text", "is_leap_month", "is_lunar", "mbti", "real_name", "status", "updated_at", "updated_by", "user_id" FROM "user_profiles";
DROP TABLE "user_profiles";
ALTER TABLE "new_user_profiles" RENAME TO "user_profiles";
CREATE UNIQUE INDEX "user_profiles_user_id_key" ON "user_profiles"("user_id");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

-- CreateIndex
CREATE INDEX "fortune_period_results_user_id_kind_created_at_idx" ON "fortune_period_results"("user_id", "kind", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "fortune_period_results_user_id_kind_period_key_saju_rev_key" ON "fortune_period_results"("user_id", "kind", "period_key", "saju_rev");

-- RedefineIndex
DROP INDEX "topic_exposure_history_user_topic_birth_key";
CREATE UNIQUE INDEX "topic_exposure_history_user_id_topic_id_birth_key_key" ON "topic_exposure_history"("user_id", "topic_id", "birth_key");

