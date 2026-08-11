-- [신통방통 복주머니 광고 적립 시스템]
-- 관리자가 등록하는 광고(fortune_ads) + 시청 이력/지급상태(fortune_ad_watch_logs).
-- 지급은 기존 Wallet(POINT)+PointHistory 원장을 그대로 재사용하며(별도 장부 없음),
-- 이 두 테이블은 "노출/보상 설정"과 "중복지급 방지(idempotency)"만 담당한다.

-- ── fortune_ads ──
CREATE TABLE IF NOT EXISTS "fortune_ads" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "ad_type" TEXT NOT NULL,
    "image_url" TEXT,
    "video_url" TEXT,
    "external_url" TEXT,
    "ad_source_html" TEXT,
    "reward_amount" INTEGER NOT NULL DEFAULT 10,
    "watch_seconds" INTEGER NOT NULL DEFAULT 15,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "start_at" DATETIME,
    "end_at" DATETIME,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "per_user_daily_limit" INTEGER NOT NULL DEFAULT 3,
    "daily_limit_reward" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE INDEX "fortune_ads_is_active_status_priority_idx" ON "fortune_ads"("is_active", "status", "priority");

-- ── fortune_ad_watch_logs ──
CREATE TABLE IF NOT EXISTS "fortune_ad_watch_logs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "ad_id" INTEGER NOT NULL,
    "session_id" TEXT NOT NULL,
    "started_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" DATETIME,
    "watch_seconds" INTEGER,
    "reward_amount" INTEGER NOT NULL DEFAULT 0,
    "reward_status" TEXT NOT NULL DEFAULT 'PENDING',
    "idempotency_key" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "fortune_ad_watch_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "fortune_ad_watch_logs_ad_id_fkey" FOREIGN KEY ("ad_id") REFERENCES "fortune_ads" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "fortune_ad_watch_logs_idempotency_key_key" ON "fortune_ad_watch_logs"("idempotency_key");
CREATE INDEX "fortune_ad_watch_logs_user_id_ad_id_created_at_idx" ON "fortune_ad_watch_logs"("user_id", "ad_id", "created_at");
CREATE INDEX "fortune_ad_watch_logs_ad_id_reward_status_created_at_idx" ON "fortune_ad_watch_logs"("ad_id", "reward_status", "created_at");
